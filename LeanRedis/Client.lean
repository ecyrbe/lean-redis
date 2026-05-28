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

private def expectIntegerArray (context : String) (reply : Protocol.Resp.Value) : Async (Array Int) := do
  match reply with
  | .array items =>
      items.mapM (expectInteger context)
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

private def expectSetScanResult (reply : Protocol.Resp.Value) : Async SetScanResult := do
  match reply with
  | .array #[cursor, members] =>
      let cursorText <- expectString "SSCAN" cursor
      let some cursor := cursorText.toNat?
        | Error.raise <| .decode "invalid SSCAN cursor"
      let members <- expectPlainStringArray "SSCAN" members
      pure { cursor := cursor.toUInt64, members }
  | .simpleError message => Error.raise <| .server message
  | _ => Error.raise <| .decode "unexpected SSCAN reply"

private def expectOptionalStringOrArray
    (context : String)
    (reply : Protocol.Resp.Value)
    : Async (Option String ⊕ Array String) := do
  match reply with
  | .null => pure <| .inl none
  | .blobString _ | .simpleString _ =>
      let value <- expectOptionalString context reply
      pure <| .inl value
  | .array _ =>
      let values <- expectPlainStringArray context reply
      pure <| .inr values
  | .simpleError message => Error.raise <| .server message
  | _ => Error.raise <| .decode s!"unexpected {context} reply"

private def decodeSortedSetEntriesFromArray
    (context : String)
    (items : Array Protocol.Resp.Value)
    : Async (Array SortedSetEntry) := do
  let pairs <- decodeStringPairsFromArray context items
  pure <| pairs.map fun (member, score) => { member, score }

private def expectSortedSetEntries (context : String) (reply : Protocol.Resp.Value) : Async (Array SortedSetEntry) := do
  match reply with
  | .array items =>
      decodeSortedSetEntriesFromArray context items
  | .map entries =>
      entries.mapM fun (member, score) => do
        let member <- expectString context member
        let score <- expectString context score
        pure { member, score }
  | .simpleError message => Error.raise <| .server message
  | _ => Error.raise <| .decode s!"unexpected {context} reply"

private def expectSortedSetScanResult (reply : Protocol.Resp.Value) : Async SortedSetScanResult := do
  match reply with
  | .array #[cursor, entries] =>
      let cursorText <- expectString "ZSCAN" cursor
      let some cursor := cursorText.toNat?
        | Error.raise <| .decode "invalid ZSCAN cursor"
      let entries <- expectSortedSetEntries "ZSCAN" entries
      pure { cursor := cursor.toUInt64, entries }
  | .simpleError message => Error.raise <| .server message
  | _ => Error.raise <| .decode "unexpected ZSCAN reply"

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

def Client.lPush [Transport.Transport τ]
    (client : Client τ)
    (key : String)
    (values : Array String)
    : Async Int := do
  let reply <- execute client <| CommandRequest.lPush key values
  expectInteger "LPUSH" reply

def Client.rPush [Transport.Transport τ]
    (client : Client τ)
    (key : String)
    (values : Array String)
    : Async Int := do
  let reply <- execute client <| CommandRequest.rPush key values
  expectInteger "RPUSH" reply

def Client.lPushX [Transport.Transport τ]
    (client : Client τ)
    (key value : String)
    : Async Int := do
  let reply <- execute client <| CommandRequest.lPushX key value
  expectInteger "LPUSHX" reply

def Client.rPushX [Transport.Transport τ]
    (client : Client τ)
    (key value : String)
    : Async Int := do
  let reply <- execute client <| CommandRequest.rPushX key value
  expectInteger "RPUSHX" reply

def Client.lPop [Transport.Transport τ]
    (client : Client τ)
    (key : String)
    : Async (Option String) := do
  let reply <- execute client <| CommandRequest.lPop key
  expectOptionalString "LPOP" reply

def Client.rPop [Transport.Transport τ]
    (client : Client τ)
    (key : String)
    : Async (Option String) := do
  let reply <- execute client <| CommandRequest.rPop key
  expectOptionalString "RPOP" reply

def Client.lLen [Transport.Transport τ]
    (client : Client τ)
    (key : String)
    : Async Int := do
  let reply <- execute client <| CommandRequest.lLen key
  expectInteger "LLEN" reply

def Client.lIndex [Transport.Transport τ]
    (client : Client τ)
    (key : String)
    (index : Int)
    : Async (Option String) := do
  let reply <- execute client <| CommandRequest.lIndex key index
  expectOptionalString "LINDEX" reply

def Client.lRange [Transport.Transport τ]
    (client : Client τ)
    (key : String)
    (start stop : Int)
    : Async (Array String) := do
  let reply <- execute client <| CommandRequest.lRange key start stop
  expectPlainStringArray "LRANGE" reply

def Client.lSet [Transport.Transport τ]
    (client : Client τ)
    (key : String)
    (index : Int)
    (value : String)
    : Async Unit := do
  let reply <- execute client <| CommandRequest.lSet key index value
  expectOk reply

def Client.lTrim [Transport.Transport τ]
    (client : Client τ)
    (key : String)
    (start stop : Int)
    : Async Unit := do
  let reply <- execute client <| CommandRequest.lTrim key start stop
  expectOk reply

def Client.lRem [Transport.Transport τ]
    (client : Client τ)
    (key : String)
    (count : Int)
    (value : String)
    : Async Int := do
  let reply <- execute client <| CommandRequest.lRem key count value
  expectInteger "LREM" reply

def Client.lInsert [Transport.Transport τ]
    (client : Client τ)
    (key : String)
    (position : LInsertPosition)
    (pivot value : String)
    : Async Int := do
  let reply <- execute client <| CommandRequest.lInsert key position pivot value
  expectInteger "LINSERT" reply

def Client.lMove [Transport.Transport τ]
    (client : Client τ)
    (source destination : String)
    (fromWhere toWhere : LMoveWhere)
    : Async (Option String) := do
  let reply <- execute client <| CommandRequest.lMove source destination fromWhere toWhere
  expectOptionalString "LMOVE" reply

def Client.lPos [Transport.Transport τ]
    (client : Client τ)
    (key element : String)
    (options : LPosOptions := {})
    : Async (Option Int) := do
  if options.count?.isSome then
    Error.raise <| .decode "LPOS with COUNT returns multiple positions; use lPosMany"
  let reply <- execute client <| CommandRequest.lPos key element options
  match reply with
  | .null => pure none
  | .number value => pure (some value)
  | .simpleError message => Error.raise <| .server message
  | _ => Error.raise <| .decode "unexpected LPOS reply"

def Client.lPosMany [Transport.Transport τ]
    (client : Client τ)
    (key element : String)
    (options : LPosOptions)
    : Async (Array Int) := do
  match options.count? with
  | none => Error.raise <| .decode "lPosMany requires COUNT"
  | some _ =>
      let reply <- execute client <| CommandRequest.lPos key element options
      expectIntegerArray "LPOS" reply

def Client.sAdd [Transport.Transport τ]
    (client : Client τ)
    (key : String)
    (members : Array String)
    : Async Int := do
  let reply <- execute client <| CommandRequest.sAdd key members
  expectInteger "SADD" reply

def Client.sRem [Transport.Transport τ]
    (client : Client τ)
    (key : String)
    (members : Array String)
    : Async Int := do
  let reply <- execute client <| CommandRequest.sRem key members
  expectInteger "SREM" reply

def Client.sCard [Transport.Transport τ]
    (client : Client τ)
    (key : String)
    : Async Int := do
  let reply <- execute client <| CommandRequest.sCard key
  expectInteger "SCARD" reply

def Client.sIsMember [Transport.Transport τ]
    (client : Client τ)
    (key member : String)
    : Async Bool := do
  let reply <- execute client <| CommandRequest.sIsMember key member
  expectBoolean "SISMEMBER" reply

def Client.sMIsMember [Transport.Transport τ]
    (client : Client τ)
    (key : String)
    (members : Array String)
    : Async (Array Bool) := do
  let reply <- execute client <| CommandRequest.sMIsMember key members
  match reply with
  | .array items =>
      items.mapM (expectBoolean "SMISMEMBER")
  | .simpleError message => Error.raise <| .server message
  | _ => Error.raise <| .decode "unexpected SMISMEMBER reply"

def Client.sMembers [Transport.Transport τ]
    (client : Client τ)
    (key : String)
    : Async (Array String) := do
  let reply <- execute client <| CommandRequest.sMembers key
  expectPlainStringArray "SMEMBERS" reply

def Client.sPop [Transport.Transport τ]
    (client : Client τ)
    (key : String)
    : Async (Option String) := do
  let reply <- execute client <| CommandRequest.sPop key
  expectOptionalString "SPOP" reply

def Client.sPopMany [Transport.Transport τ]
    (client : Client τ)
    (key : String)
    (count : UInt64)
    : Async (Array String) := do
  let reply <- execute client <| CommandRequest.sPopCount key count
  expectPlainStringArray "SPOP" reply

def Client.sRandMember [Transport.Transport τ]
    (client : Client τ)
    (key : String)
    : Async (Option String) := do
  let reply <- execute client <| CommandRequest.sRandMember key
  expectOptionalString "SRANDMEMBER" reply

def Client.sRandMembers [Transport.Transport τ]
    (client : Client τ)
    (key : String)
    (count : Int)
    : Async (Array String) := do
  let reply <- execute client <| CommandRequest.sRandMembers key count
  match (← expectOptionalStringOrArray "SRANDMEMBER" reply) with
  | .inl none => pure #[]
  | .inl (some value) => pure #[value]
  | .inr values => pure values

def Client.sMove [Transport.Transport τ]
    (client : Client τ)
    (source destination member : String)
    : Async Bool := do
  let reply <- execute client <| CommandRequest.sMove source destination member
  expectBoolean "SMOVE" reply

def Client.sDiff [Transport.Transport τ]
    (client : Client τ)
    (keys : Array String)
    : Async (Array String) := do
  let reply <- execute client <| CommandRequest.sDiff keys
  expectPlainStringArray "SDIFF" reply

def Client.sDiffStore [Transport.Transport τ]
    (client : Client τ)
    (destination : String)
    (keys : Array String)
    : Async Int := do
  let reply <- execute client <| CommandRequest.sDiffStore destination keys
  expectInteger "SDIFFSTORE" reply

def Client.sInter [Transport.Transport τ]
    (client : Client τ)
    (keys : Array String)
    : Async (Array String) := do
  let reply <- execute client <| CommandRequest.sInter keys
  expectPlainStringArray "SINTER" reply

def Client.sInterCard [Transport.Transport τ]
    (client : Client τ)
    (keys : Array String)
    : Async Int := do
  let reply <- execute client <| CommandRequest.sInterCard keys
  expectInteger "SINTERCARD" reply

def Client.sInterStore [Transport.Transport τ]
    (client : Client τ)
    (destination : String)
    (keys : Array String)
    : Async Int := do
  let reply <- execute client <| CommandRequest.sInterStore destination keys
  expectInteger "SINTERSTORE" reply

def Client.sUnion [Transport.Transport τ]
    (client : Client τ)
    (keys : Array String)
    : Async (Array String) := do
  let reply <- execute client <| CommandRequest.sUnion keys
  expectPlainStringArray "SUNION" reply

def Client.sUnionStore [Transport.Transport τ]
    (client : Client τ)
    (destination : String)
    (keys : Array String)
    : Async Int := do
  let reply <- execute client <| CommandRequest.sUnionStore destination keys
  expectInteger "SUNIONSTORE" reply

def Client.sScan [Transport.Transport τ]
    (client : Client τ)
    (key : String)
    (cursor : UInt64)
    (options : SScanOptions := {})
    : Async SetScanResult := do
  let reply <- execute client <| CommandRequest.sScan key cursor options
  expectSetScanResult reply

def Client.zAdd [Transport.Transport τ]
    (client : Client τ)
    (key : String)
    (entries : Array SortedSetEntry)
    : Async Int := do
  let reply <- execute client <| CommandRequest.zAdd key entries
  expectInteger "ZADD" reply

def Client.zRem [Transport.Transport τ]
    (client : Client τ)
    (key : String)
    (members : Array String)
    : Async Int := do
  let reply <- execute client <| CommandRequest.zRem key members
  expectInteger "ZREM" reply

def Client.zCard [Transport.Transport τ]
    (client : Client τ)
    (key : String)
    : Async Int := do
  let reply <- execute client <| CommandRequest.zCard key
  expectInteger "ZCARD" reply

def Client.zScore [Transport.Transport τ]
    (client : Client τ)
    (key member : String)
    : Async (Option String) := do
  let reply <- execute client <| CommandRequest.zScore key member
  expectOptionalString "ZSCORE" reply

def Client.zMScore [Transport.Transport τ]
    (client : Client τ)
    (key : String)
    (members : Array String)
    : Async (Array (Option String)) := do
  let reply <- execute client <| CommandRequest.zMScore key members
  expectStringArray "ZMSCORE" reply

def Client.zRank [Transport.Transport τ]
    (client : Client τ)
    (key member : String)
    : Async (Option Int) := do
  let reply <- execute client <| CommandRequest.zRank key member
  match reply with
  | .null => pure none
  | .number value => pure (some value)
  | .simpleError message => Error.raise <| .server message
  | _ => Error.raise <| .decode "unexpected ZRANK reply"

def Client.zRevRank [Transport.Transport τ]
    (client : Client τ)
    (key member : String)
    : Async (Option Int) := do
  let reply <- execute client <| CommandRequest.zRevRank key member
  match reply with
  | .null => pure none
  | .number value => pure (some value)
  | .simpleError message => Error.raise <| .server message
  | _ => Error.raise <| .decode "unexpected ZREVRANK reply"

def Client.zRange [Transport.Transport τ]
    (client : Client τ)
    (key : String)
    (start stop : Int)
    : Async (Array String) := do
  let reply <- execute client <| CommandRequest.zRange key start stop
  expectPlainStringArray "ZRANGE" reply

def Client.zRangeWithScores [Transport.Transport τ]
    (client : Client τ)
    (key : String)
    (start stop : Int)
    : Async (Array SortedSetEntry) := do
  let reply <- execute client <| CommandRequest.zRangeWithScores key start stop
  expectSortedSetEntries "ZRANGE" reply

def Client.zRevRange [Transport.Transport τ]
    (client : Client τ)
    (key : String)
    (start stop : Int)
    : Async (Array String) := do
  let reply <- execute client <| CommandRequest.zRevRange key start stop
  expectPlainStringArray "ZREVRANGE" reply

def Client.zRevRangeWithScores [Transport.Transport τ]
    (client : Client τ)
    (key : String)
    (start stop : Int)
    : Async (Array SortedSetEntry) := do
  let reply <- execute client <| CommandRequest.zRevRangeWithScores key start stop
  expectSortedSetEntries "ZREVRANGE" reply

def Client.zRangeByScore [Transport.Transport τ]
    (client : Client τ)
    (key min max : String)
    : Async (Array String) := do
  let reply <- execute client <| CommandRequest.zRangeByScore key min max
  expectPlainStringArray "ZRANGEBYSCORE" reply

def Client.zRangeByScoreWithScores [Transport.Transport τ]
    (client : Client τ)
    (key min max : String)
    : Async (Array SortedSetEntry) := do
  let reply <- execute client <| CommandRequest.zRangeByScoreWithScores key min max
  expectSortedSetEntries "ZRANGEBYSCORE" reply

def Client.zRevRangeByScore [Transport.Transport τ]
    (client : Client τ)
    (key max min : String)
    : Async (Array String) := do
  let reply <- execute client <| CommandRequest.zRevRangeByScore key max min
  expectPlainStringArray "ZREVRANGEBYSCORE" reply

def Client.zRevRangeByScoreWithScores [Transport.Transport τ]
    (client : Client τ)
    (key max min : String)
    : Async (Array SortedSetEntry) := do
  let reply <- execute client <| CommandRequest.zRevRangeByScoreWithScores key max min
  expectSortedSetEntries "ZREVRANGEBYSCORE" reply

def Client.zRangeByLex [Transport.Transport τ]
    (client : Client τ)
    (key min max : String)
    : Async (Array String) := do
  let reply <- execute client <| CommandRequest.zRangeByLex key min max
  expectPlainStringArray "ZRANGEBYLEX" reply

def Client.zRevRangeByLex [Transport.Transport τ]
    (client : Client τ)
    (key max min : String)
    : Async (Array String) := do
  let reply <- execute client <| CommandRequest.zRevRangeByLex key max min
  expectPlainStringArray "ZREVRANGEBYLEX" reply

def Client.zCount [Transport.Transport τ]
    (client : Client τ)
    (key min max : String)
    : Async Int := do
  let reply <- execute client <| CommandRequest.zCount key min max
  expectInteger "ZCOUNT" reply

def Client.zLexCount [Transport.Transport τ]
    (client : Client τ)
    (key min max : String)
    : Async Int := do
  let reply <- execute client <| CommandRequest.zLexCount key min max
  expectInteger "ZLEXCOUNT" reply

def Client.zRemRangeByRank [Transport.Transport τ]
    (client : Client τ)
    (key : String)
    (start stop : Int)
    : Async Int := do
  let reply <- execute client <| CommandRequest.zRemRangeByRank key start stop
  expectInteger "ZREMRANGEBYRANK" reply

def Client.zRemRangeByScore [Transport.Transport τ]
    (client : Client τ)
    (key min max : String)
    : Async Int := do
  let reply <- execute client <| CommandRequest.zRemRangeByScore key min max
  expectInteger "ZREMRANGEBYSCORE" reply

def Client.zRemRangeByLex [Transport.Transport τ]
    (client : Client τ)
    (key min max : String)
    : Async Int := do
  let reply <- execute client <| CommandRequest.zRemRangeByLex key min max
  expectInteger "ZREMRANGEBYLEX" reply

def Client.zIncrBy [Transport.Transport τ]
    (client : Client τ)
    (key increment member : String)
    : Async String := do
  let reply <- execute client <| CommandRequest.zIncrBy key increment member
  expectString "ZINCRBY" reply

def Client.zRandMember [Transport.Transport τ]
    (client : Client τ)
    (key : String)
    : Async (Option String) := do
  let reply <- execute client <| CommandRequest.zRandMember key
  expectOptionalString "ZRANDMEMBER" reply

def Client.zRandMembers [Transport.Transport τ]
    (client : Client τ)
    (key : String)
    (count : Int)
    : Async (Array String) := do
  let reply <- execute client <| CommandRequest.zRandMembers key count
  match (← expectOptionalStringOrArray "ZRANDMEMBER" reply) with
  | .inl none => pure #[]
  | .inl (some value) => pure #[value]
  | .inr values => pure values

def Client.zRandMembersWithScores [Transport.Transport τ]
    (client : Client τ)
    (key : String)
    (count : Int)
    : Async (Array SortedSetEntry) := do
  let reply <- execute client <| CommandRequest.zRandMembersWithScores key count
  expectSortedSetEntries "ZRANDMEMBER" reply

def Client.zDiff [Transport.Transport τ]
    (client : Client τ)
    (keys : Array String)
    : Async (Array String) := do
  let reply <- execute client <| CommandRequest.zDiff keys
  expectPlainStringArray "ZDIFF" reply

def Client.zDiffStore [Transport.Transport τ]
    (client : Client τ)
    (destination : String)
    (keys : Array String)
    : Async Int := do
  let reply <- execute client <| CommandRequest.zDiffStore destination keys
  expectInteger "ZDIFFSTORE" reply

def Client.zInter [Transport.Transport τ]
    (client : Client τ)
    (keys : Array String)
    : Async (Array String) := do
  let reply <- execute client <| CommandRequest.zInter keys
  expectPlainStringArray "ZINTER" reply

def Client.zInterCard [Transport.Transport τ]
    (client : Client τ)
    (keys : Array String)
    : Async Int := do
  let reply <- execute client <| CommandRequest.zInterCard keys
  expectInteger "ZINTERCARD" reply

def Client.zInterStore [Transport.Transport τ]
    (client : Client τ)
    (destination : String)
    (keys : Array String)
    : Async Int := do
  let reply <- execute client <| CommandRequest.zInterStore destination keys
  expectInteger "ZINTERSTORE" reply

def Client.zUnion [Transport.Transport τ]
    (client : Client τ)
    (keys : Array String)
    : Async (Array String) := do
  let reply <- execute client <| CommandRequest.zUnion keys
  expectPlainStringArray "ZUNION" reply

def Client.zUnionStore [Transport.Transport τ]
    (client : Client τ)
    (destination : String)
    (keys : Array String)
    : Async Int := do
  let reply <- execute client <| CommandRequest.zUnionStore destination keys
  expectInteger "ZUNIONSTORE" reply

def Client.zScan [Transport.Transport τ]
    (client : Client τ)
    (key : String)
    (cursor : UInt64)
    (options : ZScanOptions := {})
    : Async SortedSetScanResult := do
  let reply <- execute client <| CommandRequest.zScan key cursor options
  expectSortedSetScanResult reply

def Client.currentState (client : Client τ) : Async Engine.State := do
  liftIO <| client.manager.atomically fun ref => do
    let manager <- ref.get
    pure manager.session.state

end LeanRedis
