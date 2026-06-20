import LeanRedis
import Std.Sync.Mutex
import Test.Utils

open LeanRedis
open LeanRedisTest.Utils
open Std.Async

namespace LeanRedisTest.Client.SortedSet

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
  | "zset-int" =>
      #["%2\r\n+server\r\n+redis\r\n+proto\r\n:3\r\n".toUTF8, ":2\r\n".toUTF8]
  | "zset-score" =>
      #["%2\r\n+server\r\n+redis\r\n+proto\r\n:3\r\n".toUTF8, "$2\r\n10\r\n".toUTF8]
  | "zset-scores" =>
      #["%2\r\n+server\r\n+redis\r\n+proto\r\n:3\r\n".toUTF8, "*3\r\n$2\r\n10\r\n_\r\n$2\r\n20\r\n".toUTF8]
  | "zset-rank" =>
      #["%2\r\n+server\r\n+redis\r\n+proto\r\n:3\r\n".toUTF8, ":4\r\n".toUTF8]
  | "zset-members" =>
      #["%2\r\n+server\r\n+redis\r\n+proto\r\n:3\r\n".toUTF8, "*2\r\n$5\r\nalice\r\n$3\r\nbob\r\n".toUTF8]
  | "zset-withscores" =>
      #["%2\r\n+server\r\n+redis\r\n+proto\r\n:3\r\n".toUTF8, "*4\r\n$5\r\nalice\r\n$2\r\n10\r\n$3\r\nbob\r\n$2\r\n20\r\n".toUTF8]
  | "zset-rand-null" =>
      #["%2\r\n+server\r\n+redis\r\n+proto\r\n:3\r\n".toUTF8, "_\r\n".toUTF8]
  | "zset-scan" =>
      #["%2\r\n+server\r\n+redis\r\n+proto\r\n:3\r\n".toUTF8, "*2\r\n$1\r\n5\r\n*4\r\n$5\r\nalice\r\n$2\r\n10\r\n$3\r\nbob\r\n$2\r\n20\r\n".toUTF8]
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

def testZAdd : Async Int := do
  let client : Client FakeTransport ← Client.new {
    endpoint := { host := "zset-int", port := 6379 }
  }
  client.connect
  client.zAdd "scores" #[{ score := "10", member := "alice" }, { score := "20", member := "bob" }]

def testZScore : Async (Option String) := do
  let client : Client FakeTransport ← Client.new {
    endpoint := { host := "zset-score", port := 6379 }
  }
  client.connect
  client.zScore "scores" "alice"

def testZMScore : Async (Array (Option String)) := do
  let client : Client FakeTransport ← Client.new {
    endpoint := { host := "zset-scores", port := 6379 }
  }
  client.connect
  client.zMScore "scores" #["alice", "carol", "bob"]

def testZRank : Async (Option Int) := do
  let client : Client FakeTransport ← Client.new {
    endpoint := { host := "zset-rank", port := 6379 }
  }
  client.connect
  client.zRank "scores" "alice"

def testZRange : Async (Array String) := do
  let client : Client FakeTransport ← Client.new {
    endpoint := { host := "zset-members", port := 6379 }
  }
  client.connect
  client.zRange "scores" 0 (-1)

def testZRangeWithScores : Async (Array SortedSetEntry) := do
  let client : Client FakeTransport ← Client.new {
    endpoint := { host := "zset-withscores", port := 6379 }
  }
  client.connect
  client.zRangeWithScores "scores" 0 (-1)

def testZRandMemberNull : Async (Option String) := do
  let client : Client FakeTransport ← Client.new {
    endpoint := { host := "zset-rand-null", port := 6379 }
  }
  client.connect
  client.zRandMember "scores"

def testZScan : Async String := do
  let client : Client FakeTransport ← Client.new {
    endpoint := { host := "zset-scan", port := 6379 }
  }
  client.connect
  let result ← client.zScan "scores" 0 { count? := some 10 }
  pure s!"{result.cursor}|{result.entries.size}|{result.entries[0]?.map SortedSetEntry.member |>.getD ""}"

def testZScanWritesExpectedFrame : Async String := do
  let client : Client FakeTransport ← Client.new {
    endpoint := { host := "zset-scan", port := 6379 }
  }
  client.connect
  let _ ← client.zScan "scores" 0 { match? := some "a*", count? := some 10 }
  let writes ← writesOf client
  return renderBytes <| writes[1]?.getD ByteArray.empty

/--
info: 2
-/
#guard_msgs in
#eval testZAdd |>.block

/--
info: some "10"
-/
#guard_msgs in
#eval testZScore |>.block

/--
info: #[some "10", none, some "20"]
-/
#guard_msgs in
#eval testZMScore |>.block

/--
info: some 4
-/
#guard_msgs in
#eval testZRank |>.block

/--
info: #["alice", "bob"]
-/
#guard_msgs in
#eval testZRange |>.block

/--
info: #[{ score := "10", member := "alice" }, { score := "20", member := "bob" }]
-/
#guard_msgs in
#eval testZRangeWithScores |>.block

/--
info: none
-/
#guard_msgs in
#eval testZRandMemberNull |>.block

/--
info: "5|2|alice"
-/
#guard_msgs in
#eval testZScan |>.block

/--
info: "\"*7\\r\\n$5\\r\\nZSCAN\\r\\n$6\\r\\nscores\\r\\n$1\\r\\n0\\r\\n$5\\r\\nMATCH\\r\\n$2\\r\\na*\\r\\n$5\\r\\nCOUNT\\r\\n$2\\r\\n10\\r\\n\""
-/
#guard_msgs in
#eval testZScanWritesExpectedFrame |>.block

end LeanRedisTest.Client.SortedSet
