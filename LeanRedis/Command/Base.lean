import LeanRedis.Config
import LeanRedis.Protocol.Resp.Value
import LeanRedis.Error

namespace LeanRedis

open Protocol.Resp

structure CommandRequest where
  name : String
  args : Array ByteArray := #[]
  deriving BEq, Inhabited

namespace CommandRequest

def utf8Args (args : Array String) : Array ByteArray :=
  args.map String.toUTF8

end CommandRequest

structure Command (α: Type) where
  request: CommandRequest
  decode: Value → Except Error α
  deriving Inhabited

structure ScanResult where
  cursor : UInt64
  keys : Array String
  deriving BEq, Inhabited, Repr

structure HashScanResult where
  cursor : UInt64
  entries : Array (String × String)
  deriving BEq, Inhabited, Repr

structure SetScanResult where
  cursor : UInt64
  members : Array String
  deriving BEq, Inhabited, Repr

structure SortedSetEntry where
  score : String
  member : String
  deriving BEq, Inhabited, Repr

structure SortedSetScanResult where
  cursor : UInt64
  entries : Array SortedSetEntry
  deriving BEq, Inhabited, Repr

end LeanRedis
