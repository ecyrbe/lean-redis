import LeanRedis
import Test.Utils

open LeanRedis
open LeanRedisTest.Utils

namespace LeanRedisTest.Command.SortedSet

private def renderCommand (request : CommandRequest) : String :=
  renderChunks <| Protocol.Resp.Encode.encodeCommand request

def testEncodeZAdd : String :=
  renderCommand <| CommandRequest.zAdd "scores" #[{ score := "10", member := "alice" }, { score := "20", member := "bob" }]

def testEncodeZRangeWithScores : String :=
  renderCommand <| CommandRequest.zRangeWithScores "scores" 0 (-1)

def testEncodeZDiffStore : String :=
  renderCommand <| CommandRequest.zDiffStore "dst" #["a", "b"]

def testEncodeZInterCard : String :=
  renderCommand <| CommandRequest.zInterCard #["a", "b", "c"]

def testEncodeZScan : String :=
  renderCommand <| CommandRequest.zScan "scores" 7 {
    match? := some "a*"
    count? := some 20
  }

/--
info: "\"*6\\r\\n$4\\r\\nZADD\\r\\n$6\\r\\nscores\\r\\n$2\\r\\n10\\r\\n$5\\r\\nalice\\r\\n$2\\r\\n20\\r\\n$3\\r\\nbob\\r\\n\""
-/
#guard_msgs in
#eval testEncodeZAdd

/--
info: "\"*5\\r\\n$6\\r\\nZRANGE\\r\\n$6\\r\\nscores\\r\\n$1\\r\\n0\\r\\n$2\\r\\n-1\\r\\n$10\\r\\nWITHSCORES\\r\\n\""
-/
#guard_msgs in
#eval testEncodeZRangeWithScores

/--
info: "\"*5\\r\\n$10\\r\\nZDIFFSTORE\\r\\n$3\\r\\ndst\\r\\n$1\\r\\n2\\r\\n$1\\r\\na\\r\\n$1\\r\\nb\\r\\n\""
-/
#guard_msgs in
#eval testEncodeZDiffStore

/--
info: "\"*5\\r\\n$10\\r\\nZINTERCARD\\r\\n$1\\r\\n3\\r\\n$1\\r\\na\\r\\n$1\\r\\nb\\r\\n$1\\r\\nc\\r\\n\""
-/
#guard_msgs in
#eval testEncodeZInterCard

/--
info: "\"*7\\r\\n$5\\r\\nZSCAN\\r\\n$6\\r\\nscores\\r\\n$1\\r\\n7\\r\\n$5\\r\\nMATCH\\r\\n$2\\r\\na*\\r\\n$5\\r\\nCOUNT\\r\\n$2\\r\\n20\\r\\n\""
-/
#guard_msgs in
#eval testEncodeZScan

end LeanRedisTest.Command.SortedSet
