import LeanRedis.Pipeline.Basic

namespace LeanRedis.Pipeline

def zAdd (pipeline : Pipeline α) (key : String) (entries : Array SortedSetEntry) :=
  pipeline.hAppend <| fromCommand <| Command.zAdd key entries

def zRem (pipeline : Pipeline α) (key : String) (members : Array String) :=
  pipeline.hAppend <| fromCommand <| Command.zRem key members

def zCard (pipeline : Pipeline α) (key : String) :=
  pipeline.hAppend <| fromCommand <| Command.zCard key

def zScore (pipeline : Pipeline α) (key member : String) :=
  pipeline.hAppend <| fromCommand <| Command.zScore key member

def zMScore (pipeline : Pipeline α) (key : String) (members : Array String) :=
  pipeline.hAppend <| fromCommand <| Command.zMScore key members

def zRank (pipeline : Pipeline α) (key member : String) :=
  pipeline.hAppend <| fromCommand <| Command.zRank key member

def zRevRank (pipeline : Pipeline α) (key member : String) :=
  pipeline.hAppend <| fromCommand <| Command.zRevRank key member

def zRange (pipeline : Pipeline α) (key : String) (start stop : Int) :=
  pipeline.hAppend <| fromCommand <| Command.zRange key start stop

def zRangeWithScores (pipeline : Pipeline α) (key : String) (start stop : Int) :=
  pipeline.hAppend <| fromCommand <| Command.zRangeWithScores key start stop

def zRevRange (pipeline : Pipeline α) (key : String) (start stop : Int) :=
  pipeline.hAppend <| fromCommand <| Command.zRevRange key start stop

def zRevRangeWithScores (pipeline : Pipeline α) (key : String) (start stop : Int) :=
  pipeline.hAppend <| fromCommand <| Command.zRevRangeWithScores key start stop

def zRangeByScore (pipeline : Pipeline α) (key min max : String) :=
  pipeline.hAppend <| fromCommand <| Command.zRangeByScore key min max

def zRangeByScoreWithScores (pipeline : Pipeline α) (key min max : String) :=
  pipeline.hAppend <| fromCommand <| Command.zRangeByScoreWithScores key min max

def zRevRangeByScore (pipeline : Pipeline α) (key max min : String) :=
  pipeline.hAppend <| fromCommand <| Command.zRevRangeByScore key max min

def zRevRangeByScoreWithScores (pipeline : Pipeline α) (key max min : String) :=
  pipeline.hAppend <| fromCommand <| Command.zRevRangeByScoreWithScores key max min

def zRangeByLex (pipeline : Pipeline α) (key min max : String) :=
  pipeline.hAppend <| fromCommand <| Command.zRangeByLex key min max

def zRevRangeByLex (pipeline : Pipeline α) (key max min : String) :=
  pipeline.hAppend <| fromCommand <| Command.zRevRangeByLex key max min

def zCount (pipeline : Pipeline α) (key min max : String) :=
  pipeline.hAppend <| fromCommand <| Command.zCount key min max

def zLexCount (pipeline : Pipeline α) (key min max : String) :=
  pipeline.hAppend <| fromCommand <| Command.zLexCount key min max

def zRemRangeByRank (pipeline : Pipeline α) (key : String) (start stop : Int) :=
  pipeline.hAppend <| fromCommand <| Command.zRemRangeByRank key start stop

def zRemRangeByScore (pipeline : Pipeline α) (key min max : String) :=
  pipeline.hAppend <| fromCommand <| Command.zRemRangeByScore key min max

def zRemRangeByLex (pipeline : Pipeline α) (key min max : String) :=
  pipeline.hAppend <| fromCommand <| Command.zRemRangeByLex key min max

def zIncrBy (pipeline : Pipeline α) (key increment member : String) :=
  pipeline.hAppend <| fromCommand <| Command.zIncrBy key increment member

def zRandMember (pipeline : Pipeline α) (key : String) :=
  pipeline.hAppend <| fromCommand <| Command.zRandMember key

def zRandMembers (pipeline : Pipeline α) (key : String) (count : Int) :=
  pipeline.hAppend <| fromCommand <| Command.zRandMembers key count

def zRandMembersWithScores (pipeline : Pipeline α) (key : String) (count : Int) :=
  pipeline.hAppend <| fromCommand <| Command.zRandMembersWithScores key count

def zDiff (pipeline : Pipeline α) (keys : Array String) :=
  pipeline.hAppend <| fromCommand <| Command.zDiff keys

def zDiffStore (pipeline : Pipeline α) (destination : String) (keys : Array String) :=
  pipeline.hAppend <| fromCommand <| Command.zDiffStore destination keys

def zInter (pipeline : Pipeline α) (keys : Array String) :=
  pipeline.hAppend <| fromCommand <| Command.zInter keys

def zInterCard (pipeline : Pipeline α) (keys : Array String) :=
  pipeline.hAppend <| fromCommand <| Command.zInterCard keys

def zInterStore (pipeline : Pipeline α) (destination : String) (keys : Array String) :=
  pipeline.hAppend <| fromCommand <| Command.zInterStore destination keys

def zUnion (pipeline : Pipeline α) (keys : Array String) :=
  pipeline.hAppend <| fromCommand <| Command.zUnion keys

def zUnionStore (pipeline : Pipeline α) (destination : String) (keys : Array String) :=
  pipeline.hAppend <| fromCommand <| Command.zUnionStore destination keys

def zScan (pipeline : Pipeline α) (key : String) (cursor : UInt64) (options : ZScanOptions := {}) :=
  pipeline.hAppend <| fromCommand <| Command.zScan key cursor options

end LeanRedis.Pipeline
