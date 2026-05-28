import LeanRedis
import Std.Sync.Mutex

open LeanRedis

namespace LeanRedisTest.Client.Basic

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

instance : Transport.Transport FakeTransport where
  connect endpoint := do
    let replies <- IO.mkRef <|
      if endpoint.host == "client-select" then
        #["%2\r\n+server\r\n+redis\r\n+proto\r\n:3\r\n".toUTF8, "+OK\r\n".toUTF8]
      else if endpoint.host == "client-auth" then
        #["%2\r\n+server\r\n+redis\r\n+proto\r\n:3\r\n".toUTF8, "+OK\r\n".toUTF8]
      else if endpoint.host == "client-auth-user" then
        #["%2\r\n+server\r\n+redis\r\n+proto\r\n:3\r\n".toUTF8, "+OK\r\n".toUTF8]
      else if endpoint.host == "client-message" then
        #["%2\r\n+server\r\n+redis\r\n+proto\r\n:3\r\n".toUTF8, "$5\r\nhello\r\n".toUTF8]
      else
        #["%2\r\n+server\r\n+redis\r\n+proto\r\n:3\r\n".toUTF8, "+PONG\r\n".toUTF8]
    let writes <- IO.mkRef #[]
    pure { replies, writes }

  recv transport _ := do
    match ← Std.Internal.IO.Async.EAsync.lift <| shiftReplies transport.replies with
    | some bytes => pure { bytes }
    | none => pure { bytes := ByteArray.empty, disconnect? := some .closedByPeer }

  send transport bytes := do
    Std.Internal.IO.Async.EAsync.lift <| transport.writes.modify fun writes => writes.push bytes

  close _ := pure ()

def testIsConnected  : Async Bool := do
  let client: Client FakeTransport ← Client.connectNowWith {
    endpoint := { host := "client-ping", port := 6379 }
  }
  client.isConnected

/--
info: true
-/
#guard_msgs in
#eval testIsConnected |>.block

def testEmptyPing : Async (Option String) := do
  let client: Client FakeTransport ← Client.connectNowWith {
    endpoint := { host := "client-ping", port := 6379 }
  }
  client.ping

/--
info: none
-/
#guard_msgs in
#eval testEmptyPing |>.block

def testMessagePing : Async (Option String) := do
  let client: Client FakeTransport ← Client.connectNowWith {
    endpoint := { host := "client-message", port := 6379 }
  }
  client.ping (some "hello")

/--
info: some "hello"
-/
#guard_msgs in
#eval testMessagePing |>.block

def testPasswordAuth : Async Nat := do
  let client : Client FakeTransport <- Client.connectNowWith {
    endpoint := { host := "client-auth", port := 6379 }
  }
  client.auth { password := "secret" }
  let writes <- Std.Internal.IO.Async.EAsync.lift <| writesOf client
  pure writes.size

/--
info: 2
-/
#guard_msgs in
#eval testPasswordAuth |>.block

def testUsernameAuth : Async String := do
  let client : Client FakeTransport <- Client.connectNowWith {
    endpoint := { host := "client-auth-user", port := 6379 }
  }
  client.auth { username? := some "default", password := "secret" }
  let writes <- Std.Internal.IO.Async.EAsync.lift <| writesOf client
  pure <| renderBytes <| writes[1]?.getD ByteArray.empty

def testSelectUpdatesClientState : Async String := do
  let client : Client FakeTransport <- Client.connectNowWith {
    endpoint := { host := "client-select", port := 6379 }
  }
  let _ <- Client.select client 3
  let state <- Client.currentState client
  pure s!"{state.protocol?.isSome.toNat}|{state.selectedDb?.getD 0}"

def testPingWritesTwoFrames : Async Nat := do
  let client : Client FakeTransport <- Client.connectNowWith {
    endpoint := { host := "client-ping", port := 6379 }
  }
  let _ <- Client.ping client
  let writes <- Std.Internal.IO.Async.EAsync.lift <| writesOf client
  pure writes.size

/--
info: "\"*3\\r\\n$4\\r\\nAUTH\\r\\n$7\\r\\ndefault\\r\\n$6\\r\\nsecret\\r\\n\""
-/
#guard_msgs in
#eval testUsernameAuth |>.block

/--
info: "1|3"
-/
#guard_msgs in
#eval testSelectUpdatesClientState |>.block

/--
info: 2
-/
#guard_msgs in
#eval testPingWritesTwoFrames |>.block

end LeanRedisTest.Client.Basic
