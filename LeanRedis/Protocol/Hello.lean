import LeanRedis.Config
import LeanRedis.Command
import LeanRedis.Protocol.State
import LeanRedis.Protocol.Version
import LeanRedis.Protocol.Resp.Encode
import LeanRedis.Protocol.Resp.Value

namespace LeanRedis.Protocol

open LeanRedis

inductive HelloOutcome where
  | negotiated (version : Version)
  | fallbackToResp2
  deriving BEq, Inhabited, Repr

inductive BootstrapStep where
  | auth (request : CommandRequest)
  | hello (request : CommandRequest)
  | select (request : CommandRequest)
  deriving BEq, Inhabited

def BootstrapStep.request : BootstrapStep -> CommandRequest
  | .auth request => request
  | .hello request => request
  | .select request => request

def preferredVersion (preference : ProtocolPreference) : Version :=
  match preference with
  | .resp2 => .resp2
  | .resp3 => .resp3
  | .auto => .resp3

def helloCommand : CommandRequest :=
  {
    name := "HELLO"
    args := #["3".toUTF8]
  }

def authCommand (auth : AuthConfig) : CommandRequest :=
  CommandRequest.auth auth

def selectCommand (database : UInt32) : CommandRequest :=
  {
    name := "SELECT"
    args := #[toString database |>.toUTF8]
  }

def bootstrapPlan (config : Config) : Array BootstrapStep :=
  let withAuth := match config.auth? with
    | some auth => #[BootstrapStep.auth (authCommand auth)]
    | none => #[]
  let withHello := match config.protocolPreference with
    | .resp2 => withAuth
    | .resp3 => withAuth.push (.hello helloCommand)
    | .auto => withAuth.push (.hello helloCommand)
  match config.database? with
  | some database => withHello.push (.select (selectCommand database))
  | none => withHello

def bootstrapRequests (config : Config) : Array CommandRequest :=
  bootstrapPlan config |>.map BootstrapStep.request

def decideHelloOutcome (reply : Resp.Value) : Option HelloOutcome :=
  match reply with
  | .map entries =>
      if entries.any fun (key, value) => key == .simpleString "proto" && value == .number 3 then
        some (.negotiated .resp3)
      else
        some (.negotiated .resp2)
  | .simpleError _ => some .fallbackToResp2
  | .blobString bytes =>
      match String.fromUTF8? bytes with
      | some "OK" => some (.negotiated .resp2)
      | _ => none
  | .simpleString "OK" => some (.negotiated .resp2)
  | _ => none

def protocolAfterHello (preference : ProtocolPreference) (reply : Resp.Value) : Option Version :=
  match preference with
  | .resp2 => some .resp2
  | .resp3 =>
      match decideHelloOutcome reply with
      | some (.negotiated version) => some version
      | some .fallbackToResp2 => none
      | none => none
  | .auto =>
      match decideHelloOutcome reply with
      | some (.negotiated version) => some version
      | some .fallbackToResp2 => some .resp2
      | none => none

def initialProtocol (preference : ProtocolPreference) : Version :=
  match preference with
  | .resp2 => .resp2
  | .resp3 => .resp2
  | .auto => .resp2

def applyHelloReply
    (state : Protocol.State)
    (preference : ProtocolPreference)
    (reply : Resp.Value)
    : Option Protocol.State := do
  let version ← protocolAfterHello preference reply
  pure { state with protocol? := some version, lastReply? := some reply }

def markBootstrapReady
    (state : Protocol.State)
    (protocol : Version)
    (database? : Option UInt32)
    : Protocol.State :=
  {
    state with
    phase := .ready
    protocol? := some protocol
    selectedDb? := database?
  }

def applyBootstrapReply
    (state : Protocol.State)
    (preference : ProtocolPreference)
    (step : BootstrapStep)
    (reply : Resp.Value)
    : Option Protocol.State :=
  match step with
  | .auth _ =>
      match reply with
      | .simpleString "OK" => some { state with lastReply? := some reply }
      | .blobString bytes =>
          match String.fromUTF8? bytes with
          | some "OK" => some { state with lastReply? := some reply }
          | _ => none
      | _ => none
  | .hello _ => applyHelloReply state preference reply
  | .select _ =>
      match reply with
      | .simpleString "OK" =>
          some {
            state with
            lastReply? := some reply
            selectedDb? := state.selectedDb?
          }
      | .blobString bytes =>
          match String.fromUTF8? bytes with
          | some "OK" =>
              some {
                state with
                lastReply? := some reply
                selectedDb? := state.selectedDb?
              }
          | _ => none
      | _ => none

def bootstrapStateAfterStep
    (state : Protocol.State)
    (config : Config)
    (step : BootstrapStep)
    (reply : Resp.Value)
    : Option Protocol.State :=
  match applyBootstrapReply state config.protocolPreference step reply with
  | some nextState =>
      match step with
      | .select _ => some { nextState with selectedDb? := config.database? }
      | _ => some nextState
  | none => none

def bootstrapStateAfterReplies
    (config : Config)
    (replies : Array Resp.Value)
    : Option Protocol.State := do
  let plan := bootstrapPlan config
  if plan.size != replies.size then
    none
  else
    let initial : Protocol.State := {
      phase := .bootstrapping
      protocol? := some (initialProtocol config.protocolPreference)
      selectedDb? := none
    }
    let pairs := List.zip plan.toList replies.toList
    let mut current := initial
    for (step, reply) in pairs do
      let next ← bootstrapStateAfterStep current config step reply
      current := next
    let protocol := current.protocol?.getD (initialProtocol config.protocolPreference)
    some <| markBootstrapReady current protocol config.database?

def bootstrapSucceeded
    (state : Protocol.State)
    (preference : ProtocolPreference)
    (helloReply : Resp.Value)
    (database? : Option UInt32)
    : Option Protocol.State := do
  let state ← applyHelloReply state preference helloReply
  let protocol ← state.protocol?
  pure <| markBootstrapReady state protocol database?

end LeanRedis.Protocol
