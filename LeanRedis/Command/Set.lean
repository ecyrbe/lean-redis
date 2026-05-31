import LeanRedis.Command.Base

namespace LeanRedis

structure SScanOptions where
  match? : Option String := none
  count? : Option UInt64 := none
  deriving BEq, Inhabited, Repr

structure SetScanResult where
  cursor : UInt64
  members : Array String
  deriving BEq, Inhabited, Repr

namespace CommandRequest

def sScanArgs (options : SScanOptions) : Array ByteArray :=
  (match options.match? with
    | some pattern => utf8Args #["MATCH", pattern]
    | none => #[])
  ++ (match options.count? with
    | some count => utf8Args #["COUNT", toString count]
    | none => #[])

end CommandRequest

/--
SADD key member [member ...]
-/
def CommandRequest.sAdd (key : String) (members : Array String) : CommandRequest :=
  {
    name := "SADD"
    args := CommandRequest.utf8Args #[key] ++ CommandRequest.utf8Args members
  }

/--
SREM key member [member ...]
-/
def CommandRequest.sRem (key : String) (members : Array String) : CommandRequest :=
  {
    name := "SREM"
    args := CommandRequest.utf8Args #[key] ++ CommandRequest.utf8Args members
  }

/--
SCARD key
-/
def CommandRequest.sCard (key : String) : CommandRequest :=
  {
    name := "SCARD"
    args := CommandRequest.utf8Args #[key]
  }

/--
SISMEMBER key member
-/
def CommandRequest.sIsMember (key member : String) : CommandRequest :=
  {
    name := "SISMEMBER"
    args := CommandRequest.utf8Args #[key, member]
  }

/--
SMISMEMBER key member [member ...]
-/
def CommandRequest.sMIsMember (key : String) (members : Array String) : CommandRequest :=
  {
    name := "SMISMEMBER"
    args := CommandRequest.utf8Args #[key] ++ CommandRequest.utf8Args members
  }

/--
SMEMBERS key
-/
def CommandRequest.sMembers (key : String) : CommandRequest :=
  {
    name := "SMEMBERS"
    args := CommandRequest.utf8Args #[key]
  }

/--
SPOP key [count]
-/
def CommandRequest.sPop (key : String) : CommandRequest :=
  {
    name := "SPOP"
    args := CommandRequest.utf8Args #[key]
  }

/--
SPOP key count
-/
def CommandRequest.sPopCount (key : String) (count : UInt64) : CommandRequest :=
  {
    name := "SPOP"
    args := CommandRequest.utf8Args #[key, toString count]
  }

/--
SRANDMEMBER key [count]
-/
def CommandRequest.sRandMember (key : String) : CommandRequest :=
  {
    name := "SRANDMEMBER"
    args := CommandRequest.utf8Args #[key]
  }

/--
SRANDMEMBER key count
-/
def CommandRequest.sRandMembers (key : String) (count : Int) : CommandRequest :=
  {
    name := "SRANDMEMBER"
    args := CommandRequest.utf8Args #[key, toString count]
  }

/--
SMOVE source destination member
-/
def CommandRequest.sMove (source destination member : String) : CommandRequest :=
  {
    name := "SMOVE"
    args := CommandRequest.utf8Args #[source, destination, member]
  }

/--
SDIFF key [key ...]
-/
def CommandRequest.sDiff (keys : Array String) : CommandRequest :=
  {
    name := "SDIFF"
    args := CommandRequest.utf8Args keys
  }

/--
SDIFFSTORE destination key [key ...]
-/
def CommandRequest.sDiffStore (destination : String) (keys : Array String) : CommandRequest :=
  {
    name := "SDIFFSTORE"
    args := CommandRequest.utf8Args #[destination] ++ CommandRequest.utf8Args keys
  }

/--
SINTER key [key ...]
-/
def CommandRequest.sInter (keys : Array String) : CommandRequest :=
  {
    name := "SINTER"
    args := CommandRequest.utf8Args keys
  }

/--
SINTERCARD numkeys key [key ...]
-/
def CommandRequest.sInterCard (keys : Array String) : CommandRequest :=
  {
    name := "SINTERCARD"
    args := CommandRequest.utf8Args #[toString keys.size] ++ CommandRequest.utf8Args keys
  }

/--
SINTERSTORE destination key [key ...]
-/
def CommandRequest.sInterStore (destination : String) (keys : Array String) : CommandRequest :=
  {
    name := "SINTERSTORE"
    args := CommandRequest.utf8Args #[destination] ++ CommandRequest.utf8Args keys
  }

/--
SUNION key [key ...]
-/
def CommandRequest.sUnion (keys : Array String) : CommandRequest :=
  {
    name := "SUNION"
    args := CommandRequest.utf8Args keys
  }

/--
SUNIONSTORE destination key [key ...]
-/
def CommandRequest.sUnionStore (destination : String) (keys : Array String) : CommandRequest :=
  {
    name := "SUNIONSTORE"
    args := CommandRequest.utf8Args #[destination] ++ CommandRequest.utf8Args keys
  }

/--
SSCAN key cursor [MATCH pattern] [COUNT count]
-/
def CommandRequest.sScan (key : String) (cursor : UInt64) (options : SScanOptions := {}) : CommandRequest :=
  {
    name := "SSCAN"
    args := CommandRequest.utf8Args #[key, toString cursor] ++ CommandRequest.sScanArgs options
  }

end LeanRedis
