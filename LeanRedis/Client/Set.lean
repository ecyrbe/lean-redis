import LeanRedis.Client.Basic
import LeanRedis.Command.Set

namespace LeanRedis

open Std.Internal.IO.Async
open LeanRedis

/--
Add members to a set.

Example:
```lean
let added ← client.sAdd "tags" #["lean", "redis"]
```
-/
def Client.sAdd [Transport.Transport τ]
    (client : Client τ)
    (key : String)
    (members : Array String)
    : Async Int := do
  let cmd := Command.sAdd key members
  let reply ← Client.execute client <| cmd.request
  cmd.decode reply

/--
Remove members from a set.

Example:
```lean
let removed ← client.sRem "tags" #["redis"]
```
-/
def Client.sRem [Transport.Transport τ]
    (client : Client τ)
    (key : String)
    (members : Array String)
    : Async Int := do
  let cmd := Command.sRem key members
  let reply ← Client.execute client <| cmd.request
  cmd.decode reply

/--
Return the cardinality of a set.

Example:
```lean
let size ← client.sCard "tags"
```
-/
def Client.sCard [Transport.Transport τ]
    (client : Client τ)
    (key : String)
    : Async Int := do
  let cmd := Command.sCard key
  let reply ← Client.execute client <| cmd.request
  cmd.decode reply

/--
Check whether a member belongs to a set.

Example:
```lean
let present ← client.sIsMember "tags" "lean"
```
-/
def Client.sIsMember [Transport.Transport τ]
    (client : Client τ)
    (key member : String)
    : Async Bool := do
  let cmd := Command.sIsMember key member
  let reply ← Client.execute client <| cmd.request
  cmd.decode reply

/--
Check multiple members against a set.

Example:
```lean
let present ← client.sMIsMember "tags" #["lean", "redis"]
```
-/
def Client.sMIsMember [Transport.Transport τ]
    (client : Client τ)
    (key : String)
    (members : Array String)
    : Async (Array Bool) := do
  let cmd := Command.sMIsMember key members
  let reply ← Client.execute client <| cmd.request
  cmd.decode reply

/--
Return all members of a set.

Example:
```lean
let members ← client.sMembers "tags"
```
-/
def Client.sMembers [Transport.Transport τ]
    (client : Client τ)
    (key : String)
    : Async (Array String) := do
  let cmd := Command.sMembers key
  let reply ← Client.execute client <| cmd.request
  cmd.decode reply

/--
Pop one random member from a set.

Example:
```lean
let member ← client.sPop "tags"
```
-/
def Client.sPop [Transport.Transport τ]
    (client : Client τ)
    (key : String)
    : Async (Option String) := do
  let cmd := Command.sPop key
  let reply ← Client.execute client <| cmd.request
  cmd.decode reply

/--
Pop multiple random members from a set.

Example:
```lean
let members ← client.sPopMany "tags" 2
```
-/
def Client.sPopMany [Transport.Transport τ]
    (client : Client τ)
    (key : String)
    (count : UInt64)
    : Async (Array String) := do
  let cmd := Command.sPopMany key count
  let reply ← Client.execute client <| cmd.request
  cmd.decode reply

/--
Return one random set member without removing it.

Example:
```lean
let member ← client.sRandMember "tags"
```
-/
def Client.sRandMember [Transport.Transport τ]
    (client : Client τ)
    (key : String)
    : Async (Option String) := do
  let cmd := Command.sRandMember key
  let reply ← Client.execute client <| cmd.request
  cmd.decode reply

/--
Return random set members without removing them.

Example:
```lean
let members ← client.sRandMembers "tags" 2
```
-/
def Client.sRandMembers [Transport.Transport τ]
    (client : Client τ)
    (key : String)
    (count : Int)
    : Async (Array String) := do
  let cmd := Command.sRandMembers key count
  let reply ← Client.execute client <| cmd.request
  cmd.decode reply

/--
Move a set member to another set.

Example:
```lean
let moved ← client.sMove "todo" "done" "task:1"
```
-/
def Client.sMove [Transport.Transport τ]
    (client : Client τ)
    (source destination member : String)
    : Async Bool := do
  let cmd := Command.sMove source destination member
  let reply ← Client.execute client <| cmd.request
  cmd.decode reply

/--
Return the difference of multiple sets.

Example:
```lean
let members ← client.sDiff #["a", "b"]
```
-/
def Client.sDiff [Transport.Transport τ]
    (client : Client τ)
    (keys : Array String)
    : Async (Array String) := do
  let cmd := Command.sDiff keys
  let reply ← Client.execute client <| cmd.request
  cmd.decode reply

/--
Store the difference of multiple sets into a destination key.

Example:
```lean
let size ← client.sDiffStore "result" #["a", "b"]
```
-/
def Client.sDiffStore [Transport.Transport τ]
    (client : Client τ)
    (destination : String)
    (keys : Array String)
    : Async Int := do
  let cmd := Command.sDiffStore destination keys
  let reply ← Client.execute client <| cmd.request
  cmd.decode reply

/--
Return the intersection of multiple sets.

Example:
```lean
let members ← client.sInter #["a", "b"]
```
-/
def Client.sInter [Transport.Transport τ]
    (client : Client τ)
    (keys : Array String)
    : Async (Array String) := do
  let cmd := Command.sInter keys
  let reply ← Client.execute client <| cmd.request
  cmd.decode reply

/--
Return the intersection cardinality of multiple sets.

Example:
```lean
let size ← client.sInterCard #["a", "b"]
```
-/
def Client.sInterCard [Transport.Transport τ]
    (client : Client τ)
    (keys : Array String)
    : Async Int := do
  let cmd := Command.sInterCard keys
  let reply ← Client.execute client <| cmd.request
  cmd.decode reply

/--
Store the intersection of multiple sets into a destination key.

Example:
```lean
let size ← client.sInterStore "result" #["a", "b"]
```
-/
def Client.sInterStore [Transport.Transport τ]
    (client : Client τ)
    (destination : String)
    (keys : Array String)
    : Async Int := do
  let cmd := Command.sInterStore destination keys
  let reply ← Client.execute client <| cmd.request
  cmd.decode reply

/--
Return the union of multiple sets.

Example:
```lean
let members ← client.sUnion #["a", "b"]
```
-/
def Client.sUnion [Transport.Transport τ]
    (client : Client τ)
    (keys : Array String)
    : Async (Array String) := do
  let cmd := Command.sUnion keys
  let reply ← Client.execute client <| cmd.request
  cmd.decode reply

/--
Store the union of multiple sets into a destination key.

Example:
```lean
let size ← client.sUnionStore "result" #["a", "b"]
```
-/
def Client.sUnionStore [Transport.Transport τ]
    (client : Client τ)
    (destination : String)
    (keys : Array String)
    : Async Int := do
  let cmd := Command.sUnionStore destination keys
  let reply ← Client.execute client <| cmd.request
  cmd.decode reply

/--
Scan a set incrementally.

Example:
```lean
let page ← client.sScan "tags" 0
```
-/
def Client.sScan [Transport.Transport τ]
    (client : Client τ)
    (key : String)
    (cursor : UInt64)
    (options : SScanOptions := {})
    : Async SetScanResult := do
  let cmd := Command.sScan key cursor options
  let reply ← Client.execute client <| cmd.request
  cmd.decode reply

end LeanRedis
