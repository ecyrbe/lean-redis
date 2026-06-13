import LeanRedis.Pipeline.Basic

namespace LeanRedis.Pipeline

def sAdd (pipeline : Pipeline α) (key : String) (members : Array String) :=
  pipeline.hAppend <| fromCommand <| Command.sAdd key members

def sRem (pipeline : Pipeline α) (key : String) (members : Array String) :=
  pipeline.hAppend <| fromCommand <| Command.sRem key members

def sCard (pipeline : Pipeline α) (key : String) :=
  pipeline.hAppend <| fromCommand <| Command.sCard key

def sIsMember (pipeline : Pipeline α) (key member : String) :=
  pipeline.hAppend <| fromCommand <| Command.sIsMember key member

def sMIsMember (pipeline : Pipeline α) (key : String) (members : Array String) :=
  pipeline.hAppend <| fromCommand <| Command.sMIsMember key members

def sMembers (pipeline : Pipeline α) (key : String) :=
  pipeline.hAppend <| fromCommand <| Command.sMembers key

def sPop (pipeline : Pipeline α) (key : String) :=
  pipeline.hAppend <| fromCommand <| Command.sPop key

def sPopMany (pipeline : Pipeline α) (key : String) (count : UInt64) :=
  pipeline.hAppend <| fromCommand <| Command.sPopMany key count

def sRandMember (pipeline : Pipeline α) (key : String) :=
  pipeline.hAppend <| fromCommand <| Command.sRandMember key

def sRandMembers (pipeline : Pipeline α) (key : String) (count : Int) :=
  pipeline.hAppend <| fromCommand <| Command.sRandMembers key count

def sMove (pipeline : Pipeline α) (source destination member : String) :=
  pipeline.hAppend <| fromCommand <| Command.sMove source destination member

def sDiff (pipeline : Pipeline α) (keys : Array String) :=
  pipeline.hAppend <| fromCommand <| Command.sDiff keys

def sDiffStore (pipeline : Pipeline α) (destination : String) (keys : Array String) :=
  pipeline.hAppend <| fromCommand <| Command.sDiffStore destination keys

def sInter (pipeline : Pipeline α) (keys : Array String) :=
  pipeline.hAppend <| fromCommand <| Command.sInter keys

def sInterCard (pipeline : Pipeline α) (keys : Array String) :=
  pipeline.hAppend <| fromCommand <| Command.sInterCard keys

def sInterStore (pipeline : Pipeline α) (destination : String) (keys : Array String) :=
  pipeline.hAppend <| fromCommand <| Command.sInterStore destination keys

def sUnion (pipeline : Pipeline α) (keys : Array String) :=
  pipeline.hAppend <| fromCommand <| Command.sUnion keys

def sUnionStore (pipeline : Pipeline α) (destination : String) (keys : Array String) :=
  pipeline.hAppend <| fromCommand <| Command.sUnionStore destination keys

def sScan (pipeline : Pipeline α) (key : String) (cursor : UInt64) (options : SScanOptions := {}) :=
  pipeline.hAppend <| fromCommand <| Command.sScan key cursor options

end LeanRedis.Pipeline
