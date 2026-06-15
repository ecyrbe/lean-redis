import LeanRedis.Command
import LeanRedis.Protocol.Version
import LeanRedis.Protocol.Resp.Value

namespace LeanRedis.Protocol

inductive SessionPhase where
  | disconnected
  | bootstrapping
  | ready
  | failed
  deriving BEq, Inhabited, Repr

structure State where
  phase : SessionPhase := .disconnected
  protocol? : Option Version := none
  selectedDb? : Option UInt32 := none
  lastReply? : Option Resp.Value := none
  deriving BEq, Inhabited

end LeanRedis.Protocol
