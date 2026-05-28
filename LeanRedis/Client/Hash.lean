import LeanRedis.Client.Internal

namespace LeanRedis

open Std.Internal.IO.Async

/-- Get the value of a hash field.

Example:
```lean
let value <- client.hGet "user:1" "name"
```
-/
def Client.hGet [Transport.Transport τ]
    (client : Client τ)
    (key field : String)
    : Async (Option String) := do
  let reply <- Client.execute client <| CommandRequest.hGet key field
  Client.expectOptionalString "HGET" reply

/-- Set one or more hash fields.

Example:
```lean
let changed <- client.hSet "user:1" #[("name", "alice")]
```
-/
def Client.hSet [Transport.Transport τ]
    (client : Client τ)
    (key : String)
    (entries : Array (String × String))
    : Async Int := do
  let reply <- Client.execute client <| CommandRequest.hSet key entries
  Client.expectInteger "HSET" reply

/-- Get multiple hash fields.

Example:
```lean
let values <- client.hMGet "user:1" #["name", "role"]
```
-/
def Client.hMGet [Transport.Transport τ]
    (client : Client τ)
    (key : String)
    (fields : Array String)
    : Async (Array (Option String)) := do
  let reply <- Client.execute client <| CommandRequest.hMGet key fields
  Client.expectStringArray "HMGET" reply

/-- Set multiple hash fields with `HMSET`.

Example:
```lean
let _ <- client.hMSet "user:1" #[("name", "alice"), ("role", "admin")]
```
-/
def Client.hMSet [Transport.Transport τ]
    (client : Client τ)
    (key : String)
    (entries : Array (String × String))
    : Async Unit := do
  let reply <- Client.execute client <| CommandRequest.hMSet key entries
  Client.expectOk reply

/-- Get all hash fields and values.

Example:
```lean
let entries <- client.hGetAll "user:1"
```
-/
def Client.hGetAll [Transport.Transport τ]
    (client : Client τ)
    (key : String)
    : Async (Array (String × String)) := do
  let reply <- Client.execute client <| CommandRequest.hGetAll key
  Client.expectStringPairs "HGETALL" reply

/-- Delete one or more hash fields.

Example:
```lean
let removed <- client.hDel "user:1" #["role"]
```
-/
def Client.hDel [Transport.Transport τ]
    (client : Client τ)
    (key : String)
    (fields : Array String)
    : Async Int := do
  let reply <- Client.execute client <| CommandRequest.hDel key fields
  Client.expectInteger "HDEL" reply

/-- Check whether a hash field exists.

Example:
```lean
let exists <- client.hExists "user:1" "name"
```
-/
def Client.hExists [Transport.Transport τ]
    (client : Client τ)
    (key field : String)
    : Async Bool := do
  let reply <- Client.execute client <| CommandRequest.hExists key field
  Client.expectBoolean "HEXISTS" reply

/-- Return the number of fields in a hash.

Example:
```lean
let len <- client.hLen "user:1"
```
-/
def Client.hLen [Transport.Transport τ]
    (client : Client τ)
    (key : String)
    : Async Int := do
  let reply <- Client.execute client <| CommandRequest.hLen key
  Client.expectInteger "HLEN" reply

/-- Return all hash field names.

Example:
```lean
let keys <- client.hKeys "user:1"
```
-/
def Client.hKeys [Transport.Transport τ]
    (client : Client τ)
    (key : String)
    : Async (Array String) := do
  let reply <- Client.execute client <| CommandRequest.hKeys key
  Client.expectPlainStringArray "HKEYS" reply

/-- Return all hash values.

Example:
```lean
let vals <- client.hVals "user:1"
```
-/
def Client.hVals [Transport.Transport τ]
    (client : Client τ)
    (key : String)
    : Async (Array String) := do
  let reply <- Client.execute client <| CommandRequest.hVals key
  Client.expectPlainStringArray "HVALS" reply

/-- Return the string length of a hash field value.

Example:
```lean
let len <- client.hStrLen "user:1" "name"
```
-/
def Client.hStrLen [Transport.Transport τ]
    (client : Client τ)
    (key field : String)
    : Async Int := do
  let reply <- Client.execute client <| CommandRequest.hStrLen key field
  Client.expectInteger "HSTRLEN" reply

/-- Increment a hash integer field.

Example:
```lean
let value <- client.hIncrBy "stats" "count" 1
```
-/
def Client.hIncrBy [Transport.Transport τ]
    (client : Client τ)
    (key field : String)
    (amount : Int)
    : Async Int := do
  let reply <- Client.execute client <| CommandRequest.hIncrBy key field amount
  Client.expectInteger "HINCRBY" reply

/-- Increment a hash numeric field by a decimal amount.

Example:
```lean
let value <- client.hIncrByFloat "stats" "score" "1.5"
```
-/
def Client.hIncrByFloat [Transport.Transport τ]
    (client : Client τ)
    (key field amount : String)
    : Async String := do
  let reply <- Client.execute client <| CommandRequest.hIncrByFloat key field amount
  Client.expectString "HINCRBYFLOAT" reply

/-- Set a hash field only if it does not exist.

Example:
```lean
let stored <- client.hSetNx "user:1" "name" "alice"
```
-/
def Client.hSetNx [Transport.Transport τ]
    (client : Client τ)
    (key field value : String)
    : Async Bool := do
  let reply <- Client.execute client <| CommandRequest.hSetNx key field value
  Client.expectBoolean "HSETNX" reply

/-- Return one random hash field.

Example:
```lean
let field <- client.hRandField "user:1"
```
-/
def Client.hRandField [Transport.Transport τ]
    (client : Client τ)
    (key : String)
    : Async (Option String) := do
  let reply <- Client.execute client <| CommandRequest.hRandField key
  Client.expectOptionalString "HRANDFIELD" reply

/-- Return random hash fields.

Example:
```lean
let fields <- client.hRandFields "user:1" 2
```
-/
def Client.hRandFields [Transport.Transport τ]
    (client : Client τ)
    (key : String)
    (count : Int)
    : Async (Array String) := do
  let reply <- Client.execute client <| CommandRequest.hRandFields key count
  Client.expectPlainStringArray "HRANDFIELD" reply

/-- Return random hash fields with values.

Example:
```lean
let entries <- client.hRandFieldsWithValues "user:1" 2
```
-/
def Client.hRandFieldsWithValues [Transport.Transport τ]
    (client : Client τ)
    (key : String)
    (count : Int)
    : Async (Array (String × String)) := do
  let reply <- Client.execute client <| CommandRequest.hRandFieldsWithValues key count
  Client.expectStringPairs "HRANDFIELD" reply

/-- Scan a hash incrementally.

Example:
```lean
let page <- client.hScan "user:1" 0
```
-/
def Client.hScan [Transport.Transport τ]
    (client : Client τ)
    (key : String)
    (cursor : UInt64)
    (options : HScanOptions := {})
    : Async HashScanResult := do
  let reply <- Client.execute client <| CommandRequest.hScan key cursor options
  Client.expectHScanResult reply

end LeanRedis
