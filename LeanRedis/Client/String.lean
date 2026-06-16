import LeanRedis.Client.Basic
import LeanRedis.Command.String

namespace LeanRedis

open Std.Internal.IO.Async
open LeanRedis

/--
Get the value of a string key.

Example:
```lean
let value ← client.get "key"
```
-/
def Client.get [Transport.Transport τ]
    (client : Client τ)
    (key : String)
    : Async (Option String) := do
  let cmd := Command.get key
  let reply ← Client.execute client <| cmd.request
  cmd.decode reply

/--
Set a string key with optional `SET` modifiers.

Example:
```lean
let stored ← client.set "key" "value"
let storedNx ← client.set "key" "value" { condition? := some .nx }
```
-/
def Client.set [Transport.Transport τ]
    (client : Client τ)
    (key value : String)
    (options : SetOptions := {})
    : Async Bool := do
  let cmd := Command.set key value options
  let reply ← Client.execute client <| cmd.request
  cmd.decode reply

/--
Get multiple string keys with nullable results.

Example:
```lean
let values ← client.mGet #["a", "b"]
```
-/
def Client.mGet [Transport.Transport τ]
    (client : Client τ)
    (keys : Array String)
    : Async (Array (Option String)) := do
  let cmd := Command.mGet keys
  let reply ← Client.execute client <| cmd.request
  cmd.decode reply

/--
Set multiple string entries with `MSET`.

Example:
```lean
let _ ← client.mSet #[("a", "1"), ("b", "2")]
```
-/
def Client.mSet [Transport.Transport τ]
    (client : Client τ)
    (entries : Array (String × String))
    : Async Unit := do
  let cmd := Command.mSet entries
  let reply ← Client.execute client <| cmd.request
  cmd.decode reply

/--
Set multiple string entries only if all keys are absent.

Example:
```lean
let stored ← client.mSetNx #[("a", "1"), ("b", "2")]
```
-/
def Client.mSetNx [Transport.Transport τ]
    (client : Client τ)
    (entries : Array (String × String))
    : Async Bool := do
  let cmd := Command.mSetNx entries
  let reply ← Client.execute client <| cmd.request
  cmd.decode reply

/--
Get and delete a string key.

Example:
```lean
let previous ← client.getDel "key"
```
-/
def Client.getDel [Transport.Transport τ]
    (client : Client τ)
    (key : String)
    : Async (Option String) := do
  let cmd := Command.getDel key
  let reply ← Client.execute client <| cmd.request
  cmd.decode reply

/--
Get a string key and optionally update its expiration.

Example:
```lean
let value ← client.getEx "key" (some <| .persist)
```
-/
def Client.getEx [Transport.Transport τ]
    (client : Client τ)
    (key : String)
    (mode? : Option GetExMode := none)
    : Async (Option String) := do
  let cmd := Command.getEx key mode?
  let reply ← Client.execute client <| cmd.request
  cmd.decode reply

/--
Read a substring from a string value.

Example:
```lean
let part ← client.getRange "key" 0 4
```
-/
def Client.getRange [Transport.Transport τ]
    (client : Client τ)
    (key : String)
    (start stop : Int)
    : Async String := do
  let cmd := Command.getRange key start stop
  let reply ← Client.execute client <| cmd.request
  cmd.decode reply

/--
Replace a string value and return the previous one.

Example:
```lean
let previous ← client.getSet "key" "next"
```
-/
def Client.getSet [Transport.Transport τ]
    (client : Client τ)
    (key value : String)
    : Async (Option String) := do
  let cmd := Command.getSet key value
  let reply ← Client.execute client <| cmd.request
  cmd.decode reply

/--
Overwrite part of a string starting at the given offset.

Example:
```lean
let size ← client.setRange "key" 2 "xy"
```
-/
def Client.setRange [Transport.Transport τ]
    (client : Client τ)
    (key : String)
    (offset : UInt64)
    (value : String)
    : Async Int := do
  let cmd := Command.setRange key offset value
  let reply ← Client.execute client <| cmd.request
  cmd.decode reply

/--
Return the length of a string value.

Example:
```lean
let len ← client.strLen "key"
```
-/
def Client.strLen [Transport.Transport τ]
    (client : Client τ)
    (key : String)
    : Async Int := do
  let cmd := Command.strLen key
  let reply ← Client.execute client <| cmd.request
  cmd.decode reply

/--
Append text to a string value.

Example:
```lean
let len ← client.append "key" "suffix"
```
-/
def Client.append [Transport.Transport τ]
    (client : Client τ)
    (key value : String)
    : Async Int := do
  let cmd := Command.append key value
  let reply ← Client.execute client <| cmd.request
  cmd.decode reply

/--
Increment a string integer value by one.

Example:
```lean
let value ← client.incr "counter"
```
-/
def Client.incr [Transport.Transport τ]
    (client : Client τ)
    (key : String)
    : Async Int := do
  let cmd := Command.incr key
  let reply ← Client.execute client <| cmd.request
  cmd.decode reply

/--
Increment a string integer value by the given amount.

Example:
```lean
let value ← client.incrBy "counter" 5
```
-/
def Client.incrBy [Transport.Transport τ]
    (client : Client τ)
    (key : String)
    (amount : Int)
    : Async Int := do
  let cmd := Command.incrBy key amount
  let reply ← Client.execute client <| cmd.request
  cmd.decode reply

/--
Increment a string numeric value by a decimal amount.

Example:
```lean
let value ← client.incrByFloat "score" "1.5"
```
-/
def Client.incrByFloat [Transport.Transport τ]
    (client : Client τ)
    (key amount : String)
    : Async String := do
  let cmd := Command.incrByFloat key amount
  let reply ← Client.execute client <| cmd.request
  cmd.decode reply

/--
Decrement a string integer value by one.

Example:
```lean
let value ← client.decr "counter"
```
-/
def Client.decr [Transport.Transport τ]
    (client : Client τ)
    (key : String)
    : Async Int := do
  let cmd := Command.decr key
  let reply ← Client.execute client <| cmd.request
  cmd.decode reply

/--
Decrement a string integer value by the given amount.

Example:
```lean
let value ← client.decrBy "counter" 3
```
-/
def Client.decrBy [Transport.Transport τ]
    (client : Client τ)
    (key : String)
    (amount : Int)
    : Async Int := do
  let cmd := Command.decrBy key amount
  let reply ← Client.execute client <| cmd.request
  cmd.decode reply

/--
Set a string value only if the key does not exist.

Example:
```lean
let stored ← client.setNx "key" "value"
```
-/
def Client.setNx [Transport.Transport τ]
    (client : Client τ)
    (key value : String)
    : Async Bool := do
  let cmd := Command.setNx key value
  let reply ← Client.execute client <| cmd.request
  cmd.decode reply

/--
Set a string value with a TTL in seconds.

Example:
```lean
let _ ← client.setEx "key" 30 "value"
```
-/
def Client.setEx [Transport.Transport τ]
    (client : Client τ)
    (key : String)
    (seconds : UInt64)
    (value : String)
    : Async Unit := do
  let cmd := Command.setEx key seconds value
  let reply ← Client.execute client <| cmd.request
  cmd.decode reply

/--
Set a string value with a TTL in milliseconds.

Example:
```lean
let _ ← client.pSetEx "key" 500 "value"
```
-/
def Client.pSetEx [Transport.Transport τ]
    (client : Client τ)
    (key : String)
    (milliseconds : UInt64)
    (value : String)
    : Async Unit := do
  let cmd := Command.pSetEx key milliseconds value
  let reply ← Client.execute client <| cmd.request
  cmd.decode reply

end LeanRedis
