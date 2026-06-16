import LeanRedis.Error
import LeanRedis.Protocol.Resp.Value
import Std.Internal.Parsec.Basic
import Std.Internal.Parsec.String
import Std.Internal.Parsec.ByteArray

namespace LeanRedis.Protocol.Resp.Parse

open LeanRedis
open Std.Internal.Parsec

abbrev Parser := Std.Internal.Parsec.ByteArray.Parser

inductive ParseStatus (α : Type) where
  | done (value : α)
  | needMore
  | error (message : String)
  deriving Inhabited

structure ParserState where
  pending : ByteArray := ByteArray.empty
  deriving Inhabited

abbrev ParserM := StateT ParserState (Except Error)

def cr : UInt8 := '\r'.toUInt8
def lf : UInt8 := '\n'.toUInt8

def decodeUtf8 (bytes : ByteArray) : Except String String :=
  match String.fromUTF8? bytes with
  | some text => .ok text
  | none => .error "invalid UTF-8 in RESP text payload"

def bytesToString (slice : ByteSlice) : Except String String :=
  decodeUtf8 slice.toByteArray

def parseIntText (text : String) : Except String Int :=
  match text.toInt? with
  | some value => .ok value
  | none => .error s!"invalid integer: {text}"

def parseLineBytes : Parser ByteArray := do
  let bytes ← Std.Internal.Parsec.ByteArray.takeUntil (· == cr)
  Std.Internal.Parsec.ByteArray.skipByte cr
  Std.Internal.Parsec.ByteArray.skipByte lf
  return bytes.toByteArray

def parseLineText : Parser String := do
  let bytes ← parseLineBytes
  match decodeUtf8 bytes with
  | .ok text => pure text
  | .error message => fail message

def parseVerbatim (bytes : ByteArray) : Resp.Value :=
  match decodeUtf8 bytes with
  | .ok text =>
      match text.splitOn ":" with
      | format :: rest => .verbatimString format (String.intercalate ":" rest)
      | [] => .verbatimString "txt" text
  | .error _ => .verbatimString "bin" ""

def parseLengthHeader : Parser Int := do
  let text ← parseLineText
  match parseIntText text with
  | .ok value => pure value
  | .error message => fail message

partial def parseBlobLike (mkValue : ByteArray -> Resp.Value) : Parser Resp.Value := do
  let length ← parseLengthHeader
  if length == -1 then
    pure .null
  else if length < 0 then
    fail s!"invalid bulk length: {length}"
  else
    let payload ← Std.Internal.Parsec.ByteArray.take length.natAbs
    Std.Internal.Parsec.ByteArray.skipByte cr
    Std.Internal.Parsec.ByteArray.skipByte lf
    pure <| mkValue payload.toByteArray

partial def parseBool : Parser Resp.Value := do
  let text ← parseLineText
  match text with
  | "t" => pure (.bool true)
  | "f" => pure (.bool false)
  | _ => fail s!"invalid boolean marker: {text}"

partial def parseNumber : Parser Resp.Value := do
  pure (.number (← parseLengthHeader))

mutual

partial def parseArrayLike (mkValue : Array Resp.Value -> Resp.Value) : Parser Resp.Value := do
  let length ← parseLengthHeader
  if length == -1 then
    pure .null
  else if length < 0 then
    fail s!"invalid aggregate length: {length}"
  else
    return mkValue (← parseAggregateItems length.natAbs)

partial def parseMap : Parser Resp.Value := do
  let length ← parseLengthHeader
  if length == -1 then
    pure .null
  else if length < 0 then
    fail s!"invalid map length: {length}"
  else
    return .map (← parseMapEntries length.natAbs)

partial def parseAggregateItems (count : Nat) : Parser (Array Resp.Value) := do
  let rec loop (remaining : Nat) (acc : Array Resp.Value) : Parser (Array Resp.Value) := do
    if remaining == 0 then
      pure acc
    else
      let value ← parseValue
      loop (remaining - 1) (acc.push value)
  loop count #[]

partial def parseMapEntries (count : Nat) : Parser (Array (Resp.Value × Resp.Value)) := do
  let rec loop (remaining : Nat) (acc : Array (Resp.Value × Resp.Value)) : Parser (Array (Resp.Value × Resp.Value)) := do
    if remaining == 0 then
      pure acc
    else
      let key ← parseValue
      let value ← parseValue
      loop (remaining - 1) (acc.push (key, value))
  loop count #[]

partial def parseValue : Parser Resp.Value := do
  let marker ← any
  if marker == '+'.toUInt8 then
    return .simpleString (← parseLineText)
  if marker == '-'.toUInt8 then
    return .simpleError (← parseLineText)
  if marker == ':'.toUInt8 then
    return ← parseNumber
  if marker == '_'.toUInt8 then
    let _ ← parseLineBytes
    return .null
  if marker == '#'.toUInt8 then
    return ← parseBool
  if marker == ','.toUInt8 then
    return .double (← parseLineText)
  if marker == '('.toUInt8 then
    return .bigNumber (← parseLineText)
  if marker == '$'.toUInt8 then
    return ← parseBlobLike Resp.Value.blobString
  if marker == '='.toUInt8 then
    return ← parseBlobLike parseVerbatim
  if marker == '*'.toUInt8 then
    return ← parseArrayLike Resp.Value.array
  if marker == '~'.toUInt8 then
    return ← parseArrayLike Resp.Value.set
  if marker == '>'.toUInt8 then
    return ← parseArrayLike Resp.Value.push
  if marker == '%'.toUInt8 then
    return ← parseMap
  fail s!"unsupported RESP marker byte: {marker.toNat}"

end

def feed (state : ParserState) (chunk : ByteArray) : ParserState :=
  { pending := state.pending.append chunk }

def parseOne (state : ParserState) : ParseStatus (Resp.Value × ParserState) :=
  match parseValue state.pending.iter with
  | .success rest value =>
      let remaining := state.pending.extract rest.pos state.pending.size
      .done (value, { pending := remaining })
  | .error _ .eof => .needMore
  | .error _ err => .error (toString err)


def parseAvailable : ParserM (Array Resp.Value) := do
    let mut acc := #[]
    repeat do
      let state ← get
      match parseOne state with
      | .done (value, nextState) =>
          acc := acc.push value
          set nextState
      | .needMore => return acc
      | .error message => throw (.protocol message)
    unreachable!

end LeanRedis.Protocol.Resp.Parse
