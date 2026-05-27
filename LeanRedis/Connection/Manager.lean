import LeanRedis.Command
import LeanRedis.Config
import LeanRedis.Connection.Policy
import LeanRedis.Engine.Session
import LeanRedis.Protocol.Hello
import LeanRedis.Protocol.Resp.Encode
import LeanRedis.Protocol.Resp.Parse
import LeanRedis.Transport.Types
import LeanRedis.Transport.Tcp

namespace LeanRedis.Connection

open LeanRedis
open LeanRedis.Engine
open LeanRedis.Transport
open Std.Internal.IO.Async

def bootstrapReadSize : UInt64 := 4096

structure Manager (τ : Type) where
  config : Config
  transport? : Option τ := none
  session : Session := {}

def Manager.new (config : Config) : Manager τ :=
  {
    config
    transport? := none
    session := {}
  }

def Manager.isConnected (manager : Manager τ) : Bool :=
  manager.transport?.isSome && manager.session.isReady

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
    transport? := none
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
    : Async (Array Protocol.Resp.Value) := do
  if remaining == 0 then
    pure acc
  else
    match Protocol.Resp.Parse.parseAvailable parser with
    | .error err => Error.raise err
    | .ok (values, nextParser) =>
        if values.isEmpty then
          let read <- Transport.recv transport bootstrapReadSize
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
          let acc := acc ++ consumed
          readBootstrapReplies transport (remaining - takeCount) nextParser acc

private def runBootstrap [Transport τ] (manager : Manager τ) (transport : τ) : Async Session := do
  let plan := Protocol.bootstrapPlan manager.config
  for step in plan do
    Transport.send transport <| Protocol.Resp.Encode.encodeCommand step.request
  let replies <- readBootstrapReplies transport plan.size {} #[]
  match Protocol.bootstrapStateAfterReplies manager.config replies with
  | some state => pure { state }
  | none =>
      Error.raise <| .bootstrap s!"unexpected bootstrap replies ({replies.size})"

def Manager.connect [Transport τ] (manager : Manager τ) : Async (Manager τ) := do
  if manager.isConnected then
    pure manager
  else
    let transport <- Transport.connect manager.config.endpoint
    let manager := { manager with session := manager.session.markBootstrapping }
    try
      let session <- runBootstrap manager transport
      pure { manager with transport? := some transport, session }
    catch err =>
      try
        Transport.close transport
      catch _ =>
        pure ()
      Error.raise <| .bootstrap err.toString

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
    match manager.transport? with
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

def Manager.disconnect [Transport τ] (manager : Manager τ) : Async (Manager τ) := do
  match manager.transport? with
  | some transport =>
      Transport.close transport
      pure { manager with transport? := none, session := manager.session.markDisconnected }
  | none =>
      pure { manager with session := manager.session.markDisconnected }

end LeanRedis.Connection
