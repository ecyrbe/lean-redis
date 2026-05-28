import LeanRedis.Command
import LeanRedis.Config
import LeanRedis.Connection.Policy
import LeanRedis.Connection.Runtime
import LeanRedis.Engine.Session
import LeanRedis.Protocol.Hello
import LeanRedis.Protocol.Resp.Encode
import LeanRedis.Protocol.Resp.Parse
import LeanRedis.Protocol.Resp.Value
import LeanRedis.Transport.Types
import LeanRedis.Transport.Tcp

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

private def disconnectedState
    (manager : Manager τ)
    (phase : SessionPhase)
    : Manager τ :=
  let pending :=
    if manager.config.retryPolicy.keepsRequests then
      manager.session.state.pending
    else
      #[]
  {
    manager with
    runtime? := none
    session := {
      state := {
        manager.session.state with
        phase := phase
        pending := pending
        outbox := #[]
      }
    }
  }

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
          let read <- Transport.recv transport readSize
          match read.disconnect? with
          | some _ => Error.raise <| .bootstrap "connection closed while waiting for bootstrap reply"
          | none =>
              if read.bytes.isEmpty then
                Error.raise <| .bootstrap "connection closed while waiting for bootstrap reply"
              else
                readBootstrapReplies transport remaining (Protocol.Resp.Parse.feed nextParser read.bytes) acc
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

def Manager.recordDisconnect (manager : Manager τ) (_reason : DisconnectReason) : Manager τ :=
  disconnectedState manager .failed

def Manager.reconnect? [Transport τ] (manager : Manager τ) (attempt : Nat := 0) : Async (Option (Manager τ)) := do
  if manager.config.reconnectPolicy.allowsAttempt attempt then
    some <$> (Manager.connect <| disconnectedState manager .bootstrapping)
  else
    pure none

def Manager.ensureConnected [Transport τ] (manager : Manager τ) : Async (Manager τ) := do
  if manager.isConnected then
    pure manager
  else
    match manager.runtime? with
    | some _ => Manager.connect manager
    | none =>
        match ← manager.reconnect? with
        | some connected => pure connected
        | none => Error.raise <| .unavailable "connection is not ready and reconnect policy disallows reconnect"

def Manager.notePending (manager : Manager τ) (request : CommandRequest) : Manager τ :=
  {
    manager with
    session := {
      state := {
        manager.session.state with
        pending := manager.session.state.pending.push { request := request }
      }
    }
  }

def Manager.clearPending (manager : Manager τ) : Manager τ :=
  {
    manager with
    session := {
      state := {
        manager.session.state with
        pending := #[]
      }
    }
  }

def Manager.withRuntime [Transport τ]
    (manager : Manager τ)
    (action : Runtime τ -> Async (α × Runtime τ × Engine.State))
    : Async (α × Manager τ) := do
  let manager <- manager.ensureConnected
  let some runtime := manager.runtime?
    | Error.raise <| .unavailable "connection is not ready"
  try
    let (result, runtime, state) <- action runtime
    let manager := {
      manager.clearPending with
      runtime? := some runtime
      session := { state := state }
    }
    pure (result, manager)
  catch err =>
    Error.raise <| .transport err.toString

def Manager.disconnect [Transport τ] (manager : Manager τ) : Async (Manager τ) := do
  match manager.runtime? with
  | some runtime =>
      Runtime.close runtime
      pure { manager with runtime? := none, session := manager.session.markDisconnected }
  | none =>
      pure { manager with session := manager.session.markDisconnected }

end LeanRedis.Connection
