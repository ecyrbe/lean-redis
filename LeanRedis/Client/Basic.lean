import LeanRedis.Client.Internal
import LeanRedis.Pipeline.Basic

namespace LeanRedis.Client

open Std.Internal.IO.Async
open LeanRedis

private def eventMetadata
    (error? : Option Error := none)
    (attempt? : Option Nat := none)
    : Async Client.EventMetadata := do
  pure {
    timestamp := ← Std.Time.PlainDateTime.now
    error?
    attempt?
  }

private def emitEvent (client : Client τ) (event : Client.Event) : Async Unit := do
  let handlers <- client.subscribers.atomically fun ref => do
    let subscribers <- ref.get
    pure subscribers.handlers
  for (_, handler) in handlers do
    discard <| IO.asTask do
      let _ <- (handler event).block
      pure ()

private def getStatus (client : Client τ) : Async ClientConnectionStatus :=
  client.status.atomically fun ref => ref.get

private def setStatus (client : Client τ) (status : ClientConnectionStatus) : Async Unit :=
  client.status.atomically fun ref => ref.set status

private def getManager (client : Client τ) : Async (Connection.Manager τ) :=
  client.manager.atomically fun ref => ref.get

private def setManager (client : Client τ) (manager : Connection.Manager τ) : Async Unit :=
  client.manager.atomically fun ref => ref.set manager

private def modifyManager (client : Client τ) (f : Connection.Manager τ -> Connection.Manager τ) : Async Unit :=
  client.manager.atomically fun ref => ref.modify f

private def nextReconnectGeneration (client : Client τ) : Async Nat :=
  client.reconnectControl.atomically fun ref => do
    let control <- ref.get
    let next := control.generation + 1
    ref.set { generation := next }
    pure next

private def currentReconnectGeneration (client : Client τ) : Async Nat :=
  client.reconnectControl.atomically fun ref => do
    let control <- ref.get
    pure control.generation

private def statusErrorMessage : ClientConnectionStatus -> String
  | .disconnected => "client is not connected"
  | .connecting => "client is connecting"
  | .connected => "client is connected"
  | .reconnecting => "client is reconnecting"
  | .closed => "client is disconnected"

private def closeRuntimeIfPresent [Transport.Transport τ]
    (manager : Connection.Manager τ)
    : Async (Connection.Manager τ) := do
  match manager.runtime? with
  | some runtime =>
      try
        Connection.Runtime.close runtime
      catch _ =>
        pure ()
      pure { manager with runtime? := none, session := manager.session.markDisconnected }
  | none =>
      pure { manager with session := manager.session.markDisconnected }

private partial def reconnectLoop [Transport.Transport τ]
    (client : Client τ)
    (generation : Nat)
    (attempt : Nat)
    : Async Unit := do
  if (← currentReconnectGeneration client) != generation then
    pure ()
  else
    let attemptNumber := attempt + 1
    let started <- eventMetadata (attempt? := some attemptNumber)
    emitEvent client <| .reconnectAttemptStarted started
    let reconnectResult <- client.operation.atomically fun _ => do
      if (← currentReconnectGeneration client) != generation then
        pure <| Except.error none
      else
        let status <- getStatus client
        if status != ClientConnectionStatus.reconnecting then
          pure <| Except.error none
        else
          let manager <- getManager client
          try
            let manager <- Connection.Manager.connect manager
            setManager client manager
            setStatus client ClientConnectionStatus.connected
            pure <| Except.ok ()
          catch err =>
            let manager <- closeRuntimeIfPresent manager
            setManager client manager
            pure <| Except.error (some err)
    match reconnectResult with
    | .ok _ =>
        let metadata <- eventMetadata (attempt? := some attemptNumber)
        emitEvent client <| .reconnected metadata
    | .error none =>
        pure ()
    | .error (some err) =>
        let failure : Error := .transport err.toString
        let failed <- eventMetadata (some failure) (some attemptNumber)
        emitEvent client <| .reconnectAttemptFailed failed
        let manager <- getManager client
        match ← manager.config.reconnectStrategy.delayMs attemptNumber with
        | none =>
            if (← currentReconnectGeneration client) == generation then
              setStatus client ClientConnectionStatus.disconnected
              let stopped <- eventMetadata (some failure) (some attemptNumber)
              emitEvent client <| .reconnectStopped stopped
        | some delayMs =>
            let scheduled <- eventMetadata (some failure) (some (attemptNumber + 1))
            emitEvent client <| .reconnectScheduled delayMs scheduled
            IO.sleep delayMs
            reconnectLoop client generation (attempt + 1)

private def startReconnectWorker [Transport.Transport τ]
    (client : Client τ)
    (generation : Nat)
    : Async Unit := do
  discard <| IO.asTask do
    let _ <- (reconnectLoop client generation 0).block
    pure ()

def stateAfterReply
    (manager : Connection.Manager τ)
    (request : CommandRequest)
    (reply : Protocol.Resp.Value)
    : Engine.State :=
  match request.selectedDb? with
  | some database =>
      {
        manager.session.state with
        selectedDb? := some database
        lastReply? := some reply
      }
  | none =>
      { manager.session.state with lastReply? := some reply }

private def handleRemoteDisconnect [Transport.Transport τ]
    (client : Client τ)
    (manager : Connection.Manager τ)
    (reason : Transport.DisconnectReason)
    (err : Error)
    : Async Unit := do
  let manager <- closeRuntimeIfPresent manager
  setManager client manager
  let disconnected <- eventMetadata (some err)
  emitEvent client <| .remoteDisconnected reason disconnected
  match manager.config.reconnectStrategy with
  | .disabled =>
      setStatus client .disconnected
      let stopped <- eventMetadata (some err)
      emitEvent client <| .reconnectStopped stopped
  | _ =>
      setStatus client .reconnecting
      let generation <- nextReconnectGeneration client
      startReconnectWorker client generation

public def executeWithManagerUpdate [Transport.Transport τ]
    (client : Client τ)
    (request : CommandRequest)
    (updateManager : Connection.Manager τ -> Protocol.Resp.Value -> Async (Connection.Manager τ))
    : Async Protocol.Resp.Value := do
  client.operation.atomically fun _ => do
    let status <- getStatus client
    unless status == .connected do
      Error.raise <| .unavailable (statusErrorMessage status)
    let manager <- getManager client
    let some runtime := manager.runtime?
      | do
          setStatus client .disconnected
          Error.raise <| .unavailable "client is not connected"
    let (result, runtime) ← (Connection.Runtime.tryExecute request).run runtime
    match result with
    | .ok reply =>
        let manager := {
          manager with
          runtime? := some runtime
          session := { state := stateAfterReply manager request reply }
        }
        let manager <- updateManager manager reply
        setManager client manager
        pure reply
    | .error (.remoteDisconnect reason err) =>
        handleRemoteDisconnect client manager reason err
        Error.raise err
    | .error (.commandError err) =>
        Error.raise err

public def execute [Transport.Transport τ]
    (client : Client τ)
    (request : CommandRequest)
    : Async Protocol.Resp.Value :=
  executeWithManagerUpdate client request fun manager _ => pure manager

/--
Execute a pipeline.

Example:
```lean
 (a,b,_) ← client.runPipeline <| Pipeline.empty |>.get "hello" |>.set "bar" "baz" |>.get "bar"
```
-/
public def runPipeline
  [Transport.Transport τ]
  (client : Client τ)
  (pipeline : Pipeline α) : Async (HList α) := do
  client.operation.atomically fun _ => do
    let status <- getStatus client
    unless status == .connected do
      Error.raise <| .unavailable (statusErrorMessage status)
    let manager ← client.getManager
    match ← manager.tryRunPipeline pipeline with
    | .ok (manager', decoded) =>
        client.setManager manager'
        pure decoded
    | .error (.commandError err) =>
        Error.raise err
    | .error (.remoteDisconnect reason err) =>
        Client.handleRemoteDisconnect client manager reason err
        Error.raise err

/--
Create a new client value for the given transport type without opening a connection.

Example:
```lean
let client : LeanRedis.Client MyTransport <- LeanRedis.Client.new cfg
```
-/
public def new [Transport.Transport τ] (config : Config) : IO (Client τ) := do
  let manager <- Std.Mutex.new (Connection.Manager.new config : Connection.Manager τ)
  let operation <- Std.Mutex.new ()
  let status <- Std.Mutex.new ClientConnectionStatus.disconnected
  let reconnectControl <- Std.Mutex.new {}
  let subscribers <- Std.Mutex.new {}
  pure { manager, operation, status, reconnectControl, subscribers }

/--
Create a new client using the default TCP transport without opening a connection.

Example:
```lean
let client <- LeanRedis.Client.newDefault {
  endpoint := { host := "127.0.0.1", port := 6379 }
}
```
-/
public def newDefault (config : Config) : IO (Client Transport.TCP) :=
  Client.new config

/--
Open the transport and run Redis bootstrap for an existing client.

If a reconnect wait is in progress, this cancels it logically and tries immediately.

Example:
```lean
let _ <- client.connect
```
-/
def connect (client : Client τ) [Transport.Transport τ] : Async Unit := do
  client.operation.atomically fun _ => do
    let _ <- Client.nextReconnectGeneration client
    let status <- Client.getStatus client
    if status == .connected then
      pure ()
    else
      Client.setStatus client .connecting
      let manager <- Client.getManager client
      try
        let manager <- manager.connect
        Client.setManager client manager
        Client.setStatus client .connected
      catch err =>
        let manager <- Client.closeRuntimeIfPresent manager
        Client.setManager client manager
        Client.setStatus client .disconnected
        let failed <- Client.eventMetadata (some (.transport err.toString))
        Client.emitEvent client <| .initialConnectFailed failed
        throw err

/--
Close the current connection and stop background reconnects until a later explicit `connect`.

Example:
```lean
let _ <- client.disconnect
```
-/
def disconnect [Transport.Transport τ] (client : Client τ) : Async Unit := do
  client.operation.atomically fun _ => do
    let _ <- Client.nextReconnectGeneration client
    let manager <- Client.getManager client
    let manager <- manager.disconnect
    Client.setManager client manager
    Client.setStatus client .closed
    let metadata <- Client.eventMetadata
    Client.emitEvent client <| .explicitlyDisconnected metadata

/--
Return `true` when the client currently has a ready runtime.

Example:
```lean
let connected <- client.isConnected
```
-/
def isConnected (client : Client τ) : Async Bool := do
  pure ((← Client.getStatus client) == .connected)

/--
Return the current lifecycle status of the client.

Example:
```lean
let status <- client.connectionStatus
```
-/
def connectionStatus (client : Client τ) : Async ClientConnectionStatus :=
  Client.getStatus client

/--
Fail with an `unavailable` error unless the client is connected.

Example:
```lean
let _ <- client.requireConnected
```
-/
def requireConnected [Transport.Transport τ] (client : Client τ) : Async Unit := do
  let status <- Client.getStatus client
  unless status == .connected do
    Error.raise <| .unavailable (Client.statusErrorMessage status)

/--
Read the current internal connection state tracked by the client.

Example:
```lean
let state <- client.currentState
```
-/
def currentState (client : Client τ) : Async Engine.State := do
  let manager <- Client.getManager client
  pure manager.session.state

/--
Subscribe an async handler to client connection lifecycle events.

Returns a subscription id that can later be passed to `offEvent`.

Example:
```lean
let sub <- client.onEvent fun event => do
  IO.println s!"{repr event}"
```
-/
def onEvent (client : Client τ) (handler : Client.EventHandler) : IO ClientEventSubscriptionId :=
  client.subscribers.atomically fun ref => do
    let subscribers <- ref.get
    let id := subscribers.nextId
    ref.set {
      nextId := id + 1
      handlers := subscribers.handlers.push (id, handler)
    }
    pure id

/--
Remove a previously registered event handler.

Example:
```lean
let sub <- client.onEvent fun _ => pure ()
client.offEvent sub
```
-/
def offEvent (client : Client τ) (subscriptionId : ClientEventSubscriptionId) : IO Unit :=
  client.subscribers.atomically fun ref => do
    let subscribers <- ref.get
    ref.set {
      subscribers with
      handlers := subscribers.handlers.filter fun (id, _) => id != subscriptionId
    }

end LeanRedis.Client
