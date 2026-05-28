import LeanRedis.Command
import LeanRedis.Engine.State
import LeanRedis.Error
import LeanRedis.Protocol.Resp.Encode
import LeanRedis.Protocol.Resp.Parse
import LeanRedis.Protocol.Resp.Value
import LeanRedis.Transport.Types

namespace LeanRedis.Connection

open LeanRedis
open LeanRedis.Transport

abbrev Async := Std.Internal.IO.Async.Async

def readSize : UInt64 := 4096

structure Runtime (τ : Type) where
  transport : τ
  parser : Protocol.Resp.Parse.ParserState := {}

private partial def readReply
    [Transport τ]
    (runtime : Runtime τ)
    : Async (Protocol.Resp.Value × Runtime τ) := do
  match Protocol.Resp.Parse.parseOne runtime.parser with
  | .done (value, parser) _ => pure (value, { runtime with parser })
  | .error message => Error.raise <| .protocol message
  | .needMore =>
      let read <- Transport.recv runtime.transport readSize
      match read.disconnect? with
      | some _ => Error.raise <| .transport "connection closed while waiting for reply"
      | none =>
          if read.bytes.isEmpty then
            Error.raise <| .transport "connection closed while waiting for reply"
          else
            readReply { runtime with parser := Protocol.Resp.Parse.feed runtime.parser read.bytes }

def Runtime.execute
    [Transport τ]
    (runtime : Runtime τ)
    (request : CommandRequest)
    : Async (Protocol.Resp.Value × Runtime τ) := do
  Transport.send runtime.transport <| Protocol.Resp.Encode.encodeCommand request
  readReply runtime

def Runtime.close [Transport τ] (runtime : Runtime τ) : Async Unit :=
  Transport.close runtime.transport

end LeanRedis.Connection
