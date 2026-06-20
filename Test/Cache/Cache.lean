import LeanRedis
import Std.Sync.Mutex
import Test.Utils

open LeanRedis
open LeanRedisTest.Utils
open Std.Async

namespace LeanRedisTest.Cache

structure FakeTransport where
  replies : Std.Mutex (Array ByteArray)
  writes : IO.Ref (Array ByteArray)

private def helloReply : ByteArray :=
  "%2\r\n+server\r\n+redis\r\n+proto\r\n:3\r\n".toUTF8

private def redisNull : ByteArray :=
  "_\r\n".toUTF8

private def okReply : ByteArray :=
  "+OK\r\n".toUTF8

private def scriptedReplies (host : String) : Array ByteArray :=
  match host with
  | "cache-hit" =>
      #[helloReply, "$5\r\nhello\r\n".toUTF8]
  | "cache-miss" =>
      #[helloReply, redisNull, okReply]
  | "cache-stampede" =>
      #[helloReply, redisNull, okReply]
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

private def makeCache (host : String) : Async (Cache FakeTransport) :=
  Cache.new {
    endpoint := { host, port := 6379 }
  }

/-- A cache hit returns the Redis value without calling the callback. -/
def testHit : Async String := do
  let cache ← makeCache "cache-hit"
  cache.get "key" fun _ => do
    throw (IO.userError "should not be called")

/-- A cache miss calls the callback and returns its result. -/
def testMiss : Async String := do
  let cache ← makeCache "cache-miss"
  cache.get "key" fun _ => pure "computed"

/-- A cache miss with a failing callback propagates the error. -/
def testMissCallbackError : Async Bool := do
  let cache ← makeCache "cache-miss"
  try
    discard <| cache.get "key" fun _ => do
      throw (IO.userError "cb error")
    pure false
  catch _ =>
    pure true

/--
Two sequential requests for the same key: only one callback invocation
(stampede prevention via the inflight map).
-/
def testStampede : Async Bool := do
  let cache ← makeCache "cache-stampede"
  let callCount ← IO.mkRef 0
  let cb (_ : Unit) : Async String := do
    callCount.modify fun c => c + 1
    pure "computed"
  let r1 ← cache.get "key1" cb
  let r2 ← cache.get "key1" cb
  let count ← callCount.get
  pure (count == 1 && r1 == "computed" && r2 == "computed")

/--
info: "hello"
-/
#guard_msgs in
#eval testHit.block

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
info: true
-/
#guard_msgs in
#eval testStampede.block

end LeanRedisTest.Cache
