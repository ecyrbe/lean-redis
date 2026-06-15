import LeanRedis.Config
import LeanRedis.Protocol.Session
import LeanRedis.Protocol.Hello
import LeanRedis.Protocol.Resp.Encode
import LeanRedis.Protocol.Resp.Parse
import LeanRedis.Protocol.Resp.Value
import LeanRedis.Transport.Types
import LeanRedis.Error

namespace LeanRedis.Connection

open LeanRedis
open LeanRedis.Transport
open Std.Internal.IO.Async

structure DriverState (τ : Type) where
  transport? : Option τ := none
  parser : Protocol.Resp.Parse.ParserState := {}
  session : Protocol.Session := {}
  config : Config := default
  deriving Inhabited

def readSize : UInt64 := 4096

private partial def readOneReply [Transport τ] (transport : τ) (parser : Protocol.Resp.Parse.ParserState) : Async (Protocol.Resp.Value × Protocol.Resp.Parse.ParserState) := do
  match Protocol.Resp.Parse.parseOne parser with
  | .done (value, parser) _ => return (value, parser)
  | .error message => Error.raise <| .protocol message
  | .needMore =>
      let bytes ← Transport.recv transport readSize
      if bytes.isEmpty then
        Error.raise <| .transport "remote disconnect: closedByPeer"
      else
        readOneReply transport (Protocol.Resp.Parse.feed parser bytes)

private def readNReplies [Transport τ] (transport : τ) (parser : Protocol.Resp.Parse.ParserState) (n : Nat) : Async (Array Protocol.Resp.Value × Protocol.Resp.Parse.ParserState) := do
  let mut values := #[]
  let mut parser := parser
  let mut remaining := n
  while remaining > 0 do
    match Protocol.Resp.Parse.parseAvailable parser with
    | .error err => Error.raise err
    | .ok (nextValues, nextParser) =>
        if nextValues.isEmpty then
          let bytes ← Transport.recv transport readSize
          if bytes.isEmpty then
            Error.raise <| .transport "connection closed while waiting for pipeline reply"
          else
            parser := Protocol.Resp.Parse.feed parser bytes
        else
          let takeCount := Nat.min remaining nextValues.size
          let consumed := nextValues.extract 0 takeCount
          parser := nextParser
          remaining := remaining - takeCount
          values := values ++ consumed
  return (values, parser)

def executeCommand [Transport τ]
    (request : CommandRequest)
    (state : DriverState τ)
    : Async (DriverState τ × Protocol.Resp.Value) := do
  let some transport := state.transport?
    | Error.raise <| .unavailable "not connected"
  Transport.sendAll transport <| Protocol.Resp.Encode.encodeCommand request
  let (reply, parser) ← readOneReply transport state.parser
  let session' := (state.session.step (.replyReceived (some request) reply) state.config).1
  pure ({ state with parser, session := session' }, reply)

def executeBatch [Transport τ]
    (requests : Array CommandRequest)
    (state : DriverState τ)
    : Async (DriverState τ × Array Protocol.Resp.Value) := do
  let some transport := state.transport?
    | Error.raise <| .unavailable "not connected"
  for request in requests do
    Transport.sendAll transport <| Protocol.Resp.Encode.encodeCommand request
  let (replies, parser) ← readNReplies transport state.parser requests.size
  let mut session := state.session
  if replies.size = requests.size then
    for h: i in [:replies.size] do
      let (session', _) := session.step (.replyReceived (some requests[i]!) replies[i]) state.config
      session := session'
    return ({ state with parser, session }, replies)
  Error.raise <| Error.protocol "replies size does not match request size"

def connectBootstrap [Transport τ]
    (transport : τ)
    (config : Config)
    (state : DriverState τ)
    : Async (DriverState τ × Array Protocol.Effect) := do
  let state := { state with transport? := some transport, config }
  let (session, _) := state.session.step .transportOpened state.config
  let state := { state with session }
  let plan := Protocol.bootstrapPlan config
  if plan.isEmpty then
    pure (state, #[])
  else
    for step in plan do
      Transport.sendAll transport <| Protocol.Resp.Encode.encodeCommand step.request
    let (replies, parser) ← readNReplies transport state.parser plan.size
    let state := { state with parser }
    let (session', postEffects) := state.session.step (.bootstrapComplete replies) config
    let state := { state with session := session' }
    pure (state, postEffects)

def connect [Transport τ]
    (config : Config)
    (state : DriverState τ)
    : Async (DriverState τ × Array Protocol.Effect) := do
  let action := match state.session.phase with
    | .disconnected => .requestConnect
    | .reconnecting _ => .reconnectTick
    | _ => .requestConnect
  let (session, preEffects) := state.session.step action config
  match session.phase with
  | .connecting _ =>
      let transport ← Transport.connect config.endpoint
      let (state, postEffects) ← connectBootstrap transport config { state with session }
      pure (state, preEffects ++ postEffects)
  | _ =>
      pure ({ state with session }, preEffects)

def disconnect [Transport τ] (state : DriverState τ) : Async (DriverState τ) := do
  let (session, _) := state.session.step .requestDisconnect state.config
  match state.transport? with
  | some transport => Transport.close transport
  | none => pure ()
  let (session, _) := session.step .closeComplete (default : Config)
  pure { transport? := none, parser := {}, session }

end LeanRedis.Connection
