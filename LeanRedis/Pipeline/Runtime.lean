import LeanRedis.Command
import LeanRedis.Connection.Runtime
import LeanRedis.Protocol.Resp.Encode
import LeanRedis.Protocol.Resp.Parse
import LeanRedis.Protocol.Resp.Value
import LeanRedis.Transport.Types

namespace LeanRedis.Pipeline

open LeanRedis
open LeanRedis.Connection
open LeanRedis.Transport
open Std.Internal.IO.Async

private partial def readNReplies
    [Transport τ]
    (n : Nat)
    (acc : Array Protocol.Resp.Value := #[])
    : RuntimeM τ (Array Protocol.Resp.Value) := do
  if n == 0 then
    return acc
  else
    let runtime ← get
    match Protocol.Resp.Parse.parseAvailable runtime.parser with
    | .error err => Error.raise err
    | .ok (values, nextParser) =>
        if values.isEmpty then
          let bytes ← Transport.recv runtime.transport readSize
          if bytes.isEmpty then
            Error.raise <| .transport "connection closed while waiting for pipeline reply"
          else
            modify fun r => { r with parser := Protocol.Resp.Parse.feed r.parser bytes }
            readNReplies n acc
        else
          let takeCount := Nat.min n values.size
          let consumed := values.extract 0 takeCount
          modify fun r => { r with parser := nextParser }
          readNReplies (n - takeCount) (acc ++ consumed)

def Runtime.tryExecuteBatch
    [Transport τ]
    (requests : Array CommandRequest)
    : RuntimeM τ (Except ExecuteError (Array Protocol.Resp.Value)) := do
  let runtime ← get
  try
    for request in requests do
      Transport.sendAll runtime.transport <| Protocol.Resp.Encode.encodeCommand request
    let values ← readNReplies requests.size
    return .ok values
  catch _ =>
    return .error <| .remoteDisconnect .closedByPeer (.transport "connection closed while waiting for pipeline replies")

def Runtime.executeBatch
    [Transport τ]
    (requests : Array CommandRequest)
    : RuntimeM τ (Array Protocol.Resp.Value) := do
  match ← Runtime.tryExecuteBatch requests with
  | .ok result => return result
  | .error (.remoteDisconnect _ err) => Error.raise err
  | .error (.commandError err) => Error.raise err

end LeanRedis.Pipeline
