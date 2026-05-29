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
open Std.Internal.IO.Async

def readSize : UInt64 := 4096

inductive ExecuteError where
  | remoteDisconnect (reason : DisconnectReason) (error : Error)
  | commandError (error : Error)

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
      | some reason => Error.raise <| .transport s!"remote disconnect: {repr reason}"
      | none =>
          if read.bytes.isEmpty then
            Error.raise <| .transport "remote disconnect: closedByPeer"
          else
            readReply { runtime with parser := Protocol.Resp.Parse.feed runtime.parser read.bytes }

private def parseRemoteDisconnect? (err : IO.Error) : Option DisconnectReason :=
  let text := err.toString
  if text == "transport error: remote disconnect: LeanRedis.Transport.DisconnectReason.closedByPeer" then
    some .closedByPeer
  else if text == "transport error: remote disconnect: LeanRedis.Transport.DisconnectReason.closedByClient" then
    some .closedByClient
  else
    none

def Runtime.tryExecute
    [Transport τ]
    (runtime : Runtime τ)
    (request : CommandRequest)
    : Async (Except ExecuteError (Protocol.Resp.Value × Runtime τ)) := do
  try
    Transport.send runtime.transport <| Protocol.Resp.Encode.encodeCommand request
    let result <- readReply runtime
    pure <| .ok result
  catch err =>
    match parseRemoteDisconnect? err with
    | some reason =>
        pure <| .error <| .remoteDisconnect reason (.transport "connection closed while waiting for reply")
    | none =>
        pure <| .error <| .commandError (.transport err.toString)

def Runtime.execute
    [Transport τ]
    (runtime : Runtime τ)
    (request : CommandRequest)
    : Async (Protocol.Resp.Value × Runtime τ) := do
  match ← Runtime.tryExecute runtime request with
  | .ok result => pure result
  | .error (.remoteDisconnect _ err) => Error.raise err
  | .error (.commandError err) => Error.raise err

def Runtime.close [Transport τ] (runtime : Runtime τ) : Async Unit :=
  Transport.close runtime.transport

end LeanRedis.Connection
