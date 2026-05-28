import LeanRedis

open LeanRedis

namespace LeanRedisTest.Transport.Basic

abbrev Async := Std.Internal.IO.Async.Async


def testBytes : ByteArray := "%2\r\n+server\r\n+redis\r\n+proto\r\n:3\r\n".toUTF8

structure FakeTransport where
  connected : Bool := false
  deriving Inhabited

instance : Transport.Transport FakeTransport where
  connect _ := pure { connected := true }
  recv _ _ := pure { bytes := testBytes }
  send _ _ := pure ()
  close _ := pure ()

def testManagerStartsDisconnected : Bool :=
  let manager : Connection.Manager FakeTransport := Connection.Manager.new {
    endpoint := { host := "127.0.0.1", port := 6379 }
  }
  manager.runtime?.isNone

def testManagerConnectsToReady : Async LeanRedis.Engine.SessionPhase := do
  let manager <- ((Connection.Manager.new {
    endpoint := { host := "127.0.0.1", port := 6379 }
  } : Connection.Manager FakeTransport).connect)
  pure manager.session.state.phase

def testDefaultClientStartsDisconnected : Async Bool := do
  let client <- (Client.connect {
    endpoint := { host := "127.0.0.1", port := 6379 }
  } : Async (Client Transport.TCP))
  Client.isConnected client

def testCustomClientConnectNow : Async Bool := do
  let client <- (Client.connectWith {
    endpoint := { host := "127.0.0.1", port := 6379 }
  } : Async (Client FakeTransport))
  let _ <- Client.connectNow client
  Client.isConnected client

def testClosedByPeerReadResult : Option Transport.DisconnectReason :=
  ({ bytes := ByteArray.empty, disconnect? := some .closedByPeer } : Transport.ReadResult).disconnect?

/--
info: true
-/
#guard_msgs in
#eval testManagerStartsDisconnected

/--
info: LeanRedis.Engine.SessionPhase.ready
-/
#guard_msgs in
#eval testManagerConnectsToReady |>.block

/--
info: false
-/
#guard_msgs in
#eval testDefaultClientStartsDisconnected |>.block

/--
info: true
-/
#guard_msgs in
#eval testCustomClientConnectNow |>.block

/--
info: some (LeanRedis.Transport.DisconnectReason.closedByPeer)
-/
#guard_msgs in
#eval testClosedByPeerReadResult

end LeanRedisTest.Transport.Basic
