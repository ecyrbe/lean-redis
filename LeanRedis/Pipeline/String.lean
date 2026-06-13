import LeanRedis.Pipeline.Basic

namespace LeanRedis.Pipeline

def get (pipeline : Pipeline α) (key : String) :=
  pipeline.hAppend <| fromCommand <| Command.get key

def set (pipeline : Pipeline α) (key value : String) (options : SetOptions := {}) :=
  pipeline.hAppend <| fromCommand <| Command.set key value options

def mGet (pipeline : Pipeline α) (keys : Array String) :=
  pipeline.hAppend <| fromCommand <| Command.mGet keys

def mSet (pipeline : Pipeline α) (entries : Array (String × String)) :=
  pipeline.hAppend <| fromCommand <| Command.mSet entries

def mSetNx (pipeline : Pipeline α) (entries : Array (String × String)) :=
  pipeline.hAppend <| fromCommand <| Command.mSetNx entries

def getDel (pipeline : Pipeline α) (key : String) :=
  pipeline.hAppend <| fromCommand <| Command.getDel key

def getEx (pipeline : Pipeline α) (key : String) (mode? : Option GetExMode := none) :=
  pipeline.hAppend <| fromCommand <| Command.getEx key mode?

def getRange (pipeline : Pipeline α) (key : String) (start stop : Int) :=
  pipeline.hAppend <| fromCommand <| Command.getRange key start stop

def getSet (pipeline : Pipeline α) (key value : String) :=
  pipeline.hAppend <| fromCommand <| Command.getSet key value

def setRange (pipeline : Pipeline α) (key : String) (offset : UInt64) (value : String) :=
  pipeline.hAppend <| fromCommand <| Command.setRange key offset value

def strLen (pipeline : Pipeline α) (key : String) :=
  pipeline.hAppend <| fromCommand <| Command.strLen key

def append (pipeline : Pipeline α) (key value : String) :=
  pipeline.hAppend <| fromCommand <| Command.append key value

def incr (pipeline : Pipeline α) (key : String) :=
  pipeline.hAppend <| fromCommand <| Command.incr key

def incrBy (pipeline : Pipeline α) (key : String) (amount : Int) :=
  pipeline.hAppend <| fromCommand <| Command.incrBy key amount

def incrByFloat (pipeline : Pipeline α) (key amount : String) :=
  pipeline.hAppend <| fromCommand <| Command.incrByFloat key amount

def decr (pipeline : Pipeline α) (key : String) :=
  pipeline.hAppend <| fromCommand <| Command.decr key

def decrBy (pipeline : Pipeline α) (key : String) (amount : Int) :=
  pipeline.hAppend <| fromCommand <| Command.decrBy key amount

def setNx (pipeline : Pipeline α) (key value : String) :=
  pipeline.hAppend <| fromCommand <| Command.setNx key value

def setEx (pipeline : Pipeline α) (key : String) (seconds : UInt64) (value : String) :=
  pipeline.hAppend <| fromCommand <| Command.setEx key seconds value

def pSetEx (pipeline : Pipeline α) (key : String) (milliseconds : UInt64) (value : String) :=
  pipeline.hAppend <| fromCommand <| Command.pSetEx key milliseconds value

end LeanRedis.Pipeline
