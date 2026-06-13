import LeanRedis.Pipeline.Basic

namespace LeanRedis.Pipeline

def copy (pipeline : Pipeline α) (source destination : String) (options : CopyOptions := {}) :=
  pipeline.hAppend <| fromCommand <| Command.copy source destination options

def del (pipeline : Pipeline α) (keys : Array String) :=
  pipeline.hAppend <| fromCommand <| Command.del keys

def dump (pipeline : Pipeline α) (key : String) :=
  pipeline.hAppend <| fromCommand <| Command.dump key

def «exists» (pipeline : Pipeline α) (keys : Array String) :=
  pipeline.hAppend <| fromCommand <| Command.exists keys

def expire (pipeline : Pipeline α) (key : String) (seconds : UInt64) (option : Option ExpireOption := none) :=
  pipeline.hAppend <| fromCommand <| Command.expire key seconds option

def expireAt (pipeline : Pipeline α) (key : String) (timestamp : Std.Time.Timestamp) (option : Option ExpireOption := none) :=
  pipeline.hAppend <| fromCommand <| Command.expireAt key timestamp option

def expireTime (pipeline : Pipeline α) (key : String) :=
  pipeline.hAppend <| fromCommand <| Command.expireTime key

def keys (pipeline : Pipeline α) (pattern : String) :=
  pipeline.hAppend <| fromCommand <| Command.keys pattern

def move (pipeline : Pipeline α) (key : String) (destinationDb : UInt32) :=
  pipeline.hAppend <| fromCommand <| Command.move key destinationDb

def objectEncoding (pipeline : Pipeline α) (key : String) :=
  pipeline.hAppend <| fromCommand <| Command.objectEncoding key

def objectFreq (pipeline : Pipeline α) (key : String) :=
  pipeline.hAppend <| fromCommand <| Command.objectFreq key

def objectIdleTime (pipeline : Pipeline α) (key : String) :=
  pipeline.hAppend <| fromCommand <| Command.objectIdleTime key

def objectRefCount (pipeline : Pipeline α) (key : String) :=
  pipeline.hAppend <| fromCommand <| Command.objectRefCount key

def persist (pipeline : Pipeline α) (key : String) :=
  pipeline.hAppend <| fromCommand <| Command.persist key

def pexpire (pipeline : Pipeline α) (key : String) (milliseconds : UInt64) (option : Option ExpireOption := none) :=
  pipeline.hAppend <| fromCommand <| Command.pexpire key milliseconds option

def pexpireAt (pipeline : Pipeline α) (key : String) (timestamp : Std.Time.Timestamp) (option : Option ExpireOption := none) :=
  pipeline.hAppend <| fromCommand <| Command.pexpireAt key timestamp option

def pttl (pipeline : Pipeline α) (key : String) :=
  pipeline.hAppend <| fromCommand <| Command.pttl key

def randomKey (pipeline : Pipeline α) :=
  pipeline.hAppend <| fromCommand <| Command.randomKey

def rename (pipeline : Pipeline α) (key newKey : String) :=
  pipeline.hAppend <| fromCommand <| Command.rename key newKey

def renameNx (pipeline : Pipeline α) (key newKey : String) :=
  pipeline.hAppend <| fromCommand <| Command.renameNx key newKey

def restore (pipeline : Pipeline α) (key : String) (ttl : UInt64) (serializedValue : String) (options : RestoreOptions := {}) :=
  pipeline.hAppend <| fromCommand <| Command.restore key ttl serializedValue options

def scan (pipeline : Pipeline α) (cursor : UInt64) (options : ScanOptions := {}) :=
  pipeline.hAppend <| fromCommand <| Command.scan cursor options

def sort (pipeline : Pipeline α) (key : String) (options : SortOptions := {}) :=
  pipeline.hAppend <| fromCommand <| Command.sort key options

def sortRo (pipeline : Pipeline α) (key : String) (options : SortRoOptions := {}) :=
  pipeline.hAppend <| fromCommand <| Command.sortRo key options

def touch (pipeline : Pipeline α) (keys : Array String) :=
  pipeline.hAppend <| fromCommand <| Command.touch keys

def ttl (pipeline : Pipeline α) (key : String) :=
  pipeline.hAppend <| fromCommand <| Command.TTL key

def type (pipeline : Pipeline α) (key : String) :=
  pipeline.hAppend <| fromCommand <| Command.type key

def unlink (pipeline : Pipeline α) (keys : Array String) :=
  pipeline.hAppend <| fromCommand <| Command.unlink keys

end LeanRedis.Pipeline
