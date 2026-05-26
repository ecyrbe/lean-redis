namespace LeanRedis.Connection

inductive ReconnectPolicy where
  | failImmediately
  | retryForever
  | retryUpTo (attempts : Nat)
  deriving BEq, Inhabited, Repr

inductive RetryPolicy where
  | failPendingRequests
  | retryAfterReconnect
  deriving BEq, Inhabited, Repr

end LeanRedis.Connection
