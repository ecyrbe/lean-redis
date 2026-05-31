import LeanRedis.Client.Internal
import LeanRedis.Tools.ExpectResult

namespace LeanRedis

open Std.Internal.IO.Async

/-- Add members to a set.

Example:
```lean
let added <- client.sAdd "tags" #["lean", "redis"]
```
-/
def Client.sAdd [Transport.Transport τ]
    (client : Client τ)
    (key : String)
    (members : Array String)
    : Async Int := do
  let reply <- Client.execute client <| CommandRequest.sAdd key members
  expectInteger "SADD" reply

/-- Remove members from a set.

Example:
```lean
let removed <- client.sRem "tags" #["redis"]
```
-/
def Client.sRem [Transport.Transport τ]
    (client : Client τ)
    (key : String)
    (members : Array String)
    : Async Int := do
  let reply <- Client.execute client <| CommandRequest.sRem key members
  expectInteger "SREM" reply

/-- Return the cardinality of a set.

Example:
```lean
let size <- client.sCard "tags"
```
-/
def Client.sCard [Transport.Transport τ]
    (client : Client τ)
    (key : String)
    : Async Int := do
  let reply <- Client.execute client <| CommandRequest.sCard key
  expectInteger "SCARD" reply

/-- Check whether a member belongs to a set.

Example:
```lean
let present <- client.sIsMember "tags" "lean"
```
-/
def Client.sIsMember [Transport.Transport τ]
    (client : Client τ)
    (key member : String)
    : Async Bool := do
  let reply <- Client.execute client <| CommandRequest.sIsMember key member
  expectBoolean "SISMEMBER" reply

/-- Check multiple members against a set.

Example:
```lean
let present <- client.sMIsMember "tags" #["lean", "redis"]
```
-/
def Client.sMIsMember [Transport.Transport τ]
    (client : Client τ)
    (key : String)
    (members : Array String)
    : Async (Array Bool) := do
  let reply <- Client.execute client <| CommandRequest.sMIsMember key members
  match reply with
  | .array items =>
      items.mapM (expectBoolean "SMISMEMBER")
  | .simpleError message => Error.raise <| .server message
  | _ => Error.raise <| .decode "unexpected SMISMEMBER reply"

/-- Return all members of a set.

Example:
```lean
let members <- client.sMembers "tags"
```
-/
def Client.sMembers [Transport.Transport τ]
    (client : Client τ)
    (key : String)
    : Async (Array String) := do
  let reply <- Client.execute client <| CommandRequest.sMembers key
  expectPlainStringArray "SMEMBERS" reply

/-- Pop one random member from a set.

Example:
```lean
let member <- client.sPop "tags"
```
-/
def Client.sPop [Transport.Transport τ]
    (client : Client τ)
    (key : String)
    : Async (Option String) := do
  let reply <- Client.execute client <| CommandRequest.sPop key
  expectOptionalString "SPOP" reply

/-- Pop multiple random members from a set.

Example:
```lean
let members <- client.sPopMany "tags" 2
```
-/
def Client.sPopMany [Transport.Transport τ]
    (client : Client τ)
    (key : String)
    (count : UInt64)
    : Async (Array String) := do
  let reply <- Client.execute client <| CommandRequest.sPopCount key count
  expectPlainStringArray "SPOP" reply

/-- Return one random set member without removing it.

Example:
```lean
let member <- client.sRandMember "tags"
```
-/
def Client.sRandMember [Transport.Transport τ]
    (client : Client τ)
    (key : String)
    : Async (Option String) := do
  let reply <- Client.execute client <| CommandRequest.sRandMember key
  expectOptionalString "SRANDMEMBER" reply

/-- Return random set members without removing them.

Example:
```lean
let members <- client.sRandMembers "tags" 2
```
-/
def Client.sRandMembers [Transport.Transport τ]
    (client : Client τ)
    (key : String)
    (count : Int)
    : Async (Array String) := do
  let reply <- Client.execute client <| CommandRequest.sRandMembers key count
  match (← expectOptionalStringOrArray "SRANDMEMBER" reply) with
  | .inl none => pure #[]
  | .inl (some value) => pure #[value]
  | .inr values => pure values

/-- Move a set member to another set.

Example:
```lean
let moved <- client.sMove "todo" "done" "task:1"
```
-/
def Client.sMove [Transport.Transport τ]
    (client : Client τ)
    (source destination member : String)
    : Async Bool := do
  let reply <- Client.execute client <| CommandRequest.sMove source destination member
  expectBoolean "SMOVE" reply

/-- Return the difference of multiple sets.

Example:
```lean
let members <- client.sDiff #["a", "b"]
```
-/
def Client.sDiff [Transport.Transport τ]
    (client : Client τ)
    (keys : Array String)
    : Async (Array String) := do
  let reply <- Client.execute client <| CommandRequest.sDiff keys
  expectPlainStringArray "SDIFF" reply

/-- Store the difference of multiple sets into a destination key.

Example:
```lean
let size <- client.sDiffStore "result" #["a", "b"]
```
-/
def Client.sDiffStore [Transport.Transport τ]
    (client : Client τ)
    (destination : String)
    (keys : Array String)
    : Async Int := do
  let reply <- Client.execute client <| CommandRequest.sDiffStore destination keys
  expectInteger "SDIFFSTORE" reply

/-- Return the intersection of multiple sets.

Example:
```lean
let members <- client.sInter #["a", "b"]
```
-/
def Client.sInter [Transport.Transport τ]
    (client : Client τ)
    (keys : Array String)
    : Async (Array String) := do
  let reply <- Client.execute client <| CommandRequest.sInter keys
  expectPlainStringArray "SINTER" reply

/-- Return the intersection cardinality of multiple sets.

Example:
```lean
let size <- client.sInterCard #["a", "b"]
```
-/
def Client.sInterCard [Transport.Transport τ]
    (client : Client τ)
    (keys : Array String)
    : Async Int := do
  let reply <- Client.execute client <| CommandRequest.sInterCard keys
  expectInteger "SINTERCARD" reply

/-- Store the intersection of multiple sets into a destination key.

Example:
```lean
let size <- client.sInterStore "result" #["a", "b"]
```
-/
def Client.sInterStore [Transport.Transport τ]
    (client : Client τ)
    (destination : String)
    (keys : Array String)
    : Async Int := do
  let reply <- Client.execute client <| CommandRequest.sInterStore destination keys
  expectInteger "SINTERSTORE" reply

/-- Return the union of multiple sets.

Example:
```lean
let members <- client.sUnion #["a", "b"]
```
-/
def Client.sUnion [Transport.Transport τ]
    (client : Client τ)
    (keys : Array String)
    : Async (Array String) := do
  let reply <- Client.execute client <| CommandRequest.sUnion keys
  expectPlainStringArray "SUNION" reply

/-- Store the union of multiple sets into a destination key.

Example:
```lean
let size <- client.sUnionStore "result" #["a", "b"]
```
-/
def Client.sUnionStore [Transport.Transport τ]
    (client : Client τ)
    (destination : String)
    (keys : Array String)
    : Async Int := do
  let reply <- Client.execute client <| CommandRequest.sUnionStore destination keys
  expectInteger "SUNIONSTORE" reply

/-- Scan a set incrementally.

Example:
```lean
let page <- client.sScan "tags" 0
```
-/
def Client.sScan [Transport.Transport τ]
    (client : Client τ)
    (key : String)
    (cursor : UInt64)
    (options : SScanOptions := {})
    : Async SetScanResult := do
  let reply <- Client.execute client <| CommandRequest.sScan key cursor options
  expectSetScanResult reply

end LeanRedis
