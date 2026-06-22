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
  | .ok text => return text
  | .error message => fail message

def parseChar : Parser Char := do
  let byte ← any
  return Char.ofUInt8 byte

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
  | .ok value => return value
  | .error message => fail message

partial def parseBlobLike (mkValue : ByteArray -> Resp.Value) : Parser Resp.Value := do
  let length ← parseLengthHeader
  if length == -1 then
    return .null
  else if length < 0 then
    fail s!"invalid bulk length: {length}"
  else
    let payload ← Std.Internal.Parsec.ByteArray.take length.natAbs
    Std.Internal.Parsec.ByteArray.skipByte cr
    Std.Internal.Parsec.ByteArray.skipByte lf
    return mkValue payload.toByteArray

partial def parseBool : Parser Resp.Value := do
  let text ← parseLineText
  match text with
  | "t" => return .bool true
  | "f" => return .bool false
  | _ => fail s!"invalid boolean marker: {text}"

partial def parseNumber : Parser Resp.Value := do
  return .number (← parseLengthHeader)

mutual

partial def parseArrayLike (mkValue : Array Resp.Value -> Resp.Value) : Parser Resp.Value := do
  let length ← parseLengthHeader
  if length == -1 then
    return .null
  else if length < 0 then
    fail s!"invalid aggregate length: {length}"
  else
    return mkValue (← parseAggregateItems length.natAbs)

partial def parseMap : Parser Resp.Value := do
  let length ← parseLengthHeader
  if length == -1 then
    return .null
  else if length < 0 then
    fail s!"invalid map length: {length}"
  else
    return .map (← parseMapEntries length.natAbs)

partial def parseAggregateItems (count : Nat) : Parser (Array Resp.Value) := do
  let mut acc : Array Resp.Value := #[]
  let mut remaining := count
  while remaining > 0 do
    let value ← parseValue
    acc := acc.push value
    remaining := remaining - 1
  return acc

partial def parseMapEntries (count : Nat) : Parser (Array (Resp.Value × Resp.Value)) := do
  let mut acc : Array (Resp.Value × Resp.Value) := #[]
  let mut remaining := count
  while remaining > 0 do
    let key ← parseValue
    let value ← parseValue
    acc := acc.push (key, value)
    remaining := remaining - 1
  return acc

partial def parseValue : Parser Resp.Value := do
  let marker ← parseChar
  match marker with
  | '+' => return .simpleString (← parseLineText)
  | '-' => return .simpleError (← parseLineText)
  | ':' => return ← parseNumber
  | '_' => let _ ← parseLineBytes; return .null
  | '#' => return ← parseBool
  | ',' => return .double (← parseLineText)
  | '(' => return .bigNumber (← parseLineText)
  | '$' => return ← parseBlobLike Resp.Value.blobString
  | '=' => return ← parseBlobLike parseVerbatim
  | '*' => return ← parseArrayLike Resp.Value.array
  | '~' => return ← parseArrayLike Resp.Value.set
  | '>' => return ← parseArrayLike Resp.Value.push
  | '%' => return ← parseMap
  | _ => fail s!"unsupported RESP marker byte: {marker.toNat}"

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
