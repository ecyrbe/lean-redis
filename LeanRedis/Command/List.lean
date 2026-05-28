import LeanRedis.Command.Base

namespace LeanRedis

inductive LInsertPosition where
  | before
  | after
  deriving BEq, Inhabited, Repr

inductive LMoveWhere where
  | left
  | right
  deriving BEq, Inhabited, Repr

structure LPosOptions where
  rank? : Option Int := none
  count? : Option UInt64 := none
  maxLen? : Option UInt64 := none
  deriving BEq, Inhabited, Repr

namespace CommandRequest

def lInsertPositionArg (position : LInsertPosition) : String :=
  match position with
  | .before => "BEFORE"
  | .after => "AFTER"

def lMoveWhereArg (where_ : LMoveWhere) : String :=
  match where_ with
  | .left => "LEFT"
  | .right => "RIGHT"

def lPosArgs (options : LPosOptions) : Array ByteArray :=
  (match options.rank? with
    | some rank => utf8Args #["RANK", toString rank]
    | none => #[])
  ++ (match options.count? with
    | some count => utf8Args #["COUNT", toString count]
    | none => #[])
  ++ (match options.maxLen? with
    | some maxLen => utf8Args #["MAXLEN", toString maxLen]
    | none => #[])

end CommandRequest

def CommandRequest.lPush (key : String) (values : Array String) : CommandRequest :=
  {
    name := "LPUSH"
    args := CommandRequest.utf8Args #[key] ++ CommandRequest.utf8Args values
    allowRetry := true
  }

def CommandRequest.rPush (key : String) (values : Array String) : CommandRequest :=
  {
    name := "RPUSH"
    args := CommandRequest.utf8Args #[key] ++ CommandRequest.utf8Args values
    allowRetry := true
  }

def CommandRequest.lPushX (key : String) (value : String) : CommandRequest :=
  {
    name := "LPUSHX"
    args := CommandRequest.utf8Args #[key, value]
    allowRetry := true
  }

def CommandRequest.rPushX (key : String) (value : String) : CommandRequest :=
  {
    name := "RPUSHX"
    args := CommandRequest.utf8Args #[key, value]
    allowRetry := true
  }

def CommandRequest.lPop (key : String) : CommandRequest :=
  {
    name := "LPOP"
    args := CommandRequest.utf8Args #[key]
    allowRetry := true
  }

def CommandRequest.rPop (key : String) : CommandRequest :=
  {
    name := "RPOP"
    args := CommandRequest.utf8Args #[key]
    allowRetry := true
  }

def CommandRequest.lLen (key : String) : CommandRequest :=
  {
    name := "LLEN"
    args := CommandRequest.utf8Args #[key]
    allowRetry := true
  }

def CommandRequest.lIndex (key : String) (index : Int) : CommandRequest :=
  {
    name := "LINDEX"
    args := CommandRequest.utf8Args #[key, toString index]
    allowRetry := true
  }

def CommandRequest.lRange (key : String) (start stop : Int) : CommandRequest :=
  {
    name := "LRANGE"
    args := CommandRequest.utf8Args #[key, toString start, toString stop]
    allowRetry := true
  }

def CommandRequest.lSet (key : String) (index : Int) (value : String) : CommandRequest :=
  {
    name := "LSET"
    args := CommandRequest.utf8Args #[key, toString index, value]
    allowRetry := true
  }

def CommandRequest.lTrim (key : String) (start stop : Int) : CommandRequest :=
  {
    name := "LTRIM"
    args := CommandRequest.utf8Args #[key, toString start, toString stop]
    allowRetry := true
  }

def CommandRequest.lRem (key : String) (count : Int) (value : String) : CommandRequest :=
  {
    name := "LREM"
    args := CommandRequest.utf8Args #[key, toString count, value]
    allowRetry := true
  }

def CommandRequest.lInsert (key : String) (position : LInsertPosition) (pivot value : String) : CommandRequest :=
  {
    name := "LINSERT"
    args := CommandRequest.utf8Args #[key, CommandRequest.lInsertPositionArg position, pivot, value]
    allowRetry := true
  }

def CommandRequest.lMove
    (source destination : String)
    (fromWhere toWhere : LMoveWhere)
    : CommandRequest :=
  {
    name := "LMOVE"
    args := CommandRequest.utf8Args #[source, destination, CommandRequest.lMoveWhereArg fromWhere, CommandRequest.lMoveWhereArg toWhere]
    allowRetry := true
  }

def CommandRequest.lPos (key element : String) (options : LPosOptions := {}) : CommandRequest :=
  {
    name := "LPOS"
    args := CommandRequest.utf8Args #[key, element] ++ CommandRequest.lPosArgs options
    allowRetry := true
  }

end LeanRedis
