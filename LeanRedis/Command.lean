import LeanRedis.Config

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

structure CommandRequest where
  name : String
  args : Array ByteArray := #[]
  allowRetry : Bool := true
  deriving BEq, Inhabited

private def utf8Args (args : Array String) : Array ByteArray :=
  args.map String.toUTF8

private def expirationArgs (expiration : Expiration) : Array ByteArray :=
  utf8Args <| match expiration with
    | .ex seconds => #[("EX"), toString seconds]
    | .px milliseconds => #[("PX"), toString milliseconds]
    | .exAt unixSeconds => #[("EXAT"), toString unixSeconds]
    | .pxAt unixMilliseconds => #[("PXAT"), toString unixMilliseconds]

private def setExpiryArgs (expiry : SetExpiry) : Array ByteArray :=
  match expiry with
  | .relative expiration => expirationArgs expiration
  | .keepTtl => utf8Args #["KEEPTTL"]

private def conditionArgs (condition : SetCondition) : Array ByteArray :=
  utf8Args <| match condition with
    | .nx => #["NX"]
    | .xx => #["XX"]

private def getExModeArgs (mode : GetExMode) : Array ByteArray :=
  match mode with
  | .relative expiration => expirationArgs expiration
  | .persist => utf8Args #["PERSIST"]

def CommandRequest.ping (message? : Option String := none) : CommandRequest :=
  {
    name := "PING"
    args := match message? with
      | some message => #[message.toUTF8]
      | none => #[]
    allowRetry := true
  }

def CommandRequest.auth (auth : AuthConfig) : CommandRequest :=
  match auth.username? with
  | some username =>
      {
        name := "AUTH"
        args := #[username.toUTF8, auth.password.value.toUTF8]
        allowRetry := true
      }
  | none =>
      {
        name := "AUTH"
        args := #[auth.password.value.toUTF8]
        allowRetry := true
      }

def CommandRequest.select (database : UInt32) : CommandRequest :=
  {
    name := "SELECT"
    args := #[(toString database).toUTF8]
    allowRetry := true
  }

def CommandRequest.get (key : String) : CommandRequest :=
  {
    name := "GET"
    args := utf8Args #[key]
    allowRetry := true
  }

def CommandRequest.set (key value : String) (options : SetOptions := {}) : CommandRequest :=
  {
    name := "SET"
    args :=
      utf8Args #[key, value]
        ++ (match options.expiry? with
          | some expiry => setExpiryArgs expiry
          | none => #[])
        ++ (match options.condition? with
          | some condition => conditionArgs condition
          | none => #[])
    allowRetry := true
  }

def CommandRequest.mGet (keys : Array String) : CommandRequest :=
  {
    name := "MGET"
    args := utf8Args keys
    allowRetry := true
  }

def CommandRequest.mSet (entries : Array (String × String)) : CommandRequest :=
  {
    name := "MSET"
    args := entries.foldl (fun acc (key, value) => acc ++ utf8Args #[key, value]) #[]
    allowRetry := true
  }

def CommandRequest.mSetNx (entries : Array (String × String)) : CommandRequest :=
  {
    name := "MSETNX"
    args := entries.foldl (fun acc (key, value) => acc ++ utf8Args #[key, value]) #[]
    allowRetry := true
  }

def CommandRequest.getDel (key : String) : CommandRequest :=
  {
    name := "GETDEL"
    args := utf8Args #[key]
    allowRetry := true
  }

def CommandRequest.getEx (key : String) (mode? : Option GetExMode := none) : CommandRequest :=
  {
    name := "GETEX"
    args := utf8Args #[key]
      ++ (match mode? with
        | some mode => getExModeArgs mode
        | none => #[])
    allowRetry := true
  }

def CommandRequest.getRange (key : String) (start stop : Int) : CommandRequest :=
  {
    name := "GETRANGE"
    args := utf8Args #[key, toString start, toString stop]
    allowRetry := true
  }

def CommandRequest.getSet (key value : String) : CommandRequest :=
  {
    name := "GETSET"
    args := utf8Args #[key, value]
    allowRetry := true
  }

def CommandRequest.setRange (key : String) (offset : UInt64) (value : String) : CommandRequest :=
  {
    name := "SETRANGE"
    args := utf8Args #[key, toString offset, value]
    allowRetry := true
  }

def CommandRequest.strLen (key : String) : CommandRequest :=
  {
    name := "STRLEN"
    args := utf8Args #[key]
    allowRetry := true
  }

def CommandRequest.append (key value : String) : CommandRequest :=
  {
    name := "APPEND"
    args := utf8Args #[key, value]
    allowRetry := true
  }

def CommandRequest.incr (key : String) : CommandRequest :=
  {
    name := "INCR"
    args := utf8Args #[key]
    allowRetry := true
  }

def CommandRequest.incrBy (key : String) (amount : Int) : CommandRequest :=
  {
    name := "INCRBY"
    args := utf8Args #[key, toString amount]
    allowRetry := true
  }

def CommandRequest.incrByFloat (key amount : String) : CommandRequest :=
  {
    name := "INCRBYFLOAT"
    args := utf8Args #[key, amount]
    allowRetry := true
  }

def CommandRequest.decr (key : String) : CommandRequest :=
  {
    name := "DECR"
    args := utf8Args #[key]
    allowRetry := true
  }

def CommandRequest.decrBy (key : String) (amount : Int) : CommandRequest :=
  {
    name := "DECRBY"
    args := utf8Args #[key, toString amount]
    allowRetry := true
  }

def CommandRequest.setNx (key value : String) : CommandRequest :=
  {
    name := "SETNX"
    args := utf8Args #[key, value]
    allowRetry := true
  }

def CommandRequest.setEx (key : String) (seconds : UInt64) (value : String) : CommandRequest :=
  {
    name := "SETEX"
    args := utf8Args #[key, toString seconds, value]
    allowRetry := true
  }

def CommandRequest.pSetEx (key : String) (milliseconds : UInt64) (value : String) : CommandRequest :=
  {
    name := "PSETEX"
    args := utf8Args #[key, toString milliseconds, value]
    allowRetry := true
  }

def CommandRequest.selectedDb? (request : CommandRequest) : Option UInt32 := do
  guard (request.name == "SELECT")
  let bytes <- request.args[0]?
  let text <- String.fromUTF8? bytes
  let value <- text.toNat?
  pure value.toUInt32

end LeanRedis
