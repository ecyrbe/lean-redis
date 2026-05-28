import LeanRedis
import Test.Utils

open LeanRedis
open LeanRedisTest.Utils
open Std.Internal.IO.Async

namespace LeanRedisTest.Connection.Runtime

structure ScriptedTransport where
  reads : IO.Ref (Array Transport.ReadResult)
  writes : IO.Ref (Array ByteArray)

private def shiftReads (ref : IO.Ref (Array Transport.ReadResult)) : IO Transport.ReadResult := do
  let reads <- ref.get
  match reads[0]? with
  | some read =>
      ref.set (reads.extract 1 reads.size)
      pure read
  | none =>
      pure { bytes := ByteArray.empty, disconnect? := some .closedByPeer }

private def mkTransport (reads : Array Transport.ReadResult) : IO ScriptedTransport := do
  let reads <- IO.mkRef reads
  let writes <- IO.mkRef #[]
  pure { reads, writes }

instance : Transport.Transport ScriptedTransport where
  connect _ := mkTransport #[]

  recv transport _ := do
    EAsync.lift <| shiftReads transport.reads

  send transport bytes := do
    EAsync.lift <| transport.writes.modify fun writes => writes.push bytes

  close _ := pure ()

def testRuntimeExecuteReadsFragmentedReply : Async String := do
  let transport <- EAsync.lift <| mkTransport #[
    { bytes := "$5\r\nhe".toUTF8 },
    { bytes := "llo\r\n".toUTF8 }
  ]
  let runtime : Connection.Runtime ScriptedTransport := { transport }
  let (reply, runtime) <- Connection.Runtime.execute runtime <| CommandRequest.ping
  let writes <- EAsync.lift <| runtime.transport.writes.get
  let payload <- match reply with
    | .blobString bytes => pure <| renderBytes bytes
    | _ => pure "unexpected"
  pure s!"{payload}|{writes.size}|{renderBytes <| writes[0]?.getD ByteArray.empty}"

def testRuntimeExecuteFailsWhenReplyDisconnects : IO String := do
  try
    let transport <- mkTransport #[
      { bytes := "$5\r\nhe".toUTF8 },
      { bytes := ByteArray.empty, disconnect? := some .closedByPeer }
    ]
    let runtime : Connection.Runtime ScriptedTransport := { transport }
    let _ <- (Connection.Runtime.execute runtime <| CommandRequest.ping).block
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
#eval testRuntimeExecuteFailsWhenReplyDisconnects

end LeanRedisTest.Connection.Runtime
