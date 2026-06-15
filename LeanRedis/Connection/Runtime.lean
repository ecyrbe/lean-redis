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

abbrev RuntimeM (τ : Type) := StateRefT (Runtime τ) Async

private def readReply
    [Transport τ]
    : RuntimeM τ (Except Error Protocol.Resp.Value) := do
 repeat do
    let runtime ← get
    match Protocol.Resp.Parse.parseOne runtime.parser with
    | .done (value, parser) _ =>
        modify fun runtime => { runtime with parser }
        return (.ok value)
    | .error message =>
        return (.error <| .protocol message)
    | .needMore =>
        let bytes <- Transport.recv runtime.transport readSize
        if bytes.isEmpty then
          Error.raise <| .transport "remote disconnect: closedByPeer"
        else
          modify fun runtime =>
            { runtime with
              parser := Protocol.Resp.Parse.feed runtime.parser bytes }
  unreachable!

private def readNReplies [Transport τ] (n : Nat) : RuntimeM τ (Array Protocol.Resp.Value) := do
  let mut values := #[]
  let mut n := n
  while n > 0 do
    let runtime ← get
    match Protocol.Resp.Parse.parseAvailable runtime.parser with
    | .error err => Error.raise err
    | .ok (nextValues, nextParser) =>
        if nextValues.isEmpty then
          let bytes ← Transport.recv runtime.transport readSize
          if bytes.isEmpty then
            Error.raise <| .transport "connection closed while waiting for pipeline reply"
          else
            modify fun r => { r with parser := Protocol.Resp.Parse.feed r.parser bytes }
        else
          let takeCount := Nat.min n nextValues.size
          let consumed := nextValues.extract 0 takeCount
          modify fun r => { r with parser := nextParser }
          n := n - takeCount
          values := values ++ consumed
  return values

def Runtime.tryExecute
    [Transport τ]
    (request : CommandRequest)
    : RuntimeM τ (Except ExecuteError Protocol.Resp.Value) := do
  let runtime ← get
  try
    Transport.sendAll runtime.transport <| Protocol.Resp.Encode.encodeCommand request
    match ← readReply with
    | .ok value => return .ok value
    | .error err => return .error <| .commandError err
  catch _ =>
    return .error <| .remoteDisconnect .closedByPeer (.transport "connection closed while waiting for reply")

def Runtime.execute
    [Transport τ]
    (request : CommandRequest)
    : RuntimeM τ Protocol.Resp.Value := do
  match ← Runtime.tryExecute request with
  | .ok result => return result
  | .error (.remoteDisconnect _ err) => Error.raise err
  | .error (.commandError err) => Error.raise err

def Runtime.tryExecBatch
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

def Runtime.execBatch
    [Transport τ]
    (requests : Array CommandRequest)
    : RuntimeM τ (Array Protocol.Resp.Value) := do
  match ← Runtime.tryExecBatch requests with
  | .ok result => return result
  | .error (.remoteDisconnect _ err) => Error.raise err
  | .error (.commandError err) => Error.raise err


def Runtime.close [Transport τ] (runtime : Runtime τ) : Async Unit :=
  Transport.close runtime.transport

end LeanRedis.Connection
