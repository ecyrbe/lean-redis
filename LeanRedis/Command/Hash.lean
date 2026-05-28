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

def CommandRequest.hGet (key field : String) : CommandRequest :=
  {
    name := "HGET"
    args := CommandRequest.utf8Args #[key, field]
    allowRetry := true
  }

def CommandRequest.hSet (key : String) (entries : Array (String × String)) : CommandRequest :=
  {
    name := "HSET"
    args := CommandRequest.utf8Args #[key]
      ++ entries.foldl (fun acc (field, value) => acc ++ CommandRequest.utf8Args #[field, value]) #[]
    allowRetry := true
  }

def CommandRequest.hMGet (key : String) (fields : Array String) : CommandRequest :=
  {
    name := "HMGET"
    args := CommandRequest.utf8Args #[key] ++ CommandRequest.utf8Args fields
    allowRetry := true
  }

def CommandRequest.hMSet (key : String) (entries : Array (String × String)) : CommandRequest :=
  {
    name := "HMSET"
    args := CommandRequest.utf8Args #[key]
      ++ entries.foldl (fun acc (field, value) => acc ++ CommandRequest.utf8Args #[field, value]) #[]
    allowRetry := true
  }

def CommandRequest.hGetAll (key : String) : CommandRequest :=
  {
    name := "HGETALL"
    args := CommandRequest.utf8Args #[key]
    allowRetry := true
  }

def CommandRequest.hDel (key : String) (fields : Array String) : CommandRequest :=
  {
    name := "HDEL"
    args := CommandRequest.utf8Args #[key] ++ CommandRequest.utf8Args fields
    allowRetry := true
  }

def CommandRequest.hExists (key field : String) : CommandRequest :=
  {
    name := "HEXISTS"
    args := CommandRequest.utf8Args #[key, field]
    allowRetry := true
  }

def CommandRequest.hLen (key : String) : CommandRequest :=
  {
    name := "HLEN"
    args := CommandRequest.utf8Args #[key]
    allowRetry := true
  }

def CommandRequest.hKeys (key : String) : CommandRequest :=
  {
    name := "HKEYS"
    args := CommandRequest.utf8Args #[key]
    allowRetry := true
  }

def CommandRequest.hVals (key : String) : CommandRequest :=
  {
    name := "HVALS"
    args := CommandRequest.utf8Args #[key]
    allowRetry := true
  }

def CommandRequest.hStrLen (key field : String) : CommandRequest :=
  {
    name := "HSTRLEN"
    args := CommandRequest.utf8Args #[key, field]
    allowRetry := true
  }

def CommandRequest.hIncrBy (key field : String) (amount : Int) : CommandRequest :=
  {
    name := "HINCRBY"
    args := CommandRequest.utf8Args #[key, field, toString amount]
    allowRetry := true
  }

def CommandRequest.hIncrByFloat (key field amount : String) : CommandRequest :=
  {
    name := "HINCRBYFLOAT"
    args := CommandRequest.utf8Args #[key, field, amount]
    allowRetry := true
  }

def CommandRequest.hSetNx (key field value : String) : CommandRequest :=
  {
    name := "HSETNX"
    args := CommandRequest.utf8Args #[key, field, value]
    allowRetry := true
  }

def CommandRequest.hRandField (key : String) : CommandRequest :=
  {
    name := "HRANDFIELD"
    args := CommandRequest.utf8Args #[key]
    allowRetry := true
  }

def CommandRequest.hRandFields (key : String) (count : Int) : CommandRequest :=
  {
    name := "HRANDFIELD"
    args := CommandRequest.utf8Args #[key, toString count]
    allowRetry := true
  }

def CommandRequest.hRandFieldsWithValues (key : String) (count : Int) : CommandRequest :=
  {
    name := "HRANDFIELD"
    args := CommandRequest.utf8Args #[key, toString count, "WITHVALUES"]
    allowRetry := true
  }

def CommandRequest.hScan (key : String) (cursor : UInt64) (options : HScanOptions := {}) : CommandRequest :=
  {
    name := "HSCAN"
    args := CommandRequest.utf8Args #[key, toString cursor] ++ CommandRequest.hScanArgs options
    allowRetry := true
  }

end LeanRedis
