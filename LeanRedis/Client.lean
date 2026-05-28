import Std.Sync.Mutex
import LeanRedis.Connection.Manager
import LeanRedis.Connection.Runtime
import LeanRedis.Error
import LeanRedis.Transport.Tcp

namespace LeanRedis

open Std.Internal.IO.Async

abbrev Async := Std.Internal.IO.Async.Async

structure Client (τ : Type) where
  manager : Std.Mutex (Connection.Manager τ)

private def liftIO {α : Type} (action : IO α) : Async α :=
  Std.Internal.IO.Async.EAsync.lift action

private def withManager [Transport.Transport τ]
    (client : Client τ)
    (action : Connection.Manager τ -> Async (α × Connection.Manager τ))
    : Async α := do
  let manager <- liftIO <| client.manager.atomically fun ref => ref.get
  let (result, manager) <- action manager
  liftIO <| client.manager.atomically fun ref => ref.set manager
  pure result

private def expectOk (reply : Protocol.Resp.Value) : Async Unit := do
  match reply with
  | .simpleString "OK" => pure ()
  | .blobString bytes =>
      match String.fromUTF8? bytes with
      | some "OK" => pure ()
      | _ => Error.raise <| .decode "expected OK reply"
  | .simpleError message => Error.raise <| .server message
  | _ => Error.raise <| .decode "expected OK reply"

private def expectPong (reply : Protocol.Resp.Value) : Async (Option String) := do
  match reply with
  | .simpleString "PONG" => pure none
  | .blobString bytes =>
      match String.fromUTF8? bytes with
      | some text => pure (some text)
      | none => Error.raise <| .decode "invalid UTF-8 in PING reply"
  | .simpleString text => pure (some text)
  | .simpleError message => Error.raise <| .server message
  | _ => Error.raise <| .decode "unexpected PING reply"

private def stateAfterReply
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

private def execute [Transport.Transport τ]
    (client : Client τ)
    (request : CommandRequest)
    : Async Protocol.Resp.Value :=
  withManager client fun manager => do
    let manager := manager.notePending request
    manager.withRuntime fun runtime => do
      let (reply, runtime) <- Connection.Runtime.execute runtime request
      pure (reply, runtime, stateAfterReply manager request reply)

def Client.connectWith [Transport.Transport τ] (config : Config) : Async (Client τ) := do
  let manager <- liftIO <| Std.Mutex.new (Connection.Manager.new config : Connection.Manager τ)
  pure { manager }

def Client.connect (config : Config) : Async (Client Transport.TCP) :=
  Client.connectWith config

def Client.connectNow (client : Client τ) [Transport.Transport τ] : Async (Client τ) := do
  let _ <- withManager client fun manager => do
    let manager <- manager.connect
    pure ((), manager)
  pure client

def Client.connectNowWith [Transport.Transport τ] (config : Config) : Async (Client τ) := do
  let client <- Client.connectWith config
  Client.connectNow client

def Client.connectNowDefault (config : Config) : Async (Client Transport.TCP) := do
  let client <- Client.connect config
  Client.connectNow client

def Client.disconnect [Transport.Transport τ] (client : Client τ) : Async Unit := do
  let _ <- withManager client fun manager => do
    let manager <- manager.disconnect
    pure ((), manager)
  pure ()

def Client.isConnected (client : Client τ) : Async Bool := do
  liftIO <| client.manager.atomically fun ref => do
    let manager <- ref.get
    pure manager.isConnected

def Client.requireConnected [Transport.Transport τ] (client : Client τ) : Async Unit := do
  unless (← Client.isConnected client) do
    Error.raise <| .unavailable "client is not connected"

def Client.ping [Transport.Transport τ]
    (client : Client τ)
    (message? : Option String := none)
    : Async (Option String) := do
  let reply <- execute client <| CommandRequest.ping message?
  expectPong reply

def Client.select [Transport.Transport τ]
    (client : Client τ)
    (database : UInt32)
    : Async Unit := do
  let reply <- execute client <| CommandRequest.select database
  expectOk reply

def Client.currentState (client : Client τ) : Async Engine.State := do
  liftIO <| client.manager.atomically fun ref => do
    let manager <- ref.get
    pure manager.session.state

end LeanRedis
