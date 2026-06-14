import LeanRedis
import LeanRedis.Pipeline
import Test.Utils

open LeanRedis
open LeanRedisTest.Utils

namespace LeanRedisTest.Pipeline.Basic

def testEmptyPipelineLength : Nat :=
  (Pipeline.empty : Pipeline []).length

def testEmptyPipelineExec : String :=
  match Pipeline.exec (Pipeline.empty : Pipeline []) #[] with
  | .ok _ => "ok"
  | .error _ => "error"

def testFromCommandPing : String :=
  let p := Pipeline.fromCommand (Command.ping)
  match p.exec #[.simpleString "PONG"] with
  | .ok ((none, ())) => "ok"
  | .ok _ => "unexpected"
  | .error _ => "error"

def testFromCommandSetOk : String :=
  let p := Pipeline.fromCommand (Command.set "key" "val")
  match p.exec #[.simpleString "OK"] with
  | .ok ((true, ())) => "ok"
  | .ok _ => "unexpected"
  | .error _ => "error"

def testFromCommandDel : String :=
  let p := Pipeline.fromCommand (Command.del #["a"])
  match p.exec #[.number 1] with
  | .ok ((1, ())) => "ok"
  | .ok _ => "unexpected"
  | .error _ => "error"

def testHAppendLength : Nat :=
  let p1 := Pipeline.fromCommand (Command.ping (some "hello"))
  let p2 := Pipeline.fromCommand (Command.ping)
  (p1 ++ p2).length

def testHAppendDecode : String :=
  let p1 := Pipeline.fromCommand (Command.ping (some "hello"))
  let p2 := Pipeline.fromCommand (Command.ping)
  let p := p1 ++ p2
  match p.exec #[.simpleString "hello", .simpleString "PONG"] with
  | .ok ((some "hello", (none, ()))) => "ok"
  | .ok _ => "unexpected"
  | .error _ => "error"

def testPipelineChaining : String :=
  open LeanRedis.Pipeline in
  let p := Pipeline.empty
    |>.get "k1"
    |>.set "k2" "v"
    |>.get "k3"
  match p.exec #[
    .blobString "val1".toUTF8,
    .simpleString "OK",
    .blobString "val3".toUTF8
  ] with
  | .ok ((some "val1", (true, (some "val3", ())))) => "ok"
  | .ok _ => "unexpected"
  | .error _ => "error"

/--
info: 0
-/
#guard_msgs in
#eval testEmptyPipelineLength

/--
info: "ok"
-/
#guard_msgs in
#eval testEmptyPipelineExec

/--
info: "ok"
-/
#guard_msgs in
#eval testFromCommandPing

/--
info: "ok"
-/
#guard_msgs in
#eval testFromCommandSetOk

/--
info: "ok"
-/
#guard_msgs in
#eval testFromCommandDel

/--
info: 2
-/
#guard_msgs in
#eval testHAppendLength

/--
info: "ok"
-/
#guard_msgs in
#eval testHAppendDecode

/--
info: "ok"
-/
#guard_msgs in
#eval testPipelineChaining

end LeanRedisTest.Pipeline.Basic
