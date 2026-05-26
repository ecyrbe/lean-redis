namespace LeanRedis

structure CommandRequest where
  name : String
  args : Array ByteArray := #[]
  allowRetry : Bool := true
  deriving BEq, Inhabited

end LeanRedis
