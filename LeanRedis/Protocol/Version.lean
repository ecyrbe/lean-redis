namespace LeanRedis.Protocol

inductive Version where
  | resp2
  | resp3
  deriving BEq, Inhabited, Repr

end LeanRedis.Protocol
