import LeanRedis
import LeanRedis.Pipeline
import Std.Sync.Mutex
import Test.Utils

open LeanRedis
open LeanRedisTest.Utils
open Std.Internal.IO.Async

namespace LeanRedisTest.Client.Pipeline

open LeanRedis.Connection

structure FakeTransport where
  replies : IO.Ref (Array ByteArray)
  writes : IO.Ref (Array ByteArray)

private def shiftReplies (ref : IO.Ref (Array ByteArray)) : IO (Option ByteArray) := do
  let replies <- ref.get
  match replies[0]? with
  | some reply =>
      ref.set (replies.extract 1 replies.size)
      pure (some reply)
  | none => pure none

private def writesOf (client : Client FakeTransport) : IO (Array ByteArray) := do
  client.state.atomically fun ref => do
    let state <- ref.get
    match state.transport? with
    | some transport => transport.writes.get
    | none => pure #[]

private def scriptedReplies (host : String) : Array ByteArray :=
  match host with
  | "pipeline-get-set-get" =>
      #[
        "%2\r\n+server\r\n+redis\r\n+proto\r\n:3\r\n".toUTF8,
        "$5\r\nhello\r\n".toUTF8,
        "+OK\r\n".toUTF8,
        "$4\r\ngood\r\n".toUTF8
      ]
  | "pipeline-set-mget" =>
      #[
        "%2\r\n+server\r\n+redis\r\n+proto\r\n:3\r\n".toUTF8,
        "+OK\r\n".toUTF8,
        "*2\r\n$1\r\na\r\n$1\r\nb\r\n".toUTF8
      ]
  | "pipeline-server-error" =>
      #[
        "%2\r\n+server\r\n+redis\r\n+proto\r\n:3\r\n".toUTF8,
        "$5\r\nhello\r\n".toUTF8,
        "-ERR bad command\r\n".toUTF8
      ]
  | "pipeline-incomplete-replies" =>
      #[
        "%2\r\n+server\r\n+redis\r\n+proto\r\n:3\r\n".toUTF8,
        "$5\r\nhello\r\n".toUTF8,
        ByteArray.empty
      ]
  | _ =>
      #[
        "%2\r\n+server\r\n+redis\r\n+proto\r\n:3\r\n".toUTF8,
        "+OK\r\n".toUTF8
      ]

instance : Transport.Transport FakeTransport where
  connect endpoint := do
    let replies <- IO.mkRef <| scriptedReplies endpoint.host
    let writes <- IO.mkRef #[]
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

def testPipelineGetSetGet : Async (HList [Option String, Bool, Option String]) := do
  let client : Client FakeTransport <- Client.new {
    endpoint := { host := "pipeline-get-set-get", port := 6379 }
  }
  client.connect
  return ← client.runPipeline <|
    Pipeline.empty
      |>.get "k1"
      |>.set "k2" "v"
      |>.get "k3"

def testPipelineSetMGet : Async (HList [Bool, Array (Option String)]) := do
  let client : Client FakeTransport <- Client.new {
    endpoint := { host := "pipeline-set-mget", port := 6379 }
  }
  client.connect
  return ← client.runPipeline <|
    Pipeline.empty
      |>.set "k" "v"
      |>.mGet #["a", "b"]

def testPipelineServerError : Async String := do
  try
    let client : Client FakeTransport <- Client.new {
      endpoint := { host := "pipeline-server-error", port := 6379 }
    }
    client.connect
    let _ <- client.runPipeline <|
      Pipeline.empty
        |>.get "k1"
        |>.get "k2"
    pure "unexpected success"
  catch err =>
    pure err.toString

def testPipelineWritesCount : Async Nat := do
  let client : Client FakeTransport <- Client.new {
    endpoint := { host := "pipeline-get-set-get", port := 6379 }
  }
  client.connect
  let _ <- client.runPipeline <|
    Pipeline.empty
      |>.get "k1"
      |>.set "k2" "v"
      |>.get "k3"
  let writes <- writesOf client
  pure writes.size

def testPipelineFailsWhenDisconnected : Async String := do
  try
    let client : Client FakeTransport <- Client.new {
      endpoint := { host := "pipeline-get-set-get", port := 6379 }
    }
    let _ <- client.runPipeline <|
      Pipeline.empty
        |>.get "k1"
    pure "unexpected success"
  catch err =>
    pure err.toString

def testPipelineIncompleteReplies : Async String := do
  try
    let client : Client FakeTransport <- Client.new {
      endpoint := { host := "pipeline-incomplete-replies", port := 6379 }
    }
    client.connect
    let _ <- client.runPipeline <|
      Pipeline.empty
        |>.get "k1"
        |>.get "k2"
    pure "unexpected success"
  catch err =>
    pure err.toString

/--
info: [some "hello", true, some "good"]ₕ
-/
#guard_msgs in
#eval testPipelineGetSetGet |>.block

/--
info: [true, #[some "a", some "b"]]ₕ
-/
#guard_msgs in
#eval testPipelineSetMGet |>.block

/--
info: "server error: ERR bad command"
-/
#guard_msgs in
#eval testPipelineServerError |>.block

/--
info: 4
-/
#guard_msgs in
#eval testPipelineWritesCount |>.block

/--
info: "unavailable: client is not connected"
-/
#guard_msgs in
#eval testPipelineFailsWhenDisconnected |>.block

/--
info: "transport error: connection closed while waiting for pipeline reply"
-/
#guard_msgs in
#eval testPipelineIncompleteReplies |>.block

end LeanRedisTest.Client.Pipeline
