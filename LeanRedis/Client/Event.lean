import LeanRedis.Error
import LeanRedis.Transport.Types
import Std.Time

namespace LeanRedis.Client

structure EventMetadata where
  timestamp : Std.Time.Timestamp
  error? : Option LeanRedis.Error := none
  attempt? : Option Nat := none
  deriving Repr

inductive Event where
  | initialConnectFailed (metadata : EventMetadata)
  | remoteDisconnected (reason : LeanRedis.Transport.DisconnectReason) (metadata : EventMetadata)
  | reconnectAttemptStarted (metadata : EventMetadata)
  | reconnectAttemptFailed (metadata : EventMetadata)
  | reconnectScheduled (delayMs : UInt32) (metadata : EventMetadata)
  | reconnected (metadata : EventMetadata)
  | reconnectStopped (metadata : EventMetadata)
  | explicitlyDisconnected (metadata : EventMetadata)
  deriving Repr

abbrev EventHandler := Event -> Std.Internal.IO.Async.Async Unit

end LeanRedis.Client
