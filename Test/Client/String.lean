import LeanRedis
import Std.Sync.Mutex

open LeanRedis
open Std.Internal.IO.Async

namespace LeanRedisTest.Client.String

structure FakeTransport where
  replies : IO.Ref (Array ByteArray)
  writes : IO.Ref (Array ByteArray)

private def shiftReplies (ref : IO.Ref (Array ByteArray)) : IO (Option ByteArray) := do
  let replies <- ref.get
  match replies[0]? with
  | some reply =>
      ref.set (replies.extract 1 replies.size)
      pure (some reply)
  | none => pure none

private def writesOf (client : Client FakeTransport) : IO (Array ByteArray) := do
  client.manager.atomically fun ref => do
    let manager <- ref.get
    match manager.runtime? with
    | some runtime => runtime.transport.writes.get
    | none => pure #[]

private def escapeText (text : String) : String :=
  text.toList.foldl (fun acc ch =>
    acc ++
      match ch with
      | '\r' => "\\r"
      | '\n' => "\\n"
      | '\\' => "\\\\"
      | '"' => "\\\""
      | other => String.singleton other) ""

private def renderBytes (bytes : ByteArray) : String :=
  match String.fromUTF8? bytes with
  | some text => "\"" ++ escapeText text ++ "\""
  | none => s!"<bytes:{bytes.size}>"

private def scriptedReplies (host : String) : Array ByteArray :=
  match host with
  | "string-get" =>
      #["%2\r\n+server\r\n+redis\r\n+proto\r\n:3\r\n".toUTF8, "$5\r\nalice\r\n".toUTF8]
  | "string-set-ok" =>
      #["%2\r\n+server\r\n+redis\r\n+proto\r\n:3\r\n".toUTF8, "+OK\r\n".toUTF8]
  | "string-set-nx-miss" =>
      #["%2\r\n+server\r\n+redis\r\n+proto\r\n:3\r\n".toUTF8, "_\r\n".toUTF8]
  | "string-mget" =>
      #["%2\r\n+server\r\n+redis\r\n+proto\r\n:3\r\n".toUTF8, "*3\r\n$5\r\nalice\r\n_\r\n$3\r\nbob\r\n".toUTF8]
  | "string-bool" =>
      #["%2\r\n+server\r\n+redis\r\n+proto\r\n:3\r\n".toUTF8, ":1\r\n".toUTF8]
  | "string-getdel-null" =>
      #["%2\r\n+server\r\n+redis\r\n+proto\r\n:3\r\n".toUTF8, "_\r\n".toUTF8]
  | "string-getrange" =>
      #["%2\r\n+server\r\n+redis\r\n+proto\r\n:3\r\n".toUTF8, "$3\r\nali\r\n".toUTF8]
  | "string-int" =>
      #["%2\r\n+server\r\n+redis\r\n+proto\r\n:3\r\n".toUTF8, ":7\r\n".toUTF8]
  | "string-float" =>
      #["%2\r\n+server\r\n+redis\r\n+proto\r\n:3\r\n".toUTF8, "$3\r\n1.5\r\n".toUTF8]
  | "string-setex" =>
      #["%2\r\n+server\r\n+redis\r\n+proto\r\n:3\r\n".toUTF8, "+OK\r\n".toUTF8]
  | _ =>
      #["%2\r\n+server\r\n+redis\r\n+proto\r\n:3\r\n".toUTF8, "+OK\r\n".toUTF8]

instance : Transport.Transport FakeTransport where
  connect endpoint := do
    let replies <- IO.mkRef <| scriptedReplies endpoint.host
    let writes <- IO.mkRef #[]
    pure { replies, writes }

  recv transport _ := do
    match ← EAsync.lift <| shiftReplies transport.replies with
    | some bytes => pure { bytes }
    | none => pure { bytes := ByteArray.empty, disconnect? := some .closedByPeer }

  send transport bytes := do
    EAsync.lift <| transport.writes.modify fun writes => writes.push bytes

  close _ := pure ()

def testGet : Async (Option String) := do
  let client : Client FakeTransport <- Client.connectNowWith {
    endpoint := { host := "string-get", port := 6379 }
  }
  Client.get client "name"

def testSetReturnsStored : Async Bool := do
  let client : Client FakeTransport <- Client.connectNowWith {
    endpoint := { host := "string-set-ok", port := 6379 }
  }
  Client.set client "name" "alice"

def testSetNxStyleMissReturnsFalse : Async Bool := do
  let client : Client FakeTransport <- Client.connectNowWith {
    endpoint := { host := "string-set-nx-miss", port := 6379 }
  }
  Client.set client "name" "alice" { condition? := some .nx }

def testMGet : Async (Array (Option String)) := do
  let client : Client FakeTransport <- Client.connectNowWith {
    endpoint := { host := "string-mget", port := 6379 }
  }
  Client.mGet client #["a", "b", "c"]

def testMSetNx : Async Bool := do
  let client : Client FakeTransport <- Client.connectNowWith {
    endpoint := { host := "string-bool", port := 6379 }
  }
  Client.mSetNx client #[("a", "1")]

def testGetDelNull : Async (Option String) := do
  let client : Client FakeTransport <- Client.connectNowWith {
    endpoint := { host := "string-getdel-null", port := 6379 }
  }
  Client.getDel client "name"

def testGetRange : Async String := do
  let client : Client FakeTransport <- Client.connectNowWith {
    endpoint := { host := "string-getrange", port := 6379 }
  }
  Client.getRange client "name" 0 2

def testAppend : Async Int := do
  let client : Client FakeTransport <- Client.connectNowWith {
    endpoint := { host := "string-int", port := 6379 }
  }
  Client.append client "name" "ice"

def testIncrByFloat : Async String := do
  let client : Client FakeTransport <- Client.connectNowWith {
    endpoint := { host := "string-float", port := 6379 }
  }
  Client.incrByFloat client "counter" "1.5"

def testSetExWritesTwoFrames : Async String := do
  let client : Client FakeTransport <- Client.connectNowWith {
    endpoint := { host := "string-setex", port := 6379 }
  }
  let _ <- Client.setEx client "name" 10 "alice"
  let writes <- EAsync.lift <| writesOf client
  pure <| renderBytes <| writes[1]?.getD ByteArray.empty

/--
info: some "alice"
-/
#guard_msgs in
#eval testGet |>.block

/--
info: true
-/
#guard_msgs in
#eval testSetReturnsStored |>.block

/--
info: false
-/
#guard_msgs in
#eval testSetNxStyleMissReturnsFalse |>.block

/--
info: #[some "alice", none, some "bob"]
-/
#guard_msgs in
#eval testMGet |>.block

/--
info: true
-/
#guard_msgs in
#eval testMSetNx |>.block

/--
info: none
-/
#guard_msgs in
#eval testGetDelNull |>.block

/--
info: "ali"
-/
#guard_msgs in
#eval testGetRange |>.block

/--
info: 7
-/
#guard_msgs in
#eval testAppend |>.block

/--
info: "1.5"
-/
#guard_msgs in
#eval testIncrByFloat |>.block

/--
info: "\"*4\\r\\n$5\\r\\nSETEX\\r\\n$4\\r\\nname\\r\\n$2\\r\\n10\\r\\n$5\\r\\nalice\\r\\n\""
-/
#guard_msgs in
#eval testSetExWritesTwoFrames |>.block

end LeanRedisTest.Client.String
