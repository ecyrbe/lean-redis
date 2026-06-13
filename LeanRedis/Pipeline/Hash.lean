import LeanRedis.Pipeline.Basic

namespace LeanRedis.Pipeline

def hGet (pipeline : Pipeline α) (key field : String) :=
  pipeline.hAppend <| fromCommand <| Command.hGet key field

def hSet (pipeline : Pipeline α) (key : String) (entries : Array (String × String)) :=
  pipeline.hAppend <| fromCommand <| Command.hSet key entries

def hMGet (pipeline : Pipeline α) (key : String) (fields : Array String) :=
  pipeline.hAppend <| fromCommand <| Command.hMGet key fields

def hMSet (pipeline : Pipeline α) (key : String) (entries : Array (String × String)) :=
  pipeline.hAppend <| fromCommand <| Command.hMSet key entries

def hGetAll (pipeline : Pipeline α) (key : String) :=
  pipeline.hAppend <| fromCommand <| Command.hGetAll key

def hDel (pipeline : Pipeline α) (key : String) (fields : Array String) :=
  pipeline.hAppend <| fromCommand <| Command.hDel key fields

def hExists (pipeline : Pipeline α) (key field : String) :=
  pipeline.hAppend <| fromCommand <| Command.hExists key field

def hLen (pipeline : Pipeline α) (key : String) :=
  pipeline.hAppend <| fromCommand <| Command.hLen key

def hKeys (pipeline : Pipeline α) (key : String) :=
  pipeline.hAppend <| fromCommand <| Command.hKeys key

def hVals (pipeline : Pipeline α) (key : String) :=
  pipeline.hAppend <| fromCommand <| Command.hVals key

def hStrLen (pipeline : Pipeline α) (key field : String) :=
  pipeline.hAppend <| fromCommand <| Command.hStrLen key field

def hIncrBy (pipeline : Pipeline α) (key field : String) (amount : Int) :=
  pipeline.hAppend <| fromCommand <| Command.hIncrBy key field amount

def hIncrByFloat (pipeline : Pipeline α) (key field amount : String) :=
  pipeline.hAppend <| fromCommand <| Command.hIncrByFloat key field amount

def hSetNx (pipeline : Pipeline α) (key field value : String) :=
  pipeline.hAppend <| fromCommand <| Command.hSetNx key field value

def hRandField (pipeline : Pipeline α) (key : String) :=
  pipeline.hAppend <| fromCommand <| Command.hRandField key

def hRandFields (pipeline : Pipeline α) (key : String) (count : Int) :=
  pipeline.hAppend <| fromCommand <| Command.hRandFields key count

def hRandFieldsWithValues (pipeline : Pipeline α) (key : String) (count : Int) :=
  pipeline.hAppend <| fromCommand <| Command.hRandFieldsWithValues key count

def hScan (pipeline : Pipeline α) (key : String) (cursor : UInt64) (options : HScanOptions := {}) :=
  pipeline.hAppend <| fromCommand <| Command.hScan key cursor options

end LeanRedis.Pipeline
