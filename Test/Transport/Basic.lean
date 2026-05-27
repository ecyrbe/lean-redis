import LeanRedis

open LeanRedis

namespace LeanRedisTest.Transport.Basic

def testBytes : ByteArray := [1, 2, 3].toByteArray

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
  manager.transport?.isNone

/--
info: LeanRedis.Engine.SessionPhase.bootstrapping
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
  let client <- (Client.connect {
    endpoint := { host := "127.0.0.1", port := 6379 }
  } : IO (Client Transport.TCP))
  client.isConnected

/--
info: true
-/
#guard_msgs in
#eval do
  let client <- (Client.connectWith {
    endpoint := { host := "127.0.0.1", port := 6379 }
  } : IO (Client FakeTransport))
  let manager <- client.managerRef.get
  let connected <- Std.Internal.IO.Async.Async.block manager.connect
  pure connected.transport?.isSome

/--
info: some (LeanRedis.Transport.DisconnectReason.closedByPeer)
-/
#guard_msgs in
#eval
  ({ bytes := ByteArray.empty, disconnect? := some .closedByPeer } : Transport.ReadResult).disconnect?

end LeanRedisTest.Transport.Basic
