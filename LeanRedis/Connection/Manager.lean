import LeanRedis.Config
import LeanRedis.Connection.Runtime
import LeanRedis.Engine.Session
import LeanRedis.Protocol.Hello
import LeanRedis.Transport.Types

namespace LeanRedis.Connection

open LeanRedis
open LeanRedis.Engine
open LeanRedis.Transport
open Std.Internal.IO.Async

structure Manager (τ : Type) where
  config : Config
  runtime? : Option (Runtime τ) := none
  session : Session := {}

def Manager.new (config : Config) : Manager τ :=
  {
    config
    runtime? := none
    session := {}
  }

def Manager.isConnected (manager : Manager τ) : Bool :=
  manager.runtime?.isSome && manager.session.isReady

private partial def readBootstrapReplies
    [Transport τ]
    (transport : τ)
    (remaining : Nat)
    (parser : Protocol.Resp.Parse.ParserState)
    (acc : Array Protocol.Resp.Value)
    : Async (Array Protocol.Resp.Value × Protocol.Resp.Parse.ParserState) := do
  if remaining == 0 then
    pure (acc, parser)
  else
    match Protocol.Resp.Parse.parseAvailable parser with
    | .error err => Error.raise err
    | .ok (values, nextParser) =>
        if values.isEmpty then
          let bytes <- Transport.recv transport readSize
          if bytes.isEmpty then
            Error.raise <| .bootstrap "connection closed while waiting for bootstrap reply"
          else
            readBootstrapReplies transport remaining (Protocol.Resp.Parse.feed nextParser bytes) acc
        else
          let takeCount := Nat.min remaining values.size
          let consumed := values.extract 0 takeCount
          readBootstrapReplies transport (remaining - takeCount) nextParser (acc ++ consumed)

private def connectRuntime [Transport τ]
    (manager : Manager τ)
    : Async (Runtime τ × Session) := do
  let transport <- Transport.connect manager.config.endpoint
  try
    let plan := Protocol.bootstrapPlan manager.config
    for step in plan do
      Transport.send transport <| Protocol.Resp.Encode.encodeCommand step.request
    let (replies, parser) <- readBootstrapReplies transport plan.size {} #[]
    match Protocol.bootstrapStateAfterReplies manager.config replies with
    | some state => pure ({ transport, parser }, { state })
    | none => Error.raise <| .bootstrap s!"unexpected bootstrap replies ({replies.size})"
  catch err =>
    try
      Transport.close transport
    catch _ =>
      pure ()
    Error.raise <| .bootstrap err.toString

def Manager.connect [Transport τ] (manager : Manager τ) : Async (Manager τ) := do
  if manager.isConnected then
    pure manager
  else
    let (runtime, session) <- connectRuntime manager
    pure { manager with runtime? := some runtime, session }

def Manager.disconnect [Transport τ] (manager : Manager τ) : Async (Manager τ) := do
  match manager.runtime? with
  | some runtime =>
      Runtime.close runtime
      pure { manager with runtime? := none, session := manager.session.markDisconnected }
  | none =>
      pure { manager with session := manager.session.markDisconnected }

end LeanRedis.Connection
