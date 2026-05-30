import LeanRedis

open LeanRedis

namespace LeanRedisTest.Transport.Basic

open Std.Internal.IO.Async


def testBytes : ByteArray := "%2\r\n+server\r\n+redis\r\n+proto\r\n:3\r\n".toUTF8

structure FakeTransport where
  connected : Bool := false
  deriving Inhabited

instance : Transport.Transport FakeTransport where
  connect _ := pure { connected := true }
  recv _ _ := pure testBytes
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
  let client <- Client.newDefault {
    endpoint := { host := "127.0.0.1", port := 6379 }
  }
  Client.isConnected client

def testCustomClientConnectNow : Async Bool := do
  let client: Client FakeTransport <- Client.new {
    endpoint := { host := "127.0.0.1", port := 6379 }
  }
  let _ <- Client.connect client
  Client.isConnected client

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

end LeanRedisTest.Transport.Basic
