import LeanRedis.Command
import LeanRedis.Protocol.Resp.Value

namespace LeanRedis.Protocol.Resp.Encode

open LeanRedis

def crlf : String := "\r\n"

def encodeBulkString (arg : ByteArray) : ByteArray :=
  let header := ("$" ++ toString arg.size ++ crlf).toUTF8
  let trailer := crlf.toUTF8
  header.append arg |>.append trailer

def encodeArrayHeader (count : Nat) : ByteArray :=
  s!"*{count}{crlf}".toUTF8

def encodeSetHeader (count : Nat) : ByteArray :=
  s!"~{count}{crlf}".toUTF8

def encodePushHeader (count : Nat) : ByteArray :=
  s!">{count}{crlf}".toUTF8

def encodeMapHeader (count : Nat) : ByteArray :=
  s!"%{count}{crlf}".toUTF8

def encodeTextLine (tag : String) (value : String) : ByteArray :=
  (tag ++ value ++ crlf).toUTF8

def encodeBlobWithPrefix (tag : String) (bytes : ByteArray) : ByteArray :=
  let header := (tag ++ toString bytes.size ++ crlf).toUTF8
  header.append bytes |>.append crlf.toUTF8

partial def encodeValue : Resp.Value -> ByteArray
  | .simpleString value => encodeTextLine "+" value
  | .blobString value => encodeBlobWithPrefix "$" value
  | .simpleError message => encodeTextLine "-" message
  | .number value => encodeTextLine ":" (toString value)
  | .null => "_\r\n".toUTF8
  | .array items =>
      items.toList.foldl (fun acc value => acc.append (encodeValue value)) (encodeArrayHeader items.size)
  | .map entries =>
      entries.toList.foldl
        (fun acc (key, value) => acc.append (encodeValue key) |>.append (encodeValue value))
        (encodeMapHeader entries.size)
  | .set items =>
      items.toList.foldl (fun acc value => acc.append (encodeValue value)) (encodeSetHeader items.size)
  | .bool true => "#t\r\n".toUTF8
  | .bool false => "#f\r\n".toUTF8
  | .double value => encodeTextLine "," value
  | .bigNumber value => encodeTextLine "(" value
  | .verbatimString format value => encodeBlobWithPrefix "=" ((format ++ ":" ++ value).toUTF8)
  | .push items =>
      items.toList.foldl (fun acc value => acc.append (encodeValue value)) (encodePushHeader items.size)

def encodeCommandName (name : String) : ByteArray :=
  encodeBulkString name.toUTF8

def encodeCommand (request : CommandRequest) : Array ByteArray :=
  let header := encodeArrayHeader (request.args.size + 1)
  let commandName := encodeCommandName request.name
  let args := request.args.map encodeBulkString
  #[header, commandName] ++ args

end LeanRedis.Protocol.Resp.Encode
