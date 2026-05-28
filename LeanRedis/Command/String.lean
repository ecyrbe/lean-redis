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
    allowRetry := true
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
    allowRetry := true
  }

def CommandRequest.mGet (keys : Array String) : CommandRequest :=
  {
    name := "MGET"
    args := CommandRequest.utf8Args keys
    allowRetry := true
  }

def CommandRequest.mSet (entries : Array (String × String)) : CommandRequest :=
  {
    name := "MSET"
    args := entries.foldl (fun acc (key, value) => acc ++ CommandRequest.utf8Args #[key, value]) #[]
    allowRetry := true
  }

def CommandRequest.mSetNx (entries : Array (String × String)) : CommandRequest :=
  {
    name := "MSETNX"
    args := entries.foldl (fun acc (key, value) => acc ++ CommandRequest.utf8Args #[key, value]) #[]
    allowRetry := true
  }

def CommandRequest.getDel (key : String) : CommandRequest :=
  {
    name := "GETDEL"
    args := CommandRequest.utf8Args #[key]
    allowRetry := true
  }

def CommandRequest.getEx (key : String) (mode? : Option GetExMode := none) : CommandRequest :=
  {
    name := "GETEX"
    args := CommandRequest.utf8Args #[key]
      ++ (match mode? with
        | some mode => CommandRequest.getExModeArgs mode
        | none => #[])
    allowRetry := true
  }

def CommandRequest.getRange (key : String) (start stop : Int) : CommandRequest :=
  {
    name := "GETRANGE"
    args := CommandRequest.utf8Args #[key, toString start, toString stop]
    allowRetry := true
  }

def CommandRequest.getSet (key value : String) : CommandRequest :=
  {
    name := "GETSET"
    args := CommandRequest.utf8Args #[key, value]
    allowRetry := true
  }

def CommandRequest.setRange (key : String) (offset : UInt64) (value : String) : CommandRequest :=
  {
    name := "SETRANGE"
    args := CommandRequest.utf8Args #[key, toString offset, value]
    allowRetry := true
  }

def CommandRequest.strLen (key : String) : CommandRequest :=
  {
    name := "STRLEN"
    args := CommandRequest.utf8Args #[key]
    allowRetry := true
  }

def CommandRequest.append (key value : String) : CommandRequest :=
  {
    name := "APPEND"
    args := CommandRequest.utf8Args #[key, value]
    allowRetry := true
  }

def CommandRequest.incr (key : String) : CommandRequest :=
  {
    name := "INCR"
    args := CommandRequest.utf8Args #[key]
    allowRetry := true
  }

def CommandRequest.incrBy (key : String) (amount : Int) : CommandRequest :=
  {
    name := "INCRBY"
    args := CommandRequest.utf8Args #[key, toString amount]
    allowRetry := true
  }

def CommandRequest.incrByFloat (key amount : String) : CommandRequest :=
  {
    name := "INCRBYFLOAT"
    args := CommandRequest.utf8Args #[key, amount]
    allowRetry := true
  }

def CommandRequest.decr (key : String) : CommandRequest :=
  {
    name := "DECR"
    args := CommandRequest.utf8Args #[key]
    allowRetry := true
  }

def CommandRequest.decrBy (key : String) (amount : Int) : CommandRequest :=
  {
    name := "DECRBY"
    args := CommandRequest.utf8Args #[key, toString amount]
    allowRetry := true
  }

def CommandRequest.setNx (key value : String) : CommandRequest :=
  {
    name := "SETNX"
    args := CommandRequest.utf8Args #[key, value]
    allowRetry := true
  }

def CommandRequest.setEx (key : String) (seconds : UInt64) (value : String) : CommandRequest :=
  {
    name := "SETEX"
    args := CommandRequest.utf8Args #[key, toString seconds, value]
    allowRetry := true
  }

def CommandRequest.pSetEx (key : String) (milliseconds : UInt64) (value : String) : CommandRequest :=
  {
    name := "PSETEX"
    args := CommandRequest.utf8Args #[key, toString milliseconds, value]
    allowRetry := true
  }

end LeanRedis
