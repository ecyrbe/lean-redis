import LeanRedis.Command.Base
import LeanRedis.Tools.ExpectResult

namespace LeanRedis

inductive Expiration where
  | ex (seconds : UInt64)
  | px (milliseconds : UInt64)
  | exAt (unixSeconds : UInt64)
  | pxAt (unixMilliseconds : UInt64)
  deriving BEq, Inhabited, Repr

inductive SetCondition where
  | nx
  | xx
  deriving BEq, Inhabited, Repr

inductive SetExpiry where
  | relative (expiration : Expiration)
  | keepTtl
  deriving BEq, Inhabited, Repr

structure SetOptions where
  expiry? : Option SetExpiry := none
  condition? : Option SetCondition := none
  deriving BEq, Inhabited, Repr

inductive GetExMode where
  | relative (expiration : Expiration)
  | persist
  deriving BEq, Inhabited, Repr

namespace CommandRequest

def expirationArgs (expiration : Expiration) : Array ByteArray :=
  utf8Args <| match expiration with
    | .ex seconds => #["EX", toString seconds]
    | .px milliseconds => #["PX", toString milliseconds]
    | .exAt unixSeconds => #["EXAT", toString unixSeconds]
    | .pxAt unixMilliseconds => #["PXAT", toString unixMilliseconds]

def setExpiryArgs (expiry : SetExpiry) : Array ByteArray :=
  match expiry with
  | .relative expiration => expirationArgs expiration
  | .keepTtl => utf8Args #["KEEPTTL"]

def conditionArgs (condition : SetCondition) : Array ByteArray :=
  utf8Args <| match condition with
    | .nx => #["NX"]
    | .xx => #["XX"]

def getExModeArgs (mode : GetExMode) : Array ByteArray :=
  match mode with
  | .relative expiration => expirationArgs expiration
  | .persist => utf8Args #["PERSIST"]

end CommandRequest

/--
GET key
-/
def CommandRequest.get (key : String) : CommandRequest :=
  {
    name := "GET"
    args := CommandRequest.utf8Args #[key]
  }

/--
SET key value [NX | XX] [EX seconds | PX milliseconds | EXAT unix-time-seconds | PXAT unix-time-milliseconds | KEEPTTL]
-/
def CommandRequest.set (key value : String) (options : SetOptions := {}) : CommandRequest :=
  {
    name := "SET"
    args :=
      CommandRequest.utf8Args #[key, value]
        ++ (match options.expiry? with
          | some expiry => CommandRequest.setExpiryArgs expiry
          | none => #[])
        ++ (match options.condition? with
          | some condition => CommandRequest.conditionArgs condition
          | none => #[])
  }

/--
MGET key [key ...]
-/
def CommandRequest.mGet (keys : Array String) : CommandRequest :=
  {
    name := "MGET"
    args := CommandRequest.utf8Args keys
  }

/--
MSET key value [key value ...]
-/
def CommandRequest.mSet (entries : Array (String × String)) : CommandRequest :=
  {
    name := "MSET"
    args := entries.foldl (fun acc (key, value) => acc ++ CommandRequest.utf8Args #[key, value]) #[]
  }

/--
MSETNX key value [key value ...]
-/
def CommandRequest.mSetNx (entries : Array (String × String)) : CommandRequest :=
  {
    name := "MSETNX"
    args := entries.foldl (fun acc (key, value) => acc ++ CommandRequest.utf8Args #[key, value]) #[]
  }

/--
GETDEL key
-/
def CommandRequest.getDel (key : String) : CommandRequest :=
  {
    name := "GETDEL"
    args := CommandRequest.utf8Args #[key]
  }

/--
GETEX key [EX seconds | PX milliseconds | EXAT unix-time-seconds | PXAT unix-time-milliseconds | PERSIST]
-/
def CommandRequest.getEx (key : String) (mode? : Option GetExMode := none) : CommandRequest :=
  {
    name := "GETEX"
    args := CommandRequest.utf8Args #[key]
      ++ (match mode? with
        | some mode => CommandRequest.getExModeArgs mode
        | none => #[])
  }

/--
GETRANGE key start end
-/
def CommandRequest.getRange (key : String) (start stop : Int) : CommandRequest :=
  {
    name := "GETRANGE"
    args := CommandRequest.utf8Args #[key, toString start, toString stop]
  }

/--
GETSET key value
-/
def CommandRequest.getSet (key value : String) : CommandRequest :=
  {
    name := "GETSET"
    args := CommandRequest.utf8Args #[key, value]
  }

/--
SETRANGE key offset value
-/
def CommandRequest.setRange (key : String) (offset : UInt64) (value : String) : CommandRequest :=
  {
    name := "SETRANGE"
    args := CommandRequest.utf8Args #[key, toString offset, value]
  }

/--
STRLEN key
-/
def CommandRequest.strLen (key : String) : CommandRequest :=
  {
    name := "STRLEN"
    args := CommandRequest.utf8Args #[key]
  }

/--
APPEND key value
-/
def CommandRequest.append (key value : String) : CommandRequest :=
  {
    name := "APPEND"
    args := CommandRequest.utf8Args #[key, value]
  }

/--
INCR key
-/
def CommandRequest.incr (key : String) : CommandRequest :=
  {
    name := "INCR"
    args := CommandRequest.utf8Args #[key]
  }

/--
INCRBY key increment
-/
def CommandRequest.incrBy (key : String) (amount : Int) : CommandRequest :=
  {
    name := "INCRBY"
    args := CommandRequest.utf8Args #[key, toString amount]
  }

/--
INCRBYFLOAT key increment
-/
def CommandRequest.incrByFloat (key amount : String) : CommandRequest :=
  {
    name := "INCRBYFLOAT"
    args := CommandRequest.utf8Args #[key, amount]
  }

/--
DECR key
-/
def CommandRequest.decr (key : String) : CommandRequest :=
  {
    name := "DECR"
    args := CommandRequest.utf8Args #[key]
  }

/--
DECRBY key decrement
-/
def CommandRequest.decrBy (key : String) (amount : Int) : CommandRequest :=
  {
    name := "DECRBY"
    args := CommandRequest.utf8Args #[key, toString amount]
  }

/--
SETNX key value
-/
def CommandRequest.setNx (key value : String) : CommandRequest :=
  {
    name := "SETNX"
    args := CommandRequest.utf8Args #[key, value]
  }

/--
SETEX key seconds value
-/
def CommandRequest.setEx (key : String) (seconds : UInt64) (value : String) : CommandRequest :=
  {
    name := "SETEX"
    args := CommandRequest.utf8Args #[key, toString seconds, value]
  }

/--
PSETEX key milliseconds value
-/
def CommandRequest.pSetEx (key : String) (milliseconds : UInt64) (value : String) : CommandRequest :=
  {
    name := "PSETEX"
    args := CommandRequest.utf8Args #[key, toString milliseconds, value]
  }

def Command.get (key : String) : Command (Option String) :=
  ⟨ CommandRequest.get key, expectOptionalString "GET" ⟩

def Command.set (key value : String) (options : SetOptions := {}) : Command Bool :=
  ⟨ CommandRequest.set key value options, expectStored ⟩

def Command.mGet (keys : Array String) : Command (Array (Option String)) :=
  ⟨ CommandRequest.mGet keys, expectStringArray "MGET" ⟩

def Command.mSet (entries : Array (String × String)) : Command Unit :=
  ⟨ CommandRequest.mSet entries, expectOk ⟩

def Command.mSetNx (entries : Array (String × String)) : Command Bool :=
  ⟨ CommandRequest.mSetNx entries, expectBoolean "MSETNX" ⟩

def Command.getDel (key : String) : Command (Option String) :=
  ⟨ CommandRequest.getDel key, expectOptionalString "GETDEL" ⟩

def Command.getEx (key : String) (mode? : Option GetExMode := none) : Command (Option String) :=
  ⟨ CommandRequest.getEx key mode?, expectOptionalString "GETEX" ⟩

def Command.getRange (key : String) (start stop : Int) : Command String :=
  ⟨ CommandRequest.getRange key start stop, expectString "GETRANGE" ⟩

def Command.getSet (key value : String) : Command (Option String) :=
  ⟨ CommandRequest.getSet key value, expectOptionalString "GETSET" ⟩

def Command.setRange (key : String) (offset : UInt64) (value : String) : Command Int :=
  ⟨ CommandRequest.setRange key offset value, expectInteger "SETRANGE" ⟩

def Command.strLen (key : String) : Command Int :=
  ⟨ CommandRequest.strLen key, expectInteger "STRLEN" ⟩

def Command.append (key value : String) : Command Int :=
  ⟨ CommandRequest.append key value, expectInteger "APPEND" ⟩

def Command.incr (key : String) : Command Int :=
  ⟨ CommandRequest.incr key, expectInteger "INCR" ⟩

def Command.incrBy (key : String) (amount : Int) : Command Int :=
  ⟨ CommandRequest.incrBy key amount, expectInteger "INCRBY" ⟩

def Command.incrByFloat (key amount : String) : Command String :=
  ⟨ CommandRequest.incrByFloat key amount, expectString "INCRBYFLOAT" ⟩

def Command.decr (key : String) : Command Int :=
  ⟨ CommandRequest.decr key, expectInteger "DECR" ⟩

def Command.decrBy (key : String) (amount : Int) : Command Int :=
  ⟨ CommandRequest.decrBy key amount, expectInteger "DECRBY" ⟩

def Command.setNx (key value : String) : Command Bool :=
  ⟨ CommandRequest.setNx key value, expectBoolean "SETNX" ⟩

def Command.setEx (key : String) (seconds : UInt64) (value : String) : Command Unit :=
  ⟨ CommandRequest.setEx key seconds value, expectOk ⟩

def Command.pSetEx (key : String) (milliseconds : UInt64) (value : String) : Command Unit :=
  ⟨ CommandRequest.pSetEx key milliseconds value, expectOk ⟩

end LeanRedis
