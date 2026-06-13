import LeanRedis.Command.Base
import LeanRedis.Tools.ExpectResult

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

/--
LPUSH key element [element ...]
-/
def CommandRequest.lPush (key : String) (values : Array String) : CommandRequest :=
  {
    name := "LPUSH"
    args := CommandRequest.utf8Args #[key] ++ CommandRequest.utf8Args values
  }

/--
RPUSH key element [element ...]
-/
def CommandRequest.rPush (key : String) (values : Array String) : CommandRequest :=
  {
    name := "RPUSH"
    args := CommandRequest.utf8Args #[key] ++ CommandRequest.utf8Args values
  }

/--
LPUSHX key element
-/
def CommandRequest.lPushX (key : String) (value : String) : CommandRequest :=
  {
    name := "LPUSHX"
    args := CommandRequest.utf8Args #[key, value]
  }

/--
RPUSHX key element
-/
def CommandRequest.rPushX (key : String) (value : String) : CommandRequest :=
  {
    name := "RPUSHX"
    args := CommandRequest.utf8Args #[key, value]
  }

/--
LPOP key [count]
-/
def CommandRequest.lPop (key : String) : CommandRequest :=
  {
    name := "LPOP"
    args := CommandRequest.utf8Args #[key]
  }

/--
RPOP key [count]
-/
def CommandRequest.rPop (key : String) : CommandRequest :=
  {
    name := "RPOP"
    args := CommandRequest.utf8Args #[key]
  }

/--
LLEN key
-/
def CommandRequest.lLen (key : String) : CommandRequest :=
  {
    name := "LLEN"
    args := CommandRequest.utf8Args #[key]
  }

/--
LINDEX key index
-/
def CommandRequest.lIndex (key : String) (index : Int) : CommandRequest :=
  {
    name := "LINDEX"
    args := CommandRequest.utf8Args #[key, toString index]
  }

/--
LRANGE key start stop
-/
def CommandRequest.lRange (key : String) (start stop : Int) : CommandRequest :=
  {
    name := "LRANGE"
    args := CommandRequest.utf8Args #[key, toString start, toString stop]
  }

/--
LSET key index value
-/
def CommandRequest.lSet (key : String) (index : Int) (value : String) : CommandRequest :=
  {
    name := "LSET"
    args := CommandRequest.utf8Args #[key, toString index, value]
  }

/--
LTRIM key start stop
-/
def CommandRequest.lTrim (key : String) (start stop : Int) : CommandRequest :=
  {
    name := "LTRIM"
    args := CommandRequest.utf8Args #[key, toString start, toString stop]
  }

/--
LREM key count value
-/
def CommandRequest.lRem (key : String) (count : Int) (value : String) : CommandRequest :=
  {
    name := "LREM"
    args := CommandRequest.utf8Args #[key, toString count, value]
  }

/--
LINSERT key BEFORE|AFTER pivot value
-/
def CommandRequest.lInsert (key : String) (position : LInsertPosition) (pivot value : String) : CommandRequest :=
  {
    name := "LINSERT"
    args := CommandRequest.utf8Args #[key, CommandRequest.lInsertPositionArg position, pivot, value]
  }

/--
LMOVE source destination LEFT|RIGHT LEFT|RIGHT
-/
def CommandRequest.lMove
    (source destination : String)
    (fromWhere toWhere : LMoveWhere)
    : CommandRequest :=
  {
    name := "LMOVE"
    args := CommandRequest.utf8Args #[source, destination, CommandRequest.lMoveWhereArg fromWhere, CommandRequest.lMoveWhereArg toWhere]
  }

/--
LPOS key element [RANK rank] [COUNT count] [MAXLEN maxlen]
-/
def CommandRequest.lPos (key element : String) (options : LPosOptions := {}) : CommandRequest :=
  {
    name := "LPOS"
    args := CommandRequest.utf8Args #[key, element] ++ CommandRequest.lPosArgs options
  }

def Command.lPush (key : String) (values : Array String) : Command Int :=
  ⟨ CommandRequest.lPush key values, expectInteger "LPUSH" ⟩

def Command.rPush (key : String) (values : Array String) : Command Int :=
  ⟨ CommandRequest.rPush key values, expectInteger "RPUSH" ⟩

def Command.lPushX (key value : String) : Command Int :=
  ⟨ CommandRequest.lPushX key value, expectInteger "LPUSHX" ⟩

def Command.rPushX (key value : String) : Command Int :=
  ⟨ CommandRequest.rPushX key value, expectInteger "RPUSHX" ⟩

def Command.lPop (key : String) : Command (Option String) :=
  ⟨ CommandRequest.lPop key, expectOptionalString "LPOP" ⟩

def Command.rPop (key : String) : Command (Option String) :=
  ⟨ CommandRequest.rPop key, expectOptionalString "RPOP" ⟩

def Command.lLen (key : String) : Command Int :=
  ⟨ CommandRequest.lLen key, expectInteger "LLEN" ⟩

def Command.lIndex (key : String) (index : Int) : Command (Option String) :=
  ⟨ CommandRequest.lIndex key index, expectOptionalString "LINDEX" ⟩

def Command.lRange (key : String) (start stop : Int) : Command (Array String) :=
  ⟨ CommandRequest.lRange key start stop, expectPlainStringArray "LRANGE" ⟩

def Command.lSet (key : String) (index : Int) (value : String) : Command Unit :=
  ⟨ CommandRequest.lSet key index value, expectOk ⟩

def Command.lTrim (key : String) (start stop : Int) : Command Unit :=
  ⟨ CommandRequest.lTrim key start stop, expectOk ⟩

def Command.lRem (key : String) (count : Int) (value : String) : Command Int :=
  ⟨ CommandRequest.lRem key count value, expectInteger "LREM" ⟩

def Command.lInsert (key : String) (position : LInsertPosition) (pivot value : String) : Command Int :=
  ⟨ CommandRequest.lInsert key position pivot value, expectInteger "LINSERT" ⟩

def Command.lMove (source destination : String) (fromWhere toWhere : LMoveWhere) : Command (Option String) :=
  ⟨ CommandRequest.lMove source destination fromWhere toWhere, expectOptionalString "LMOVE" ⟩

def Command.lPos (key element : String) (options : LPosOptions := {}) : Command (Option Int) :=
  {
    request := CommandRequest.lPos key element options
    decode := fun
      | .null => .ok none
      | .number value => .ok (some value)
      | .simpleError message => .error (.server message)
      | _ => .error (.decode "unexpected LPOS reply")
  }

def Command.lPosMany (key element : String) (options : LPosOptions) : Command (Array Int) :=
  ⟨ CommandRequest.lPos key element options, expectIntegerArray "LPOS" ⟩

end LeanRedis
