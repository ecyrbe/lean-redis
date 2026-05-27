import LeanRedis

open LeanRedis

namespace LeanRedisTest.Connection.Manager

abbrev Async := Std.Internal.IO.Async.Async

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
    match ← Std.Internal.IO.Async.EAsync.lift <| shiftReplies transport.replies with
    | some bytes => pure { bytes }
    | none => pure { bytes := ByteArray.empty, disconnect? := some .closedByPeer }

  send transport bytes := do
    Std.Internal.IO.Async.EAsync.lift <| transport.writes.modify fun writes => writes.push bytes

  close _ := pure ()

def renderProtocol (version? : Option Protocol.Version) : String :=
  match version? with
  | some .resp2 => "resp2"
  | some .resp3 => "resp3"
  | none => "none"

/--
info: "true|resp3|2"
-/
#guard_msgs in
#eval do
  let manager <- Std.Internal.IO.Async.Async.block <| ((Connection.Manager.new {
    endpoint := { host := "resp3-db", port := 6379 }
    database? := some 2
    reconnectPolicy := .retryForever
  } : Connection.Manager FakeTransport).connect)
  pure s!"{manager.isConnected}|{renderProtocol manager.session.state.protocol?}|{manager.session.state.selectedDb?.getD 0}"

/--
info: 0
-/
#guard_msgs in
#eval
  (Protocol.bootstrapPlan {
    endpoint := { host := "127.0.0.1", port := 6379 }
    protocolPreference := .resp2
  }).size

/--
info: 2
-/
#guard_msgs in
#eval
  (Protocol.bootstrapPlan {
    endpoint := { host := "127.0.0.1", port := 6379 }
    protocolPreference := .resp2
    auth? := some { password := "secret" }
    database? := some 4
  }).size

/--
info: "failed|0"
-/
#guard_msgs in
#eval
  let manager : Connection.Manager FakeTransport := Connection.Manager.new {
    endpoint := { host := "127.0.0.1", port := 6379 }
    retryPolicy := .failPendingRequests
  }
  let manager := manager.notePending { name := "PING" }
  let manager := manager.recordDisconnect .closedByPeer
  s!"{match manager.session.state.phase with | .failed => "failed" | _ => "other"}|{manager.session.state.pending.size}"

/--
info: true
-/
#guard_msgs in
#eval do
  let manager : Connection.Manager FakeTransport := Connection.Manager.new {
    endpoint := { host := "resp3", port := 6379 }
    reconnectPolicy := .retryForever
  }
  let failed := manager.recordDisconnect .closedByPeer
  let some reconnected <- Std.Internal.IO.Async.Async.block <| failed.reconnect?
    | pure false
  pure reconnected.isConnected

/--
info: true
-/
#guard_msgs in
#eval do
  let manager : Connection.Manager FakeTransport := Connection.Manager.new {
    endpoint := { host := "resp3", port := 6379 }
    reconnectPolicy := .retryForever
  }
  let connected <- Std.Internal.IO.Async.Async.block manager.ensureConnected
  pure connected.isConnected

end LeanRedisTest.Connection.Manager
