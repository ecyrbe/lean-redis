import LeanRedis.Command.Base

namespace LeanRedis

structure HScanOptions where
  match? : Option String := none
  count? : Option UInt64 := none
  deriving BEq, Inhabited, Repr

structure HashScanResult where
  cursor : UInt64
  entries : Array (String × String)
  deriving BEq, Inhabited, Repr

namespace CommandRequest

def hScanArgs (options : HScanOptions) : Array ByteArray :=
  (match options.match? with
    | some pattern => utf8Args #["MATCH", pattern]
    | none => #[])
  ++ (match options.count? with
    | some count => utf8Args #["COUNT", toString count]
    | none => #[])

end CommandRequest

/--
HGET key field
-/
def CommandRequest.hGet (key field : String) : CommandRequest :=
  {
    name := "HGET"
    args := CommandRequest.utf8Args #[key, field]
  }

/--
HSET key field value [field value ...]
-/
def CommandRequest.hSet (key : String) (entries : Array (String × String)) : CommandRequest :=
  {
    name := "HSET"
    args := CommandRequest.utf8Args #[key]
      ++ entries.foldl (fun acc (field, value) => acc ++ CommandRequest.utf8Args #[field, value]) #[]
  }

/--
HMGET key field [field ...]
-/
def CommandRequest.hMGet (key : String) (fields : Array String) : CommandRequest :=
  {
    name := "HMGET"
    args := CommandRequest.utf8Args #[key] ++ CommandRequest.utf8Args fields
  }

/--
HMSET key field value [field value ...]
-/
def CommandRequest.hMSet (key : String) (entries : Array (String × String)) : CommandRequest :=
  {
    name := "HMSET"
    args := CommandRequest.utf8Args #[key]
      ++ entries.foldl (fun acc (field, value) => acc ++ CommandRequest.utf8Args #[field, value]) #[]
  }

/--
HGETALL key
-/
def CommandRequest.hGetAll (key : String) : CommandRequest :=
  {
    name := "HGETALL"
    args := CommandRequest.utf8Args #[key]
  }

/--
HDEL key field [field ...]
-/
def CommandRequest.hDel (key : String) (fields : Array String) : CommandRequest :=
  {
    name := "HDEL"
    args := CommandRequest.utf8Args #[key] ++ CommandRequest.utf8Args fields
  }

/--
HEXISTS key field
-/
def CommandRequest.hExists (key field : String) : CommandRequest :=
  {
    name := "HEXISTS"
    args := CommandRequest.utf8Args #[key, field]
  }

/--
HLEN key
-/
def CommandRequest.hLen (key : String) : CommandRequest :=
  {
    name := "HLEN"
    args := CommandRequest.utf8Args #[key]
  }

/--
HKEYS key
-/
def CommandRequest.hKeys (key : String) : CommandRequest :=
  {
    name := "HKEYS"
    args := CommandRequest.utf8Args #[key]
  }

/--
HVALS key
-/
def CommandRequest.hVals (key : String) : CommandRequest :=
  {
    name := "HVALS"
    args := CommandRequest.utf8Args #[key]
  }

/--
HSTRLEN key field
-/
def CommandRequest.hStrLen (key field : String) : CommandRequest :=
  {
    name := "HSTRLEN"
    args := CommandRequest.utf8Args #[key, field]
  }

/--
HINCRBY key field increment
-/
def CommandRequest.hIncrBy (key field : String) (amount : Int) : CommandRequest :=
  {
    name := "HINCRBY"
    args := CommandRequest.utf8Args #[key, field, toString amount]
  }

/--
HINCRBYFLOAT key field increment
-/
def CommandRequest.hIncrByFloat (key field amount : String) : CommandRequest :=
  {
    name := "HINCRBYFLOAT"
    args := CommandRequest.utf8Args #[key, field, amount]
  }

/--
HSETNX key field value
-/
def CommandRequest.hSetNx (key field value : String) : CommandRequest :=
  {
    name := "HSETNX"
    args := CommandRequest.utf8Args #[key, field, value]
  }

/--
HRANDFIELD key [count [WITHVALUES]]
-/
def CommandRequest.hRandField (key : String) : CommandRequest :=
  {
    name := "HRANDFIELD"
    args := CommandRequest.utf8Args #[key]
  }

/--
HRANDFIELD key count
-/
def CommandRequest.hRandFields (key : String) (count : Int) : CommandRequest :=
  {
    name := "HRANDFIELD"
    args := CommandRequest.utf8Args #[key, toString count]
  }

/--
HRANDFIELD key count WITHVALUES
-/
def CommandRequest.hRandFieldsWithValues (key : String) (count : Int) : CommandRequest :=
  {
    name := "HRANDFIELD"
    args := CommandRequest.utf8Args #[key, toString count, "WITHVALUES"]
  }

/--
HSCAN key cursor [MATCH pattern] [COUNT count]
-/
def CommandRequest.hScan (key : String) (cursor : UInt64) (options : HScanOptions := {}) : CommandRequest :=
  {
    name := "HSCAN"
    args := CommandRequest.utf8Args #[key, toString cursor] ++ CommandRequest.hScanArgs options
  }

end LeanRedis
