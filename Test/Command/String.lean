import LeanRedis

open LeanRedis

namespace LeanRedisTest.Command.String

def escapeText (text : String) : String :=
  text.toList.foldl (fun acc ch =>
    acc ++
      match ch with
      | '\r' => "\\r"
      | '\n' => "\\n"
      | '\\' => "\\\\"
      | '"' => "\\\""
      | other => String.singleton other) ""

def renderBytes (bytes : ByteArray) : String :=
  match String.fromUTF8? bytes with
  | some text => "\"" ++ escapeText text ++ "\""
  | none => s!"<bytes:{bytes.size}>"

private def renderCommand (request : CommandRequest) : String :=
  renderBytes <| Protocol.Resp.Encode.encodeCommand request

def testEncodeSetWithExpiryAndCondition : String :=
  renderCommand <| CommandRequest.set "name" "alice" {
    expiry? := some <| .relative (.ex 60)
    condition? := some .nx
  }

def testEncodeSetKeepTtl : String :=
  renderCommand <| CommandRequest.set "name" "alice" {
    expiry? := some .keepTtl
  }

def testEncodeMGet : String :=
  renderCommand <| CommandRequest.mGet #["first", "second"]

def testEncodeMSetNx : String :=
  renderCommand <| CommandRequest.mSetNx #[("first", "1"), ("second", "2")]

def testEncodeGetExPersist : String :=
  renderCommand <| CommandRequest.getEx "name" (some .persist)

def testEncodeGetRange : String :=
  renderCommand <| CommandRequest.getRange "name" 0 2

def testEncodeSetRange : String :=
  renderCommand <| CommandRequest.setRange "name" 3 "XYZ"

def testEncodeIncrByFloat : String :=
  renderCommand <| CommandRequest.incrByFloat "counter" "1.5"

def testEncodeSetEx : String :=
  renderCommand <| CommandRequest.setEx "name" 10 "alice"

def testEncodePSetEx : String :=
  renderCommand <| CommandRequest.pSetEx "name" 1500 "alice"

/--
info: "\"*6\\r\\n$3\\r\\nSET\\r\\n$4\\r\\nname\\r\\n$5\\r\\nalice\\r\\n$2\\r\\nEX\\r\\n$2\\r\\n60\\r\\n$2\\r\\nNX\\r\\n\""
-/
#guard_msgs in
#eval testEncodeSetWithExpiryAndCondition

/--
info: "\"*4\\r\\n$3\\r\\nSET\\r\\n$4\\r\\nname\\r\\n$5\\r\\nalice\\r\\n$7\\r\\nKEEPTTL\\r\\n\""
-/
#guard_msgs in
#eval testEncodeSetKeepTtl

/--
info: "\"*3\\r\\n$4\\r\\nMGET\\r\\n$5\\r\\nfirst\\r\\n$6\\r\\nsecond\\r\\n\""
-/
#guard_msgs in
#eval testEncodeMGet

/--
info: "\"*5\\r\\n$6\\r\\nMSETNX\\r\\n$5\\r\\nfirst\\r\\n$1\\r\\n1\\r\\n$6\\r\\nsecond\\r\\n$1\\r\\n2\\r\\n\""
-/
#guard_msgs in
#eval testEncodeMSetNx

/--
info: "\"*3\\r\\n$5\\r\\nGETEX\\r\\n$4\\r\\nname\\r\\n$7\\r\\nPERSIST\\r\\n\""
-/
#guard_msgs in
#eval testEncodeGetExPersist

/--
info: "\"*4\\r\\n$8\\r\\nGETRANGE\\r\\n$4\\r\\nname\\r\\n$1\\r\\n0\\r\\n$1\\r\\n2\\r\\n\""
-/
#guard_msgs in
#eval testEncodeGetRange

/--
info: "\"*4\\r\\n$8\\r\\nSETRANGE\\r\\n$4\\r\\nname\\r\\n$1\\r\\n3\\r\\n$3\\r\\nXYZ\\r\\n\""
-/
#guard_msgs in
#eval testEncodeSetRange

/--
info: "\"*3\\r\\n$11\\r\\nINCRBYFLOAT\\r\\n$7\\r\\ncounter\\r\\n$3\\r\\n1.5\\r\\n\""
-/
#guard_msgs in
#eval testEncodeIncrByFloat

/--
info: "\"*4\\r\\n$5\\r\\nSETEX\\r\\n$4\\r\\nname\\r\\n$2\\r\\n10\\r\\n$5\\r\\nalice\\r\\n\""
-/
#guard_msgs in
#eval testEncodeSetEx

/--
info: "\"*4\\r\\n$6\\r\\nPSETEX\\r\\n$4\\r\\nname\\r\\n$4\\r\\n1500\\r\\n$5\\r\\nalice\\r\\n\""
-/
#guard_msgs in
#eval testEncodePSetEx

end LeanRedisTest.Command.String
