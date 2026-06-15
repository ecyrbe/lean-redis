import LeanRedis.Client.Internal
import LeanRedis.Connection.Driver
import LeanRedis.Pipeline.Basic
import LeanRedis.Transport.Tcp
import LeanRedis.Transport.Types

namespace LeanRedis.Client

open Std.Internal.IO.Async
open LeanRedis
open LeanRedis.Connection
open LeanRedis.Transport

private def eventMetadata
    (error? : Option Error := none)
    (attempt? : Option Nat := none)
    : Async Client.EventMetadata := do
  pure {
    timestamp := (<- Std.Time.PlainDateTime.now)
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

private def emitEffect (client : Client τ) (tag : Protocol.EventTag) : Async Unit := do
  let metadata <- eventMetadata
  let event := match tag with
    | .initialConnectFailed => .initialConnectFailed metadata
    | .remoteDisconnected => .remoteDisconnected .closedByPeer metadata
    | .reconnectAttemptStarted => .reconnectAttemptStarted metadata
    | .reconnectAttemptFailed => .reconnectAttemptFailed metadata
    | .reconnected => .reconnected metadata
    | .reconnectStopped => .reconnectStopped metadata
    | .explicitlyDisconnected => .explicitlyDisconnected metadata
  emitEvent client event

private def executeEffects (client : Client τ) (effects : Array Protocol.Effect) : Async Unit :=
  for eff in effects do
    match eff with
    | .emit tag => emitEffect client tag
    | _ => pure ()

private def getState (client : Client τ) : Async (DriverState τ) :=
  client.state.atomically fun ref => ref.get

private def setState (client : Client τ) (state : DriverState τ) : Async Unit :=
  client.state.atomically fun ref => ref.set state

private partial def doReconnectAttempt [Transport.Transport τ]
    (client : Client τ)
    : Async Unit := do
  let state <- getState client
  match state.session.phase with
  | .reconnecting _ =>
      let (session, preEffects) := state.session.step .reconnectTick state.config
      setState client { state with session }
      executeEffects client preEffects
      match session.phase with
      | .connecting _ =>
          try
            let transport ← Transport.Transport.connect state.config.endpoint
            let (state', postEffects) <- LeanRedis.Connection.connectBootstrap transport state.config { state with session }
            setState client state'
            executeEffects client postEffects
          catch err =>
            let state <- getState client
            let (session, effects) := state.session.step (.transportFailed err.toString) state.config
            setState client { state with session }
            executeEffects client effects
            if session.phase matches .reconnecting _ then
              doReconnectAttempt client
            else
              pure ()
      | _ => pure ()
  | _ => pure ()

private partial def handleReconnectDelay [Transport.Transport τ]
    (client : Client τ)
    (attemptNumber : Nat)
    (delayMs : UInt32)
    : Async Unit := do
  let scheduled <- eventMetadata (attempt? := some attemptNumber)
  emitEvent client (.reconnectScheduled delayMs scheduled)
  IO.sleep delayMs
  doReconnectAttempt client

private partial def handleReconnectExhausted [Transport.Transport τ]
    (client : Client τ)
    (state : DriverState τ)
    : Async Unit := do
  let (session, effects) := state.session.step .reconnectExhausted state.config
  setState client { state with session }
  executeEffects client effects

private partial def handleReconnectIteration [Transport.Transport τ]
    (client : Client τ)
    (state : DriverState τ)
    : Async Unit := do
  let n := match state.session.phase with | .reconnecting n => n | _ => 0
  let attemptNumber := n + 1
  let delayMs? <- state.config.reconnectStrategy.delayMs n
  match delayMs? with
  | none => handleReconnectExhausted client state
  | some delayMs => handleReconnectDelay client attemptNumber delayMs

private partial def reconnectLoop [Transport.Transport τ]
    (client : Client τ)
    (attempt : Nat)
    : Async Unit := do
  let state <- getState client
  match state.session.phase with
  | .reconnecting n =>
      if n != attempt then pure ()
      else handleReconnectIteration client state
  | _ => pure ()

private def startReconnectWorker [Transport.Transport τ]
    (client : Client τ)
    : Async Unit := do
  discard <| IO.asTask do
    let _ <- (reconnectLoop client 0).block
    pure ()

/--
Execute a single command and return its Redis response value.

Example:
```lean
let reply <- client.execute (Command.ping ()).request
```
-/
public def execute [Transport.Transport τ]
    (client : Client τ)
    (request : CommandRequest)
    : Async Protocol.Resp.Value := do
  client.state.atomically fun ref => do
    let state <- ref.get
    match state.session.phase with
    | .ready _ _ =>
        try
          let (state', reply) <- executeCommand request state
          ref.set state'
          pure reply
        catch
          | err =>
            if Error.isTransportIOError err then
              let (session, effects) := state.session.step .remoteDisconnect state.config
              ref.set { state with session }
              executeEffects client effects
              startReconnectWorker client
            throw err
    | _ => Error.raise <| .unavailable "client is not connected"

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
    (pipeline : Pipeline α)
    : Async (HList α) := do
  client.state.atomically fun ref => do
    let state <- ref.get
    match state.session.phase with
    | .ready _ _ =>
        try
          let (state', values) <- executeBatch pipeline.requests state
          ref.set state'
          match pipeline.exec values with
          | .ok decoded => pure decoded
          | .error err => Error.raise err
        catch
          | err =>
            if Error.isTransportIOError err then
              let (session, effects) := state.session.step .remoteDisconnect state.config
              ref.set { state with session }
              executeEffects client effects
              startReconnectWorker client
            throw err
    | _ => Error.raise <| .unavailable "client is not connected"

/--
Create a new client value for the given transport type without opening a connection.

Example:
```lean
let client : LeanRedis.Client MyTransport <- LeanRedis.Client.new cfg
```
-/
public def new [Transport.Transport τ] (config : Config) : IO (Client τ) := do
  let state <- Std.Mutex.new ({ config } : DriverState τ)
  let subscribers <- Std.Mutex.new ({} : ClientSubscribers)
  pure { state, subscribers }

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
def connect [Transport.Transport τ] (client : Client τ) : Async Unit := do
  client.state.atomically fun ref => do
    let state <- ref.get
    match state.session.phase with
    | .disconnected | .failed _ =>
        let (session, _) := state.session.step .requestConnect state.config
        ref.set { state with session }
        try
          let transport ← Transport.Transport.connect state.config.endpoint
          let (state', effects) <- LeanRedis.Connection.connectBootstrap transport state.config { state with session }
          ref.set state'
          executeEffects client effects
        catch err =>
          let state <- ref.get
          let (session, effects) := state.session.step (.transportFailed err.toString) state.config
          ref.set { state with session }
          executeEffects client effects
          throw err
    | _ => pure ()

/--
Close the current connection and stop background reconnects until a later explicit `connect`.

Example:
```lean
let _ <- client.disconnect
```
-/
def disconnect [Transport.Transport τ] (client : Client τ) : Async Unit := do
  client.state.atomically fun ref => do
    let state <- ref.get
    let (session, effects) := state.session.step .requestDisconnect state.config
    executeEffects client effects
    match state.transport? with
    | some transport => Transport.close transport
    | none => pure ()
    let (session, _) := session.step .closeComplete state.config
    ref.set { transport? := none, parser := {}, session := session, config := state.config }

/--
Return `true` when the client currently has a ready runtime.

Example:
```lean
let connected <- client.isConnected
```
-/
def isConnected (client : Client τ) : Async Bool := do
  let state <- getState client
  pure state.session.isReady

/--
Return the current lifecycle status of the client.

Example:
```lean
let status <- client.connectionStatus
```
-/
def connectionStatus (client : Client τ) : Async Protocol.Phase := do
  let state <- getState client
  pure state.session.phase

/--
Fail with an `unavailable` error unless the client is connected.

Example:
```lean
let _ <- client.requireConnected
```
-/
def requireConnected [Transport.Transport τ] (client : Client τ) : Async Unit := do
  let state <- getState client
  unless state.session.isReady do
    Error.raise <| .unavailable "client is not connected"

/--
Read the current internal connection state tracked by the client.

Example:
```lean
let state <- client.currentState
```
-/
def currentState (client : Client τ) : Async Protocol.Session := do
  let state <- getState client
  pure state.session

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
