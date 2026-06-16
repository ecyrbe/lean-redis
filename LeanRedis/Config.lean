import LeanRedis.Transport.Types
import LeanRedis.Data.Redacted

namespace LeanRedis

structure ReconnectExponentialBackoff where
  baseDelayMs : UInt32 := 100
  maxDelayMs : UInt32 := 30_000
  jitter : Bool := true
  deriving BEq, Inhabited, Repr

inductive ReconnectStrategy where
  | disabled
  | fixedInterval (delayMs : UInt32) (maxAttempts? : Option Nat := none)
  | exponentialBackoff (config : ReconnectExponentialBackoff := {}) (maxAttempts? : Option Nat := none)
  deriving BEq, Inhabited, Repr

inductive ProtocolPreference where
  | auto
  | resp2
  | resp3
  deriving BEq, Inhabited, Repr

structure AuthConfig where
  username? : Option String := none
  password : Redacted
  deriving BEq, Inhabited, Repr

structure TimeoutConfig where
  connectMs? : Option UInt32 := none
  responseMs? : Option UInt32 := none
  deriving BEq, Inhabited, Repr

structure Config where
  endpoint : Transport.Endpoint
  auth? : Option AuthConfig := none
  database? : Option UInt32 := none
  protocolPreference : ProtocolPreference := .auto
  clientName? : Option String := none
  timeouts : TimeoutConfig := {}
  reconnectStrategy : ReconnectStrategy := .disabled
  deriving BEq, Repr

instance : Inhabited Config where
  default := {
    endpoint := { host := "", port := 0 }
  }

end LeanRedis
