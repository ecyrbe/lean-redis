import LeanRedis
import Test.Utils

open LeanRedis
open LeanRedisTest.Utils

namespace LeanRedisTest.Command.Hash

private def renderCommand (request : CommandRequest) : String :=
  renderBytes <| Protocol.Resp.Encode.encodeCommand request

def testEncodeHSet : String :=
  renderCommand <| CommandRequest.hSet "user:1" #[("name", "alice"), ("role", "admin")]

def testEncodeHMGet : String :=
  renderCommand <| CommandRequest.hMGet "user:1" #["name", "role"]

def testEncodeHDel : String :=
  renderCommand <| CommandRequest.hDel "user:1" #["name", "role"]

def testEncodeHIncrByFloat : String :=
  renderCommand <| CommandRequest.hIncrByFloat "scores" "pi" "1.5"

def testEncodeHRandFieldWithValues : String :=
  renderCommand <| CommandRequest.hRandFieldsWithValues "user:1" 2

def testEncodeHScan : String :=
  renderCommand <| CommandRequest.hScan "user:1" 7 {
    match? := some "na*"
    count? := some 20
  }

/--
info: "\"*6\\r\\n$4\\r\\nHSET\\r\\n$6\\r\\nuser:1\\r\\n$4\\r\\nname\\r\\n$5\\r\\nalice\\r\\n$4\\r\\nrole\\r\\n$5\\r\\nadmin\\r\\n\""
-/
#guard_msgs in
#eval testEncodeHSet

/--
info: "\"*4\\r\\n$5\\r\\nHMGET\\r\\n$6\\r\\nuser:1\\r\\n$4\\r\\nname\\r\\n$4\\r\\nrole\\r\\n\""
-/
#guard_msgs in
#eval testEncodeHMGet

/--
info: "\"*4\\r\\n$4\\r\\nHDEL\\r\\n$6\\r\\nuser:1\\r\\n$4\\r\\nname\\r\\n$4\\r\\nrole\\r\\n\""
-/
#guard_msgs in
#eval testEncodeHDel

/--
info: "\"*4\\r\\n$12\\r\\nHINCRBYFLOAT\\r\\n$6\\r\\nscores\\r\\n$2\\r\\npi\\r\\n$3\\r\\n1.5\\r\\n\""
-/
#guard_msgs in
#eval testEncodeHIncrByFloat

/--
info: "\"*4\\r\\n$10\\r\\nHRANDFIELD\\r\\n$6\\r\\nuser:1\\r\\n$1\\r\\n2\\r\\n$10\\r\\nWITHVALUES\\r\\n\""
-/
#guard_msgs in
#eval testEncodeHRandFieldWithValues

/--
info: "\"*7\\r\\n$5\\r\\nHSCAN\\r\\n$6\\r\\nuser:1\\r\\n$1\\r\\n7\\r\\n$5\\r\\nMATCH\\r\\n$3\\r\\nna*\\r\\n$5\\r\\nCOUNT\\r\\n$2\\r\\n20\\r\\n\""
-/
#guard_msgs in
#eval testEncodeHScan

end LeanRedisTest.Command.Hash
