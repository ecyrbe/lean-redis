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

def CommandRequest.zAdd (key : String) (entries : Array SortedSetEntry) : CommandRequest :=
  {
    name := "ZADD"
    args := CommandRequest.utf8Args #[key] ++ CommandRequest.sortedSetEntryArgs entries
  }

def CommandRequest.zRem (key : String) (members : Array String) : CommandRequest :=
  {
    name := "ZREM"
    args := CommandRequest.utf8Args #[key] ++ CommandRequest.utf8Args members
  }

def CommandRequest.zCard (key : String) : CommandRequest :=
  {
    name := "ZCARD"
    args := CommandRequest.utf8Args #[key]
  }

def CommandRequest.zScore (key member : String) : CommandRequest :=
  {
    name := "ZSCORE"
    args := CommandRequest.utf8Args #[key, member]
  }

def CommandRequest.zMScore (key : String) (members : Array String) : CommandRequest :=
  {
    name := "ZMSCORE"
    args := CommandRequest.utf8Args #[key] ++ CommandRequest.utf8Args members
  }

def CommandRequest.zRank (key member : String) : CommandRequest :=
  {
    name := "ZRANK"
    args := CommandRequest.utf8Args #[key, member]
  }

def CommandRequest.zRevRank (key member : String) : CommandRequest :=
  {
    name := "ZREVRANK"
    args := CommandRequest.utf8Args #[key, member]
  }

def CommandRequest.zRange (key : String) (start stop : Int) : CommandRequest :=
  {
    name := "ZRANGE"
    args := CommandRequest.utf8Args #[key, toString start, toString stop]
  }

def CommandRequest.zRangeWithScores (key : String) (start stop : Int) : CommandRequest :=
  {
    name := "ZRANGE"
    args := CommandRequest.utf8Args #[key, toString start, toString stop, "WITHSCORES"]
  }

def CommandRequest.zRevRange (key : String) (start stop : Int) : CommandRequest :=
  {
    name := "ZREVRANGE"
    args := CommandRequest.utf8Args #[key, toString start, toString stop]
  }

def CommandRequest.zRevRangeWithScores (key : String) (start stop : Int) : CommandRequest :=
  {
    name := "ZREVRANGE"
    args := CommandRequest.utf8Args #[key, toString start, toString stop, "WITHSCORES"]
  }

def CommandRequest.zRangeByScore (key min max : String) : CommandRequest :=
  {
    name := "ZRANGEBYSCORE"
    args := CommandRequest.utf8Args #[key, min, max]
  }

def CommandRequest.zRangeByScoreWithScores (key min max : String) : CommandRequest :=
  {
    name := "ZRANGEBYSCORE"
    args := CommandRequest.utf8Args #[key, min, max, "WITHSCORES"]
  }

def CommandRequest.zRevRangeByScore (key max min : String) : CommandRequest :=
  {
    name := "ZREVRANGEBYSCORE"
    args := CommandRequest.utf8Args #[key, max, min]
  }

def CommandRequest.zRevRangeByScoreWithScores (key max min : String) : CommandRequest :=
  {
    name := "ZREVRANGEBYSCORE"
    args := CommandRequest.utf8Args #[key, max, min, "WITHSCORES"]
  }

def CommandRequest.zRangeByLex (key min max : String) : CommandRequest :=
  {
    name := "ZRANGEBYLEX"
    args := CommandRequest.utf8Args #[key, min, max]
  }

def CommandRequest.zRevRangeByLex (key max min : String) : CommandRequest :=
  {
    name := "ZREVRANGEBYLEX"
    args := CommandRequest.utf8Args #[key, max, min]
  }

def CommandRequest.zCount (key min max : String) : CommandRequest :=
  {
    name := "ZCOUNT"
    args := CommandRequest.utf8Args #[key, min, max]
  }

def CommandRequest.zLexCount (key min max : String) : CommandRequest :=
  {
    name := "ZLEXCOUNT"
    args := CommandRequest.utf8Args #[key, min, max]
  }

def CommandRequest.zRemRangeByRank (key : String) (start stop : Int) : CommandRequest :=
  {
    name := "ZREMRANGEBYRANK"
    args := CommandRequest.utf8Args #[key, toString start, toString stop]
  }

def CommandRequest.zRemRangeByScore (key min max : String) : CommandRequest :=
  {
    name := "ZREMRANGEBYSCORE"
    args := CommandRequest.utf8Args #[key, min, max]
  }

def CommandRequest.zRemRangeByLex (key min max : String) : CommandRequest :=
  {
    name := "ZREMRANGEBYLEX"
    args := CommandRequest.utf8Args #[key, min, max]
  }

def CommandRequest.zIncrBy (key increment member : String) : CommandRequest :=
  {
    name := "ZINCRBY"
    args := CommandRequest.utf8Args #[key, increment, member]
  }

def CommandRequest.zRandMember (key : String) : CommandRequest :=
  {
    name := "ZRANDMEMBER"
    args := CommandRequest.utf8Args #[key]
  }

def CommandRequest.zRandMembers (key : String) (count : Int) : CommandRequest :=
  {
    name := "ZRANDMEMBER"
    args := CommandRequest.utf8Args #[key, toString count]
  }

def CommandRequest.zRandMembersWithScores (key : String) (count : Int) : CommandRequest :=
  {
    name := "ZRANDMEMBER"
    args := CommandRequest.utf8Args #[key, toString count, "WITHSCORES"]
  }

def CommandRequest.zDiff (keys : Array String) : CommandRequest :=
  {
    name := "ZDIFF"
    args := CommandRequest.utf8Args #[toString keys.size] ++ CommandRequest.utf8Args keys
  }

def CommandRequest.zDiffStore (destination : String) (keys : Array String) : CommandRequest :=
  {
    name := "ZDIFFSTORE"
    args := CommandRequest.utf8Args #[destination, toString keys.size] ++ CommandRequest.utf8Args keys
  }

def CommandRequest.zInter (keys : Array String) : CommandRequest :=
  {
    name := "ZINTER"
    args := CommandRequest.utf8Args #[toString keys.size] ++ CommandRequest.utf8Args keys
  }

def CommandRequest.zInterCard (keys : Array String) : CommandRequest :=
  {
    name := "ZINTERCARD"
    args := CommandRequest.utf8Args #[toString keys.size] ++ CommandRequest.utf8Args keys
  }

def CommandRequest.zInterStore (destination : String) (keys : Array String) : CommandRequest :=
  {
    name := "ZINTERSTORE"
    args := CommandRequest.utf8Args #[destination, toString keys.size] ++ CommandRequest.utf8Args keys
  }

def CommandRequest.zUnion (keys : Array String) : CommandRequest :=
  {
    name := "ZUNION"
    args := CommandRequest.utf8Args #[toString keys.size] ++ CommandRequest.utf8Args keys
  }

def CommandRequest.zUnionStore (destination : String) (keys : Array String) : CommandRequest :=
  {
    name := "ZUNIONSTORE"
    args := CommandRequest.utf8Args #[destination, toString keys.size] ++ CommandRequest.utf8Args keys
  }

def CommandRequest.zScan (key : String) (cursor : UInt64) (options : ZScanOptions := {}) : CommandRequest :=
  {
    name := "ZSCAN"
    args := CommandRequest.utf8Args #[key, toString cursor] ++ CommandRequest.zScanArgs options
  }

end LeanRedis
