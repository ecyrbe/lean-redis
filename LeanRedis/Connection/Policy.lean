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

def ReconnectPolicy.allowsAttempt (policy : ReconnectPolicy) (attempt : Nat) : Bool :=
  match policy with
  | .failImmediately => false
  | .retryForever => true
  | .retryUpTo limit => attempt < limit

def RetryPolicy.keepsRequests (policy : RetryPolicy) : Bool :=
  match policy with
  | .failPendingRequests => false
  | .retryAfterReconnect => true

end LeanRedis.Connection
