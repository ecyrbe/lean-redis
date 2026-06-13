import LeanRedis.Protocol.Resp.Value
import LeanRedis.Error
import LeanRedis.Command.Base

namespace LeanRedis

def expectOk (reply : Protocol.Resp.Value) : Except Error Unit :=
  match reply with
  | .simpleString "OK" => return ()
  | .blobString bytes =>
      match String.fromUTF8? bytes with
      | some "OK" => return ()
      | _ => throw <| .decode "expected OK reply"
  | .simpleError message => throw <| .server message
  | _ => throw <| .decode "expected OK reply"

def expectPong (reply : Protocol.Resp.Value) : Except Error (Option String) :=
  match reply with
  | .simpleString "PONG" => return none
  | .blobString bytes =>
      match String.fromUTF8? bytes with
      | some text => return (some text)
      | none => throw <| .decode "invalid UTF-8 in PING reply"
  | .simpleString text => return (some text)
  | .simpleError message => throw <| .server message
  | _ => throw <| .decode "unexpected PING reply"

def expectStored (reply : Protocol.Resp.Value) : Except Error Bool :=
  match reply with
  | .simpleString "OK" => return true
  | .blobString bytes =>
      match String.fromUTF8? bytes with
      | some "OK" => return true
      | _ => throw <| .decode "expected OK reply"
  | .null => return false
  | .simpleError message => throw <| .server message
  | _ => throw <| .decode "unexpected SET reply"

def decodeUtf8 (context : String) (bytes : ByteArray) : Except Error String :=
  match String.fromUTF8? bytes with
  | some text => return text
  | none => throw <| .decode s!"invalid UTF-8 in {context} reply"

def expectOptionalString (context : String) (reply : Protocol.Resp.Value) : Except Error (Option String) :=
  match reply with
  | .null => return none
  | .blobString bytes =>
      match decodeUtf8 context bytes with
      | .ok text => return (some text)
      | .error e => throw e
  | .simpleString text => return (some text)
  | .simpleError message => throw <| .server message
  | _ => throw <| .decode s!"unexpected {context} reply"

def expectString (context : String) (reply : Protocol.Resp.Value) : Except Error String :=
  match expectOptionalString context reply with
  | .ok (some text) => return text
  | .ok none => throw <| .decode s!"unexpected null {context} reply"
  | .error e => throw e

def expectInteger (context : String) (reply : Protocol.Resp.Value) : Except Error Int :=
  match reply with
  | .number value => return value
  | .simpleError message => throw <| .server message
  | _ => throw <| .decode s!"unexpected {context} reply"

def expectBoolean (context : String) (reply : Protocol.Resp.Value) : Except Error Bool :=
  match reply with
  | .bool value => return value
  | .number value => return (value != 0)
  | .simpleError message => throw <| .server message
  | _ => throw <| .decode s!"unexpected {context} reply"

def expectStringArray (context : String) (reply : Protocol.Resp.Value) : Except Error (Array (Option String)) :=
  match reply with
  | .array items =>
      items.mapM (expectOptionalString context)
  | .simpleError message => throw <| .server message
  | _ => throw <| .decode s!"unexpected {context} reply"

def expectPlainStringArray (context : String) (reply : Protocol.Resp.Value) : Except Error (Array String) :=
  match reply with
  | .array items =>
      items.mapM (expectString context)
  | .simpleError message => throw <| .server message
  | _ => throw <| .decode s!"unexpected {context} reply"

def expectIntegerArray (context : String) (reply : Protocol.Resp.Value) : Except Error (Array Int) :=
  match reply with
  | .array items =>
      items.mapM (expectInteger context)
  | .simpleError message => throw <| .server message
  | _ => throw <| .decode s!"unexpected {context} reply"

def decodeStringPairsFromArray
    (context : String)
    (items : Array Protocol.Resp.Value)
    : Except Error (Array (String × String)) :=
  let rec loop (index : Nat) (acc : Array (String × String)) : Except Error (Array (String × String)) :=
    if h : index < items.size then
      match expectString context items[index] with
      | .error e => throw e
      | .ok key =>
        let next := index + 1
        if hNext : next < items.size then
          match expectString context items[next] with
          | .error e => throw e
          | .ok value => loop (next + 1) (acc.push (key, value))
        else
          throw <| .decode s!"unexpected odd-sized {context} reply"
    else
      return acc
  loop 0 #[]

def expectStringPairs (context : String) (reply : Protocol.Resp.Value) : Except Error (Array (String × String)) :=
  match reply with
  | .array items =>
      decodeStringPairsFromArray context items
  | .map entries =>
      entries.mapM fun (key, value) => do
        let key <- expectString context key
        let value <- expectString context value
        return (key, value)
  | .simpleError message => throw <| .server message
  | _ => throw <| .decode s!"unexpected {context} reply"

def expectHScanResult (reply : Protocol.Resp.Value) : Except Error HashScanResult := do
  match reply with
  | .array #[cursor, entries] =>
      let cursorText <- expectString "HSCAN" cursor
      let some cursor := cursorText.toNat?
        | throw <| .decode "invalid HSCAN cursor"
      let entries <- match entries with
        | .array items => decodeStringPairsFromArray "HSCAN" items
        | .map kvs =>
            kvs.mapM fun (key, value) => do
              let key <- expectString "HSCAN" key
              let value <- expectString "HSCAN" value
              return (key, value)
        | .simpleError message => throw <| .server message
        | _ => throw <| .decode "unexpected HSCAN entries reply"
      return { cursor := cursor.toUInt64, entries }
  | .simpleError message => throw <| .server message
  | _ => throw <| .decode "unexpected HSCAN reply"

def expectSetScanResult (reply : Protocol.Resp.Value) : Except Error SetScanResult := do
  match reply with
  | .array #[cursor, members] =>
      let cursorText <- expectString "SSCAN" cursor
      let some cursor := cursorText.toNat?
        | throw <| .decode "invalid SSCAN cursor"
      let members <- expectPlainStringArray "SSCAN" members
      return { cursor := cursor.toUInt64, members }
  | .simpleError message => throw <| .server message
  | _ => throw <| .decode "unexpected SSCAN reply"

def expectScanResult (reply : Protocol.Resp.Value) : Except Error ScanResult := do
  match reply with
  | .array #[cursor, keys] =>
      let cursorText <- expectString "SCAN" cursor
      let some cursor := cursorText.toNat?
        | throw <| .decode "invalid SCAN cursor"
      let keys <- expectPlainStringArray "SCAN" keys
      return { cursor := cursor.toUInt64, keys }
  | .simpleError message => throw <| .server message
  | _ => throw <| .decode "unexpected SCAN reply"

def expectOptionalStringOrArray
    (context : String)
    (reply : Protocol.Resp.Value)
    : Except Error (Option String ⊕ Array String) :=
  match reply with
  | .null => return .inl none
  | .blobString _ | .simpleString _ =>
      match expectOptionalString context reply with
      | .ok value => return .inl value
      | .error e => throw e
  | .array _ =>
      match expectPlainStringArray context reply with
      | .ok values => return .inr values
      | .error e => throw e
  | .simpleError message => throw <| .server message
  | _ => throw <| .decode s!"unexpected {context} reply"

def decodeSortedSetEntriesFromArray
    (context : String)
    (items : Array Protocol.Resp.Value)
    : Except Error (Array SortedSetEntry) :=
  match decodeStringPairsFromArray context items with
  | .error e => throw e
  | .ok pairs => return (pairs.map fun (member, score) => { member, score })

def expectSortedSetEntries (context : String) (reply : Protocol.Resp.Value) : Except Error (Array SortedSetEntry) :=
  match reply with
  | .array items =>
      decodeSortedSetEntriesFromArray context items
  | .map entries =>
      entries.mapM fun (member, score) => do
        let member <- expectString context member
        let score <- expectString context score
        return { member, score }
  | .simpleError message => throw <| .server message
  | _ => throw <| .decode s!"unexpected {context} reply"

def expectSortedSetScanResult (reply : Protocol.Resp.Value) : Except Error SortedSetScanResult := do
  match reply with
  | .array #[cursor, entries] =>
      let cursorText <- expectString "ZSCAN" cursor
      let some cursor := cursorText.toNat?
        | throw <| .decode "invalid ZSCAN cursor"
      let entries <- expectSortedSetEntries "ZSCAN" entries
      return { cursor := cursor.toUInt64, entries }
  | .simpleError message => throw <| .server message
  | _ => throw <| .decode "unexpected ZSCAN reply"

end LeanRedis
