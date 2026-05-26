namespace LeanRedis.Transport

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

structure Transport where
  read : IO ByteArray
  write : ByteArray -> IO Unit
  close : IO Unit

abbrev Factory := Endpoint -> IO Transport

end LeanRedis.Transport
