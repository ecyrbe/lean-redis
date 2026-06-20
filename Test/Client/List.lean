import LeanRedis
import Std.Sync.Mutex
import Test.Utils

open LeanRedis
open LeanRedisTest.Utils
open Std.Async

namespace LeanRedisTest.Client.List

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
  | "list-int" =>
      #["%2\r\n+server\r\n+redis\r\n+proto\r\n:3\r\n".toUTF8, ":3\r\n".toUTF8]
  | "list-pop" =>
      #["%2\r\n+server\r\n+redis\r\n+proto\r\n:3\r\n".toUTF8, "$1\r\na\r\n".toUTF8]
  | "list-null" =>
      #["%2\r\n+server\r\n+redis\r\n+proto\r\n:3\r\n".toUTF8, "_\r\n".toUTF8]
  | "list-range" =>
      #["%2\r\n+server\r\n+redis\r\n+proto\r\n:3\r\n".toUTF8, "*3\r\n$1\r\na\r\n$1\r\nb\r\n$1\r\nc\r\n".toUTF8]
  | "list-ok" =>
      #["%2\r\n+server\r\n+redis\r\n+proto\r\n:3\r\n".toUTF8, "+OK\r\n".toUTF8]
  | "list-move" =>
      #["%2\r\n+server\r\n+redis\r\n+proto\r\n:3\r\n".toUTF8, "$1\r\nz\r\n".toUTF8]
  | "list-lpos-one" =>
      #["%2\r\n+server\r\n+redis\r\n+proto\r\n:3\r\n".toUTF8, ":4\r\n".toUTF8]
  | "list-lpos-many" =>
      #["%2\r\n+server\r\n+redis\r\n+proto\r\n:3\r\n".toUTF8, "*2\r\n:1\r\n:3\r\n".toUTF8]
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

def testLPush : Async Int := do
  let client : Client FakeTransport ← Client.new {
    endpoint := { host := "list-int", port := 6379 }
  }
  client.connect
  client.lPush "jobs" #["a", "b", "c"]

def testLPop : Async (Option String) := do
  let client : Client FakeTransport ← Client.new {
    endpoint := { host := "list-pop", port := 6379 }
  }
  client.connect
  client.lPop "jobs"

def testRPopNull : Async (Option String) := do
  let client : Client FakeTransport ← Client.new {
    endpoint := { host := "list-null", port := 6379 }
  }
  client.connect
  client.rPop "jobs"

def testLRange : Async (Array String) := do
  let client : Client FakeTransport ← Client.new {
    endpoint := { host := "list-range", port := 6379 }
  }
  client.connect
  client.lRange "jobs" 0 (-1)

def testLSet : Async String := do
  let client : Client FakeTransport ← Client.new {
    endpoint := { host := "list-ok", port := 6379 }
  }
  client.connect
  let _ ← client.lSet "jobs" 1 "x"
  let writes ← writesOf client
  return renderBytes <| writes[1]?.getD ByteArray.empty

def testLMove : Async (Option String) := do
  let client : Client FakeTransport ← Client.new {
    endpoint := { host := "list-move", port := 6379 }
  }
  client.connect
  client.lMove "src" "dst" .right .left

def testLPos : Async (Option Int) := do
  let client : Client FakeTransport ← Client.new {
    endpoint := { host := "list-lpos-one", port := 6379 }
  }
  client.connect
  client.lPos "jobs" "a" { rank? := some 2 }

def testLPosMany : Async (Array Int) := do
  let client : Client FakeTransport ← Client.new {
    endpoint := { host := "list-lpos-many", port := 6379 }
  }
  client.connect
  client.lPosMany "jobs" "a" { count? := some 2 }

/--
info: 3
-/
#guard_msgs in
#eval testLPush |>.block

/--
info: some "a"
-/
#guard_msgs in
#eval testLPop |>.block

/--
info: none
-/
#guard_msgs in
#eval testRPopNull |>.block

/--
info: #["a", "b", "c"]
-/
#guard_msgs in
#eval testLRange |>.block

/--
info: "\"*4\\r\\n$4\\r\\nLSET\\r\\n$4\\r\\njobs\\r\\n$1\\r\\n1\\r\\n$1\\r\\nx\\r\\n\""
-/
#guard_msgs in
#eval testLSet |>.block

/--
info: some "z"
-/
#guard_msgs in
#eval testLMove |>.block

/--
info: some 4
-/
#guard_msgs in
#eval testLPos |>.block

/--
info: #[1, 3]
-/
#guard_msgs in
#eval testLPosMany |>.block

end LeanRedisTest.Client.List
