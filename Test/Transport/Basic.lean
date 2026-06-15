import LeanRedis

open LeanRedis
open LeanRedis.Connection

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
  sendAll _ _ := pure ()
  close _ := pure ()

def testDriverConnectToReady : Async Protocol.Phase := do
  let config : Config := { endpoint := { host := "127.0.0.1", port := 6379 } }
  let state : DriverState FakeTransport := { config := config }
  let (s, _) := onConnectRequest state
  let (s', _) ← connectTransport s
  pure s'.session.phase

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
info: LeanRedis.Protocol.Phase.ready (LeanRedis.Protocol.Version.resp3) none
-/
#guard_msgs in
#eval testDriverConnectToReady |>.block

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
