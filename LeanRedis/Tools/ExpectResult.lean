import Std.Internal.Async
import LeanRedis.Protocol.Resp.Value
import LeanRedis.Error
import LeanRedis.Command.Hash
import LeanRedis.Command.Set
import LeanRedis.Command.Generic
import LeanRedis.Command.SortedSet

namespace LeanRedis

open Std.Internal.IO.Async

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

def expectScanResult (reply : Protocol.Resp.Value) : Async ScanResult := do
  match reply with
  | .array #[cursor, keys] =>
      let cursorText ← expectString "SCAN" cursor
      let some cursor := cursorText.toNat?
        | Error.raise <| .decode "invalid SCAN cursor"
      let keys ← expectPlainStringArray "SCAN" keys
      pure { cursor := cursor.toUInt64, keys }
  | .simpleError message => Error.raise <| .server message
  | _ => Error.raise <| .decode "unexpected SCAN reply"

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

end LeanRedis
