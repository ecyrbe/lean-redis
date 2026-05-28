import LeanRedis
import Test.Utils

open LeanRedis
open LeanRedisTest.Utils

namespace LeanRedisTest.Command.Set

private def renderCommand (request : CommandRequest) : String :=
  renderBytes <| Protocol.Resp.Encode.encodeCommand request

def testEncodeSAdd : String :=
  renderCommand <| CommandRequest.sAdd "tags" #["lean", "redis"]

def testEncodeSMIsMember : String :=
  renderCommand <| CommandRequest.sMIsMember "tags" #["lean", "lisp"]

def testEncodeSInterCard : String :=
  renderCommand <| CommandRequest.sInterCard #["a", "b", "c"]

def testEncodeSUnionStore : String :=
  renderCommand <| CommandRequest.sUnionStore "dst" #["a", "b"]

def testEncodeSScan : String :=
  renderCommand <| CommandRequest.sScan "tags" 5 {
    match? := some "le*"
    count? := some 20
  }

/--
info: "\"*4\\r\\n$4\\r\\nSADD\\r\\n$4\\r\\ntags\\r\\n$4\\r\\nlean\\r\\n$5\\r\\nredis\\r\\n\""
-/
#guard_msgs in
#eval testEncodeSAdd

/--
info: "\"*4\\r\\n$10\\r\\nSMISMEMBER\\r\\n$4\\r\\ntags\\r\\n$4\\r\\nlean\\r\\n$4\\r\\nlisp\\r\\n\""
-/
#guard_msgs in
#eval testEncodeSMIsMember

/--
info: "\"*5\\r\\n$10\\r\\nSINTERCARD\\r\\n$1\\r\\n3\\r\\n$1\\r\\na\\r\\n$1\\r\\nb\\r\\n$1\\r\\nc\\r\\n\""
-/
#guard_msgs in
#eval testEncodeSInterCard

/--
info: "\"*4\\r\\n$11\\r\\nSUNIONSTORE\\r\\n$3\\r\\ndst\\r\\n$1\\r\\na\\r\\n$1\\r\\nb\\r\\n\""
-/
#guard_msgs in
#eval testEncodeSUnionStore

/--
info: "\"*7\\r\\n$5\\r\\nSSCAN\\r\\n$4\\r\\ntags\\r\\n$1\\r\\n5\\r\\n$5\\r\\nMATCH\\r\\n$3\\r\\nle*\\r\\n$5\\r\\nCOUNT\\r\\n$2\\r\\n20\\r\\n\""
-/
#guard_msgs in
#eval testEncodeSScan

end LeanRedisTest.Command.Set
