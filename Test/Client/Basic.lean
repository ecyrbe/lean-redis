import LeanRedis
import Std.Sync.Mutex
import Test.Utils

open LeanRedis
open LeanRedisTest.Utils
open Std.Async

namespace LeanRedisTest.Client.Basic

open LeanRedis.Connection

structure FakeTransport where
  replies : IO.Ref (Array ByteArray)
  writes : IO.Ref (Array ByteArray)

structure ReconnectingTransport where
  replies : IO.Ref (Array ByteArray)
  writes : IO.Ref (Array ByteArray)

structure FailingReconnectTransport where
  replies : IO.Ref (Array ByteArray)
  writes : IO.Ref (Array ByteArray)

private def shiftReplies (ref : IO.Ref (Array ByteArray)) : IO (Option ByteArray) := do
  let replies ← ref.get
  match replies[0]? with
  | some reply =>
      ref.set (replies.extract 1 replies.size)
      return (some reply)
  | none => return none

private def writesOf (client : Client FakeTransport) : IO (Array ByteArray) := do
  client.state.atomically fun ref => do
    let state ← ref.get
    match state.transport? with
    | some transport => transport.writes.get
    | none => pure #[]

instance : Transport.Transport FakeTransport where
  connect endpoint := do
    let replies ← IO.mkRef <|
      if endpoint.host == "client-select" then
        #["%2\r\n+server\r\n+redis\r\n+proto\r\n:3\r\n".toUTF8, "+OK\r\n".toUTF8]
      else if endpoint.host == "client-auth" then
        #["%2\r\n+server\r\n+redis\r\n+proto\r\n:3\r\n".toUTF8, "+OK\r\n".toUTF8]
      else if endpoint.host == "client-auth-user" then
        #["%2\r\n+server\r\n+redis\r\n+proto\r\n:3\r\n".toUTF8, "+OK\r\n".toUTF8]
      else if endpoint.host == "client-server-error" then
        #["%2\r\n+server\r\n+redis\r\n+proto\r\n:3\r\n".toUTF8, "-ERR no such key\r\n".toUTF8]
      else if endpoint.host == "client-message" then
        #["%2\r\n+server\r\n+redis\r\n+proto\r\n:3\r\n".toUTF8, "$5\r\nhello\r\n".toUTF8]
      else
        #["%2\r\n+server\r\n+redis\r\n+proto\r\n:3\r\n".toUTF8, "+PONG\r\n".toUTF8]
    let writes ← IO.mkRef #[]
    pure { replies, writes }

  recv transport _ := do
    match ← shiftReplies transport.replies with
    | some bytes => pure bytes
    | none => pure ByteArray.empty

  send transport bytes := do
    transport.writes.modify fun writes => writes.push bytes

  sendAll transport chunks := do
    let combined := chunks.foldl (fun acc c => acc.append c) ByteArray.empty
    transport.writes.modify fun writes => writes.push combined

  close _ := pure ()

private def reconnectReplies (attempt : Nat) : Array ByteArray :=
  if attempt == 0 then
    #[
      "%2\r\n+server\r\n+redis\r\n+proto\r\n:3\r\n".toUTF8,
      ByteArray.empty
    ]
  else
    #[
      "%2\r\n+server\r\n+redis\r\n+proto\r\n:3\r\n".toUTF8,
      "+PONG\r\n".toUTF8
    ]

instance : Transport.Transport ReconnectingTransport where
  connect _ := do
    let attempt ← reconnectAttemptsRef.modifyGet fun value => (value, value + 1)
    let replies ← IO.mkRef <| reconnectReplies attempt
    let writes ← IO.mkRef #[]
    pure { replies, writes }

  recv transport _ := do
    match ← shiftReplies transport.replies with
    | some bytes => pure bytes
    | none => pure ByteArray.empty

  send transport bytes := do
    transport.writes.modify fun writes => writes.push bytes

  sendAll transport chunks := do
    let combined := chunks.foldl ByteArray.append ByteArray.empty
    transport.writes.modify fun writes => writes.push combined

  close _ := pure ()

instance : Transport.Transport FailingReconnectTransport where
  connect _ := do
    let attempt ← reconnectAttemptsRef.modifyGet fun value => (value, value + 1)
    let replies ← IO.mkRef <|
      if attempt == 0 then
        #["%2\r\n+server\r\n+redis\r\n+proto\r\n:3\r\n".toUTF8, ByteArray.empty]
      else
        #[]
    let writes ← IO.mkRef #[]
    pure { replies, writes }

  recv transport _ := do
    match ← shiftReplies transport.replies with
    | some bytes => pure bytes
    | none => pure ByteArray.empty

  send transport bytes := do
    transport.writes.modify fun writes => writes.push bytes

  sendAll transport chunks := do
    let combined := chunks.foldl (fun acc c => acc.append c) ByteArray.empty
    transport.writes.modify fun writes => writes.push combined

  close _ := pure ()

def testIsConnected : Async Bool := do
  let client: Client FakeTransport ← Client.new {
    endpoint := { host := "client-ping", port := 6379 }
  }
  Client.connect client
  client.isConnected

/--
info: true
-/
#guard_msgs in
#eval testIsConnected |>.block

def testEmptyPing : Async (Option String) := do
  let client: Client FakeTransport ← Client.new {
    endpoint := { host := "client-ping", port := 6379 }
  }
  client.connect
  client.ping

/--
info: none
-/
#guard_msgs in
#eval testEmptyPing |>.block

def testMessagePing : Async (Option String) := do
  let client: Client FakeTransport ← Client.new {
    endpoint := { host := "client-message", port := 6379 }
  }
  client.connect
  client.ping (some "hello")

/--
info: some "hello"
-/
#guard_msgs in
#eval testMessagePing |>.block

def testPasswordAuth : Async Nat := do
  let client : Client FakeTransport ← Client.new {
    endpoint := { host := "client-auth", port := 6379 }
  }
  client.connect
  client.auth { password := "secret" }
  let writes ← writesOf client
  pure writes.size

/--
info: 2
-/
#guard_msgs in
#eval testPasswordAuth |>.block

def testUsernameAuth : Async String := do
  let client : Client FakeTransport ← Client.new {
    endpoint := { host := "client-auth-user", port := 6379 }
  }
  client.connect
  client.auth { username? := some "default", password := "secret" }
  let writes ← writesOf client
  return renderBytes <| writes[1]?.getD ByteArray.empty

def testSelectUpdatesClientState : Async String := do
  let client : Client FakeTransport ← Client.new {
    endpoint := { host := "client-select", port := 6379 }
  }
  client.connect
  let _ ← Client.select client 3
  let state ← Client.currentState client
  pure s!"{state.protocol?.isSome.toNat}|{state.selectedDb?.getD 0}"

def testPingWritesTwoFrames : Async Nat := do
  let client : Client FakeTransport ← Client.new {
    endpoint := { host := "client-ping", port := 6379 }
  }
  client.connect
  let _ ← client.ping
  let writes ← writesOf client
  pure writes.size

def testServerErrorsStayServerErrors : Async String := do
  try
    let client : Client FakeTransport ← Client.new {
      endpoint := { host := "client-server-error", port := 6379 }
    }
    let _ ← client.connect
    let _ ← client.ping
    pure "unexpected success"
  catch err =>
    pure err.toString

def testRequireConnectedUsesRichStatus : Async String := do
  try
    let client : Client FakeTransport ← Client.new {
      endpoint := { host := "client-ping", port := 6379 }
    }
    let _ ← client.requireConnected
    pure "unexpected success"
  catch err =>
    pure err.toString

def testDisconnectUpdatesStatus : Async String := do
  let client : Client FakeTransport ← Client.new {
    endpoint := { host := "client-ping", port := 6379 }
  }
  client.connect
  client.disconnect
  let status ← client.connectionStatus
  pure s!"{repr status}"

def testReconnectEventsAndRecovery : Async String := do
  reconnectAttemptsRef.set 0
  let events ← IO.mkRef (#[] : Array String)
  let client : Client ReconnectingTransport ← Client.new {
    endpoint := { host := "client-reconnect", port := 6379 }
    reconnectStrategy := .fixedInterval 1 (some 3)
  }
  let _ ← client.onEvent fun event => do
    let label := match event with
      | .remoteDisconnected _ _ => "remote-disconnected"
      | .reconnectAttemptStarted _ => "reconnect-started"
      | .reconnectAttemptFailed _ => "reconnect-failed"
      | .reconnectScheduled _ _ => "reconnect-scheduled"
      | .reconnectStopped _ => "reconnect-stopped"
      | .reconnected _ => "reconnected"
      | _ => "other"
    events.modify fun xs => xs.push label
  client.connect
  try
    let _ ← client.ping
    pure ()
  catch _ =>
    pure ()
  sleep 1000
  let pong ← client.ping
  let seen ← events.get
  pure s!"{pong.isNone}|{String.intercalate "," seen.toList}"

def testReconnectStopsAfterMaxAttempts : Async String := do
  reconnectAttemptsRef.set 0
  let events ← IO.mkRef (#[] : Array String)
  let client : Client FailingReconnectTransport ← Client.new {
    endpoint := { host := "client-reconnect-stop", port := 6379 }
    reconnectStrategy := .fixedInterval 1 (some 1)
  }
  let _ ← client.onEvent fun event => do
    let label := match event with
      | .remoteDisconnected _ _ => "remote-disconnected"
      | .reconnectAttemptStarted _ => "reconnect-started"
      | .reconnectAttemptFailed _ => "reconnect-failed"
      | .reconnectScheduled _ _ => "reconnect-scheduled"
      | .reconnectStopped _ => "reconnect-stopped"
      | .reconnected _ => "reconnected"
      | _ => "other"
    events.modify fun xs => xs.push label
  client.connect
  try
    let _ ← client.ping
    pure ()
  catch _ =>
    pure ()
  sleep 1000
  let status ← client.connectionStatus
  let seen ← events.get
  pure s!"{repr status}|{String.intercalate "," seen.toList}"

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

/--
info: "server error: ERR no such key"
-/
#guard_msgs in
#eval testServerErrorsStayServerErrors |>.block

/--
info: "unavailable: client is not connected"
-/
#guard_msgs in
#eval testRequireConnectedUsesRichStatus |>.block

/--
info: "LeanRedis.Protocol.Phase.disconnected"
-/
#guard_msgs in
#eval testDisconnectUpdatesStatus |>.block

/--
info: "true|remote-disconnected,reconnect-scheduled,reconnect-started,reconnected"
-/
#guard_msgs in
#eval testReconnectEventsAndRecovery |>.block

/--
info: "LeanRedis.Protocol.Phase.disconnected|remote-disconnected,reconnect-scheduled,reconnect-started,reconnect-failed,reconnect-stopped"
-/
#guard_msgs in
#eval testReconnectStopsAfterMaxAttempts |>.block

end LeanRedisTest.Client.Basic
