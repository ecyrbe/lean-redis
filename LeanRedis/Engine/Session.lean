import LeanRedis.Config
import LeanRedis.Command
import LeanRedis.Protocol.Version
import LeanRedis.Protocol.Resp.Value
import LeanRedis.Protocol.Hello

namespace LeanRedis.Engine

open LeanRedis

inductive Phase where
  | disconnected
  | connecting (attempt : Nat)
  | bootstrapping (isReconnect : Bool)
  | ready (version : Protocol.Version) (selectedDb? : Option UInt32)
  | reconnecting (attempt : Nat)
  | closing
  | failed (error : String)
  deriving BEq, Inhabited, Repr

structure Session where
  phase : Phase := .disconnected
  lastReply? : Option Protocol.Resp.Value := none
  deriving BEq, Inhabited

inductive Action where
  | requestConnect
  | transportOpened
  | transportFailed (error : String)
  | bootstrapComplete (replies : Array Protocol.Resp.Value)
  | replyReceived (request? : Option CommandRequest) (reply : Protocol.Resp.Value)
  | remoteDisconnect
  | reconnectTick
  | reconnectExhausted
  | requestDisconnect
  | closeComplete
  deriving BEq, Inhabited

inductive EventTag where
  | initialConnectFailed
  | remoteDisconnected
  | reconnectAttemptStarted
  | reconnectAttemptFailed
  | reconnected
  | reconnectStopped
  | explicitlyDisconnected
  deriving BEq, Inhabited

inductive Effect where
  | sendBootstrapRequests
  | closeTransport
  | emit (tag : EventTag)
  deriving BEq, Inhabited

def Session.isReady (session : Session) : Bool :=
  match session.phase with
  | .ready _ _ => true
  | _ => false

def Session.isDisconnected (session : Session) : Bool :=
  match session.phase with
  | .disconnected => true
  | _ => false

def Session.protocol? (session : Session) : Option Protocol.Version :=
  match session.phase with
  | .ready v _ => some v
  | _ => none

def Session.selectedDb? (session : Session) : Option UInt32 :=
  match session.phase with
  | .ready _ db => db
  | _ => none

def step (action : Action) (session : Session) (config : Config) : Session × Array Effect :=
  match session.phase, action with
  | .disconnected, .requestConnect =>
      ({ session with phase := .connecting 0 }, #[])

  | .connecting n, .transportOpened =>
      let plan := Protocol.bootstrapPlan config
      let effects := if plan.isEmpty then #[] else #[.sendBootstrapRequests]
      ({ session with phase := .bootstrapping (n > 0) }, effects)

  | .connecting 0, .transportFailed _ =>
      ({ session with phase := .failed "connect failed" }, #[.emit .initialConnectFailed])

  | .connecting n, .transportFailed _ =>
      ({ session with phase := .reconnecting (n + 1) }, #[.emit .reconnectAttemptFailed])

  | .bootstrapping reconnect, .bootstrapComplete replies =>
      match Protocol.bootstrapStateAfterReplies config replies with
      | some state =>
          let version := state.protocol?.getD (Protocol.initialProtocol config.protocolPreference)
          let db := config.database?
          let effects := if reconnect then #[.emit .reconnected] else #[]
          ({ session with phase := .ready version db, lastReply? := state.lastReply? }, effects)
      | none =>
          ({ session with phase := .disconnected }, #[])

  | .ready v db, .replyReceived request? reply =>
      let newDb := match request? with
        | some req => req.selectedDb?
        | none => none
      let db' := newDb.orElse (fun () => db)
      ({ session with phase := .ready v db', lastReply? := some reply }, #[])

  | .ready _ _, .remoteDisconnect =>
      ({ session with phase := .reconnecting 0 }, #[.emit .remoteDisconnected])

  | .reconnecting n, .reconnectTick =>
      let attempt := n + 1
      if config.reconnectStrategy.shouldAttempt n then
        ({ session with phase := .connecting attempt }, #[.emit .reconnectAttemptStarted])
      else
        ({ session with phase := .disconnected }, #[.emit .reconnectStopped])

  | .reconnecting _, .reconnectExhausted =>
      ({ session with phase := .disconnected }, #[.emit .reconnectStopped])

  | _, .requestDisconnect =>
      ({ session with phase := .closing }, #[.closeTransport, .emit .explicitlyDisconnected])

  | .closing, .closeComplete =>
      ({ session with phase := .disconnected }, #[])

  | _, _ =>
      (session, #[])

end LeanRedis.Engine
