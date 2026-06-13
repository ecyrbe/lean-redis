import LeanRedis.Command.Base
import LeanRedis.Tools.ExpectResult

namespace LeanRedis

structure ZScanOptions where
  match? : Option String := none
  count? : Option UInt64 := none
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

def Command.zAdd (key : String) (entries : Array SortedSetEntry) : Command Int :=
  ⟨ CommandRequest.zAdd key entries, expectInteger "ZADD" ⟩

def Command.zRem (key : String) (members : Array String) : Command Int :=
  ⟨ CommandRequest.zRem key members, expectInteger "ZREM" ⟩

def Command.zCard (key : String) : Command Int :=
  ⟨ CommandRequest.zCard key, expectInteger "ZCARD" ⟩

def Command.zScore (key member : String) : Command (Option String) :=
  ⟨ CommandRequest.zScore key member, expectOptionalString "ZSCORE" ⟩

def Command.zMScore (key : String) (members : Array String) : Command (Array (Option String)) :=
  ⟨ CommandRequest.zMScore key members, expectStringArray "ZMSCORE" ⟩

def Command.zRank (key member : String) : Command (Option Int) :=
  {
    request := CommandRequest.zRank key member
    decode := fun
      | .null => .ok none
      | .number value => .ok (some value)
      | .simpleError message => .error (.server message)
      | _ => .error (.decode "unexpected ZRANK reply")
  }

def Command.zRevRank (key member : String) : Command (Option Int) :=
  {
    request := CommandRequest.zRevRank key member
    decode := fun
      | .null => .ok none
      | .number value => .ok (some value)
      | .simpleError message => .error (.server message)
      | _ => .error (.decode "unexpected ZREVRANK reply")
  }

def Command.zRange (key : String) (start stop : Int) : Command (Array String) :=
  ⟨ CommandRequest.zRange key start stop, expectPlainStringArray "ZRANGE" ⟩

def Command.zRangeWithScores (key : String) (start stop : Int) : Command (Array SortedSetEntry) :=
  ⟨ CommandRequest.zRangeWithScores key start stop, expectSortedSetEntries "ZRANGE" ⟩

def Command.zRevRange (key : String) (start stop : Int) : Command (Array String) :=
  ⟨ CommandRequest.zRevRange key start stop, expectPlainStringArray "ZREVRANGE" ⟩

def Command.zRevRangeWithScores (key : String) (start stop : Int) : Command (Array SortedSetEntry) :=
  ⟨ CommandRequest.zRevRangeWithScores key start stop, expectSortedSetEntries "ZREVRANGE" ⟩

def Command.zRangeByScore (key min max : String) : Command (Array String) :=
  ⟨ CommandRequest.zRangeByScore key min max, expectPlainStringArray "ZRANGEBYSCORE" ⟩

def Command.zRangeByScoreWithScores (key min max : String) : Command (Array SortedSetEntry) :=
  ⟨ CommandRequest.zRangeByScoreWithScores key min max, expectSortedSetEntries "ZRANGEBYSCORE" ⟩

def Command.zRevRangeByScore (key max min : String) : Command (Array String) :=
  ⟨ CommandRequest.zRevRangeByScore key max min, expectPlainStringArray "ZREVRANGEBYSCORE" ⟩

def Command.zRevRangeByScoreWithScores (key max min : String) : Command (Array SortedSetEntry) :=
  ⟨ CommandRequest.zRevRangeByScoreWithScores key max min, expectSortedSetEntries "ZREVRANGEBYSCORE" ⟩

def Command.zRangeByLex (key min max : String) : Command (Array String) :=
  ⟨ CommandRequest.zRangeByLex key min max, expectPlainStringArray "ZRANGEBYLEX" ⟩

def Command.zRevRangeByLex (key max min : String) : Command (Array String) :=
  ⟨ CommandRequest.zRevRangeByLex key max min, expectPlainStringArray "ZREVRANGEBYLEX" ⟩

def Command.zCount (key min max : String) : Command Int :=
  ⟨ CommandRequest.zCount key min max, expectInteger "ZCOUNT" ⟩

def Command.zLexCount (key min max : String) : Command Int :=
  ⟨ CommandRequest.zLexCount key min max, expectInteger "ZLEXCOUNT" ⟩

def Command.zRemRangeByRank (key : String) (start stop : Int) : Command Int :=
  ⟨ CommandRequest.zRemRangeByRank key start stop, expectInteger "ZREMRANGEBYRANK" ⟩

def Command.zRemRangeByScore (key min max : String) : Command Int :=
  ⟨ CommandRequest.zRemRangeByScore key min max, expectInteger "ZREMRANGEBYSCORE" ⟩

def Command.zRemRangeByLex (key min max : String) : Command Int :=
  ⟨ CommandRequest.zRemRangeByLex key min max, expectInteger "ZREMRANGEBYLEX" ⟩

def Command.zIncrBy (key increment member : String) : Command String :=
  ⟨ CommandRequest.zIncrBy key increment member, expectString "ZINCRBY" ⟩

def Command.zRandMember (key : String) : Command (Option String) :=
  ⟨ CommandRequest.zRandMember key, expectOptionalString "ZRANDMEMBER" ⟩

def Command.zRandMembers (key : String) (count : Int) : Command (Array String) :=
  {
    request := CommandRequest.zRandMembers key count
    decode := fun reply =>
      match expectOptionalStringOrArray "ZRANDMEMBER" reply with
      | .ok (.inl none) => .ok #[]
      | .ok (.inl (some value)) => .ok #[value]
      | .ok (.inr values) => .ok values
      | .error e => .error e
  }

def Command.zRandMembersWithScores (key : String) (count : Int) : Command (Array SortedSetEntry) :=
  ⟨ CommandRequest.zRandMembersWithScores key count, expectSortedSetEntries "ZRANDMEMBER" ⟩

def Command.zDiff (keys : Array String) : Command (Array String) :=
  ⟨ CommandRequest.zDiff keys, expectPlainStringArray "ZDIFF" ⟩

def Command.zDiffStore (destination : String) (keys : Array String) : Command Int :=
  ⟨ CommandRequest.zDiffStore destination keys, expectInteger "ZDIFFSTORE" ⟩

def Command.zInter (keys : Array String) : Command (Array String) :=
  ⟨ CommandRequest.zInter keys, expectPlainStringArray "ZINTER" ⟩

def Command.zInterCard (keys : Array String) : Command Int :=
  ⟨ CommandRequest.zInterCard keys, expectInteger "ZINTERCARD" ⟩

def Command.zInterStore (destination : String) (keys : Array String) : Command Int :=
  ⟨ CommandRequest.zInterStore destination keys, expectInteger "ZINTERSTORE" ⟩

def Command.zUnion (keys : Array String) : Command (Array String) :=
  ⟨ CommandRequest.zUnion keys, expectPlainStringArray "ZUNION" ⟩

def Command.zUnionStore (destination : String) (keys : Array String) : Command Int :=
  ⟨ CommandRequest.zUnionStore destination keys, expectInteger "ZUNIONSTORE" ⟩

def Command.zScan (key : String) (cursor : UInt64) (options : ZScanOptions := {}) : Command SortedSetScanResult :=
  ⟨ CommandRequest.zScan key cursor options, expectSortedSetScanResult ⟩

end LeanRedis
