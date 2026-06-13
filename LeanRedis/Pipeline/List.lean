import LeanRedis.Pipeline.Basic

namespace LeanRedis.Pipeline

def lPush (pipeline : Pipeline α) (key : String) (values : Array String) :=
  pipeline.hAppend <| fromCommand <| Command.lPush key values

def rPush (pipeline : Pipeline α) (key : String) (values : Array String) :=
  pipeline.hAppend <| fromCommand <| Command.rPush key values

def lPushX (pipeline : Pipeline α) (key value : String) :=
  pipeline.hAppend <| fromCommand <| Command.lPushX key value

def rPushX (pipeline : Pipeline α) (key value : String) :=
  pipeline.hAppend <| fromCommand <| Command.rPushX key value

def lPop (pipeline : Pipeline α) (key : String) :=
  pipeline.hAppend <| fromCommand <| Command.lPop key

def rPop (pipeline : Pipeline α) (key : String) :=
  pipeline.hAppend <| fromCommand <| Command.rPop key

def lLen (pipeline : Pipeline α) (key : String) :=
  pipeline.hAppend <| fromCommand <| Command.lLen key

def lIndex (pipeline : Pipeline α) (key : String) (index : Int) :=
  pipeline.hAppend <| fromCommand <| Command.lIndex key index

def lRange (pipeline : Pipeline α) (key : String) (start stop : Int) :=
  pipeline.hAppend <| fromCommand <| Command.lRange key start stop

def lSet (pipeline : Pipeline α) (key : String) (index : Int) (value : String) :=
  pipeline.hAppend <| fromCommand <| Command.lSet key index value

def lTrim (pipeline : Pipeline α) (key : String) (start stop : Int) :=
  pipeline.hAppend <| fromCommand <| Command.lTrim key start stop

def lRem (pipeline : Pipeline α) (key : String) (count : Int) (value : String) :=
  pipeline.hAppend <| fromCommand <| Command.lRem key count value

def lInsert (pipeline : Pipeline α) (key : String) (position : LInsertPosition) (pivot value : String) :=
  pipeline.hAppend <| fromCommand <| Command.lInsert key position pivot value

def lMove (pipeline : Pipeline α) (source destination : String) (fromWhere toWhere : LMoveWhere) :=
  pipeline.hAppend <| fromCommand <| Command.lMove source destination fromWhere toWhere

def lPos (pipeline : Pipeline α) (key element : String) (options : LPosOptions := {}) :=
  pipeline.hAppend <| fromCommand <| Command.lPos key element options

def lPosMany (pipeline : Pipeline α) (key element : String) (options : LPosOptions) :=
  pipeline.hAppend <| fromCommand <| Command.lPosMany key element options

end LeanRedis.Pipeline
