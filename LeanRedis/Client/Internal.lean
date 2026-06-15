import Std.Sync.Mutex
import LeanRedis.Client.Event
import LeanRedis.Connection.Driver
import LeanRedis.Error

namespace LeanRedis

open LeanRedis

abbrev ClientEventSubscriptionId := Nat

structure ClientSubscribers where
  nextId : ClientEventSubscriptionId := 0
  handlers : Array (ClientEventSubscriptionId × Client.EventHandler) := #[]
  deriving Inhabited

structure Client (τ : Type) where
  state : Std.Mutex (Connection.DriverState τ)
  subscribers : Std.Mutex ClientSubscribers

end LeanRedis
