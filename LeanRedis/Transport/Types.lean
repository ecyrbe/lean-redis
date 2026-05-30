import Std.Internal.Async

namespace LeanRedis.Transport

open Std.Internal.IO.Async

structure Endpoint where
  host : String
  port : UInt16 := 6379
  deriving BEq, Inhabited, Repr

inductive DisconnectReason where
  | closedByPeer
  | closedByClient
  | readFailure (message : String)
  | writeFailure (message : String)
  deriving BEq, Inhabited, Repr

class Transport (α : Type) where
  connect : Endpoint -> Async α
  recv : α -> UInt64 -> Async ByteArray
  send : α -> ByteArray -> Async Unit
  close : α -> Async Unit

end LeanRedis.Transport
