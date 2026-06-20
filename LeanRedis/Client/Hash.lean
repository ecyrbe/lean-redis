import LeanRedis.Client.Basic
import LeanRedis.Command.Hash

namespace LeanRedis

open Std.Async
open LeanRedis

/--
Get the value of a hash field.

Example:
```lean
let value ← client.hGet "user:1" "name"
```
-/
def Client.hGet [Transport.Transport τ]
    (client : Client τ)
    (key field : String)
    : Async (Option String) := do
  let cmd := Command.hGet key field
  let reply ← Client.execute client <| cmd.request
  cmd.decode reply

/--
Set one or more hash fields.

Example:
```lean
let changed ← client.hSet "user:1" #[("name", "alice")]
```
-/
def Client.hSet [Transport.Transport τ]
    (client : Client τ)
    (key : String)
    (entries : Array (String × String))
    : Async Int := do
  let cmd := Command.hSet key entries
  let reply ← Client.execute client <| cmd.request
  cmd.decode reply

/--
Get multiple hash fields.

Example:
```lean
let values ← client.hMGet "user:1" #["name", "role"]
```
-/
def Client.hMGet [Transport.Transport τ]
    (client : Client τ)
    (key : String)
    (fields : Array String)
    : Async (Array (Option String)) := do
  let cmd := Command.hMGet key fields
  let reply ← Client.execute client <| cmd.request
  cmd.decode reply

/--
Set multiple hash fields with `HMSET`.

Example:
```lean
let _ ← client.hMSet "user:1" #[("name", "alice"), ("role", "admin")]
```
-/
def Client.hMSet [Transport.Transport τ]
    (client : Client τ)
    (key : String)
    (entries : Array (String × String))
    : Async Unit := do
  let cmd := Command.hMSet key entries
  let reply ← Client.execute client <| cmd.request
  cmd.decode reply

/--
Get all hash fields and values.

Example:
```lean
let entries ← client.hGetAll "user:1"
```
-/
def Client.hGetAll [Transport.Transport τ]
    (client : Client τ)
    (key : String)
    : Async (Array (String × String)) := do
  let cmd := Command.hGetAll key
  let reply ← Client.execute client <| cmd.request
  cmd.decode reply

/--
Delete one or more hash fields.

Example:
```lean
let removed ← client.hDel "user:1" #["role"]
```
-/
def Client.hDel [Transport.Transport τ]
    (client : Client τ)
    (key : String)
    (fields : Array String)
    : Async Int := do
  let cmd := Command.hDel key fields
  let reply ← Client.execute client <| cmd.request
  cmd.decode reply

/--
Check whether a hash field exists.

Example:
```lean
let exists ← client.hExists "user:1" "name"
```
-/
def Client.hExists [Transport.Transport τ]
    (client : Client τ)
    (key field : String)
    : Async Bool := do
  let cmd := Command.hExists key field
  let reply ← Client.execute client <| cmd.request
  cmd.decode reply

/--
Return the number of fields in a hash.

Example:
```lean
let len ← client.hLen "user:1"
```
-/
def Client.hLen [Transport.Transport τ]
    (client : Client τ)
    (key : String)
    : Async Int := do
  let cmd := Command.hLen key
  let reply ← Client.execute client <| cmd.request
  cmd.decode reply

/--
Return all hash field names.

Example:
```lean
let keys ← client.hKeys "user:1"
```
-/
def Client.hKeys [Transport.Transport τ]
    (client : Client τ)
    (key : String)
    : Async (Array String) := do
  let cmd := Command.hKeys key
  let reply ← Client.execute client <| cmd.request
  cmd.decode reply

/--
Return all hash values.

Example:
```lean
let vals ← client.hVals "user:1"
```
-/
def Client.hVals [Transport.Transport τ]
    (client : Client τ)
    (key : String)
    : Async (Array String) := do
  let cmd := Command.hVals key
  let reply ← Client.execute client <| cmd.request
  cmd.decode reply

/--
Return the string length of a hash field value.

Example:
```lean
let len ← client.hStrLen "user:1" "name"
```
-/
def Client.hStrLen [Transport.Transport τ]
    (client : Client τ)
    (key field : String)
    : Async Int := do
  let cmd := Command.hStrLen key field
  let reply ← Client.execute client <| cmd.request
  cmd.decode reply

/--
Increment a hash integer field.

Example:
```lean
let value ← client.hIncrBy "stats" "count" 1
```
-/
def Client.hIncrBy [Transport.Transport τ]
    (client : Client τ)
    (key field : String)
    (amount : Int)
    : Async Int := do
  let cmd := Command.hIncrBy key field amount
  let reply ← Client.execute client <| cmd.request
  cmd.decode reply

/--
Increment a hash numeric field by a decimal amount.

Example:
```lean
let value ← client.hIncrByFloat "stats" "score" "1.5"
```
-/
def Client.hIncrByFloat [Transport.Transport τ]
    (client : Client τ)
    (key field amount : String)
    : Async String := do
  let cmd := Command.hIncrByFloat key field amount
  let reply ← Client.execute client <| cmd.request
  cmd.decode reply

/--
Set a hash field only if it does not exist.

Example:
```lean
let stored ← client.hSetNx "user:1" "name" "alice"
```
-/
def Client.hSetNx [Transport.Transport τ]
    (client : Client τ)
    (key field value : String)
    : Async Bool := do
  let cmd := Command.hSetNx key field value
  let reply ← Client.execute client <| cmd.request
  cmd.decode reply

/--
Return one random hash field.

Example:
```lean
let field ← client.hRandField "user:1"
```
-/
def Client.hRandField [Transport.Transport τ]
    (client : Client τ)
    (key : String)
    : Async (Option String) := do
  let cmd := Command.hRandField key
  let reply ← Client.execute client <| cmd.request
  cmd.decode reply

/--
Return random hash fields.

Example:
```lean
let fields ← client.hRandFields "user:1" 2
```
-/
def Client.hRandFields [Transport.Transport τ]
    (client : Client τ)
    (key : String)
    (count : Int)
    : Async (Array String) := do
  let cmd := Command.hRandFields key count
  let reply ← Client.execute client <| cmd.request
  cmd.decode reply

/--
Return random hash fields with values.

Example:
```lean
let entries ← client.hRandFieldsWithValues "user:1" 2
```
-/
def Client.hRandFieldsWithValues [Transport.Transport τ]
    (client : Client τ)
    (key : String)
    (count : Int)
    : Async (Array (String × String)) := do
  let cmd := Command.hRandFieldsWithValues key count
  let reply ← Client.execute client <| cmd.request
  cmd.decode reply

/--
Scan a hash incrementally.

Example:
```lean
let page ← client.hScan "user:1" 0
```
-/
def Client.hScan [Transport.Transport τ]
    (client : Client τ)
    (key : String)
    (cursor : UInt64)
    (options : HScanOptions := {})
    : Async HashScanResult := do
  let cmd := Command.hScan key cursor options
  let reply ← Client.execute client <| cmd.request
  cmd.decode reply

end LeanRedis
