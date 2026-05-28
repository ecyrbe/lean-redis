import LeanRedis.Client.Internal

namespace LeanRedis

open Std.Internal.IO.Async

def Client.zAdd [Transport.Transport τ]
    (client : Client τ)
    (key : String)
    (entries : Array SortedSetEntry)
    : Async Int := do
  let reply <- Client.execute client <| CommandRequest.zAdd key entries
  Client.expectInteger "ZADD" reply

def Client.zRem [Transport.Transport τ]
    (client : Client τ)
    (key : String)
    (members : Array String)
    : Async Int := do
  let reply <- Client.execute client <| CommandRequest.zRem key members
  Client.expectInteger "ZREM" reply

def Client.zCard [Transport.Transport τ]
    (client : Client τ)
    (key : String)
    : Async Int := do
  let reply <- Client.execute client <| CommandRequest.zCard key
  Client.expectInteger "ZCARD" reply

def Client.zScore [Transport.Transport τ]
    (client : Client τ)
    (key member : String)
    : Async (Option String) := do
  let reply <- Client.execute client <| CommandRequest.zScore key member
  Client.expectOptionalString "ZSCORE" reply

def Client.zMScore [Transport.Transport τ]
    (client : Client τ)
    (key : String)
    (members : Array String)
    : Async (Array (Option String)) := do
  let reply <- Client.execute client <| CommandRequest.zMScore key members
  Client.expectStringArray "ZMSCORE" reply

def Client.zRank [Transport.Transport τ]
    (client : Client τ)
    (key member : String)
    : Async (Option Int) := do
  let reply <- Client.execute client <| CommandRequest.zRank key member
  match reply with
  | .null => pure none
  | .number value => pure (some value)
  | .simpleError message => Error.raise <| .server message
  | _ => Error.raise <| .decode "unexpected ZRANK reply"

def Client.zRevRank [Transport.Transport τ]
    (client : Client τ)
    (key member : String)
    : Async (Option Int) := do
  let reply <- Client.execute client <| CommandRequest.zRevRank key member
  match reply with
  | .null => pure none
  | .number value => pure (some value)
  | .simpleError message => Error.raise <| .server message
  | _ => Error.raise <| .decode "unexpected ZREVRANK reply"

def Client.zRange [Transport.Transport τ]
    (client : Client τ)
    (key : String)
    (start stop : Int)
    : Async (Array String) := do
  let reply <- Client.execute client <| CommandRequest.zRange key start stop
  Client.expectPlainStringArray "ZRANGE" reply

def Client.zRangeWithScores [Transport.Transport τ]
    (client : Client τ)
    (key : String)
    (start stop : Int)
    : Async (Array SortedSetEntry) := do
  let reply <- Client.execute client <| CommandRequest.zRangeWithScores key start stop
  Client.expectSortedSetEntries "ZRANGE" reply

def Client.zRevRange [Transport.Transport τ]
    (client : Client τ)
    (key : String)
    (start stop : Int)
    : Async (Array String) := do
  let reply <- Client.execute client <| CommandRequest.zRevRange key start stop
  Client.expectPlainStringArray "ZREVRANGE" reply

def Client.zRevRangeWithScores [Transport.Transport τ]
    (client : Client τ)
    (key : String)
    (start stop : Int)
    : Async (Array SortedSetEntry) := do
  let reply <- Client.execute client <| CommandRequest.zRevRangeWithScores key start stop
  Client.expectSortedSetEntries "ZREVRANGE" reply

def Client.zRangeByScore [Transport.Transport τ]
    (client : Client τ)
    (key min max : String)
    : Async (Array String) := do
  let reply <- Client.execute client <| CommandRequest.zRangeByScore key min max
  Client.expectPlainStringArray "ZRANGEBYSCORE" reply

def Client.zRangeByScoreWithScores [Transport.Transport τ]
    (client : Client τ)
    (key min max : String)
    : Async (Array SortedSetEntry) := do
  let reply <- Client.execute client <| CommandRequest.zRangeByScoreWithScores key min max
  Client.expectSortedSetEntries "ZRANGEBYSCORE" reply

def Client.zRevRangeByScore [Transport.Transport τ]
    (client : Client τ)
    (key max min : String)
    : Async (Array String) := do
  let reply <- Client.execute client <| CommandRequest.zRevRangeByScore key max min
  Client.expectPlainStringArray "ZREVRANGEBYSCORE" reply

def Client.zRevRangeByScoreWithScores [Transport.Transport τ]
    (client : Client τ)
    (key max min : String)
    : Async (Array SortedSetEntry) := do
  let reply <- Client.execute client <| CommandRequest.zRevRangeByScoreWithScores key max min
  Client.expectSortedSetEntries "ZREVRANGEBYSCORE" reply

def Client.zRangeByLex [Transport.Transport τ]
    (client : Client τ)
    (key min max : String)
    : Async (Array String) := do
  let reply <- Client.execute client <| CommandRequest.zRangeByLex key min max
  Client.expectPlainStringArray "ZRANGEBYLEX" reply

def Client.zRevRangeByLex [Transport.Transport τ]
    (client : Client τ)
    (key max min : String)
    : Async (Array String) := do
  let reply <- Client.execute client <| CommandRequest.zRevRangeByLex key max min
  Client.expectPlainStringArray "ZREVRANGEBYLEX" reply

def Client.zCount [Transport.Transport τ]
    (client : Client τ)
    (key min max : String)
    : Async Int := do
  let reply <- Client.execute client <| CommandRequest.zCount key min max
  Client.expectInteger "ZCOUNT" reply

def Client.zLexCount [Transport.Transport τ]
    (client : Client τ)
    (key min max : String)
    : Async Int := do
  let reply <- Client.execute client <| CommandRequest.zLexCount key min max
  Client.expectInteger "ZLEXCOUNT" reply

def Client.zRemRangeByRank [Transport.Transport τ]
    (client : Client τ)
    (key : String)
    (start stop : Int)
    : Async Int := do
  let reply <- Client.execute client <| CommandRequest.zRemRangeByRank key start stop
  Client.expectInteger "ZREMRANGEBYRANK" reply

def Client.zRemRangeByScore [Transport.Transport τ]
    (client : Client τ)
    (key min max : String)
    : Async Int := do
  let reply <- Client.execute client <| CommandRequest.zRemRangeByScore key min max
  Client.expectInteger "ZREMRANGEBYSCORE" reply

def Client.zRemRangeByLex [Transport.Transport τ]
    (client : Client τ)
    (key min max : String)
    : Async Int := do
  let reply <- Client.execute client <| CommandRequest.zRemRangeByLex key min max
  Client.expectInteger "ZREMRANGEBYLEX" reply

def Client.zIncrBy [Transport.Transport τ]
    (client : Client τ)
    (key increment member : String)
    : Async String := do
  let reply <- Client.execute client <| CommandRequest.zIncrBy key increment member
  Client.expectString "ZINCRBY" reply

def Client.zRandMember [Transport.Transport τ]
    (client : Client τ)
    (key : String)
    : Async (Option String) := do
  let reply <- Client.execute client <| CommandRequest.zRandMember key
  Client.expectOptionalString "ZRANDMEMBER" reply

def Client.zRandMembers [Transport.Transport τ]
    (client : Client τ)
    (key : String)
    (count : Int)
    : Async (Array String) := do
  let reply <- Client.execute client <| CommandRequest.zRandMembers key count
  match (← Client.expectOptionalStringOrArray "ZRANDMEMBER" reply) with
  | .inl none => pure #[]
  | .inl (some value) => pure #[value]
  | .inr values => pure values

def Client.zRandMembersWithScores [Transport.Transport τ]
    (client : Client τ)
    (key : String)
    (count : Int)
    : Async (Array SortedSetEntry) := do
  let reply <- Client.execute client <| CommandRequest.zRandMembersWithScores key count
  Client.expectSortedSetEntries "ZRANDMEMBER" reply

def Client.zDiff [Transport.Transport τ]
    (client : Client τ)
    (keys : Array String)
    : Async (Array String) := do
  let reply <- Client.execute client <| CommandRequest.zDiff keys
  Client.expectPlainStringArray "ZDIFF" reply

def Client.zDiffStore [Transport.Transport τ]
    (client : Client τ)
    (destination : String)
    (keys : Array String)
    : Async Int := do
  let reply <- Client.execute client <| CommandRequest.zDiffStore destination keys
  Client.expectInteger "ZDIFFSTORE" reply

def Client.zInter [Transport.Transport τ]
    (client : Client τ)
    (keys : Array String)
    : Async (Array String) := do
  let reply <- Client.execute client <| CommandRequest.zInter keys
  Client.expectPlainStringArray "ZINTER" reply

def Client.zInterCard [Transport.Transport τ]
    (client : Client τ)
    (keys : Array String)
    : Async Int := do
  let reply <- Client.execute client <| CommandRequest.zInterCard keys
  Client.expectInteger "ZINTERCARD" reply

def Client.zInterStore [Transport.Transport τ]
    (client : Client τ)
    (destination : String)
    (keys : Array String)
    : Async Int := do
  let reply <- Client.execute client <| CommandRequest.zInterStore destination keys
  Client.expectInteger "ZINTERSTORE" reply

def Client.zUnion [Transport.Transport τ]
    (client : Client τ)
    (keys : Array String)
    : Async (Array String) := do
  let reply <- Client.execute client <| CommandRequest.zUnion keys
  Client.expectPlainStringArray "ZUNION" reply

def Client.zUnionStore [Transport.Transport τ]
    (client : Client τ)
    (destination : String)
    (keys : Array String)
    : Async Int := do
  let reply <- Client.execute client <| CommandRequest.zUnionStore destination keys
  Client.expectInteger "ZUNIONSTORE" reply

def Client.zScan [Transport.Transport τ]
    (client : Client τ)
    (key : String)
    (cursor : UInt64)
    (options : ZScanOptions := {})
    : Async SortedSetScanResult := do
  let reply <- Client.execute client <| CommandRequest.zScan key cursor options
  Client.expectSortedSetScanResult reply

end LeanRedis
