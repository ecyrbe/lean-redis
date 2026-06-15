import LeanRedis.Config
import LeanRedis.Connection.Runtime
import LeanRedis.Engine.Session
import LeanRedis.Protocol.Hello
import LeanRedis.Transport.Types
import LeanRedis.Pipeline.Basic

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
      Transport.sendAll transport <| Protocol.Resp.Encode.encodeCommand step.request
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

/--
Execute a pipeline on the Manager's runtime, returning the raw `ExecuteError`
so callers (e.g. Client) can distinguish remote disconnect from command errors.
-/
def Manager.tryRunPipeline
    [Transport τ]
    (pipeline : Pipeline α)
    (manager : Connection.Manager τ)
    : Async (Except ExecuteError (Connection.Manager τ × HList α)) := do
  let some runtime := manager.runtime?
    | return (.error <| .commandError (.unavailable "manager is not connected"))
  let (result, runtime) ← (Runtime.tryExecBatch pipeline.requests).run runtime
  match result with
  | .error err => return (.error err)
  | .ok values =>
      match pipeline.exec values with
      | .ok decoded =>
          let lastReply := if h: values.size > 0 then some values[values.size - 1] else none
          let manager := {
            manager with
            runtime? := some runtime
            session := { manager.session with state := { manager.session.state with lastReply? := lastReply } }
          }
          return (.ok (manager, decoded))
      | .error err => return (.error <| .commandError err)

/--
Execute a pipeline on the Manager's runtime, raising on any error.
-/
def Manager.runPipeline
    [Transport τ]
    (pipeline : Pipeline α)
    (manager : Connection.Manager τ)
    : Async (Connection.Manager τ × HList α) := do
  match ← manager.tryRunPipeline pipeline with
  | .ok result => pure result
  | .error (.commandError err) => Error.raise err
  | .error (.remoteDisconnect _ err) => Error.raise err

end LeanRedis.Connection
