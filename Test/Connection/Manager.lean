import LeanRedis

open LeanRedis

namespace LeanRedisTest.Connection.Manager

open Std.Internal.IO.Async

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

instance : Transport.Transport FakeTransport where
  connect endpoint := do
    let replies <- IO.mkRef <|
      if endpoint.host == "resp2" then
        #["+OK\r\n".toUTF8]
      else if endpoint.host == "resp3-db" then
        #["%2\r\n+server\r\n+redis\r\n+proto\r\n:3\r\n".toUTF8, "+OK\r\n".toUTF8]
      else
        #["%2\r\n+server\r\n+redis\r\n+proto\r\n:3\r\n".toUTF8]
    let writes <- IO.mkRef #[]
    pure { replies, writes }

  recv transport _ := do
    match ← shiftReplies transport.replies with
    | some bytes => pure { bytes }
    | none => pure { bytes := ByteArray.empty, disconnect? := some .closedByPeer }

  send transport bytes := do
    transport.writes.modify fun writes => writes.push bytes

  close _ := pure ()

def renderProtocol (version? : Option Protocol.Version) : String :=
  match version? with
  | some .resp2 => "resp2"
  | some .resp3 => "resp3"
  | none => "none"

def testBootstrapConnectWithDatabase : Async String := do
  let manager <- ((Connection.Manager.new {
    endpoint := { host := "resp3-db", port := 6379 }
    database? := some 2
  } : Connection.Manager FakeTransport).connect)
  pure s!"{manager.isConnected}|{renderProtocol manager.session.state.protocol?}|{manager.session.state.selectedDb?.getD 0}"

def testResp2PlanWithoutHello : Nat :=
  (Protocol.bootstrapPlan {
    endpoint := { host := "127.0.0.1", port := 6379 }
    protocolPreference := .resp2
  }).size

def testResp2PlanWithAuthAndSelect : Nat :=
  (Protocol.bootstrapPlan {
    endpoint := { host := "127.0.0.1", port := 6379 }
    protocolPreference := .resp2
    auth? := some { password := "secret" }
    database? := some 4
  }).size

def testDisconnectClearsReadyRuntime : Async String := do
  let manager <- ((Connection.Manager.new {
    endpoint := { host := "resp3", port := 6379 }
  } : Connection.Manager FakeTransport).connect)
  let manager <- manager.disconnect
  pure s!"{manager.isConnected}|{match manager.session.state.phase with | .disconnected => "disconnected" | _ => "other"}"

/--
info: "true|resp3|2"
-/
#guard_msgs in
#eval testBootstrapConnectWithDatabase |>.block

/--
info: 0
-/
#guard_msgs in
#eval testResp2PlanWithoutHello

/--
info: 2
-/
#guard_msgs in
#eval testResp2PlanWithAuthAndSelect

/--
info: "false|disconnected"
-/
#guard_msgs in
#eval testDisconnectClearsReadyRuntime |>.block

end LeanRedisTest.Connection.Manager
