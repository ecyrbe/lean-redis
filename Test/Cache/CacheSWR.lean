import LeanRedis
import Std.Sync.Mutex
import Test.Utils

open LeanRedis
open LeanRedisTest.Utils
open Std.Internal.IO.Async

namespace LeanRedisTest.CacheSWR

structure FakeTransport where
  replies : Std.Mutex (Array ByteArray)
  writes : IO.Ref (Array ByteArray)

private def helloReply : ByteArray :=
  "%2\r\n+server\r\n+redis\r\n+proto\r\n:3\r\n".toUTF8

private def okReply : ByteArray :=
  "+OK\r\n".toUTF8

private def expireReply : ByteArray :=
  ":1\r\n".toUTF8

private def hmgetFreshReply : ByteArray :=
  "*2\r\n$5\r\nhello\r\n$10\r\n9999999999\r\n".toUTF8

private def hmgetStaleReply : ByteArray :=
  "*2\r\n$5\r\nhello\r\n$1\r\n0\r\n".toUTF8

private def hmgetNullReply : ByteArray :=
  "*2\r\n_\r\n_\r\n".toUTF8

private def scriptedReplies (host : String) : Array ByteArray :=
  match host with
  | "cache-hit" =>
      #[helloReply, hmgetFreshReply]
  | "cache-stale" =>
      #[helloReply, hmgetStaleReply, okReply, expireReply]
  | "cache-miss" =>
      #[helloReply, hmgetNullReply, okReply, expireReply]
  | "cache-stale-inflight" =>
      #[helloReply, hmgetStaleReply, hmgetStaleReply, okReply, expireReply]
  | _ =>
      #[helloReply, okReply]

instance : Transport.Transport FakeTransport where
  connect endpoint := do
    let replies ← Std.Mutex.new (scriptedReplies endpoint.host)
    let writes ← IO.mkRef #[]
    pure { replies, writes }

  recv transport _ := do
    let mb ← transport.replies.atomically fun ref => do
      let arr ← ref.get
      match arr[0]? with
      | some reply =>
          ref.set (arr.extract 1 arr.size)
          pure (some reply)
      | none => pure none
    match mb with
    | some bytes => pure bytes
    | none => pure ByteArray.empty

  send transport bytes := do
    transport.writes.modify fun writes => writes.push bytes

  sendAll transport chunks := do
    let combined := chunks.foldl (fun acc c => acc.append c) ByteArray.empty
    transport.writes.modify fun writes => writes.push combined

  close _ := pure ()

private def makeCache (host : String) : Async (CacheSWR FakeTransport) :=
  CacheSWR.new {
    endpoint := { host, port := 6379 }
  }

/-- A cache hit returns the fresh value without calling the callback. -/
def testHit : Async String := do
  let cache ← makeCache "cache-hit"
  cache.get "key" (fun _ => do
    throw (IO.userError "should not be called"))
    { staleTtl := 3600 }

/-- A cache stale returns the stale value and triggers a background refresh. -/
def testStale : Async (String × Nat) := do
  let cache ← makeCache "cache-stale"
  let callCount ← IO.mkRef 0
  let value ← cache.get "key" (fun _ => do
    callCount.modify fun c => c + 1
    pure "refreshed")
    { staleTtl := 3600 }
  IO.sleep 50
  let count ← callCount.get
  pure (value,count)

/-- A cache miss calls the callback and returns its result. -/
def testMiss : Async String := do
  let cache ← makeCache "cache-miss"
  cache.get "key" (fun _ => pure "computed")
    { staleTtl := 3600 }

/-- A cache miss with a failing callback propagates the error. -/
def testMissCallbackError : Async Bool := do
  let cache ← makeCache "cache-miss"
  try
    discard <| cache.get "key" (fun _ => do
      throw (IO.userError "cb error"))
      { staleTtl := 3600 }
    pure false
  catch _ =>
    pure true

/--
Two sequential stale requests: only one callback invocation
(stampede prevention via the inflight map).
-/
def testStaleInflight : Async (Nat × String × String) := do
  let cache ← makeCache "cache-stale-inflight"
  let callCount ← IO.mkRef 0
  let cb (_ : Unit) : Async String := do
    callCount.modify fun c => c + 1
    pure "refreshed"
  let r1 ← cache.get "key1" cb { staleTtl := 3600 }
  let r2 ← cache.get "key1" cb { staleTtl := 3600 }
  IO.sleep 50
  let count ← callCount.get
  pure (count, r1, r2)

/--
info: "hello"
-/
#guard_msgs in
#eval testHit.block

/--
info: ("hello", 1)
-/
#guard_msgs in
#eval testStale.block

/--
info: "computed"
-/
#guard_msgs in
#eval testMiss.block

/--
info: true
-/
#guard_msgs in
#eval testMissCallbackError.block

/--
info: (1, "hello", "hello")
-/
#guard_msgs in
#eval testStaleInflight.block

end LeanRedisTest.CacheSWR
