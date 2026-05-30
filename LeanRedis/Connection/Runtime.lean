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
 while true do
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

def Runtime.tryExecute
    [Transport τ]
    (request : CommandRequest)
    : RuntimeM τ (Except ExecuteError Protocol.Resp.Value) := do
  let runtime ← get
  try
    Transport.send runtime.transport <| Protocol.Resp.Encode.encodeCommand request
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

def Runtime.close [Transport τ] (runtime : Runtime τ) : Async Unit :=
  Transport.close runtime.transport

end LeanRedis.Connection
