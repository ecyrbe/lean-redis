import LeanRedis

open LeanRedis

namespace LeanRedisTest.Transport.Basic

def testBytes : ByteArray := "%2\r\n+server\r\n+redis\r\n+proto\r\n:3\r\n".toUTF8

structure FakeTransport where
  connected : Bool := false
  deriving Inhabited

instance : Transport.Transport FakeTransport where
  connect _ := pure { connected := true }
  recv _ _ := pure { bytes := testBytes }
  send _ _ := pure ()
  close _ := pure ()

/--
info: true
-/
#guard_msgs in
#eval
  let manager : Connection.Manager FakeTransport := Connection.Manager.new {
    endpoint := { host := "127.0.0.1", port := 6379 }
  }
  manager.runtime?.isNone

/--
info: LeanRedis.Engine.SessionPhase.ready
-/
#guard_msgs in
#eval do
  let manager <- Std.Internal.IO.Async.Async.block <| ((Connection.Manager.new {
    endpoint := { host := "127.0.0.1", port := 6379 }
  } : Connection.Manager FakeTransport).connect)
  pure manager.session.state.phase

/--
info: false
-/
#guard_msgs in
#eval do
  let client <- Std.Internal.IO.Async.Async.block <| (Client.connect {
    endpoint := { host := "127.0.0.1", port := 6379 }
  } : Std.Internal.IO.Async.Async (Client Transport.TCP))
  Std.Internal.IO.Async.Async.block <| Client.isConnected client

/--
info: true
-/
#guard_msgs in
#eval do
  let client <- Std.Internal.IO.Async.Async.block <| (Client.connectWith {
    endpoint := { host := "127.0.0.1", port := 6379 }
  } : Std.Internal.IO.Async.Async (Client FakeTransport))
  let _ <- Std.Internal.IO.Async.Async.block <| Client.connectNow client
  Std.Internal.IO.Async.Async.block <| Client.isConnected client

/--
info: some (LeanRedis.Transport.DisconnectReason.closedByPeer)
-/
#guard_msgs in
#eval
  ({ bytes := ByteArray.empty, disconnect? := some .closedByPeer } : Transport.ReadResult).disconnect?

end LeanRedisTest.Transport.Basic
