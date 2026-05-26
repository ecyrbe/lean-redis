import LeanRedis

open LeanRedis

namespace LeanRedisTest.Protocol.Resp

instance : Repr ByteArray where
  reprPrec value _ := Std.Format.text s!"{value.toList}"

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

/--
info: Except.ok (LeanRedis.Protocol.Resp.Value.simpleString "PONG", [])
-/
#guard_msgs in
#eval parseOne? "+PONG\r\n".toUTF8

/--
info: Except.ok (LeanRedis.Protocol.Resp.Value.blobString [104, 101, 108, 108, 111], [])
-/
#guard_msgs in
#eval parseOne? "$5\r\nhello\r\n".toUTF8

/--
info: Except.ok (LeanRedis.Protocol.Resp.Value.array ["LeanRedis.Protocol.Resp.Value.blobString [71, 69, 84]", "LeanRedis.Protocol.Resp.Value.blobString [107, 101, 121]"],
 [])
-/
#guard_msgs in
#eval parseOne? "*2\r\n$3\r\nGET\r\n$3\r\nkey\r\n".toUTF8

/--
info: some (LeanRedis.Protocol.HelloOutcome.negotiated (LeanRedis.Protocol.Version.resp3))
-/
#guard_msgs in
#eval LeanRedis.Protocol.decideHelloOutcome
  (match parseOne? "%2\r\n+server\r\n+redis\r\n+proto\r\n:3\r\n".toUTF8 with
  | .ok (value, _) => value
  | .error _ => .simpleError "parse failed")

/--
info: Except.error "needMore"
-/
#guard_msgs in
#eval
  let state0 : LeanRedis.Protocol.Resp.Parse.ParserState := {}
  let state1 := LeanRedis.Protocol.Resp.Parse.feed state0 "$5\r\nhe".toUTF8
  match LeanRedis.Protocol.Resp.Parse.parseOne state1 with
  | .done (value, nextState) _ => Except.ok (value, nextState.pending)
  | .needMore => Except.error "needMore"
  | .error message => Except.error message

/--
info: Except.ok (LeanRedis.Protocol.Resp.Value.blobString [104, 101, 108, 108, 111], [])
-/
#guard_msgs in
#eval
  let state0 : LeanRedis.Protocol.Resp.Parse.ParserState := {}
  let state1 := LeanRedis.Protocol.Resp.Parse.feed state0 "$5\r\nhe".toUTF8
  let state2 := LeanRedis.Protocol.Resp.Parse.feed state1 "llo\r\n".toUTF8
  match LeanRedis.Protocol.Resp.Parse.parseOne state2 with
  | .done (value, nextState) _ => Except.ok (value, nextState.pending)
  | .needMore => Except.error "needMore"
  | .error message => Except.error message

/--
info: Except.ok (#[LeanRedis.Protocol.Resp.Value.simpleString "OK", LeanRedis.Protocol.Resp.Value.number 42], [])
-/
#guard_msgs in
#eval parseAvailable? "+OK\r\n:42\r\n".toUTF8

/--
info: [42, 50, 13, 10, 36, 52, 13, 10, 80, 73, 78, 71, 13, 10, 36, 53, 13, 10, 104, 101, 108, 108, 111, 13, 10]
-/
#guard_msgs in
#eval LeanRedis.Protocol.Resp.Encode.encodeCommand {
  name := "PING"
  args := #["hello".toUTF8]
  allowRetry := true
}

/--
info: [43, 80, 79, 78, 71, 13, 10]
-/
#guard_msgs in
#eval LeanRedis.Protocol.Resp.Encode.encodeValue (.simpleString "PONG")

/--
info: [36, 53, 13, 10, 104, 101, 108, 108, 111, 13, 10]
-/
#guard_msgs in
#eval LeanRedis.Protocol.Resp.Encode.encodeValue (.blobString "hello".toUTF8)

/--
info: [42, 50, 13, 10, 43, 79, 75, 13, 10, 58, 52, 50, 13, 10]
-/
#guard_msgs in
#eval LeanRedis.Protocol.Resp.Encode.encodeValue (.array #[.simpleString "OK", .number 42])

/--
info: [37, 49, 13, 10, 43, 112, 114, 111, 116, 111, 13, 10, 58, 51, 13, 10]
-/
#guard_msgs in
#eval LeanRedis.Protocol.Resp.Encode.encodeValue (.map #[(.simpleString "proto", .number 3)])

/--
info: [126, 50, 13, 10, 58, 49, 13, 10, 58, 50, 13, 10]
-/
#guard_msgs in
#eval LeanRedis.Protocol.Resp.Encode.encodeValue (.set #[.number 1, .number 2])

/--
info: [61, 57, 13, 10, 116, 120, 116, 58, 104, 101, 108, 108, 111, 13, 10]
-/
#guard_msgs in
#eval LeanRedis.Protocol.Resp.Encode.encodeValue (.verbatimString "txt" "hello")

/--
info: [62, 50, 13, 10, 43, 112, 117, 98, 115, 117, 98, 13, 10, 36, 55, 13, 10, 99, 104, 97, 110, 110, 101, 108, 13, 10]
-/
#guard_msgs in
#eval LeanRedis.Protocol.Resp.Encode.encodeValue (.push #[.simpleString "pubsub", .blobString "channel".toUTF8])

/--
info: Except.ok (LeanRedis.Protocol.Resp.Value.simpleString "PONG", [])
-/
#guard_msgs in
#eval
  let bytes := LeanRedis.Protocol.Resp.Encode.encodeValue (.simpleString "PONG")
  parseOne? bytes

/--
info: Except.ok (LeanRedis.Protocol.Resp.Value.array ["LeanRedis.Protocol.Resp.Value.simpleString \"OK\"", "LeanRedis.Protocol.Resp.Value.number 42"],
 [])
-/
#guard_msgs in
#eval
  let bytes := LeanRedis.Protocol.Resp.Encode.encodeValue (.array #[.simpleString "OK", .number 42])
  parseOne? bytes

/--
info: some (LeanRedis.Protocol.Version.resp2)
-/
#guard_msgs in
#eval LeanRedis.Protocol.protocolAfterHello .auto (.simpleError "ERR unknown command 'HELLO'")

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
info: #[[42, 51, 13, 10, 36, 52, 13, 10, 65, 85, 84, 72, 13, 10, 36, 55, 13, 10, 100, 101, 102, 97, 117, 108, 116, 13, 10, 36, 54, 13, 10, 115, 101, 99, 114, 101, 116, 13, 10],
  [42, 50, 13, 10, 36, 53, 13, 10, 72, 69, 76, 76, 79, 13, 10, 36, 49, 13, 10, 51, 13, 10],
  [42, 50, 13, 10, 36, 54, 13, 10, 83, 69, 76, 69, 67, 84, 13, 10, 36, 49, 13, 10, 50, 13, 10]]
-/
#guard_msgs in
#eval
  let cfg : LeanRedis.Config := {
    endpoint := { host := "127.0.0.1", port := 6379 }
    auth? := some { username? := some "default", password := "secret" }
    database? := some 2
  }
  LeanRedis.Protocol.encodeBootstrap cfg

end LeanRedisTest.Protocol.Resp
