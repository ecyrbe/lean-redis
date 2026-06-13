import LeanRedis.Command.Base
import LeanRedis.Tools.ExpectResult

namespace LeanRedis

structure SScanOptions where
  match? : Option String := none
  count? : Option UInt64 := none
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

def Command.sAdd (key : String) (members : Array String) : Command Int :=
  ⟨ CommandRequest.sAdd key members, expectInteger "SADD" ⟩

def Command.sRem (key : String) (members : Array String) : Command Int :=
  ⟨ CommandRequest.sRem key members, expectInteger "SREM" ⟩

def Command.sCard (key : String) : Command Int :=
  ⟨ CommandRequest.sCard key, expectInteger "SCARD" ⟩

def Command.sIsMember (key member : String) : Command Bool :=
  ⟨ CommandRequest.sIsMember key member, expectBoolean "SISMEMBER" ⟩

def Command.sMIsMember (key : String) (members : Array String) : Command (Array Bool) :=
  {
    request := CommandRequest.sMIsMember key members
    decode := fun
      | .array items => items.mapM (expectBoolean "SMISMEMBER")
      | .simpleError message => .error (.server message)
      | _ => .error (.decode "unexpected SMISMEMBER reply")
  }

def Command.sMembers (key : String) : Command (Array String) :=
  ⟨ CommandRequest.sMembers key, expectPlainStringArray "SMEMBERS" ⟩

def Command.sPop (key : String) : Command (Option String) :=
  ⟨ CommandRequest.sPop key, expectOptionalString "SPOP" ⟩

def Command.sPopMany (key : String) (count : UInt64) : Command (Array String) :=
  ⟨ CommandRequest.sPopCount key count, expectPlainStringArray "SPOP" ⟩

def Command.sRandMember (key : String) : Command (Option String) :=
  ⟨ CommandRequest.sRandMember key, expectOptionalString "SRANDMEMBER" ⟩

def Command.sRandMembers (key : String) (count : Int) : Command (Array String) :=
  {
    request := CommandRequest.sRandMembers key count
    decode := fun reply =>
      match expectOptionalStringOrArray "SRANDMEMBER" reply with
      | .ok (.inl none) => .ok #[]
      | .ok (.inl (some value)) => .ok #[value]
      | .ok (.inr values) => .ok values
      | .error e => .error e
  }

def Command.sMove (source destination member : String) : Command Bool :=
  ⟨ CommandRequest.sMove source destination member, expectBoolean "SMOVE" ⟩

def Command.sDiff (keys : Array String) : Command (Array String) :=
  ⟨ CommandRequest.sDiff keys, expectPlainStringArray "SDIFF" ⟩

def Command.sDiffStore (destination : String) (keys : Array String) : Command Int :=
  ⟨ CommandRequest.sDiffStore destination keys, expectInteger "SDIFFSTORE" ⟩

def Command.sInter (keys : Array String) : Command (Array String) :=
  ⟨ CommandRequest.sInter keys, expectPlainStringArray "SINTER" ⟩

def Command.sInterCard (keys : Array String) : Command Int :=
  ⟨ CommandRequest.sInterCard keys, expectInteger "SINTERCARD" ⟩

def Command.sInterStore (destination : String) (keys : Array String) : Command Int :=
  ⟨ CommandRequest.sInterStore destination keys, expectInteger "SINTERSTORE" ⟩

def Command.sUnion (keys : Array String) : Command (Array String) :=
  ⟨ CommandRequest.sUnion keys, expectPlainStringArray "SUNION" ⟩

def Command.sUnionStore (destination : String) (keys : Array String) : Command Int :=
  ⟨ CommandRequest.sUnionStore destination keys, expectInteger "SUNIONSTORE" ⟩

def Command.sScan (key : String) (cursor : UInt64) (options : SScanOptions := {}) : Command SetScanResult :=
  ⟨ CommandRequest.sScan key cursor options, expectSetScanResult ⟩

end LeanRedis
