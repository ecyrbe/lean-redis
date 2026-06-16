import LeanRedis
import Std.Sync.Mutex
import Test.Utils

open LeanRedis
open LeanRedisTest.Utils
open Std.Internal.IO.Async

namespace LeanRedisTest.Client.Set

structure FakeTransport where
  replies : IO.Ref (Array ByteArray)
  writes : IO.Ref (Array ByteArray)

private def shiftReplies (ref : IO.Ref (Array ByteArray)) : IO (Option ByteArray) := do
  let replies ← ref.get
  match replies[0]? with
  | some reply =>
      ref.set (replies.extract 1 replies.size)
      pure (some reply)
  | none => pure none

private def writesOf (client : Client FakeTransport) : IO (Array ByteArray) := do
  client.state.atomically fun ref => do
    let state ← ref.get
    match state.transport? with
    | some transport => transport.writes.get
    | none => pure #[]

private def scriptedReplies (host : String) : Array ByteArray :=
  match host with
  | "set-int" =>
      #["%2\r\n+server\r\n+redis\r\n+proto\r\n:3\r\n".toUTF8, ":2\r\n".toUTF8]
  | "set-bool" =>
      #["%2\r\n+server\r\n+redis\r\n+proto\r\n:3\r\n".toUTF8, ":1\r\n".toUTF8]
  | "set-bools" =>
      #["%2\r\n+server\r\n+redis\r\n+proto\r\n:3\r\n".toUTF8, "*3\r\n:1\r\n:0\r\n:1\r\n".toUTF8]
  | "set-members" =>
      #["%2\r\n+server\r\n+redis\r\n+proto\r\n:3\r\n".toUTF8, "*2\r\n$4\r\nlean\r\n$5\r\nredis\r\n".toUTF8]
  | "set-pop-one" =>
      #["%2\r\n+server\r\n+redis\r\n+proto\r\n:3\r\n".toUTF8, "$4\r\nlean\r\n".toUTF8]
  | "set-pop-many" =>
      #["%2\r\n+server\r\n+redis\r\n+proto\r\n:3\r\n".toUTF8, "*2\r\n$4\r\nlean\r\n$5\r\nredis\r\n".toUTF8]
  | "set-rand-null" =>
      #["%2\r\n+server\r\n+redis\r\n+proto\r\n:3\r\n".toUTF8, "_\r\n".toUTF8]
  | "set-rand-many" =>
      #["%2\r\n+server\r\n+redis\r\n+proto\r\n:3\r\n".toUTF8, "*2\r\n$4\r\nlean\r\n$5\r\nredis\r\n".toUTF8]
  | "set-scan" =>
      #["%2\r\n+server\r\n+redis\r\n+proto\r\n:3\r\n".toUTF8, "*2\r\n$1\r\n7\r\n*2\r\n$4\r\nlean\r\n$5\r\nredis\r\n".toUTF8]
  | _ =>
      #["%2\r\n+server\r\n+redis\r\n+proto\r\n:3\r\n".toUTF8, "+OK\r\n".toUTF8]

instance : Transport.Transport FakeTransport where
  connect endpoint := do
    let replies ← IO.mkRef <| scriptedReplies endpoint.host
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

def testSAdd : Async Int := do
  let client : Client FakeTransport ← Client.new {
    endpoint := { host := "set-int", port := 6379 }
  }
  client.connect
  client.sAdd "tags" #["lean", "redis"]

def testSIsMember : Async Bool := do
  let client : Client FakeTransport ← Client.new {
    endpoint := { host := "set-bool", port := 6379 }
  }
  client.connect
  client.sIsMember "tags" "lean"

def testSMIsMember : Async (Array Bool) := do
  let client : Client FakeTransport ← Client.new {
    endpoint := { host := "set-bools", port := 6379 }
  }
  client.connect
  client.sMIsMember "tags" #["lean", "lisp", "redis"]

def testSMembers : Async (Array String) := do
  let client : Client FakeTransport ← Client.new {
    endpoint := { host := "set-members", port := 6379 }
  }
  client.connect
  client.sMembers "tags"

def testSPop : Async (Option String) := do
  let client : Client FakeTransport ← Client.new {
    endpoint := { host := "set-pop-one", port := 6379 }
  }
  client.connect
  client.sPop "tags"

def testSPopMany : Async (Array String) := do
  let client : Client FakeTransport ← Client.new {
    endpoint := { host := "set-pop-many", port := 6379 }
  }
  client.connect
  client.sPopMany "tags" 2

def testSRandMemberNull : Async (Option String) := do
  let client : Client FakeTransport ← Client.new {
    endpoint := { host := "set-rand-null", port := 6379 }
  }
  client.connect
  client.sRandMember "tags"

def testSRandMembers : Async (Array String) := do
  let client : Client FakeTransport ← Client.new {
    endpoint := { host := "set-rand-many", port := 6379 }
  }
  client.connect
  client.sRandMembers "tags" 2

def testSScan : Async String := do
  let client : Client FakeTransport ← Client.new {
    endpoint := { host := "set-scan", port := 6379 }
  }
  client.connect
  let result ← client.sScan "tags" 0 { count? := some 10 }
  pure s!"{result.cursor}|{result.members.size}|{result.members[0]?.getD ""}"

def testSScanWritesExpectedFrame : Async String := do
  let client : Client FakeTransport ← Client.new {
    endpoint := { host := "set-scan", port := 6379 }
  }
  client.connect
  let _ ← client.sScan "tags" 0 { match? := some "le*", count? := some 10 }
  let writes ← writesOf client
  return renderBytes <| writes[1]?.getD ByteArray.empty

/--
info: 2
-/
#guard_msgs in
#eval testSAdd |>.block

/--
info: true
-/
#guard_msgs in
#eval testSIsMember |>.block

/--
info: #[true, false, true]
-/
#guard_msgs in
#eval testSMIsMember |>.block

/--
info: #["lean", "redis"]
-/
#guard_msgs in
#eval testSMembers |>.block

/--
info: some "lean"
-/
#guard_msgs in
#eval testSPop |>.block

/--
info: #["lean", "redis"]
-/
#guard_msgs in
#eval testSPopMany |>.block

/--
info: none
-/
#guard_msgs in
#eval testSRandMemberNull |>.block

/--
info: #["lean", "redis"]
-/
#guard_msgs in
#eval testSRandMembers |>.block

/--
info: "7|2|lean"
-/
#guard_msgs in
#eval testSScan |>.block

/--
info: "\"*7\\r\\n$5\\r\\nSSCAN\\r\\n$4\\r\\ntags\\r\\n$1\\r\\n0\\r\\n$5\\r\\nMATCH\\r\\n$3\\r\\nle*\\r\\n$5\\r\\nCOUNT\\r\\n$2\\r\\n10\\r\\n\""
-/
#guard_msgs in
#eval testSScanWritesExpectedFrame |>.block

end LeanRedisTest.Client.Set
