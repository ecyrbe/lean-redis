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

structure SScanOptions where
  match? : Option String := none
  count? : Option UInt64 := none
  deriving BEq, Inhabited, Repr

structure SetScanResult where
  cursor : UInt64
  members : Array String
  deriving BEq, Inhabited, Repr

structure SortedSetEntry where
  score : String
  member : String
  deriving BEq, Inhabited, Repr

structure ZScanOptions where
  match? : Option String := none
  count? : Option UInt64 := none
  deriving BEq, Inhabited, Repr

structure SortedSetScanResult where
  cursor : UInt64
  entries : Array SortedSetEntry
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

private def sScanArgs (options : SScanOptions) : Array ByteArray :=
  (match options.match? with
    | some pattern => utf8Args #["MATCH", pattern]
    | none => #[])
  ++ (match options.count? with
    | some count => utf8Args #["COUNT", toString count]
    | none => #[])

private def zScanArgs (options : ZScanOptions) : Array ByteArray :=
  (match options.match? with
    | some pattern => utf8Args #["MATCH", pattern]
    | none => #[])
  ++ (match options.count? with
    | some count => utf8Args #["COUNT", toString count]
    | none => #[])

private def sortedSetEntryArgs (entries : Array SortedSetEntry) : Array ByteArray :=
  entries.foldl (fun acc entry => acc ++ utf8Args #[entry.score, entry.member]) #[]

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

def CommandRequest.sAdd (key : String) (members : Array String) : CommandRequest :=
  {
    name := "SADD"
    args := utf8Args #[key] ++ utf8Args members
    allowRetry := true
  }

def CommandRequest.sRem (key : String) (members : Array String) : CommandRequest :=
  {
    name := "SREM"
    args := utf8Args #[key] ++ utf8Args members
    allowRetry := true
  }

def CommandRequest.sCard (key : String) : CommandRequest :=
  {
    name := "SCARD"
    args := utf8Args #[key]
    allowRetry := true
  }

def CommandRequest.sIsMember (key member : String) : CommandRequest :=
  {
    name := "SISMEMBER"
    args := utf8Args #[key, member]
    allowRetry := true
  }

def CommandRequest.sMIsMember (key : String) (members : Array String) : CommandRequest :=
  {
    name := "SMISMEMBER"
    args := utf8Args #[key] ++ utf8Args members
    allowRetry := true
  }

def CommandRequest.sMembers (key : String) : CommandRequest :=
  {
    name := "SMEMBERS"
    args := utf8Args #[key]
    allowRetry := true
  }

def CommandRequest.sPop (key : String) : CommandRequest :=
  {
    name := "SPOP"
    args := utf8Args #[key]
    allowRetry := true
  }

def CommandRequest.sPopCount (key : String) (count : UInt64) : CommandRequest :=
  {
    name := "SPOP"
    args := utf8Args #[key, toString count]
    allowRetry := true
  }

def CommandRequest.sRandMember (key : String) : CommandRequest :=
  {
    name := "SRANDMEMBER"
    args := utf8Args #[key]
    allowRetry := true
  }

def CommandRequest.sRandMembers (key : String) (count : Int) : CommandRequest :=
  {
    name := "SRANDMEMBER"
    args := utf8Args #[key, toString count]
    allowRetry := true
  }

def CommandRequest.sMove (source destination member : String) : CommandRequest :=
  {
    name := "SMOVE"
    args := utf8Args #[source, destination, member]
    allowRetry := true
  }

def CommandRequest.sDiff (keys : Array String) : CommandRequest :=
  {
    name := "SDIFF"
    args := utf8Args keys
    allowRetry := true
  }

def CommandRequest.sDiffStore (destination : String) (keys : Array String) : CommandRequest :=
  {
    name := "SDIFFSTORE"
    args := utf8Args #[destination] ++ utf8Args keys
    allowRetry := true
  }

def CommandRequest.sInter (keys : Array String) : CommandRequest :=
  {
    name := "SINTER"
    args := utf8Args keys
    allowRetry := true
  }

def CommandRequest.sInterCard (keys : Array String) : CommandRequest :=
  {
    name := "SINTERCARD"
    args := utf8Args #[toString keys.size] ++ utf8Args keys
    allowRetry := true
  }

def CommandRequest.sInterStore (destination : String) (keys : Array String) : CommandRequest :=
  {
    name := "SINTERSTORE"
    args := utf8Args #[destination] ++ utf8Args keys
    allowRetry := true
  }

def CommandRequest.sUnion (keys : Array String) : CommandRequest :=
  {
    name := "SUNION"
    args := utf8Args keys
    allowRetry := true
  }

def CommandRequest.sUnionStore (destination : String) (keys : Array String) : CommandRequest :=
  {
    name := "SUNIONSTORE"
    args := utf8Args #[destination] ++ utf8Args keys
    allowRetry := true
  }

def CommandRequest.sScan (key : String) (cursor : UInt64) (options : SScanOptions := {}) : CommandRequest :=
  {
    name := "SSCAN"
    args := utf8Args #[key, toString cursor] ++ sScanArgs options
    allowRetry := true
  }

def CommandRequest.zAdd (key : String) (entries : Array SortedSetEntry) : CommandRequest :=
  {
    name := "ZADD"
    args := utf8Args #[key] ++ sortedSetEntryArgs entries
    allowRetry := true
  }

def CommandRequest.zRem (key : String) (members : Array String) : CommandRequest :=
  {
    name := "ZREM"
    args := utf8Args #[key] ++ utf8Args members
    allowRetry := true
  }

def CommandRequest.zCard (key : String) : CommandRequest :=
  {
    name := "ZCARD"
    args := utf8Args #[key]
    allowRetry := true
  }

def CommandRequest.zScore (key member : String) : CommandRequest :=
  {
    name := "ZSCORE"
    args := utf8Args #[key, member]
    allowRetry := true
  }

def CommandRequest.zMScore (key : String) (members : Array String) : CommandRequest :=
  {
    name := "ZMSCORE"
    args := utf8Args #[key] ++ utf8Args members
    allowRetry := true
  }

def CommandRequest.zRank (key member : String) : CommandRequest :=
  {
    name := "ZRANK"
    args := utf8Args #[key, member]
    allowRetry := true
  }

def CommandRequest.zRevRank (key member : String) : CommandRequest :=
  {
    name := "ZREVRANK"
    args := utf8Args #[key, member]
    allowRetry := true
  }

def CommandRequest.zRange (key : String) (start stop : Int) : CommandRequest :=
  {
    name := "ZRANGE"
    args := utf8Args #[key, toString start, toString stop]
    allowRetry := true
  }

def CommandRequest.zRangeWithScores (key : String) (start stop : Int) : CommandRequest :=
  {
    name := "ZRANGE"
    args := utf8Args #[key, toString start, toString stop, "WITHSCORES"]
    allowRetry := true
  }

def CommandRequest.zRevRange (key : String) (start stop : Int) : CommandRequest :=
  {
    name := "ZREVRANGE"
    args := utf8Args #[key, toString start, toString stop]
    allowRetry := true
  }

def CommandRequest.zRevRangeWithScores (key : String) (start stop : Int) : CommandRequest :=
  {
    name := "ZREVRANGE"
    args := utf8Args #[key, toString start, toString stop, "WITHSCORES"]
    allowRetry := true
  }

def CommandRequest.zRangeByScore (key min max : String) : CommandRequest :=
  {
    name := "ZRANGEBYSCORE"
    args := utf8Args #[key, min, max]
    allowRetry := true
  }

def CommandRequest.zRangeByScoreWithScores (key min max : String) : CommandRequest :=
  {
    name := "ZRANGEBYSCORE"
    args := utf8Args #[key, min, max, "WITHSCORES"]
    allowRetry := true
  }

def CommandRequest.zRevRangeByScore (key max min : String) : CommandRequest :=
  {
    name := "ZREVRANGEBYSCORE"
    args := utf8Args #[key, max, min]
    allowRetry := true
  }

def CommandRequest.zRevRangeByScoreWithScores (key max min : String) : CommandRequest :=
  {
    name := "ZREVRANGEBYSCORE"
    args := utf8Args #[key, max, min, "WITHSCORES"]
    allowRetry := true
  }

def CommandRequest.zRangeByLex (key min max : String) : CommandRequest :=
  {
    name := "ZRANGEBYLEX"
    args := utf8Args #[key, min, max]
    allowRetry := true
  }

def CommandRequest.zRevRangeByLex (key max min : String) : CommandRequest :=
  {
    name := "ZREVRANGEBYLEX"
    args := utf8Args #[key, max, min]
    allowRetry := true
  }

def CommandRequest.zCount (key min max : String) : CommandRequest :=
  {
    name := "ZCOUNT"
    args := utf8Args #[key, min, max]
    allowRetry := true
  }

def CommandRequest.zLexCount (key min max : String) : CommandRequest :=
  {
    name := "ZLEXCOUNT"
    args := utf8Args #[key, min, max]
    allowRetry := true
  }

def CommandRequest.zRemRangeByRank (key : String) (start stop : Int) : CommandRequest :=
  {
    name := "ZREMRANGEBYRANK"
    args := utf8Args #[key, toString start, toString stop]
    allowRetry := true
  }

def CommandRequest.zRemRangeByScore (key min max : String) : CommandRequest :=
  {
    name := "ZREMRANGEBYSCORE"
    args := utf8Args #[key, min, max]
    allowRetry := true
  }

def CommandRequest.zRemRangeByLex (key min max : String) : CommandRequest :=
  {
    name := "ZREMRANGEBYLEX"
    args := utf8Args #[key, min, max]
    allowRetry := true
  }

def CommandRequest.zIncrBy (key increment member : String) : CommandRequest :=
  {
    name := "ZINCRBY"
    args := utf8Args #[key, increment, member]
    allowRetry := true
  }

def CommandRequest.zRandMember (key : String) : CommandRequest :=
  {
    name := "ZRANDMEMBER"
    args := utf8Args #[key]
    allowRetry := true
  }

def CommandRequest.zRandMembers (key : String) (count : Int) : CommandRequest :=
  {
    name := "ZRANDMEMBER"
    args := utf8Args #[key, toString count]
    allowRetry := true
  }

def CommandRequest.zRandMembersWithScores (key : String) (count : Int) : CommandRequest :=
  {
    name := "ZRANDMEMBER"
    args := utf8Args #[key, toString count, "WITHSCORES"]
    allowRetry := true
  }

def CommandRequest.zDiff (keys : Array String) : CommandRequest :=
  {
    name := "ZDIFF"
    args := utf8Args #[toString keys.size] ++ utf8Args keys
    allowRetry := true
  }

def CommandRequest.zDiffStore (destination : String) (keys : Array String) : CommandRequest :=
  {
    name := "ZDIFFSTORE"
    args := utf8Args #[destination, toString keys.size] ++ utf8Args keys
    allowRetry := true
  }

def CommandRequest.zInter (keys : Array String) : CommandRequest :=
  {
    name := "ZINTER"
    args := utf8Args #[toString keys.size] ++ utf8Args keys
    allowRetry := true
  }

def CommandRequest.zInterCard (keys : Array String) : CommandRequest :=
  {
    name := "ZINTERCARD"
    args := utf8Args #[toString keys.size] ++ utf8Args keys
    allowRetry := true
  }

def CommandRequest.zInterStore (destination : String) (keys : Array String) : CommandRequest :=
  {
    name := "ZINTERSTORE"
    args := utf8Args #[destination, toString keys.size] ++ utf8Args keys
    allowRetry := true
  }

def CommandRequest.zUnion (keys : Array String) : CommandRequest :=
  {
    name := "ZUNION"
    args := utf8Args #[toString keys.size] ++ utf8Args keys
    allowRetry := true
  }

def CommandRequest.zUnionStore (destination : String) (keys : Array String) : CommandRequest :=
  {
    name := "ZUNIONSTORE"
    args := utf8Args #[destination, toString keys.size] ++ utf8Args keys
    allowRetry := true
  }

def CommandRequest.zScan (key : String) (cursor : UInt64) (options : ZScanOptions := {}) : CommandRequest :=
  {
    name := "ZSCAN"
    args := utf8Args #[key, toString cursor] ++ zScanArgs options
    allowRetry := true
  }

def CommandRequest.selectedDb? (request : CommandRequest) : Option UInt32 := do
  guard (request.name == "SELECT")
  let bytes <- request.args[0]?
  let text <- String.fromUTF8? bytes
  let value <- text.toNat?
  pure value.toUInt32

end LeanRedis
