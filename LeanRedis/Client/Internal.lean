import Std.Sync.Mutex
import LeanRedis.Connection.Manager
import LeanRedis.Connection.Runtime
import LeanRedis.Error
import LeanRedis.Transport.Tcp

namespace LeanRedis

open Std.Internal.IO.Async

structure Client (τ : Type) where
  manager : Std.Mutex (Connection.Manager τ)

namespace Client

def liftIO {α : Type} (action : IO α) : Async α :=
  EAsync.lift action

def withManager [Transport.Transport τ]
    (client : Client τ)
    (action : Connection.Manager τ -> Async (α × Connection.Manager τ))
    : Async α := do
  let manager <- liftIO <| client.manager.atomically fun ref => ref.get
  let (result, manager) <- action manager
  liftIO <| client.manager.atomically fun ref => ref.set manager
  pure result

def expectOk (reply : Protocol.Resp.Value) : Async Unit := do
  match reply with
  | .simpleString "OK" => pure ()
  | .blobString bytes =>
      match String.fromUTF8? bytes with
      | some "OK" => pure ()
      | _ => Error.raise <| .decode "expected OK reply"
  | .simpleError message => Error.raise <| .server message
  | _ => Error.raise <| .decode "expected OK reply"

def expectPong (reply : Protocol.Resp.Value) : Async (Option String) := do
  match reply with
  | .simpleString "PONG" => pure none
  | .blobString bytes =>
      match String.fromUTF8? bytes with
      | some text => pure (some text)
      | none => Error.raise <| .decode "invalid UTF-8 in PING reply"
  | .simpleString text => pure (some text)
  | .simpleError message => Error.raise <| .server message
  | _ => Error.raise <| .decode "unexpected PING reply"

def expectStored (reply : Protocol.Resp.Value) : Async Bool := do
  match reply with
  | .simpleString "OK" => pure true
  | .blobString bytes =>
      match String.fromUTF8? bytes with
      | some "OK" => pure true
      | _ => Error.raise <| .decode "expected OK reply"
  | .null => pure false
  | .simpleError message => Error.raise <| .server message
  | _ => Error.raise <| .decode "unexpected SET reply"

def decodeUtf8 (context : String) (bytes : ByteArray) : Async String := do
  match String.fromUTF8? bytes with
  | some text => pure text
  | none => Error.raise <| .decode s!"invalid UTF-8 in {context} reply"

def expectOptionalString (context : String) (reply : Protocol.Resp.Value) : Async (Option String) := do
  match reply with
  | .null => pure none
  | .blobString bytes =>
      let text <- decodeUtf8 context bytes
      pure (some text)
  | .simpleString text => pure (some text)
  | .simpleError message => Error.raise <| .server message
  | _ => Error.raise <| .decode s!"unexpected {context} reply"

def expectString (context : String) (reply : Protocol.Resp.Value) : Async String := do
  match (← expectOptionalString context reply) with
  | some text => pure text
  | none => Error.raise <| .decode s!"unexpected null {context} reply"

def expectInteger (context : String) (reply : Protocol.Resp.Value) : Async Int := do
  match reply with
  | .number value => pure value
  | .simpleError message => Error.raise <| .server message
  | _ => Error.raise <| .decode s!"unexpected {context} reply"

def expectBoolean (context : String) (reply : Protocol.Resp.Value) : Async Bool := do
  match reply with
  | .bool value => pure value
  | .number value => pure (value != 0)
  | .simpleError message => Error.raise <| .server message
  | _ => Error.raise <| .decode s!"unexpected {context} reply"

def expectStringArray (context : String) (reply : Protocol.Resp.Value) : Async (Array (Option String)) := do
  match reply with
  | .array items =>
      items.mapM (expectOptionalString context)
  | .simpleError message => Error.raise <| .server message
  | _ => Error.raise <| .decode s!"unexpected {context} reply"

def expectPlainStringArray (context : String) (reply : Protocol.Resp.Value) : Async (Array String) := do
  match reply with
  | .array items =>
      items.mapM (expectString context)
  | .simpleError message => Error.raise <| .server message
  | _ => Error.raise <| .decode s!"unexpected {context} reply"

def expectIntegerArray (context : String) (reply : Protocol.Resp.Value) : Async (Array Int) := do
  match reply with
  | .array items =>
      items.mapM (expectInteger context)
  | .simpleError message => Error.raise <| .server message
  | _ => Error.raise <| .decode s!"unexpected {context} reply"

def decodeStringPairsFromArray
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

def expectStringPairs (context : String) (reply : Protocol.Resp.Value) : Async (Array (String × String)) := do
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

def expectHScanResult (reply : Protocol.Resp.Value) : Async HashScanResult := do
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

def expectSetScanResult (reply : Protocol.Resp.Value) : Async SetScanResult := do
  match reply with
  | .array #[cursor, members] =>
      let cursorText <- expectString "SSCAN" cursor
      let some cursor := cursorText.toNat?
        | Error.raise <| .decode "invalid SSCAN cursor"
      let members <- expectPlainStringArray "SSCAN" members
      pure { cursor := cursor.toUInt64, members }
  | .simpleError message => Error.raise <| .server message
  | _ => Error.raise <| .decode "unexpected SSCAN reply"

def expectOptionalStringOrArray
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

def decodeSortedSetEntriesFromArray
    (context : String)
    (items : Array Protocol.Resp.Value)
    : Async (Array SortedSetEntry) := do
  let pairs <- decodeStringPairsFromArray context items
  pure <| pairs.map fun (member, score) => { member, score }

def expectSortedSetEntries (context : String) (reply : Protocol.Resp.Value) : Async (Array SortedSetEntry) := do
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

def expectSortedSetScanResult (reply : Protocol.Resp.Value) : Async SortedSetScanResult := do
  match reply with
  | .array #[cursor, entries] =>
      let cursorText <- expectString "ZSCAN" cursor
      let some cursor := cursorText.toNat?
        | Error.raise <| .decode "invalid ZSCAN cursor"
      let entries <- expectSortedSetEntries "ZSCAN" entries
      pure { cursor := cursor.toUInt64, entries }
  | .simpleError message => Error.raise <| .server message
  | _ => Error.raise <| .decode "unexpected ZSCAN reply"

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

def execute [Transport.Transport τ]
    (client : Client τ)
    (request : CommandRequest)
    : Async Protocol.Resp.Value :=
  withManager client fun manager => do
    let manager := manager.notePending request
    manager.withRuntime fun runtime => do
      let (reply, runtime) <- Connection.Runtime.execute runtime request
      pure (reply, runtime, stateAfterReply manager request reply)

end Client

def Client.new [Transport.Transport τ] (config : Config) : Async (Client τ) := do
  let manager <- Client.liftIO <| Std.Mutex.new (Connection.Manager.new config : Connection.Manager τ)
  pure { manager }

def Client.newDefault (config : Config) : Async (Client Transport.TCP) :=
  Client.new config

def Client.connect (client : Client τ) [Transport.Transport τ] : Async Unit := do
  let _ <- Client.withManager client fun manager => do
    let manager <- manager.connect
    pure ((), manager)
  pure ()

def Client.disconnect [Transport.Transport τ] (client : Client τ) : Async Unit := do
  let _ <- Client.withManager client fun manager => do
    let manager <- manager.disconnect
    pure ((), manager)
  pure ()

def Client.isConnected (client : Client τ) : Async Bool := do
  Client.liftIO <| client.manager.atomically fun ref => do
    let manager <- ref.get
    pure manager.isConnected

def Client.requireConnected [Transport.Transport τ] (client : Client τ) : Async Unit := do
  unless (← Client.isConnected client) do
    Error.raise <| .unavailable "client is not connected"

def Client.currentState (client : Client τ) : Async Engine.State := do
  Client.liftIO <| client.manager.atomically fun ref => do
    let manager <- ref.get
    pure manager.session.state

end LeanRedis
