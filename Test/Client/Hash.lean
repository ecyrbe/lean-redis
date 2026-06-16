import LeanRedis
import Std.Sync.Mutex
import Test.Utils

open LeanRedis
open LeanRedisTest.Utils
open Std.Internal.IO.Async

namespace LeanRedisTest.Client.Hash

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
  | "hash-get" =>
      #["%2\r\n+server\r\n+redis\r\n+proto\r\n:3\r\n".toUTF8, "$5\r\nalice\r\n".toUTF8]
  | "hash-set" =>
      #["%2\r\n+server\r\n+redis\r\n+proto\r\n:3\r\n".toUTF8, ":2\r\n".toUTF8]
  | "hash-mget" =>
      #["%2\r\n+server\r\n+redis\r\n+proto\r\n:3\r\n".toUTF8, "*3\r\n$5\r\nalice\r\n_\r\n$5\r\nadmin\r\n".toUTF8]
  | "hash-getall-map" =>
      #["%2\r\n+server\r\n+redis\r\n+proto\r\n:3\r\n".toUTF8, "%2\r\n+name\r\n$5\r\nalice\r\n+role\r\n$5\r\nadmin\r\n".toUTF8]
  | "hash-getall-array" =>
      #["%2\r\n+server\r\n+redis\r\n+proto\r\n:3\r\n".toUTF8, "*4\r\n$4\r\nname\r\n$5\r\nalice\r\n$4\r\nrole\r\n$5\r\nadmin\r\n".toUTF8]
  | "hash-bool" =>
      #["%2\r\n+server\r\n+redis\r\n+proto\r\n:3\r\n".toUTF8, ":1\r\n".toUTF8]
  | "hash-array" =>
      #["%2\r\n+server\r\n+redis\r\n+proto\r\n:3\r\n".toUTF8, "*2\r\n$4\r\nname\r\n$4\r\nrole\r\n".toUTF8]
  | "hash-int" =>
      #["%2\r\n+server\r\n+redis\r\n+proto\r\n:3\r\n".toUTF8, ":7\r\n".toUTF8]
  | "hash-float" =>
      #["%2\r\n+server\r\n+redis\r\n+proto\r\n:3\r\n".toUTF8, "$3\r\n1.5\r\n".toUTF8]
  | "hash-rand-null" =>
      #["%2\r\n+server\r\n+redis\r\n+proto\r\n:3\r\n".toUTF8, "_\r\n".toUTF8]
  | "hash-rand-pairs" =>
      #["%2\r\n+server\r\n+redis\r\n+proto\r\n:3\r\n".toUTF8, "*4\r\n$4\r\nname\r\n$5\r\nalice\r\n$4\r\nrole\r\n$5\r\nadmin\r\n".toUTF8]
  | "hash-scan" =>
      #["%2\r\n+server\r\n+redis\r\n+proto\r\n:3\r\n".toUTF8, "*2\r\n$1\r\n5\r\n*4\r\n$4\r\nname\r\n$5\r\nalice\r\n$4\r\nrole\r\n$5\r\nadmin\r\n".toUTF8]
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

def testHGet : Async (Option String) := do
  let client : Client FakeTransport ← Client.new {
    endpoint := { host := "hash-get", port := 6379 }
  }
  client.connect
  client.hGet "user:1" "name"

def testHSet : Async Int := do
  let client : Client FakeTransport ← Client.new {
    endpoint := { host := "hash-set", port := 6379 }
  }
  client.connect
  client.hSet "user:1" #[("name", "alice"), ("role", "admin")]

def testHMGet : Async (Array (Option String)) := do
  let client : Client FakeTransport ← Client.new {
    endpoint := { host := "hash-mget", port := 6379 }
  }
  client.connect
  client.hMGet "user:1" #["name", "email", "role"]

def testHGetAllMap : Async (Array (String × String)) := do
  let client : Client FakeTransport ← Client.new {
    endpoint := { host := "hash-getall-map", port := 6379 }
  }
  client.connect
  client.hGetAll "user:1"

def testHGetAllArray : Async (Array (String × String)) := do
  let client : Client FakeTransport ← Client.new {
    endpoint := { host := "hash-getall-array", port := 6379 }
  }
  client.connect
  client.hGetAll "user:1"

def testHExists : Async Bool := do
  let client : Client FakeTransport ← Client.new {
    endpoint := { host := "hash-bool", port := 6379 }
  }
  client.connect
  client.hExists "user:1" "name"

def testHKeys : Async (Array String) := do
  let client : Client FakeTransport ← Client.new {
    endpoint := { host := "hash-array", port := 6379 }
  }
  client.connect
  client.hKeys "user:1"

def testHIncrByFloat : Async String := do
  let client : Client FakeTransport ← Client.new {
    endpoint := { host := "hash-float", port := 6379 }
  }
  client.connect
  client.hIncrByFloat "scores" "pi" "1.5"

def testHRandFieldNull : Async (Option String) := do
  let client : Client FakeTransport ← Client.new {
    endpoint := { host := "hash-rand-null", port := 6379 }
  }
  client.connect
  client.hRandField "user:1"

def testHRandFieldsWithValues : Async (Array (String × String)) := do
  let client : Client FakeTransport ← Client.new {
    endpoint := { host := "hash-rand-pairs", port := 6379 }
  }
  client.connect
  client.hRandFieldsWithValues "user:1" 2

def testHScan : Async String := do
  let client : Client FakeTransport ← Client.new {
    endpoint := { host := "hash-scan", port := 6379 }
  }
  client.connect
  let result ← client.hScan "user:1" 0 { count? := some 10 }
  return s!"{result.cursor}|{result.entries.size}|{result.entries[0]?.map Prod.fst |>.getD ""}"

def testHScanWritesExpectedFrame : Async String := do
  let client : Client FakeTransport ← Client.new {
    endpoint := { host := "hash-scan", port := 6379 }
  }
  client.connect
  let _ ← client.hScan "user:1" 0 { match? := some "na*", count? := some 10 }
  let writes ← writesOf client
  return renderBytes <| writes[1]?.getD ByteArray.empty

/--
info: some "alice"
-/
#guard_msgs in
#eval testHGet |>.block

/--
info: 2
-/
#guard_msgs in
#eval testHSet |>.block

/--
info: #[some "alice", none, some "admin"]
-/
#guard_msgs in
#eval testHMGet |>.block

/--
info: #[("name", "alice"), ("role", "admin")]
-/
#guard_msgs in
#eval testHGetAllMap |>.block

/--
info: #[("name", "alice"), ("role", "admin")]
-/
#guard_msgs in
#eval testHGetAllArray |>.block

/--
info: true
-/
#guard_msgs in
#eval testHExists |>.block

/--
info: #["name", "role"]
-/
#guard_msgs in
#eval testHKeys |>.block

/--
info: "1.5"
-/
#guard_msgs in
#eval testHIncrByFloat |>.block

/--
info: none
-/
#guard_msgs in
#eval testHRandFieldNull |>.block

/--
info: #[("name", "alice"), ("role", "admin")]
-/
#guard_msgs in
#eval testHRandFieldsWithValues |>.block

/--
info: "5|2|name"
-/
#guard_msgs in
#eval testHScan |>.block

/--
info: "\"*7\\r\\n$5\\r\\nHSCAN\\r\\n$6\\r\\nuser:1\\r\\n$1\\r\\n0\\r\\n$5\\r\\nMATCH\\r\\n$3\\r\\nna*\\r\\n$5\\r\\nCOUNT\\r\\n$2\\r\\n10\\r\\n\""
-/
#guard_msgs in
#eval testHScanWritesExpectedFrame |>.block

end LeanRedisTest.Client.Hash
