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

private def expectPlainStringArray (context : String) (reply : Protocol.Resp.Value) : Async (Array String) := do
  match reply with
  | .array items =>
      items.mapM (expectString context)
  | .simpleError message => Error.raise <| .server message
  | _ => Error.raise <| .decode s!"unexpected {context} reply"

private def decodeStringPairsFromArray
    (context : String)
    (items : Array Protocol.Resp.Value)
    : Async (Array (String × String)) := do
  let rec loop (index : Nat) (acc : Array (String × String)) : Async (Array (String × String)) := do
    if h : index < items.size then
      let key <- expectString context items[index]
      let next := index + 1
      if hNext : next < items.size then
        let value <- expectString context items[next]
        loop (next + 1) (acc.push (key, value))
      else
        Error.raise <| .decode s!"unexpected odd-sized {context} reply"
    else
      pure acc
  loop 0 #[]

private def expectStringPairs (context : String) (reply : Protocol.Resp.Value) : Async (Array (String × String)) := do
  match reply with
  | .array items =>
      decodeStringPairsFromArray context items
  | .map entries =>
      entries.mapM fun (key, value) => do
        let key <- expectString context key
        let value <- expectString context value
        pure (key, value)
  | .simpleError message => Error.raise <| .server message
  | _ => Error.raise <| .decode s!"unexpected {context} reply"

private def expectHScanResult (reply : Protocol.Resp.Value) : Async HashScanResult := do
  match reply with
  | .array #[cursor, entries] =>
      let cursorText <- expectString "HSCAN" cursor
      let some cursor := cursorText.toNat?
        | Error.raise <| .decode "invalid HSCAN cursor"
      let entries <- match entries with
        | .array items => decodeStringPairsFromArray "HSCAN" items
        | .map kvs =>
            kvs.mapM fun (key, value) => do
              let key <- expectString "HSCAN" key
              let value <- expectString "HSCAN" value
              pure (key, value)
        | .simpleError message => Error.raise <| .server message
        | _ => Error.raise <| .decode "unexpected HSCAN entries reply"
      pure { cursor := cursor.toUInt64, entries }
  | .simpleError message => Error.raise <| .server message
  | _ => Error.raise <| .decode "unexpected HSCAN reply"

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

def Client.new [Transport.Transport τ] (config : Config) : Async (Client τ) := do
  let manager <- liftIO <| Std.Mutex.new (Connection.Manager.new config : Connection.Manager τ)
  pure { manager }

def Client.newDefault (config : Config) : Async (Client Transport.TCP) :=
  Client.new config

def Client.connect (client : Client τ) [Transport.Transport τ] : Async Unit := do
  let _ <- withManager client fun manager => do
    let manager <- manager.connect
    pure ((), manager)
  pure ()

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

def Client.hGet [Transport.Transport τ]
    (client : Client τ)
    (key field : String)
    : Async (Option String) := do
  let reply <- execute client <| CommandRequest.hGet key field
  expectOptionalString "HGET" reply

def Client.hSet [Transport.Transport τ]
    (client : Client τ)
    (key : String)
    (entries : Array (String × String))
    : Async Int := do
  let reply <- execute client <| CommandRequest.hSet key entries
  expectInteger "HSET" reply

def Client.hMGet [Transport.Transport τ]
    (client : Client τ)
    (key : String)
    (fields : Array String)
    : Async (Array (Option String)) := do
  let reply <- execute client <| CommandRequest.hMGet key fields
  expectStringArray "HMGET" reply

def Client.hMSet [Transport.Transport τ]
    (client : Client τ)
    (key : String)
    (entries : Array (String × String))
    : Async Unit := do
  let reply <- execute client <| CommandRequest.hMSet key entries
  expectOk reply

def Client.hGetAll [Transport.Transport τ]
    (client : Client τ)
    (key : String)
    : Async (Array (String × String)) := do
  let reply <- execute client <| CommandRequest.hGetAll key
  expectStringPairs "HGETALL" reply

def Client.hDel [Transport.Transport τ]
    (client : Client τ)
    (key : String)
    (fields : Array String)
    : Async Int := do
  let reply <- execute client <| CommandRequest.hDel key fields
  expectInteger "HDEL" reply

def Client.hExists [Transport.Transport τ]
    (client : Client τ)
    (key field : String)
    : Async Bool := do
  let reply <- execute client <| CommandRequest.hExists key field
  expectBoolean "HEXISTS" reply

def Client.hLen [Transport.Transport τ]
    (client : Client τ)
    (key : String)
    : Async Int := do
  let reply <- execute client <| CommandRequest.hLen key
  expectInteger "HLEN" reply

def Client.hKeys [Transport.Transport τ]
    (client : Client τ)
    (key : String)
    : Async (Array String) := do
  let reply <- execute client <| CommandRequest.hKeys key
  expectPlainStringArray "HKEYS" reply

def Client.hVals [Transport.Transport τ]
    (client : Client τ)
    (key : String)
    : Async (Array String) := do
  let reply <- execute client <| CommandRequest.hVals key
  expectPlainStringArray "HVALS" reply

def Client.hStrLen [Transport.Transport τ]
    (client : Client τ)
    (key field : String)
    : Async Int := do
  let reply <- execute client <| CommandRequest.hStrLen key field
  expectInteger "HSTRLEN" reply

def Client.hIncrBy [Transport.Transport τ]
    (client : Client τ)
    (key field : String)
    (amount : Int)
    : Async Int := do
  let reply <- execute client <| CommandRequest.hIncrBy key field amount
  expectInteger "HINCRBY" reply

def Client.hIncrByFloat [Transport.Transport τ]
    (client : Client τ)
    (key field amount : String)
    : Async String := do
  let reply <- execute client <| CommandRequest.hIncrByFloat key field amount
  expectString "HINCRBYFLOAT" reply

def Client.hSetNx [Transport.Transport τ]
    (client : Client τ)
    (key field value : String)
    : Async Bool := do
  let reply <- execute client <| CommandRequest.hSetNx key field value
  expectBoolean "HSETNX" reply

def Client.hRandField [Transport.Transport τ]
    (client : Client τ)
    (key : String)
    : Async (Option String) := do
  let reply <- execute client <| CommandRequest.hRandField key
  expectOptionalString "HRANDFIELD" reply

def Client.hRandFields [Transport.Transport τ]
    (client : Client τ)
    (key : String)
    (count : Int)
    : Async (Array String) := do
  let reply <- execute client <| CommandRequest.hRandFields key count
  expectPlainStringArray "HRANDFIELD" reply

def Client.hRandFieldsWithValues [Transport.Transport τ]
    (client : Client τ)
    (key : String)
    (count : Int)
    : Async (Array (String × String)) := do
  let reply <- execute client <| CommandRequest.hRandFieldsWithValues key count
  expectStringPairs "HRANDFIELD" reply

def Client.hScan [Transport.Transport τ]
    (client : Client τ)
    (key : String)
    (cursor : UInt64)
    (options : HScanOptions := {})
    : Async HashScanResult := do
  let reply <- execute client <| CommandRequest.hScan key cursor options
  expectHScanResult reply

def Client.currentState (client : Client τ) : Async Engine.State := do
  liftIO <| client.manager.atomically fun ref => do
    let manager <- ref.get
    pure manager.session.state

end LeanRedis
