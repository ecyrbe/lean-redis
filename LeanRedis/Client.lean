import Std.Sync.Mutex
import LeanRedis.Connection.Manager
import LeanRedis.Connection.Runtime
import LeanRedis.Error
import LeanRedis.Transport.Tcp

namespace LeanRedis

open Std.Internal.IO.Async

structure Client (τ : Type) where
  manager : Std.Mutex (Connection.Manager τ)

private def liftIO {α : Type} (action : IO α) : Async α :=
  EAsync.lift action

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

private def expectStored (reply : Protocol.Resp.Value) : Async Bool := do
  match reply with
  | .simpleString "OK" => pure true
  | .blobString bytes =>
      match String.fromUTF8? bytes with
      | some "OK" => pure true
      | _ => Error.raise <| .decode "expected OK reply"
  | .null => pure false
  | .simpleError message => Error.raise <| .server message
  | _ => Error.raise <| .decode "unexpected SET reply"

private def decodeUtf8 (context : String) (bytes : ByteArray) : Async String := do
  match String.fromUTF8? bytes with
  | some text => pure text
  | none => Error.raise <| .decode s!"invalid UTF-8 in {context} reply"

private def expectOptionalString (context : String) (reply : Protocol.Resp.Value) : Async (Option String) := do
  match reply with
  | .null => pure none
  | .blobString bytes =>
      let text <- decodeUtf8 context bytes
      pure (some text)
  | .simpleString text => pure (some text)
  | .simpleError message => Error.raise <| .server message
  | _ => Error.raise <| .decode s!"unexpected {context} reply"

private def expectString (context : String) (reply : Protocol.Resp.Value) : Async String := do
  match (← expectOptionalString context reply) with
  | some text => pure text
  | none => Error.raise <| .decode s!"unexpected null {context} reply"

private def expectInteger (context : String) (reply : Protocol.Resp.Value) : Async Int := do
  match reply with
  | .number value => pure value
  | .simpleError message => Error.raise <| .server message
  | _ => Error.raise <| .decode s!"unexpected {context} reply"

private def expectBoolean (context : String) (reply : Protocol.Resp.Value) : Async Bool := do
  match reply with
  | .bool value => pure value
  | .number value => pure (value != 0)
  | .simpleError message => Error.raise <| .server message
  | _ => Error.raise <| .decode s!"unexpected {context} reply"

private def expectStringArray (context : String) (reply : Protocol.Resp.Value) : Async (Array (Option String)) := do
  match reply with
  | .array items =>
      items.mapM (expectOptionalString context)
  | .simpleError message => Error.raise <| .server message
  | _ => Error.raise <| .decode s!"unexpected {context} reply"

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

def Client.auth [Transport.Transport τ]
    (client : Client τ)
    (auth : AuthConfig)
    : Async Unit := do
  let reply <- execute client <| CommandRequest.auth auth
  expectOk reply

def Client.select [Transport.Transport τ]
    (client : Client τ)
    (database : UInt32)
    : Async Unit := do
  let reply <- execute client <| CommandRequest.select database
  expectOk reply

def Client.get [Transport.Transport τ]
    (client : Client τ)
    (key : String)
    : Async (Option String) := do
  let reply <- execute client <| CommandRequest.get key
  expectOptionalString "GET" reply

def Client.set [Transport.Transport τ]
    (client : Client τ)
    (key value : String)
    (options : SetOptions := {})
    : Async Bool := do
  let reply <- execute client <| CommandRequest.set key value options
  expectStored reply

def Client.mGet [Transport.Transport τ]
    (client : Client τ)
    (keys : Array String)
    : Async (Array (Option String)) := do
  let reply <- execute client <| CommandRequest.mGet keys
  expectStringArray "MGET" reply

def Client.mSet [Transport.Transport τ]
    (client : Client τ)
    (entries : Array (String × String))
    : Async Unit := do
  let reply <- execute client <| CommandRequest.mSet entries
  expectOk reply

def Client.mSetNx [Transport.Transport τ]
    (client : Client τ)
    (entries : Array (String × String))
    : Async Bool := do
  let reply <- execute client <| CommandRequest.mSetNx entries
  expectBoolean "MSETNX" reply

def Client.getDel [Transport.Transport τ]
    (client : Client τ)
    (key : String)
    : Async (Option String) := do
  let reply <- execute client <| CommandRequest.getDel key
  expectOptionalString "GETDEL" reply

def Client.getEx [Transport.Transport τ]
    (client : Client τ)
    (key : String)
    (mode? : Option GetExMode := none)
    : Async (Option String) := do
  let reply <- execute client <| CommandRequest.getEx key mode?
  expectOptionalString "GETEX" reply

def Client.getRange [Transport.Transport τ]
    (client : Client τ)
    (key : String)
    (start stop : Int)
    : Async String := do
  let reply <- execute client <| CommandRequest.getRange key start stop
  expectString "GETRANGE" reply

def Client.getSet [Transport.Transport τ]
    (client : Client τ)
    (key value : String)
    : Async (Option String) := do
  let reply <- execute client <| CommandRequest.getSet key value
  expectOptionalString "GETSET" reply

def Client.setRange [Transport.Transport τ]
    (client : Client τ)
    (key : String)
    (offset : UInt64)
    (value : String)
    : Async Int := do
  let reply <- execute client <| CommandRequest.setRange key offset value
  expectInteger "SETRANGE" reply

def Client.strLen [Transport.Transport τ]
    (client : Client τ)
    (key : String)
    : Async Int := do
  let reply <- execute client <| CommandRequest.strLen key
  expectInteger "STRLEN" reply

def Client.append [Transport.Transport τ]
    (client : Client τ)
    (key value : String)
    : Async Int := do
  let reply <- execute client <| CommandRequest.append key value
  expectInteger "APPEND" reply

def Client.incr [Transport.Transport τ]
    (client : Client τ)
    (key : String)
    : Async Int := do
  let reply <- execute client <| CommandRequest.incr key
  expectInteger "INCR" reply

def Client.incrBy [Transport.Transport τ]
    (client : Client τ)
    (key : String)
    (amount : Int)
    : Async Int := do
  let reply <- execute client <| CommandRequest.incrBy key amount
  expectInteger "INCRBY" reply

def Client.incrByFloat [Transport.Transport τ]
    (client : Client τ)
    (key amount : String)
    : Async String := do
  let reply <- execute client <| CommandRequest.incrByFloat key amount
  expectString "INCRBYFLOAT" reply

def Client.decr [Transport.Transport τ]
    (client : Client τ)
    (key : String)
    : Async Int := do
  let reply <- execute client <| CommandRequest.decr key
  expectInteger "DECR" reply

def Client.decrBy [Transport.Transport τ]
    (client : Client τ)
    (key : String)
    (amount : Int)
    : Async Int := do
  let reply <- execute client <| CommandRequest.decrBy key amount
  expectInteger "DECRBY" reply

def Client.setNx [Transport.Transport τ]
    (client : Client τ)
    (key value : String)
    : Async Bool := do
  let reply <- execute client <| CommandRequest.setNx key value
  expectBoolean "SETNX" reply

def Client.setEx [Transport.Transport τ]
    (client : Client τ)
    (key : String)
    (seconds : UInt64)
    (value : String)
    : Async Unit := do
  let reply <- execute client <| CommandRequest.setEx key seconds value
  expectOk reply

def Client.pSetEx [Transport.Transport τ]
    (client : Client τ)
    (key : String)
    (milliseconds : UInt64)
    (value : String)
    : Async Unit := do
  let reply <- execute client <| CommandRequest.pSetEx key milliseconds value
  expectOk reply

def Client.currentState (client : Client τ) : Async Engine.State := do
  liftIO <| client.manager.atomically fun ref => do
    let manager <- ref.get
    pure manager.session.state

end LeanRedis
