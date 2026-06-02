import LeanRedis.Client.Basic
import LeanRedis.Tools.ExpectResult

namespace LeanRedis.Client

open Std.Internal.IO.Async
open LeanRedis

/--
Get the value of a string key.

Example:
```lean
let value <- client.get "key"
```
-/
def get [Transport.Transport τ]
    (client : Client τ)
    (key : String)
    : Async (Option String) := do
  let reply <- Client.execute client <| CommandRequest.get key
  expectOptionalString "GET" reply

/--
Set a string key with optional `SET` modifiers.

Example:
```lean
let stored <- client.set "key" "value"
let storedNx <- client.set "key" "value" { condition? := some .nx }
```
-/
def set [Transport.Transport τ]
    (client : Client τ)
    (key value : String)
    (options : SetOptions := {})
    : Async Bool := do
  let reply <- Client.execute client <| CommandRequest.set key value options
  expectStored reply

/--
Get multiple string keys with nullable results.

Example:
```lean
let values <- client.mGet #["a", "b"]
```
-/
def mGet [Transport.Transport τ]
    (client : Client τ)
    (keys : Array String)
    : Async (Array (Option String)) := do
  let reply <- Client.execute client <| CommandRequest.mGet keys
  expectStringArray "MGET" reply

/--
Set multiple string entries with `MSET`.

Example:
```lean
let _ <- client.mSet #[("a", "1"), ("b", "2")]
```
-/
def mSet [Transport.Transport τ]
    (client : Client τ)
    (entries : Array (String × String))
    : Async Unit := do
  let reply <- Client.execute client <| CommandRequest.mSet entries
  expectOk reply

/--
Set multiple string entries only if all keys are absent.

Example:
```lean
let stored <- client.mSetNx #[("a", "1"), ("b", "2")]
```
-/
def mSetNx [Transport.Transport τ]
    (client : Client τ)
    (entries : Array (String × String))
    : Async Bool := do
  let reply <- Client.execute client <| CommandRequest.mSetNx entries
  expectBoolean "MSETNX" reply

/--
Get and delete a string key.

Example:
```lean
let previous <- client.getDel "key"
```
-/
def getDel [Transport.Transport τ]
    (client : Client τ)
    (key : String)
    : Async (Option String) := do
  let reply <- Client.execute client <| CommandRequest.getDel key
  expectOptionalString "GETDEL" reply

/--
Get a string key and optionally update its expiration.

Example:
```lean
let value <- client.getEx "key" (some <| .persist)
```
-/
def getEx [Transport.Transport τ]
    (client : Client τ)
    (key : String)
    (mode? : Option GetExMode := none)
    : Async (Option String) := do
  let reply <- Client.execute client <| CommandRequest.getEx key mode?
  expectOptionalString "GETEX" reply

/--
Read a substring from a string value.

Example:
```lean
let part <- client.getRange "key" 0 4
```
-/
def getRange [Transport.Transport τ]
    (client : Client τ)
    (key : String)
    (start stop : Int)
    : Async String := do
  let reply <- Client.execute client <| CommandRequest.getRange key start stop
  expectString "GETRANGE" reply

/--
Replace a string value and return the previous one.

Example:
```lean
let previous <- client.getSet "key" "next"
```
-/
def getSet [Transport.Transport τ]
    (client : Client τ)
    (key value : String)
    : Async (Option String) := do
  let reply <- Client.execute client <| CommandRequest.getSet key value
  expectOptionalString "GETSET" reply

/--
Overwrite part of a string starting at the given offset.

Example:
```lean
let size <- client.setRange "key" 2 "xy"
```
-/
def setRange [Transport.Transport τ]
    (client : Client τ)
    (key : String)
    (offset : UInt64)
    (value : String)
    : Async Int := do
  let reply <- Client.execute client <| CommandRequest.setRange key offset value
  expectInteger "SETRANGE" reply

/--
Return the length of a string value.

Example:
```lean
let len <- client.strLen "key"
```
-/
def strLen [Transport.Transport τ]
    (client : Client τ)
    (key : String)
    : Async Int := do
  let reply <- Client.execute client <| CommandRequest.strLen key
  expectInteger "STRLEN" reply

/--
Append text to a string value.

Example:
```lean
let len <- client.append "key" "suffix"
```
-/
def append [Transport.Transport τ]
    (client : Client τ)
    (key value : String)
    : Async Int := do
  let reply <- Client.execute client <| CommandRequest.append key value
  expectInteger "APPEND" reply

/--
Increment a string integer value by one.

Example:
```lean
let value <- client.incr "counter"
```
-/
def incr [Transport.Transport τ]
    (client : Client τ)
    (key : String)
    : Async Int := do
  let reply <- Client.execute client <| CommandRequest.incr key
  expectInteger "INCR" reply

/--
Increment a string integer value by the given amount.

Example:
```lean
let value <- client.incrBy "counter" 5
```
-/
def incrBy [Transport.Transport τ]
    (client : Client τ)
    (key : String)
    (amount : Int)
    : Async Int := do
  let reply <- Client.execute client <| CommandRequest.incrBy key amount
  expectInteger "INCRBY" reply

/--
Increment a string numeric value by a decimal amount.

Example:
```lean
let value <- client.incrByFloat "score" "1.5"
```
-/
def incrByFloat [Transport.Transport τ]
    (client : Client τ)
    (key amount : String)
    : Async String := do
  let reply <- Client.execute client <| CommandRequest.incrByFloat key amount
  expectString "INCRBYFLOAT" reply

/--
Decrement a string integer value by one.

Example:
```lean
let value <- client.decr "counter"
```
-/
def decr [Transport.Transport τ]
    (client : Client τ)
    (key : String)
    : Async Int := do
  let reply <- Client.execute client <| CommandRequest.decr key
  expectInteger "DECR" reply

/--
Decrement a string integer value by the given amount.

Example:
```lean
let value <- client.decrBy "counter" 3
```
-/
def decrBy [Transport.Transport τ]
    (client : Client τ)
    (key : String)
    (amount : Int)
    : Async Int := do
  let reply <- Client.execute client <| CommandRequest.decrBy key amount
  expectInteger "DECRBY" reply

/--
Set a string value only if the key does not exist.

Example:
```lean
let stored <- client.setNx "key" "value"
```
-/
def setNx [Transport.Transport τ]
    (client : Client τ)
    (key value : String)
    : Async Bool := do
  let reply <- Client.execute client <| CommandRequest.setNx key value
  expectBoolean "SETNX" reply

/--
Set a string value with a TTL in seconds.

Example:
```lean
let _ <- client.setEx "key" 30 "value"
```
-/
def setEx [Transport.Transport τ]
    (client : Client τ)
    (key : String)
    (seconds : UInt64)
    (value : String)
    : Async Unit := do
  let reply <- Client.execute client <| CommandRequest.setEx key seconds value
  expectOk reply

/--
Set a string value with a TTL in milliseconds.

Example:
```lean
let _ <- client.pSetEx "key" 500 "value"
```
-/
def pSetEx [Transport.Transport τ]
    (client : Client τ)
    (key : String)
    (milliseconds : UInt64)
    (value : String)
    : Async Unit := do
  let reply <- Client.execute client <| CommandRequest.pSetEx key milliseconds value
  expectOk reply

end LeanRedis.Client
