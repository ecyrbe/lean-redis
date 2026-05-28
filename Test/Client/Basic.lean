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

instance : Transport.Transport FakeTransport where
  connect endpoint := do
    let replies <- IO.mkRef <|
      if endpoint.host == "client-select" then
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

/--
info: "1|3"
-/
#guard_msgs in
#eval do
  let client <- Std.Internal.IO.Async.Async.block <| (Client.connectNowWith {
    endpoint := { host := "client-select", port := 6379 }
  } : Std.Internal.IO.Async.Async (Client FakeTransport))
  let _ <- Std.Internal.IO.Async.Async.block <| Client.select client 3
  let state <- Std.Internal.IO.Async.Async.block <| Client.currentState client
  pure s!"{state.protocol?.isSome.toNat}|{state.selectedDb?.getD 0}"

/--
info: 2
-/
#guard_msgs in
#eval do
  let client <- Std.Internal.IO.Async.Async.block <| (Client.connectNowWith {
    endpoint := { host := "client-ping", port := 6379 }
  } : Std.Internal.IO.Async.Async (Client FakeTransport))
  let _ <- Std.Internal.IO.Async.Async.block <| Client.ping client
  let writes <- writesOf client
  pure writes.size

end LeanRedisTest.Client.Basic
