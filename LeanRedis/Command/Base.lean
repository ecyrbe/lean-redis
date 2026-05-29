import LeanRedis.Config

namespace LeanRedis

structure CommandRequest where
  name : String
  args : Array ByteArray := #[]
  deriving BEq, Inhabited

namespace CommandRequest

def utf8Args (args : Array String) : Array ByteArray :=
  args.map String.toUTF8

end CommandRequest

end LeanRedis
