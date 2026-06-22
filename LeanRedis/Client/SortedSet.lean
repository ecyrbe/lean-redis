import LeanRedis.Client.Basic
import LeanRedis.Command.SortedSet

namespace LeanRedis

open Std.Async
open LeanRedis

/--
Add scored members to a sorted set.

Example:
```lean
let added ← client.zAdd "scores" #[{ score := "10", member := "alice" }]
```
-/
def Client.zAdd [Transport.Transport τ]
    (client : Client τ)
    (key : String)
    (entries : Array SortedSetEntry)
    : Async Int := do
  let cmd := Command.zAdd key entries
  let reply ← client.execute cmd.request
  cmd.decode reply

/--
Remove members from a sorted set.

Example:
```lean
let removed ← client.zRem "scores" #["alice"]
```
-/
def Client.zRem [Transport.Transport τ]
    (client : Client τ)
    (key : String)
    (members : Array String)
    : Async Int := do
  let cmd := Command.zRem key members
  let reply ← client.execute cmd.request
  cmd.decode reply

/--
Return the cardinality of a sorted set.

Example:
```lean
let size ← client.zCard "scores"
```
-/
def Client.zCard [Transport.Transport τ]
    (client : Client τ)
    (key : String)
    : Async Int := do
  let cmd := Command.zCard key
  let reply ← client.execute cmd.request
  cmd.decode reply

/--
Return the score of a sorted-set member.

Example:
```lean
let score ← client.zScore "scores" "alice"
```
-/
def Client.zScore [Transport.Transport τ]
    (client : Client τ)
    (key member : String)
    : Async (Option String) := do
  let cmd := Command.zScore key member
  let reply ← client.execute cmd.request
  cmd.decode reply

/--
Return the scores for multiple sorted-set members.

Example:
```lean
let scores ← client.zMScore "scores" #["alice", "bob"]
```
-/
def Client.zMScore [Transport.Transport τ]
    (client : Client τ)
    (key : String)
    (members : Array String)
    : Async (Array (Option String)) := do
  let cmd := Command.zMScore key members
  let reply ← client.execute cmd.request
  cmd.decode reply

/--
Return the rank of a sorted-set member.

Example:
```lean
let rank ← client.zRank "scores" "alice"
```
-/
def Client.zRank [Transport.Transport τ]
    (client : Client τ)
    (key member : String)
    : Async (Option Int) := do
  let cmd := Command.zRank key member
  let reply ← client.execute cmd.request
  cmd.decode reply

/--
Return the reverse rank of a sorted-set member.

Example:
```lean
let rank ← client.zRevRank "scores" "alice"
```
-/
def Client.zRevRank [Transport.Transport τ]
    (client : Client τ)
    (key member : String)
    : Async (Option Int) := do
  let cmd := Command.zRevRank key member
  let reply ← client.execute cmd.request
  cmd.decode reply

/--
Return sorted-set members in score order by rank range.

Example:
```lean
let members ← client.zRange "scores" 0 (-1)
```
-/
def Client.zRange [Transport.Transport τ]
    (client : Client τ)
    (key : String)
    (start stop : Int)
    : Async (Array String) := do
  let cmd := Command.zRange key start stop
  let reply ← client.execute cmd.request
  cmd.decode reply

/--
Return sorted-set members with scores by rank range.

Example:
```lean
let entries ← client.zRangeWithScores "scores" 0 (-1)
```
-/
def Client.zRangeWithScores [Transport.Transport τ]
    (client : Client τ)
    (key : String)
    (start stop : Int)
    : Async (Array SortedSetEntry) := do
  let cmd := Command.zRangeWithScores key start stop
  let reply ← client.execute cmd.request
  cmd.decode reply

/--
Return sorted-set members in reverse score order by rank range.

Example:
```lean
let members ← client.zRevRange "scores" 0 (-1)
```
-/
def Client.zRevRange [Transport.Transport τ]
    (client : Client τ)
    (key : String)
    (start stop : Int)
    : Async (Array String) := do
  let cmd := Command.zRevRange key start stop
  let reply ← client.execute cmd.request
  cmd.decode reply

/--
Return sorted-set members with scores in reverse score order.

Example:
```lean
let entries ← client.zRevRangeWithScores "scores" 0 (-1)
```
-/
def Client.zRevRangeWithScores [Transport.Transport τ]
    (client : Client τ)
    (key : String)
    (start stop : Int)
    : Async (Array SortedSetEntry) := do
  let cmd := Command.zRevRangeWithScores key start stop
  let reply ← client.execute cmd.request
  cmd.decode reply

/--
Return sorted-set members within a score range.

Example:
```lean
let members ← client.zRangeByScore "scores" "0" "100"
```
-/
def Client.zRangeByScore [Transport.Transport τ]
    (client : Client τ)
    (key min max : String)
    : Async (Array String) := do
  let cmd := Command.zRangeByScore key min max
  let reply ← client.execute cmd.request
  cmd.decode reply

/--
Return sorted-set members with scores within a score range.

Example:
```lean
let entries ← client.zRangeByScoreWithScores "scores" "0" "100"
```
-/
def Client.zRangeByScoreWithScores [Transport.Transport τ]
    (client : Client τ)
    (key min max : String)
    : Async (Array SortedSetEntry) := do
  let cmd := Command.zRangeByScoreWithScores key min max
  let reply ← client.execute cmd.request
  cmd.decode reply

/--
Return sorted-set members within a reverse score range.

Example:
```lean
let members ← client.zRevRangeByScore "scores" "100" "0"
```
-/
def Client.zRevRangeByScore [Transport.Transport τ]
    (client : Client τ)
    (key max min : String)
    : Async (Array String) := do
  let cmd := Command.zRevRangeByScore key max min
  let reply ← client.execute cmd.request
  cmd.decode reply

/--
Return sorted-set members with scores within a reverse score range.

Example:
```lean
let entries ← client.zRevRangeByScoreWithScores "scores" "100" "0"
```
-/
def Client.zRevRangeByScoreWithScores [Transport.Transport τ]
    (client : Client τ)
    (key max min : String)
    : Async (Array SortedSetEntry) := do
  let cmd := Command.zRevRangeByScoreWithScores key max min
  let reply ← client.execute cmd.request
  cmd.decode reply

/--
Return sorted-set members within a lexicographic range.

Example:
```lean
let members ← client.zRangeByLex "names" "-" "+"
```
-/
def Client.zRangeByLex [Transport.Transport τ]
    (client : Client τ)
    (key min max : String)
    : Async (Array String) := do
  let cmd := Command.zRangeByLex key min max
  let reply ← client.execute cmd.request
  cmd.decode reply

/--
Return sorted-set members within a reverse lexicographic range.

Example:
```lean
let members ← client.zRevRangeByLex "names" "+" "-"
```
-/
def Client.zRevRangeByLex [Transport.Transport τ]
    (client : Client τ)
    (key max min : String)
    : Async (Array String) := do
  let cmd := Command.zRevRangeByLex key max min
  let reply ← client.execute cmd.request
  cmd.decode reply

/--
Count members within a score range.

Example:
```lean
let count ← client.zCount "scores" "0" "100"
```
-/
def Client.zCount [Transport.Transport τ]
    (client : Client τ)
    (key min max : String)
    : Async Int := do
  let cmd := Command.zCount key min max
  let reply ← client.execute cmd.request
  cmd.decode reply

/--
Count members within a lexicographic range.

Example:
```lean
let count ← client.zLexCount "names" "-" "+"
```
-/
def Client.zLexCount [Transport.Transport τ]
    (client : Client τ)
    (key min max : String)
    : Async Int := do
  let cmd := Command.zLexCount key min max
  let reply ← client.execute cmd.request
  cmd.decode reply

/--
Remove members by rank range.

Example:
```lean
let removed ← client.zRemRangeByRank "scores" 0 1
```
-/
def Client.zRemRangeByRank [Transport.Transport τ]
    (client : Client τ)
    (key : String)
    (start stop : Int)
    : Async Int := do
  let cmd := Command.zRemRangeByRank key start stop
  let reply ← client.execute cmd.request
  cmd.decode reply

/--
Remove members by score range.

Example:
```lean
let removed ← client.zRemRangeByScore "scores" "0" "10"
```
-/
def Client.zRemRangeByScore [Transport.Transport τ]
    (client : Client τ)
    (key min max : String)
    : Async Int := do
  let cmd := Command.zRemRangeByScore key min max
  let reply ← client.execute cmd.request
  cmd.decode reply

/--
Remove members by lexicographic range.

Example:
```lean
let removed ← client.zRemRangeByLex "names" "-" "+"
```
-/
def Client.zRemRangeByLex [Transport.Transport τ]
    (client : Client τ)
    (key min max : String)
    : Async Int := do
  let cmd := Command.zRemRangeByLex key min max
  let reply ← client.execute cmd.request
  cmd.decode reply

/--
Increment a sorted-set member score.

Example:
```lean
let score ← client.zIncrBy "scores" "1.5" "alice"
```
-/
def Client.zIncrBy [Transport.Transport τ]
    (client : Client τ)
    (key increment member : String)
    : Async String := do
  let cmd := Command.zIncrBy key increment member
  let reply ← client.execute cmd.request
  cmd.decode reply

/--
Return one random sorted-set member without removing it.

Example:
```lean
let member ← client.zRandMember "scores"
```
-/
def Client.zRandMember [Transport.Transport τ]
    (client : Client τ)
    (key : String)
    : Async (Option String) := do
  let cmd := Command.zRandMember key
  let reply ← client.execute cmd.request
  cmd.decode reply

/--
Return random sorted-set members without removing them.

Example:
```lean
let members ← client.zRandMembers "scores" 2
```
-/
def Client.zRandMembers [Transport.Transport τ]
    (client : Client τ)
    (key : String)
    (count : Int)
    : Async (Array String) := do
  let cmd := Command.zRandMembers key count
  let reply ← client.execute cmd.request
  cmd.decode reply

/--
Return random sorted-set members with scores.

Example:
```lean
let entries ← client.zRandMembersWithScores "scores" 2
```
-/
def Client.zRandMembersWithScores [Transport.Transport τ]
    (client : Client τ)
    (key : String)
    (count : Int)
    : Async (Array SortedSetEntry) := do
  let cmd := Command.zRandMembersWithScores key count
  let reply ← client.execute cmd.request
  cmd.decode reply

/--
Return the difference of multiple sorted sets.

Example:
```lean
let members ← client.zDiff #["a", "b"]
```
-/
def Client.zDiff [Transport.Transport τ]
    (client : Client τ)
    (keys : Array String)
    : Async (Array String) := do
  let cmd := Command.zDiff keys
  let reply ← client.execute cmd.request
  cmd.decode reply

/--
Store the difference of multiple sorted sets into a destination key.

Example:
```lean
let size ← client.zDiffStore "result" #["a", "b"]
```
-/
def Client.zDiffStore [Transport.Transport τ]
    (client : Client τ)
    (destination : String)
    (keys : Array String)
    : Async Int := do
  let cmd := Command.zDiffStore destination keys
  let reply ← client.execute cmd.request
  cmd.decode reply

/--
Return the intersection of multiple sorted sets.

Example:
```lean
let members ← client.zInter #["a", "b"]
```
-/
def Client.zInter [Transport.Transport τ]
    (client : Client τ)
    (keys : Array String)
    : Async (Array String) := do
  let cmd := Command.zInter keys
  let reply ← client.execute cmd.request
  cmd.decode reply

/--
Return the intersection cardinality of multiple sorted sets.

Example:
```lean
let size ← client.zInterCard #["a", "b"]
```
-/
def Client.zInterCard [Transport.Transport τ]
    (client : Client τ)
    (keys : Array String)
    : Async Int := do
  let cmd := Command.zInterCard keys
  let reply ← client.execute cmd.request
  cmd.decode reply

/--
Store the intersection of multiple sorted sets into a destination key.

Example:
```lean
let size ← client.zInterStore "result" #["a", "b"]
```
-/
def Client.zInterStore [Transport.Transport τ]
    (client : Client τ)
    (destination : String)
    (keys : Array String)
    : Async Int := do
  let cmd := Command.zInterStore destination keys
  let reply ← client.execute cmd.request
  cmd.decode reply

/--
Return the union of multiple sorted sets.

Example:
```lean
let members ← client.zUnion #["a", "b"]
```
-/
def Client.zUnion [Transport.Transport τ]
    (client : Client τ)
    (keys : Array String)
    : Async (Array String) := do
  let cmd := Command.zUnion keys
  let reply ← client.execute cmd.request
  cmd.decode reply

/--
Store the union of multiple sorted sets into a destination key.

Example:
```lean
let size ← client.zUnionStore "result" #["a", "b"]
```
-/
def Client.zUnionStore [Transport.Transport τ]
    (client : Client τ)
    (destination : String)
    (keys : Array String)
    : Async Int := do
  let cmd := Command.zUnionStore destination keys
  let reply ← client.execute cmd.request
  cmd.decode reply

/--
Scan a sorted set incrementally.

Example:
```lean
let page ← client.zScan "scores" 0
```
-/
def Client.zScan [Transport.Transport τ]
    (client : Client τ)
    (key : String)
    (cursor : UInt64)
    (options : ZScanOptions := {})
    : Async SortedSetScanResult := do
  let cmd := Command.zScan key cursor options
  let reply ← client.execute cmd.request
  cmd.decode reply

end LeanRedis
