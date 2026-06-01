import LeanRedis.Client.Internal
import LeanRedis.Tools.ExpectResult

namespace LeanRedis

open Std.Internal.IO.Async

/--
Push values to the left side of a list.

Example:
```lean
let len <- client.lPush "jobs" #["a", "b"]
```
-/
def Client.lPush [Transport.Transport τ]
    (client : Client τ)
    (key : String)
    (values : Array String)
    : Async Int := do
  let reply <- Client.execute client <| CommandRequest.lPush key values
  expectInteger "LPUSH" reply

/--
Push values to the right side of a list.

Example:
```lean
let len <- client.rPush "jobs" #["a", "b"]
```
-/
def Client.rPush [Transport.Transport τ]
    (client : Client τ)
    (key : String)
    (values : Array String)
    : Async Int := do
  let reply <- Client.execute client <| CommandRequest.rPush key values
  expectInteger "RPUSH" reply

/--
Push a value to the left only if the list already exists.

Example:
```lean
let len <- client.lPushX "jobs" "a"
```
-/
def Client.lPushX [Transport.Transport τ]
    (client : Client τ)
    (key value : String)
    : Async Int := do
  let reply <- Client.execute client <| CommandRequest.lPushX key value
  expectInteger "LPUSHX" reply

/--
Push a value to the right only if the list already exists.

Example:
```lean
let len <- client.rPushX "jobs" "a"
```
-/
def Client.rPushX [Transport.Transport τ]
    (client : Client τ)
    (key value : String)
    : Async Int := do
  let reply <- Client.execute client <| CommandRequest.rPushX key value
  expectInteger "RPUSHX" reply

/--
Pop one value from the left side of a list.

Example:
```lean
let value <- client.lPop "jobs"
```
-/
def Client.lPop [Transport.Transport τ]
    (client : Client τ)
    (key : String)
    : Async (Option String) := do
  let reply <- Client.execute client <| CommandRequest.lPop key
  expectOptionalString "LPOP" reply

/--
Pop one value from the right side of a list.

Example:
```lean
let value <- client.rPop "jobs"
```
-/
def Client.rPop [Transport.Transport τ]
    (client : Client τ)
    (key : String)
    : Async (Option String) := do
  let reply <- Client.execute client <| CommandRequest.rPop key
  expectOptionalString "RPOP" reply

/--
Return the current length of a list.

Example:
```lean
let len <- client.lLen "jobs"
```
-/
def Client.lLen [Transport.Transport τ]
    (client : Client τ)
    (key : String)
    : Async Int := do
  let reply <- Client.execute client <| CommandRequest.lLen key
  expectInteger "LLEN" reply

/--
Return the value at a list index.

Example:
```lean
let value <- client.lIndex "jobs" 0
```
-/
def Client.lIndex [Transport.Transport τ]
    (client : Client τ)
    (key : String)
    (index : Int)
    : Async (Option String) := do
  let reply <- Client.execute client <| CommandRequest.lIndex key index
  expectOptionalString "LINDEX" reply

/--
Return a range of list elements.

Example:
```lean
let values <- client.lRange "jobs" 0 (-1)
```
-/
def Client.lRange [Transport.Transport τ]
    (client : Client τ)
    (key : String)
    (start stop : Int)
    : Async (Array String) := do
  let reply <- Client.execute client <| CommandRequest.lRange key start stop
  expectPlainStringArray "LRANGE" reply

/--
Replace the value at a list index.

Example:
```lean
let _ <- client.lSet "jobs" 0 "next"
```
-/
def Client.lSet [Transport.Transport τ]
    (client : Client τ)
    (key : String)
    (index : Int)
    (value : String)
    : Async Unit := do
  let reply <- Client.execute client <| CommandRequest.lSet key index value
  expectOk reply

/--
Trim a list to the given inclusive range.

Example:
```lean
let _ <- client.lTrim "jobs" 0 9
```
-/
def Client.lTrim [Transport.Transport τ]
    (client : Client τ)
    (key : String)
    (start stop : Int)
    : Async Unit := do
  let reply <- Client.execute client <| CommandRequest.lTrim key start stop
  expectOk reply

/--
Remove matching elements from a list.

Example:
```lean
let removed <- client.lRem "jobs" 0 "done"
```
-/
def Client.lRem [Transport.Transport τ]
    (client : Client τ)
    (key : String)
    (count : Int)
    (value : String)
    : Async Int := do
  let reply <- Client.execute client <| CommandRequest.lRem key count value
  expectInteger "LREM" reply

/--
Insert a value before or after a pivot element.

Example:
```lean
let index <- client.lInsert "jobs" .after "a" "b"
```
-/
def Client.lInsert [Transport.Transport τ]
    (client : Client τ)
    (key : String)
    (position : LInsertPosition)
    (pivot value : String)
    : Async Int := do
  let reply <- Client.execute client <| CommandRequest.lInsert key position pivot value
  expectInteger "LINSERT" reply

/--
Move one element between lists.

Example:
```lean
let value <- client.lMove "jobs" "done" .left .right
```
-/
def Client.lMove [Transport.Transport τ]
    (client : Client τ)
    (source destination : String)
    (fromWhere toWhere : LMoveWhere)
    : Async (Option String) := do
  let reply <- Client.execute client <| CommandRequest.lMove source destination fromWhere toWhere
  expectOptionalString "LMOVE" reply

/--
Return a single matching position from `LPOS`.

Example:
```lean
let pos <- client.lPos "jobs" "a"
```
-/
def Client.lPos [Transport.Transport τ]
    (client : Client τ)
    (key element : String)
    (options : LPosOptions := {})
    : Async (Option Int) := do
  if options.count?.isSome then
    Error.raise <| .decode "LPOS with COUNT returns multiple positions; use lPosMany"
  let reply <- Client.execute client <| CommandRequest.lPos key element options
  match reply with
  | .null => pure none
  | .number value => pure (some value)
  | .simpleError message => Error.raise <| .server message
  | _ => Error.raise <| .decode "unexpected LPOS reply"

/--
Return multiple matching positions from `LPOS`.

Example:
```lean
let positions <- client.lPosMany "jobs" "a" { count? := some 3 }
```
-/
def Client.lPosMany [Transport.Transport τ]
    (client : Client τ)
    (key element : String)
    (options : LPosOptions)
    : Async (Array Int) := do
  match options.count? with
  | none => Error.raise <| .decode "lPosMany requires COUNT"
  | some _ =>
      let reply <- Client.execute client <| CommandRequest.lPos key element options
      expectIntegerArray "LPOS" reply

end LeanRedis
