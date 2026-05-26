import LeanRedis.Command

namespace LeanRedis.Protocol.Resp.Encode

open LeanRedis

def crlf : String := "\r\n"

def encodeBulkString (arg : ByteArray) : ByteArray :=
  let header := ("$" ++ toString arg.size ++ crlf).toUTF8
  let trailer := crlf.toUTF8
  header.append arg |>.append trailer

def encodeArrayHeader (count : Nat) : ByteArray :=
  s!"*{count}{crlf}".toUTF8

def encodeCommandName (name : String) : ByteArray :=
  encodeBulkString name.toUTF8

def encodeCommand (request : CommandRequest) : ByteArray :=
  let payload := request.args.toList.foldl
    (fun acc arg => acc.append (encodeBulkString arg))
    (encodeCommandName request.name)
  encodeArrayHeader (request.args.size + 1) |>.append payload

end LeanRedis.Protocol.Resp.Encode
