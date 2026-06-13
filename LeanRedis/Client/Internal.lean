import Std.Sync.Mutex
import LeanRedis.Client.Event
import LeanRedis.Connection.Manager
import LeanRedis.Connection.Runtime
import LeanRedis.Pipeline.Manager
import LeanRedis.Error
import LeanRedis.Transport.Tcp
import Std.Time

namespace LeanRedis

inductive ClientConnectionStatus where
  | disconnected
  | connecting
  | connected
  | reconnecting
  | closed
  deriving BEq, Inhabited, Repr

abbrev ClientEventSubscriptionId := Nat

structure ClientReconnectControl where
  generation : Nat := 0
  deriving Inhabited

structure ClientSubscribers where
  nextId : ClientEventSubscriptionId := 0
  handlers : Array (ClientEventSubscriptionId × Client.EventHandler) := #[]
  deriving Inhabited

structure Client (τ : Type) where
  manager : Std.Mutex (Connection.Manager τ)
  operation : Std.Mutex PUnit
  status : Std.Mutex ClientConnectionStatus
  reconnectControl : Std.Mutex ClientReconnectControl
  subscribers : Std.Mutex ClientSubscribers

end LeanRedis
