import LeanRedis.Command
import LeanRedis.Protocol.Version
import LeanRedis.Protocol.Resp.Value

namespace LeanRedis.Engine

inductive SessionPhase where
  | disconnected
  | bootstrapping
  | ready
  | failed
  deriving BEq, Inhabited, Repr

structure State where
  phase : SessionPhase := .disconnected
  protocol? : Option Protocol.Version := none
  selectedDb? : Option UInt32 := none
  lastReply? : Option Protocol.Resp.Value := none
  deriving BEq, Inhabited

end LeanRedis.Engine
