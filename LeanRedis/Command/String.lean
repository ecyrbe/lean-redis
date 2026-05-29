import LeanRedis.Command.Base

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

def CommandRequest.get (key : String) : CommandRequest :=
  {
    name := "GET"
    args := CommandRequest.utf8Args #[key]
  }

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

def CommandRequest.mGet (keys : Array String) : CommandRequest :=
  {
    name := "MGET"
    args := CommandRequest.utf8Args keys
  }

def CommandRequest.mSet (entries : Array (String × String)) : CommandRequest :=
  {
    name := "MSET"
    args := entries.foldl (fun acc (key, value) => acc ++ CommandRequest.utf8Args #[key, value]) #[]
  }

def CommandRequest.mSetNx (entries : Array (String × String)) : CommandRequest :=
  {
    name := "MSETNX"
    args := entries.foldl (fun acc (key, value) => acc ++ CommandRequest.utf8Args #[key, value]) #[]
  }

def CommandRequest.getDel (key : String) : CommandRequest :=
  {
    name := "GETDEL"
    args := CommandRequest.utf8Args #[key]
  }

def CommandRequest.getEx (key : String) (mode? : Option GetExMode := none) : CommandRequest :=
  {
    name := "GETEX"
    args := CommandRequest.utf8Args #[key]
      ++ (match mode? with
        | some mode => CommandRequest.getExModeArgs mode
        | none => #[])
  }

def CommandRequest.getRange (key : String) (start stop : Int) : CommandRequest :=
  {
    name := "GETRANGE"
    args := CommandRequest.utf8Args #[key, toString start, toString stop]
  }

def CommandRequest.getSet (key value : String) : CommandRequest :=
  {
    name := "GETSET"
    args := CommandRequest.utf8Args #[key, value]
  }

def CommandRequest.setRange (key : String) (offset : UInt64) (value : String) : CommandRequest :=
  {
    name := "SETRANGE"
    args := CommandRequest.utf8Args #[key, toString offset, value]
  }

def CommandRequest.strLen (key : String) : CommandRequest :=
  {
    name := "STRLEN"
    args := CommandRequest.utf8Args #[key]
  }

def CommandRequest.append (key value : String) : CommandRequest :=
  {
    name := "APPEND"
    args := CommandRequest.utf8Args #[key, value]
  }

def CommandRequest.incr (key : String) : CommandRequest :=
  {
    name := "INCR"
    args := CommandRequest.utf8Args #[key]
  }

def CommandRequest.incrBy (key : String) (amount : Int) : CommandRequest :=
  {
    name := "INCRBY"
    args := CommandRequest.utf8Args #[key, toString amount]
  }

def CommandRequest.incrByFloat (key amount : String) : CommandRequest :=
  {
    name := "INCRBYFLOAT"
    args := CommandRequest.utf8Args #[key, amount]
  }

def CommandRequest.decr (key : String) : CommandRequest :=
  {
    name := "DECR"
    args := CommandRequest.utf8Args #[key]
  }

def CommandRequest.decrBy (key : String) (amount : Int) : CommandRequest :=
  {
    name := "DECRBY"
    args := CommandRequest.utf8Args #[key, toString amount]
  }

def CommandRequest.setNx (key value : String) : CommandRequest :=
  {
    name := "SETNX"
    args := CommandRequest.utf8Args #[key, value]
  }

def CommandRequest.setEx (key : String) (seconds : UInt64) (value : String) : CommandRequest :=
  {
    name := "SETEX"
    args := CommandRequest.utf8Args #[key, toString seconds, value]
  }

def CommandRequest.pSetEx (key : String) (milliseconds : UInt64) (value : String) : CommandRequest :=
  {
    name := "PSETEX"
    args := CommandRequest.utf8Args #[key, toString milliseconds, value]
  }

end LeanRedis
