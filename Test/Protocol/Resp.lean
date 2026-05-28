import LeanRedis

open LeanRedis

namespace LeanRedisTest.Protocol.Resp

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

instance : Repr ByteArray where
  reprPrec value _ := Std.Format.text (renderBytes value)

instance {α : Type} [Repr α] : Repr (Except String α) where
  reprPrec value _ :=
    match value with
    | .ok result => Std.Format.text s!"Except.ok {repr result}"
    | .error message => Std.Format.text s!"Except.error {repr message}"

def parseOne? (input : ByteArray) : Except String (LeanRedis.Protocol.Resp.Value × ByteArray) :=
  let state := LeanRedis.Protocol.Resp.Parse.feed {} input
  match LeanRedis.Protocol.Resp.Parse.parseOne state with
  | .done (value, nextState) _ => .ok (value, nextState.pending)
  | .needMore => .error "needMore"
  | .error message => .error message

def parseAvailable? (input : ByteArray) : Except String (Array LeanRedis.Protocol.Resp.Value × ByteArray) :=
  let state := LeanRedis.Protocol.Resp.Parse.feed {} input
  match LeanRedis.Protocol.Resp.Parse.parseAvailable state with
  | .ok (values, nextState) => .ok (values, nextState.pending)
  | .error err => .error err.message

def testParseSimpleString : Except String (LeanRedis.Protocol.Resp.Value × ByteArray) :=
  parseOne? "+PONG\r\n".toUTF8

def testParseBlobString : Except String (LeanRedis.Protocol.Resp.Value × ByteArray) :=
  parseOne? "$5\r\nhello\r\n".toUTF8

def testParseArray : Except String (LeanRedis.Protocol.Resp.Value × ByteArray) :=
  parseOne? "*2\r\n$3\r\nGET\r\n$3\r\nkey\r\n".toUTF8

def testHelloOutcomeFromMap : Option LeanRedis.Protocol.HelloOutcome :=
  LeanRedis.Protocol.decideHelloOutcome
    (match parseOne? "%2\r\n+server\r\n+redis\r\n+proto\r\n:3\r\n".toUTF8 with
    | .ok (value, _) => value
    | .error _ => .simpleError "parse failed")

def testIncrementalParseNeedsMore : Except String (LeanRedis.Protocol.Resp.Value × ByteArray) :=
  let state0 : LeanRedis.Protocol.Resp.Parse.ParserState := {}
  let state1 := LeanRedis.Protocol.Resp.Parse.feed state0 "$5\r\nhe".toUTF8
  match LeanRedis.Protocol.Resp.Parse.parseOne state1 with
  | .done (value, nextState) _ => Except.ok (value, nextState.pending)
  | .needMore => Except.error "needMore"
  | .error message => Except.error message

def testIncrementalParseCompletesAcrossChunks : Except String (LeanRedis.Protocol.Resp.Value × ByteArray) :=
  let state0 : LeanRedis.Protocol.Resp.Parse.ParserState := {}
  let state1 := LeanRedis.Protocol.Resp.Parse.feed state0 "$5\r\nhe".toUTF8
  let state2 := LeanRedis.Protocol.Resp.Parse.feed state1 "llo\r\n".toUTF8
  match LeanRedis.Protocol.Resp.Parse.parseOne state2 with
  | .done (value, nextState) _ => Except.ok (value, nextState.pending)
  | .needMore => Except.error "needMore"
  | .error message => Except.error message

def testParseAvailableValues : Except String (Array LeanRedis.Protocol.Resp.Value × ByteArray) :=
  parseAvailable? "+OK\r\n:42\r\n".toUTF8

def testEncodePingCommand : String :=
  renderBytes <| LeanRedis.Protocol.Resp.Encode.encodeCommand {
    name := "PING"
    args := #["hello".toUTF8]
    allowRetry := true
  }

def testEncodeSimpleString : String :=
  renderBytes <| LeanRedis.Protocol.Resp.Encode.encodeValue (.simpleString "PONG")

def testEncodeBlobString : String :=
  renderBytes <| LeanRedis.Protocol.Resp.Encode.encodeValue (.blobString "hello".toUTF8)

def testEncodeArray : String :=
  renderBytes <| LeanRedis.Protocol.Resp.Encode.encodeValue (.array #[.simpleString "OK", .number 42])

def testEncodeMap : String :=
  renderBytes <| LeanRedis.Protocol.Resp.Encode.encodeValue (.map #[(.simpleString "proto", .number 3)])

def testEncodeSet : String :=
  renderBytes <| LeanRedis.Protocol.Resp.Encode.encodeValue (.set #[.number 1, .number 2])

def testEncodeVerbatimString : String :=
  renderBytes <| LeanRedis.Protocol.Resp.Encode.encodeValue (.verbatimString "txt" "hello")

def testEncodePushValue : String :=
  renderBytes <| LeanRedis.Protocol.Resp.Encode.encodeValue (.push #[.simpleString "pubsub", .blobString "channel".toUTF8])

def testRoundTripSimpleString : Except String (LeanRedis.Protocol.Resp.Value × ByteArray) :=
  let bytes := LeanRedis.Protocol.Resp.Encode.encodeValue (.simpleString "PONG")
  parseOne? bytes

def testRoundTripArray : Except String (LeanRedis.Protocol.Resp.Value × ByteArray) :=
  let bytes := LeanRedis.Protocol.Resp.Encode.encodeValue (.array #[.simpleString "OK", .number 42])
  parseOne? bytes

def testProtocolFallbackAuto : Option LeanRedis.Protocol.Version :=
  LeanRedis.Protocol.protocolAfterHello .auto (.simpleError "ERR unknown command 'HELLO'")

def testProtocolFallbackResp3Strict : Option LeanRedis.Protocol.Version :=
  LeanRedis.Protocol.protocolAfterHello .resp3 (.simpleError "ERR unknown command 'HELLO'")

def testEncodedBootstrapFrames : Array String :=
  let cfg : LeanRedis.Config := {
    endpoint := { host := "127.0.0.1", port := 6379 }
    auth? := some { username? := some "default", password := "secret" }
    database? := some 2
  }
  LeanRedis.Protocol.encodeBootstrap cfg |>.map renderBytes

/--
info: Except.ok (LeanRedis.Protocol.Resp.Value.simpleString "PONG", "")
-/
#guard_msgs in
#eval testParseSimpleString

/--
info: Except.ok (LeanRedis.Protocol.Resp.Value.blobString [104, 101, 108, 108, 111], "")
-/
#guard_msgs in
#eval testParseBlobString

/--
info: Except.ok (LeanRedis.Protocol.Resp.Value.array ["LeanRedis.Protocol.Resp.Value.blobString [71, 69, 84]", "LeanRedis.Protocol.Resp.Value.blobString [107, 101, 121]"],
 "")
-/
#guard_msgs in
#eval testParseArray

/--
info: some (LeanRedis.Protocol.HelloOutcome.negotiated (LeanRedis.Protocol.Version.resp3))
-/
#guard_msgs in
#eval testHelloOutcomeFromMap

/--
info: Except.error "needMore"
-/
#guard_msgs in
#eval testIncrementalParseNeedsMore

/--
info: Except.ok (LeanRedis.Protocol.Resp.Value.blobString [104, 101, 108, 108, 111], "")
-/
#guard_msgs in
#eval testIncrementalParseCompletesAcrossChunks

/--
info: Except.ok (#[LeanRedis.Protocol.Resp.Value.simpleString "OK", LeanRedis.Protocol.Resp.Value.number 42], "")
-/
#guard_msgs in
#eval testParseAvailableValues

/--
info: "\"*2\\r\\n$4\\r\\nPING\\r\\n$5\\r\\nhello\\r\\n\""
-/
#guard_msgs in
#eval testEncodePingCommand

/--
info: "\"+PONG\\r\\n\""
-/
#guard_msgs in
#eval testEncodeSimpleString

/--
info: "\"$5\\r\\nhello\\r\\n\""
-/
#guard_msgs in
#eval testEncodeBlobString

/--
info: "\"*2\\r\\n+OK\\r\\n:42\\r\\n\""
-/
#guard_msgs in
#eval testEncodeArray

/--
info: "\"%1\\r\\n+proto\\r\\n:3\\r\\n\""
-/
#guard_msgs in
#eval testEncodeMap

/--
info: "\"~2\\r\\n:1\\r\\n:2\\r\\n\""
-/
#guard_msgs in
#eval testEncodeSet

/--
info: "\"=9\\r\\ntxt:hello\\r\\n\""
-/
#guard_msgs in
#eval testEncodeVerbatimString

/--
info: "\">2\\r\\n+pubsub\\r\\n$7\\r\\nchannel\\r\\n\""
-/
#guard_msgs in
#eval testEncodePushValue

/--
info: Except.ok (LeanRedis.Protocol.Resp.Value.simpleString "PONG", "")
-/
#guard_msgs in
#eval testRoundTripSimpleString

/--
info: Except.ok (LeanRedis.Protocol.Resp.Value.array ["LeanRedis.Protocol.Resp.Value.simpleString \"OK\"", "LeanRedis.Protocol.Resp.Value.number 42"],
 "")
-/
#guard_msgs in
#eval testRoundTripArray

/--
info: some (LeanRedis.Protocol.Version.resp2)
-/
#guard_msgs in
#eval testProtocolFallbackAuto

/--
info: none
-/
#guard_msgs in
#eval LeanRedis.Protocol.protocolAfterHello .resp3 (.simpleError "ERR unknown command 'HELLO'")

def renderBootstrapSuccess : String :=
  match LeanRedis.Protocol.bootstrapSucceeded
      {}
      .auto
      (.map #[(.simpleString "proto", .number 3)])
      (some 2) with
  | some state =>
      let protocol := match state.protocol? with
        | some .resp2 => "resp2"
        | some .resp3 => "resp3"
        | none => "none"
      let db := match state.selectedDb? with
        | some value => toString value
        | none => "none"
      s!"ready={state.phase == .ready}; protocol={protocol}; db={db}"
  | none => "none"

/--
info: "ready=true; protocol=resp3; db=2"
-/
#guard_msgs in
#eval renderBootstrapSuccess
/--
info: #["\"*3\\r\\n$4\\r\\nAUTH\\r\\n$7\\r\\ndefault\\r\\n$6\\r\\nsecret\\r\\n\"",
  "\"*2\\r\\n$5\\r\\nHELLO\\r\\n$1\\r\\n3\\r\\n\"", "\"*2\\r\\n$6\\r\\nSELECT\\r\\n$1\\r\\n2\\r\\n\""]
-/
#guard_msgs in
#eval testEncodedBootstrapFrames

end LeanRedisTest.Protocol.Resp
