import LeanRedis.Client.Basic
import LeanRedis.Tools.ExpectResult

namespace LeanRedis.Client

open Std.Internal.IO.Async
open LeanRedis

/--
Add scored members to a sorted set.

Example:
```lean
let added <- client.zAdd "scores" #[{ score := "10", member := "alice" }]
```
-/
def zAdd [Transport.Transport τ]
    (client : Client τ)
    (key : String)
    (entries : Array SortedSetEntry)
    : Async Int := do
  let reply <- Client.execute client <| CommandRequest.zAdd key entries
  expectInteger "ZADD" reply

/--
Remove members from a sorted set.

Example:
```lean
let removed <- client.zRem "scores" #["alice"]
```
-/
def zRem [Transport.Transport τ]
    (client : Client τ)
    (key : String)
    (members : Array String)
    : Async Int := do
  let reply <- Client.execute client <| CommandRequest.zRem key members
  expectInteger "ZREM" reply

/--
Return the cardinality of a sorted set.

Example:
```lean
let size <- client.zCard "scores"
```
-/
def zCard [Transport.Transport τ]
    (client : Client τ)
    (key : String)
    : Async Int := do
  let reply <- Client.execute client <| CommandRequest.zCard key
  expectInteger "ZCARD" reply

/--
Return the score of a sorted-set member.

Example:
```lean
let score <- client.zScore "scores" "alice"
```
-/
def zScore [Transport.Transport τ]
    (client : Client τ)
    (key member : String)
    : Async (Option String) := do
  let reply <- Client.execute client <| CommandRequest.zScore key member
  expectOptionalString "ZSCORE" reply

/--
Return the scores for multiple sorted-set members.

Example:
```lean
let scores <- client.zMScore "scores" #["alice", "bob"]
```
-/
def zMScore [Transport.Transport τ]
    (client : Client τ)
    (key : String)
    (members : Array String)
    : Async (Array (Option String)) := do
  let reply <- Client.execute client <| CommandRequest.zMScore key members
  expectStringArray "ZMSCORE" reply

/--
Return the rank of a sorted-set member.

Example:
```lean
let rank <- client.zRank "scores" "alice"
```
-/
def zRank [Transport.Transport τ]
    (client : Client τ)
    (key member : String)
    : Async (Option Int) := do
  let reply <- Client.execute client <| CommandRequest.zRank key member
  match reply with
  | .null => pure none
  | .number value => pure (some value)
  | .simpleError message => Error.raise <| .server message
  | _ => Error.raise <| .decode "unexpected ZRANK reply"

/--
Return the reverse rank of a sorted-set member.

Example:
```lean
let rank <- client.zRevRank "scores" "alice"
```
-/
def zRevRank [Transport.Transport τ]
    (client : Client τ)
    (key member : String)
    : Async (Option Int) := do
  let reply <- Client.execute client <| CommandRequest.zRevRank key member
  match reply with
  | .null => pure none
  | .number value => pure (some value)
  | .simpleError message => Error.raise <| .server message
  | _ => Error.raise <| .decode "unexpected ZREVRANK reply"

/--
Return sorted-set members in score order by rank range.

Example:
```lean
let members <- client.zRange "scores" 0 (-1)
```
-/
def zRange [Transport.Transport τ]
    (client : Client τ)
    (key : String)
    (start stop : Int)
    : Async (Array String) := do
  let reply <- Client.execute client <| CommandRequest.zRange key start stop
  expectPlainStringArray "ZRANGE" reply

/--
Return sorted-set members with scores by rank range.

Example:
```lean
let entries <- client.zRangeWithScores "scores" 0 (-1)
```
-/
def zRangeWithScores [Transport.Transport τ]
    (client : Client τ)
    (key : String)
    (start stop : Int)
    : Async (Array SortedSetEntry) := do
  let reply <- Client.execute client <| CommandRequest.zRangeWithScores key start stop
  expectSortedSetEntries "ZRANGE" reply

/--
Return sorted-set members in reverse score order by rank range.

Example:
```lean
let members <- client.zRevRange "scores" 0 (-1)
```
-/
def zRevRange [Transport.Transport τ]
    (client : Client τ)
    (key : String)
    (start stop : Int)
    : Async (Array String) := do
  let reply <- Client.execute client <| CommandRequest.zRevRange key start stop
  expectPlainStringArray "ZREVRANGE" reply

/--
Return sorted-set members with scores in reverse score order.

Example:
```lean
let entries <- client.zRevRangeWithScores "scores" 0 (-1)
```
-/
def zRevRangeWithScores [Transport.Transport τ]
    (client : Client τ)
    (key : String)
    (start stop : Int)
    : Async (Array SortedSetEntry) := do
  let reply <- Client.execute client <| CommandRequest.zRevRangeWithScores key start stop
  expectSortedSetEntries "ZREVRANGE" reply

/--
Return sorted-set members within a score range.

Example:
```lean
let members <- client.zRangeByScore "scores" "0" "100"
```
-/
def zRangeByScore [Transport.Transport τ]
    (client : Client τ)
    (key min max : String)
    : Async (Array String) := do
  let reply <- Client.execute client <| CommandRequest.zRangeByScore key min max
  expectPlainStringArray "ZRANGEBYSCORE" reply

/--
Return sorted-set members with scores within a score range.

Example:
```lean
let entries <- client.zRangeByScoreWithScores "scores" "0" "100"
```
-/
def zRangeByScoreWithScores [Transport.Transport τ]
    (client : Client τ)
    (key min max : String)
    : Async (Array SortedSetEntry) := do
  let reply <- Client.execute client <| CommandRequest.zRangeByScoreWithScores key min max
  expectSortedSetEntries "ZRANGEBYSCORE" reply

/--
Return sorted-set members within a reverse score range.

Example:
```lean
let members <- client.zRevRangeByScore "scores" "100" "0"
```
-/
def zRevRangeByScore [Transport.Transport τ]
    (client : Client τ)
    (key max min : String)
    : Async (Array String) := do
  let reply <- Client.execute client <| CommandRequest.zRevRangeByScore key max min
  expectPlainStringArray "ZREVRANGEBYSCORE" reply

/--
Return sorted-set members with scores within a reverse score range.

Example:
```lean
let entries <- client.zRevRangeByScoreWithScores "scores" "100" "0"
```
-/
def zRevRangeByScoreWithScores [Transport.Transport τ]
    (client : Client τ)
    (key max min : String)
    : Async (Array SortedSetEntry) := do
  let reply <- Client.execute client <| CommandRequest.zRevRangeByScoreWithScores key max min
  expectSortedSetEntries "ZREVRANGEBYSCORE" reply

/--
Return sorted-set members within a lexicographic range.

Example:
```lean
let members <- client.zRangeByLex "names" "-" "+"
```
-/
def zRangeByLex [Transport.Transport τ]
    (client : Client τ)
    (key min max : String)
    : Async (Array String) := do
  let reply <- Client.execute client <| CommandRequest.zRangeByLex key min max
  expectPlainStringArray "ZRANGEBYLEX" reply

/--
Return sorted-set members within a reverse lexicographic range.

Example:
```lean
let members <- client.zRevRangeByLex "names" "+" "-"
```
-/
def zRevRangeByLex [Transport.Transport τ]
    (client : Client τ)
    (key max min : String)
    : Async (Array String) := do
  let reply <- Client.execute client <| CommandRequest.zRevRangeByLex key max min
  expectPlainStringArray "ZREVRANGEBYLEX" reply

/--
Count members within a score range.

Example:
```lean
let count <- client.zCount "scores" "0" "100"
```
-/
def zCount [Transport.Transport τ]
    (client : Client τ)
    (key min max : String)
    : Async Int := do
  let reply <- Client.execute client <| CommandRequest.zCount key min max
  expectInteger "ZCOUNT" reply

/--
Count members within a lexicographic range.

Example:
```lean
let count <- client.zLexCount "names" "-" "+"
```
-/
def zLexCount [Transport.Transport τ]
    (client : Client τ)
    (key min max : String)
    : Async Int := do
  let reply <- Client.execute client <| CommandRequest.zLexCount key min max
  expectInteger "ZLEXCOUNT" reply

/--
Remove members by rank range.

Example:
```lean
let removed <- client.zRemRangeByRank "scores" 0 1
```
-/
def zRemRangeByRank [Transport.Transport τ]
    (client : Client τ)
    (key : String)
    (start stop : Int)
    : Async Int := do
  let reply <- Client.execute client <| CommandRequest.zRemRangeByRank key start stop
  expectInteger "ZREMRANGEBYRANK" reply

/--
Remove members by score range.

Example:
```lean
let removed <- client.zRemRangeByScore "scores" "0" "10"
```
-/
def zRemRangeByScore [Transport.Transport τ]
    (client : Client τ)
    (key min max : String)
    : Async Int := do
  let reply <- Client.execute client <| CommandRequest.zRemRangeByScore key min max
  expectInteger "ZREMRANGEBYSCORE" reply

/--
Remove members by lexicographic range.

Example:
```lean
let removed <- client.zRemRangeByLex "names" "-" "+"
```
-/
def zRemRangeByLex [Transport.Transport τ]
    (client : Client τ)
    (key min max : String)
    : Async Int := do
  let reply <- Client.execute client <| CommandRequest.zRemRangeByLex key min max
  expectInteger "ZREMRANGEBYLEX" reply

/--
Increment a sorted-set member score.

Example:
```lean
let score <- client.zIncrBy "scores" "1.5" "alice"
```
-/
def zIncrBy [Transport.Transport τ]
    (client : Client τ)
    (key increment member : String)
    : Async String := do
  let reply <- Client.execute client <| CommandRequest.zIncrBy key increment member
  expectString "ZINCRBY" reply

/--
Return one random sorted-set member without removing it.

Example:
```lean
let member <- client.zRandMember "scores"
```
-/
def zRandMember [Transport.Transport τ]
    (client : Client τ)
    (key : String)
    : Async (Option String) := do
  let reply <- Client.execute client <| CommandRequest.zRandMember key
  expectOptionalString "ZRANDMEMBER" reply

/--
Return random sorted-set members without removing them.

Example:
```lean
let members <- client.zRandMembers "scores" 2
```
-/
def zRandMembers [Transport.Transport τ]
    (client : Client τ)
    (key : String)
    (count : Int)
    : Async (Array String) := do
  let reply <- Client.execute client <| CommandRequest.zRandMembers key count
  match (← expectOptionalStringOrArray "ZRANDMEMBER" reply) with
  | .inl none => pure #[]
  | .inl (some value) => pure #[value]
  | .inr values => pure values

/--
Return random sorted-set members with scores.

Example:
```lean
let entries <- client.zRandMembersWithScores "scores" 2
```
-/
def zRandMembersWithScores [Transport.Transport τ]
    (client : Client τ)
    (key : String)
    (count : Int)
    : Async (Array SortedSetEntry) := do
  let reply <- Client.execute client <| CommandRequest.zRandMembersWithScores key count
  expectSortedSetEntries "ZRANDMEMBER" reply

/--
Return the difference of multiple sorted sets.

Example:
```lean
let members <- client.zDiff #["a", "b"]
```
-/
def zDiff [Transport.Transport τ]
    (client : Client τ)
    (keys : Array String)
    : Async (Array String) := do
  let reply <- Client.execute client <| CommandRequest.zDiff keys
  expectPlainStringArray "ZDIFF" reply

/--
Store the difference of multiple sorted sets into a destination key.

Example:
```lean
let size <- client.zDiffStore "result" #["a", "b"]
```
-/
def zDiffStore [Transport.Transport τ]
    (client : Client τ)
    (destination : String)
    (keys : Array String)
    : Async Int := do
  let reply <- Client.execute client <| CommandRequest.zDiffStore destination keys
  expectInteger "ZDIFFSTORE" reply

/--
Return the intersection of multiple sorted sets.

Example:
```lean
let members <- client.zInter #["a", "b"]
```
-/
def zInter [Transport.Transport τ]
    (client : Client τ)
    (keys : Array String)
    : Async (Array String) := do
  let reply <- Client.execute client <| CommandRequest.zInter keys
  expectPlainStringArray "ZINTER" reply

/--
Return the intersection cardinality of multiple sorted sets.

Example:
```lean
let size <- client.zInterCard #["a", "b"]
```
-/
def zInterCard [Transport.Transport τ]
    (client : Client τ)
    (keys : Array String)
    : Async Int := do
  let reply <- Client.execute client <| CommandRequest.zInterCard keys
  expectInteger "ZINTERCARD" reply

/--
Store the intersection of multiple sorted sets into a destination key.

Example:
```lean
let size <- client.zInterStore "result" #["a", "b"]
```
-/
def zInterStore [Transport.Transport τ]
    (client : Client τ)
    (destination : String)
    (keys : Array String)
    : Async Int := do
  let reply <- Client.execute client <| CommandRequest.zInterStore destination keys
  expectInteger "ZINTERSTORE" reply

/--
Return the union of multiple sorted sets.

Example:
```lean
let members <- client.zUnion #["a", "b"]
```
-/
def zUnion [Transport.Transport τ]
    (client : Client τ)
    (keys : Array String)
    : Async (Array String) := do
  let reply <- Client.execute client <| CommandRequest.zUnion keys
  expectPlainStringArray "ZUNION" reply

/--
Store the union of multiple sorted sets into a destination key.

Example:
```lean
let size <- client.zUnionStore "result" #["a", "b"]
```
-/
def zUnionStore [Transport.Transport τ]
    (client : Client τ)
    (destination : String)
    (keys : Array String)
    : Async Int := do
  let reply <- Client.execute client <| CommandRequest.zUnionStore destination keys
  expectInteger "ZUNIONSTORE" reply

/--
Scan a sorted set incrementally.

Example:
```lean
let page <- client.zScan "scores" 0
```
-/
def zScan [Transport.Transport τ]
    (client : Client τ)
    (key : String)
    (cursor : UInt64)
    (options : ZScanOptions := {})
    : Async SortedSetScanResult := do
  let reply <- Client.execute client <| CommandRequest.zScan key cursor options
  expectSortedSetScanResult reply

end LeanRedis.Client
