import LeanRedis
import Test.Utils

open LeanRedis
open LeanRedisTest.Utils

namespace LeanRedisTest.Command.List

private def renderCommand (request : CommandRequest) : String :=
  renderChunks <| Protocol.Resp.Encode.encodeCommand request

def testEncodeLPush : String :=
  renderCommand <| CommandRequest.lPush "jobs" #["a", "b", "c"]

def testEncodeLInsert : String :=
  renderCommand <| CommandRequest.lInsert "jobs" .before "b" "x"

def testEncodeLMove : String :=
  renderCommand <| CommandRequest.lMove "src" "dst" .right .left

def testEncodeLPos : String :=
  renderCommand <| CommandRequest.lPos "jobs" "a" {
    rank? := some 2
    maxLen? := some 10
  }

def testEncodeLPosMany : String :=
  renderCommand <| CommandRequest.lPos "jobs" "a" {
    count? := some 3
  }

/--
info: "\"*5\\r\\n$5\\r\\nLPUSH\\r\\n$4\\r\\njobs\\r\\n$1\\r\\na\\r\\n$1\\r\\nb\\r\\n$1\\r\\nc\\r\\n\""
-/
#guard_msgs in
#eval testEncodeLPush

/--
info: "\"*5\\r\\n$7\\r\\nLINSERT\\r\\n$4\\r\\njobs\\r\\n$6\\r\\nBEFORE\\r\\n$1\\r\\nb\\r\\n$1\\r\\nx\\r\\n\""
-/
#guard_msgs in
#eval testEncodeLInsert

/--
info: "\"*5\\r\\n$5\\r\\nLMOVE\\r\\n$3\\r\\nsrc\\r\\n$3\\r\\ndst\\r\\n$5\\r\\nRIGHT\\r\\n$4\\r\\nLEFT\\r\\n\""
-/
#guard_msgs in
#eval testEncodeLMove

/--
info: "\"*7\\r\\n$4\\r\\nLPOS\\r\\n$4\\r\\njobs\\r\\n$1\\r\\na\\r\\n$4\\r\\nRANK\\r\\n$1\\r\\n2\\r\\n$6\\r\\nMAXLEN\\r\\n$2\\r\\n10\\r\\n\""
-/
#guard_msgs in
#eval testEncodeLPos

/--
info: "\"*5\\r\\n$4\\r\\nLPOS\\r\\n$4\\r\\njobs\\r\\n$1\\r\\na\\r\\n$5\\r\\nCOUNT\\r\\n$1\\r\\n3\\r\\n\""
-/
#guard_msgs in
#eval testEncodeLPosMany

end LeanRedisTest.Command.List
