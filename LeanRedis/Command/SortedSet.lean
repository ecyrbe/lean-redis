import LeanRedis.Command.Base

namespace LeanRedis

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

namespace CommandRequest

def zScanArgs (options : ZScanOptions) : Array ByteArray :=
  (match options.match? with
    | some pattern => utf8Args #["MATCH", pattern]
    | none => #[])
  ++ (match options.count? with
    | some count => utf8Args #["COUNT", toString count]
    | none => #[])

def sortedSetEntryArgs (entries : Array SortedSetEntry) : Array ByteArray :=
  entries.foldl (fun acc entry => acc ++ utf8Args #[entry.score, entry.member]) #[]

end CommandRequest

/--
ZADD key score member [score member ...]
-/
def CommandRequest.zAdd (key : String) (entries : Array SortedSetEntry) : CommandRequest :=
  {
    name := "ZADD"
    args := CommandRequest.utf8Args #[key] ++ CommandRequest.sortedSetEntryArgs entries
  }

/--
ZREM key member [member ...]
-/
def CommandRequest.zRem (key : String) (members : Array String) : CommandRequest :=
  {
    name := "ZREM"
    args := CommandRequest.utf8Args #[key] ++ CommandRequest.utf8Args members
  }

/--
ZCARD key
-/
def CommandRequest.zCard (key : String) : CommandRequest :=
  {
    name := "ZCARD"
    args := CommandRequest.utf8Args #[key]
  }

/--
ZSCORE key member
-/
def CommandRequest.zScore (key member : String) : CommandRequest :=
  {
    name := "ZSCORE"
    args := CommandRequest.utf8Args #[key, member]
  }

/--
ZMSCORE key member [member ...]
-/
def CommandRequest.zMScore (key : String) (members : Array String) : CommandRequest :=
  {
    name := "ZMSCORE"
    args := CommandRequest.utf8Args #[key] ++ CommandRequest.utf8Args members
  }

/--
ZRANK key member
-/
def CommandRequest.zRank (key member : String) : CommandRequest :=
  {
    name := "ZRANK"
    args := CommandRequest.utf8Args #[key, member]
  }

/--
ZREVRANK key member
-/
def CommandRequest.zRevRank (key member : String) : CommandRequest :=
  {
    name := "ZREVRANK"
    args := CommandRequest.utf8Args #[key, member]
  }

/--
ZRANGE key start stop [BYSCORE | BYLEX] [REV] [LIMIT offset count] [WITHSCORES]
-/
def CommandRequest.zRange (key : String) (start stop : Int) : CommandRequest :=
  {
    name := "ZRANGE"
    args := CommandRequest.utf8Args #[key, toString start, toString stop]
  }

/--
ZRANGE key start stop WITHSCORES
-/
def CommandRequest.zRangeWithScores (key : String) (start stop : Int) : CommandRequest :=
  {
    name := "ZRANGE"
    args := CommandRequest.utf8Args #[key, toString start, toString stop, "WITHSCORES"]
  }

/--
ZREVRANGE key start stop [WITHSCORES]
-/
def CommandRequest.zRevRange (key : String) (start stop : Int) : CommandRequest :=
  {
    name := "ZREVRANGE"
    args := CommandRequest.utf8Args #[key, toString start, toString stop]
  }

/--
ZREVRANGE key start stop WITHSCORES
-/
def CommandRequest.zRevRangeWithScores (key : String) (start stop : Int) : CommandRequest :=
  {
    name := "ZREVRANGE"
    args := CommandRequest.utf8Args #[key, toString start, toString stop, "WITHSCORES"]
  }

/--
ZRANGEBYSCORE key min max [WITHSCORES] [LIMIT offset count]
-/
def CommandRequest.zRangeByScore (key min max : String) : CommandRequest :=
  {
    name := "ZRANGEBYSCORE"
    args := CommandRequest.utf8Args #[key, min, max]
  }

/--
ZRANGEBYSCORE key min max WITHSCORES [LIMIT offset count]
-/
def CommandRequest.zRangeByScoreWithScores (key min max : String) : CommandRequest :=
  {
    name := "ZRANGEBYSCORE"
    args := CommandRequest.utf8Args #[key, min, max, "WITHSCORES"]
  }

/--
ZREVRANGEBYSCORE key max min [WITHSCORES] [LIMIT offset count]
-/
def CommandRequest.zRevRangeByScore (key max min : String) : CommandRequest :=
  {
    name := "ZREVRANGEBYSCORE"
    args := CommandRequest.utf8Args #[key, max, min]
  }

/--
ZREVRANGEBYSCORE key max min WITHSCORES [LIMIT offset count]
-/
def CommandRequest.zRevRangeByScoreWithScores (key max min : String) : CommandRequest :=
  {
    name := "ZREVRANGEBYSCORE"
    args := CommandRequest.utf8Args #[key, max, min, "WITHSCORES"]
  }

/--
ZRANGEBYLEX key min max [LIMIT offset count]
-/
def CommandRequest.zRangeByLex (key min max : String) : CommandRequest :=
  {
    name := "ZRANGEBYLEX"
    args := CommandRequest.utf8Args #[key, min, max]
  }

/--
ZREVRANGEBYLEX key max min [LIMIT offset count]
-/
def CommandRequest.zRevRangeByLex (key max min : String) : CommandRequest :=
  {
    name := "ZREVRANGEBYLEX"
    args := CommandRequest.utf8Args #[key, max, min]
  }

/--
ZCOUNT key min max
-/
def CommandRequest.zCount (key min max : String) : CommandRequest :=
  {
    name := "ZCOUNT"
    args := CommandRequest.utf8Args #[key, min, max]
  }

/--
ZLEXCOUNT key min max
-/
def CommandRequest.zLexCount (key min max : String) : CommandRequest :=
  {
    name := "ZLEXCOUNT"
    args := CommandRequest.utf8Args #[key, min, max]
  }

/--
ZREMRANGEBYRANK key start stop
-/
def CommandRequest.zRemRangeByRank (key : String) (start stop : Int) : CommandRequest :=
  {
    name := "ZREMRANGEBYRANK"
    args := CommandRequest.utf8Args #[key, toString start, toString stop]
  }

/--
ZREMRANGEBYSCORE key min max
-/
def CommandRequest.zRemRangeByScore (key min max : String) : CommandRequest :=
  {
    name := "ZREMRANGEBYSCORE"
    args := CommandRequest.utf8Args #[key, min, max]
  }

/--
ZREMRANGEBYLEX key min max
-/
def CommandRequest.zRemRangeByLex (key min max : String) : CommandRequest :=
  {
    name := "ZREMRANGEBYLEX"
    args := CommandRequest.utf8Args #[key, min, max]
  }

/--
ZINCRBY key increment member
-/
def CommandRequest.zIncrBy (key increment member : String) : CommandRequest :=
  {
    name := "ZINCRBY"
    args := CommandRequest.utf8Args #[key, increment, member]
  }

/--
ZRANDMEMBER key [count [WITHSCORES]]
-/
def CommandRequest.zRandMember (key : String) : CommandRequest :=
  {
    name := "ZRANDMEMBER"
    args := CommandRequest.utf8Args #[key]
  }

/--
ZRANDMEMBER key count
-/
def CommandRequest.zRandMembers (key : String) (count : Int) : CommandRequest :=
  {
    name := "ZRANDMEMBER"
    args := CommandRequest.utf8Args #[key, toString count]
  }

/--
ZRANDMEMBER key count WITHSCORES
-/
def CommandRequest.zRandMembersWithScores (key : String) (count : Int) : CommandRequest :=
  {
    name := "ZRANDMEMBER"
    args := CommandRequest.utf8Args #[key, toString count, "WITHSCORES"]
  }

/--
ZDIFF numkeys key [key ...]
-/
def CommandRequest.zDiff (keys : Array String) : CommandRequest :=
  {
    name := "ZDIFF"
    args := CommandRequest.utf8Args #[toString keys.size] ++ CommandRequest.utf8Args keys
  }

/--
ZDIFFSTORE destination numkeys key [key ...]
-/
def CommandRequest.zDiffStore (destination : String) (keys : Array String) : CommandRequest :=
  {
    name := "ZDIFFSTORE"
    args := CommandRequest.utf8Args #[destination, toString keys.size] ++ CommandRequest.utf8Args keys
  }

/--
ZINTER numkeys key [key ...]
-/
def CommandRequest.zInter (keys : Array String) : CommandRequest :=
  {
    name := "ZINTER"
    args := CommandRequest.utf8Args #[toString keys.size] ++ CommandRequest.utf8Args keys
  }

/--
ZINTERCARD numkeys key [key ...]
-/
def CommandRequest.zInterCard (keys : Array String) : CommandRequest :=
  {
    name := "ZINTERCARD"
    args := CommandRequest.utf8Args #[toString keys.size] ++ CommandRequest.utf8Args keys
  }

/--
ZINTERSTORE destination numkeys key [key ...]
-/
def CommandRequest.zInterStore (destination : String) (keys : Array String) : CommandRequest :=
  {
    name := "ZINTERSTORE"
    args := CommandRequest.utf8Args #[destination, toString keys.size] ++ CommandRequest.utf8Args keys
  }

/--
ZUNION numkeys key [key ...]
-/
def CommandRequest.zUnion (keys : Array String) : CommandRequest :=
  {
    name := "ZUNION"
    args := CommandRequest.utf8Args #[toString keys.size] ++ CommandRequest.utf8Args keys
  }

/--
ZUNIONSTORE destination numkeys key [key ...]
-/
def CommandRequest.zUnionStore (destination : String) (keys : Array String) : CommandRequest :=
  {
    name := "ZUNIONSTORE"
    args := CommandRequest.utf8Args #[destination, toString keys.size] ++ CommandRequest.utf8Args keys
  }

/--
ZSCAN key cursor [MATCH pattern] [COUNT count]
-/
def CommandRequest.zScan (key : String) (cursor : UInt64) (options : ZScanOptions := {}) : CommandRequest :=
  {
    name := "ZSCAN"
    args := CommandRequest.utf8Args #[key, toString cursor] ++ CommandRequest.zScanArgs options
  }

end LeanRedis
