import LeanRedis
import Test.Utils

open LeanRedis
open LeanRedisTest.Utils
open Std.Internal.IO.Async

namespace LeanRedisTest.Connection.Runtime

structure ScriptedTransport where
  reads : IO.Ref (Array ByteArray)
  writes : IO.Ref (Array ByteArray)

private def shiftReads (ref : IO.Ref (Array ByteArray)) : IO ByteArray := do
  let reads <- ref.get
  match reads[0]? with
  | some bytes =>
      ref.set (reads.extract 1 reads.size)
      pure bytes
  | none =>
      pure ByteArray.empty

private def mkTransport (reads : Array ByteArray) : IO ScriptedTransport := do
  let reads <- IO.mkRef reads
  let writes <- IO.mkRef #[]
  pure { reads, writes }

instance : Transport.Transport ScriptedTransport where
  connect _ := mkTransport #[]

  recv transport _ := do
    shiftReads transport.reads

  send transport bytes := do
    transport.writes.modify fun writes => writes.push bytes

  sendAll transport chunks := do
    let combined := chunks.foldl (fun acc c => acc.append c) ByteArray.empty
    transport.writes.modify fun writes => writes.push combined

  close _ := pure ()

def testRuntimeExecuteReadsFragmentedReply : Async String := do
  let transport <- mkTransport #[
    "$5\r\nhe".toUTF8,
    "llo\r\n".toUTF8
  ]
  let runtime : Connection.Runtime ScriptedTransport := { transport }
  let (reply, runtime) ← (Connection.Runtime.execute (CommandRequest.ping)).run runtime
  let writes <- runtime.transport.writes.get
  let payload <- match reply with
    | .blobString bytes => pure <| renderBytes bytes
    | _ => pure "unexpected"
  pure s!"{payload}|{writes.size}|{renderBytes <| writes[0]?.getD ByteArray.empty}"

def testRuntimeExecuteFailsWhenReplyDisconnects : Async String := do
  try
    let transport <- mkTransport #[
      "$5\r\nhe".toUTF8,
      ByteArray.empty
    ]
    let runtime : Connection.Runtime ScriptedTransport := { transport }
    let _ ← (Connection.Runtime.execute (CommandRequest.ping)).run runtime
    pure "unexpected success"
  catch err =>
    pure err.toString

/--
info: "\"hello\"|1|\"*1\\r\\n$4\\r\\nPING\\r\\n\""
-/
#guard_msgs in
#eval testRuntimeExecuteReadsFragmentedReply |>.block

/--
info: "transport error: connection closed while waiting for reply"
-/
#guard_msgs in
#eval testRuntimeExecuteFailsWhenReplyDisconnects |>.block

def testRuntimeTryExecuteReportsRemoteDisconnect : Async String := do
  let transport <- mkTransport #[ByteArray.empty]
  let runtime : Connection.Runtime ScriptedTransport := { transport }
  let (result, _) ← (Connection.Runtime.tryExecute (CommandRequest.ping)).run runtime
  match result with
  | .ok _ => pure "unexpected success"
  | .error (.remoteDisconnect reason err) => pure s!"{repr reason}|{err.message}"
  | .error (.commandError err) => pure err.message

/--
info: "LeanRedis.Transport.DisconnectReason.closedByPeer|transport error: connection closed while waiting for reply"
-/
#guard_msgs in
#eval testRuntimeTryExecuteReportsRemoteDisconnect |>.block

end LeanRedisTest.Connection.Runtime
