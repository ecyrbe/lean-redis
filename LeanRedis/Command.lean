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

structure HScanOptions where
  match? : Option String := none
  count? : Option UInt64 := none
  deriving BEq, Inhabited, Repr

structure HashScanResult where
  cursor : UInt64
  entries : Array (String × String)
  deriving BEq, Inhabited, Repr

inductive LInsertPosition where
  | before
  | after
  deriving BEq, Inhabited, Repr

inductive LMoveWhere where
  | left
  | right
  deriving BEq, Inhabited, Repr

structure LPosOptions where
  rank? : Option Int := none
  count? : Option UInt64 := none
  maxLen? : Option UInt64 := none
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

private def hScanArgs (options : HScanOptions) : Array ByteArray :=
  (match options.match? with
    | some pattern => utf8Args #["MATCH", pattern]
    | none => #[])
  ++ (match options.count? with
    | some count => utf8Args #["COUNT", toString count]
    | none => #[])

private def lInsertPositionArg (position : LInsertPosition) : String :=
  match position with
  | .before => "BEFORE"
  | .after => "AFTER"

private def lMoveWhereArg (where_ : LMoveWhere) : String :=
  match where_ with
  | .left => "LEFT"
  | .right => "RIGHT"

private def lPosArgs (options : LPosOptions) : Array ByteArray :=
  (match options.rank? with
    | some rank => utf8Args #["RANK", toString rank]
    | none => #[])
  ++ (match options.count? with
    | some count => utf8Args #["COUNT", toString count]
    | none => #[])
  ++ (match options.maxLen? with
    | some maxLen => utf8Args #["MAXLEN", toString maxLen]
    | none => #[])

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

def CommandRequest.hGet (key field : String) : CommandRequest :=
  {
    name := "HGET"
    args := utf8Args #[key, field]
    allowRetry := true
  }

def CommandRequest.hSet (key : String) (entries : Array (String × String)) : CommandRequest :=
  {
    name := "HSET"
    args := utf8Args #[key] ++ entries.foldl (fun acc (field, value) => acc ++ utf8Args #[field, value]) #[]
    allowRetry := true
  }

def CommandRequest.hMGet (key : String) (fields : Array String) : CommandRequest :=
  {
    name := "HMGET"
    args := utf8Args #[key] ++ utf8Args fields
    allowRetry := true
  }

def CommandRequest.hMSet (key : String) (entries : Array (String × String)) : CommandRequest :=
  {
    name := "HMSET"
    args := utf8Args #[key] ++ entries.foldl (fun acc (field, value) => acc ++ utf8Args #[field, value]) #[]
    allowRetry := true
  }

def CommandRequest.hGetAll (key : String) : CommandRequest :=
  {
    name := "HGETALL"
    args := utf8Args #[key]
    allowRetry := true
  }

def CommandRequest.hDel (key : String) (fields : Array String) : CommandRequest :=
  {
    name := "HDEL"
    args := utf8Args #[key] ++ utf8Args fields
    allowRetry := true
  }

def CommandRequest.hExists (key field : String) : CommandRequest :=
  {
    name := "HEXISTS"
    args := utf8Args #[key, field]
    allowRetry := true
  }

def CommandRequest.hLen (key : String) : CommandRequest :=
  {
    name := "HLEN"
    args := utf8Args #[key]
    allowRetry := true
  }

def CommandRequest.hKeys (key : String) : CommandRequest :=
  {
    name := "HKEYS"
    args := utf8Args #[key]
    allowRetry := true
  }

def CommandRequest.hVals (key : String) : CommandRequest :=
  {
    name := "HVALS"
    args := utf8Args #[key]
    allowRetry := true
  }

def CommandRequest.hStrLen (key field : String) : CommandRequest :=
  {
    name := "HSTRLEN"
    args := utf8Args #[key, field]
    allowRetry := true
  }

def CommandRequest.hIncrBy (key field : String) (amount : Int) : CommandRequest :=
  {
    name := "HINCRBY"
    args := utf8Args #[key, field, toString amount]
    allowRetry := true
  }

def CommandRequest.hIncrByFloat (key field amount : String) : CommandRequest :=
  {
    name := "HINCRBYFLOAT"
    args := utf8Args #[key, field, amount]
    allowRetry := true
  }

def CommandRequest.hSetNx (key field value : String) : CommandRequest :=
  {
    name := "HSETNX"
    args := utf8Args #[key, field, value]
    allowRetry := true
  }

def CommandRequest.hRandField (key : String) : CommandRequest :=
  {
    name := "HRANDFIELD"
    args := utf8Args #[key]
    allowRetry := true
  }

def CommandRequest.hRandFields (key : String) (count : Int) : CommandRequest :=
  {
    name := "HRANDFIELD"
    args := utf8Args #[key, toString count]
    allowRetry := true
  }

def CommandRequest.hRandFieldsWithValues (key : String) (count : Int) : CommandRequest :=
  {
    name := "HRANDFIELD"
    args := utf8Args #[key, toString count, "WITHVALUES"]
    allowRetry := true
  }

def CommandRequest.hScan (key : String) (cursor : UInt64) (options : HScanOptions := {}) : CommandRequest :=
  {
    name := "HSCAN"
    args := utf8Args #[key, toString cursor] ++ hScanArgs options
    allowRetry := true
  }

def CommandRequest.lPush (key : String) (values : Array String) : CommandRequest :=
  {
    name := "LPUSH"
    args := utf8Args #[key] ++ utf8Args values
    allowRetry := true
  }

def CommandRequest.rPush (key : String) (values : Array String) : CommandRequest :=
  {
    name := "RPUSH"
    args := utf8Args #[key] ++ utf8Args values
    allowRetry := true
  }

def CommandRequest.lPushX (key : String) (value : String) : CommandRequest :=
  {
    name := "LPUSHX"
    args := utf8Args #[key, value]
    allowRetry := true
  }

def CommandRequest.rPushX (key : String) (value : String) : CommandRequest :=
  {
    name := "RPUSHX"
    args := utf8Args #[key, value]
    allowRetry := true
  }

def CommandRequest.lPop (key : String) : CommandRequest :=
  {
    name := "LPOP"
    args := utf8Args #[key]
    allowRetry := true
  }

def CommandRequest.rPop (key : String) : CommandRequest :=
  {
    name := "RPOP"
    args := utf8Args #[key]
    allowRetry := true
  }

def CommandRequest.lLen (key : String) : CommandRequest :=
  {
    name := "LLEN"
    args := utf8Args #[key]
    allowRetry := true
  }

def CommandRequest.lIndex (key : String) (index : Int) : CommandRequest :=
  {
    name := "LINDEX"
    args := utf8Args #[key, toString index]
    allowRetry := true
  }

def CommandRequest.lRange (key : String) (start stop : Int) : CommandRequest :=
  {
    name := "LRANGE"
    args := utf8Args #[key, toString start, toString stop]
    allowRetry := true
  }

def CommandRequest.lSet (key : String) (index : Int) (value : String) : CommandRequest :=
  {
    name := "LSET"
    args := utf8Args #[key, toString index, value]
    allowRetry := true
  }

def CommandRequest.lTrim (key : String) (start stop : Int) : CommandRequest :=
  {
    name := "LTRIM"
    args := utf8Args #[key, toString start, toString stop]
    allowRetry := true
  }

def CommandRequest.lRem (key : String) (count : Int) (value : String) : CommandRequest :=
  {
    name := "LREM"
    args := utf8Args #[key, toString count, value]
    allowRetry := true
  }

def CommandRequest.lInsert (key : String) (position : LInsertPosition) (pivot value : String) : CommandRequest :=
  {
    name := "LINSERT"
    args := utf8Args #[key, lInsertPositionArg position, pivot, value]
    allowRetry := true
  }

def CommandRequest.lMove
    (source destination : String)
    (fromWhere toWhere : LMoveWhere)
    : CommandRequest :=
  {
    name := "LMOVE"
    args := utf8Args #[source, destination, lMoveWhereArg fromWhere, lMoveWhereArg toWhere]
    allowRetry := true
  }

def CommandRequest.lPos (key element : String) (options : LPosOptions := {}) : CommandRequest :=
  {
    name := "LPOS"
    args := utf8Args #[key, element] ++ lPosArgs options
    allowRetry := true
  }

def CommandRequest.selectedDb? (request : CommandRequest) : Option UInt32 := do
  guard (request.name == "SELECT")
  let bytes <- request.args[0]?
  let text <- String.fromUTF8? bytes
  let value <- text.toNat?
  pure value.toUInt32

end LeanRedis
