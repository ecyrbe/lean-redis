import LeanRedis.Client.Basic
import LeanRedis.Command.Generic

namespace LeanRedis

open Std.Async
open LeanRedis

/--
Copy a key to a new key.

Example:
```lean
let copied ← client.copy "src" "dst"
```
-/
def Client.copy [Transport.Transport τ]
    (client : Client τ)
    (source destination : String)
    (options : CopyOptions := {})
    : Async Bool := do
  let cmd := Command.copy source destination options
  let reply ← Client.execute client <| cmd.request
  cmd.decode reply

/--
Delete one or more keys.

Example:
```lean
let removed ← client.del #["key1", "key2"]
```
-/
def Client.del [Transport.Transport τ]
    (client : Client τ)
    (keys : Array String)
    : Async Int := do
  let cmd := Command.del keys
  let reply ← Client.execute client <| cmd.request
  cmd.decode reply

/--
Dump a serialised version of the value stored at a key.

Example:
```lean
let serialized ← client.dump "key"
```
-/
def Client.dump [Transport.Transport τ]
    (client : Client τ)
    (key : String)
    : Async String := do
  let cmd := Command.dump key
  let reply ← Client.execute client <| cmd.request
  cmd.decode reply

/--
Determine whether one or more keys exist.

Example:
```lean
let count ← client.exists #["key1", "key2"]
```
-/
def Client.exists [Transport.Transport τ]
    (client : Client τ)
    (keys : Array String)
    : Async Int := do
  let cmd := Command.exists keys
  let reply ← Client.execute client <| cmd.request
  cmd.decode reply

/--
Set a key's time to live in seconds.

Example:
```lean
let set ← client.expire "key" 60
```
-/
def Client.expire [Transport.Transport τ]
    (client : Client τ)
    (key : String)
    (seconds : UInt64)
    (option : Option ExpireOption := none)
    : Async Bool := do
  let cmd := Command.expire key seconds option
  let reply ← Client.execute client <| cmd.request
  cmd.decode reply

/--
Set a key's time to live as a Unix timestamp in seconds.

Example:
```lean
let set ← client.expireAt "key" timestamp
```
-/
def Client.expireAt [Transport.Transport τ]
    (client : Client τ)
    (key : String)
    (timestamp : Std.Time.Timestamp)
    (option : Option ExpireOption := none)
    : Async Bool := do
  let cmd := Command.expireAt key timestamp option
  let reply ← Client.execute client <| cmd.request
  cmd.decode reply

/--
Get the expiration time of a key as a Unix timestamp in seconds.

Example:
```lean
let ts ← client.expireTime "key"
```
-/
def Client.expireTime [Transport.Transport τ]
    (client : Client τ)
    (key : String)
    : Async Int := do
  let cmd := Command.expireTime key
  let reply ← Client.execute client <| cmd.request
  cmd.decode reply

/--
Find all keys matching the given pattern.

Example:
```lean
let keys ← client.keys "user:*"
```
-/
def Client.keys [Transport.Transport τ]
    (client : Client τ)
    (pattern : String)
    : Async (Array String) := do
  let cmd := Command.keys pattern
  let reply ← Client.execute client <| cmd.request
  cmd.decode reply

/--
Move a key to another database.

Example:
```lean
let moved ← client.move "key" 1
```
-/
def Client.move [Transport.Transport τ]
    (client : Client τ)
    (key : String)
    (destinationDb : UInt32)
    : Async Bool := do
  let cmd := Command.move key destinationDb
  let reply ← Client.execute client <| cmd.request
  cmd.decode reply

/--
Get the internal encoding of a key's value.

Example:
```lean
let encoding ← client.objectEncoding "key"
```
-/
def Client.objectEncoding [Transport.Transport τ]
    (client : Client τ)
    (key : String)
    : Async String := do
  let cmd := Command.objectEncoding key
  let reply ← Client.execute client <| cmd.request
  cmd.decode reply

/--
Get the logarithmic access frequency counter of a key's value.

Example:
```lean
let freq ← client.objectFreq "key"
```
-/
def Client.objectFreq [Transport.Transport τ]
    (client : Client τ)
    (key : String)
    : Async Int := do
  let cmd := Command.objectFreq key
  let reply ← Client.execute client <| cmd.request
  cmd.decode reply

/--
Get the idle time of a key in seconds.

Example:
```lean
let idle ← client.objectIdleTime "key"
```
-/
def Client.objectIdleTime [Transport.Transport τ]
    (client : Client τ)
    (key : String)
    : Async Int := do
  let cmd := Command.objectIdleTime key
  let reply ← Client.execute client <| cmd.request
  cmd.decode reply

/--
Get the reference count of a key's value.

Example:
```lean
let refcount ← client.objectRefCount "key"
```
-/
def Client.objectRefCount [Transport.Transport τ]
    (client : Client τ)
    (key : String)
    : Async Int := do
  let cmd := Command.objectRefCount key
  let reply ← Client.execute client <| cmd.request
  cmd.decode reply

/--
Remove the expiration from a key.

Example:
```lean
let removed ← client.persist "key"
```
-/
def Client.persist [Transport.Transport τ]
    (client : Client τ)
    (key : String)
    : Async Bool := do
  let cmd := Command.persist key
  let reply ← Client.execute client <| cmd.request
  cmd.decode reply

/--
Set a key's time to live in milliseconds.

Example:
```lean
let set ← client.pexpire "key" 5000
```
-/
def Client.pexpire [Transport.Transport τ]
    (client : Client τ)
    (key : String)
    (milliseconds : UInt64)
    (option : Option ExpireOption := none)
    : Async Bool := do
  let cmd := Command.pexpire key milliseconds option
  let reply ← Client.execute client <| cmd.request
  cmd.decode reply

/--
Set a key's time to live as a Unix timestamp in milliseconds.

Example:
```lean
let set ← client.pexpireAt "key" timestamp
```
-/
def Client.pexpireAt [Transport.Transport τ]
    (client : Client τ)
    (key : String)
    (timestamp : Std.Time.Timestamp)
    (option : Option ExpireOption := none)
    : Async Bool := do
  let cmd := Command.pexpireAt key timestamp option
  let reply ← Client.execute client <| cmd.request
  cmd.decode reply

/--
Get the time to live for a key in milliseconds.

Example:
```lean
let ttl ← client.pttl "key"
```
-/
def Client.pttl [Transport.Transport τ]
    (client : Client τ)
    (key : String)
    : Async Int := do
  let cmd := Command.pttl key
  let reply ← Client.execute client <| cmd.request
  cmd.decode reply

/--
Return a random key from the keyspace.

Example:
```lean
let key ← client.randomKey
```
-/
def Client.randomKey [Transport.Transport τ]
    (client : Client τ)
    : Async (Option String) := do
  let cmd := Command.randomKey
  let reply ← Client.execute client <| cmd.request
  cmd.decode reply

/--
Rename a key.

Example:
```lean
let _ ← client.rename "old" "new"
```
-/
def Client.rename [Transport.Transport τ]
    (client : Client τ)
    (key newKey : String)
    : Async Unit := do
  let cmd := Command.rename key newKey
  let reply ← Client.execute client <| cmd.request
  cmd.decode reply

/--
Rename a key only when the target key does not exist.

Example:
```lean
let renamed ← client.renameNx "old" "new"
```
-/
def Client.renameNx [Transport.Transport τ]
    (client : Client τ)
    (key newKey : String)
    : Async Bool := do
  let cmd := Command.renameNx key newKey
  let reply ← Client.execute client <| cmd.request
  cmd.decode reply

/--
Restore a serialised value previously obtained with DUMP.

Example:
```lean
let _ ← client.restore "key" 0 serialized
```
-/
def Client.restore [Transport.Transport τ]
    (client : Client τ)
    (key : String)
    (ttl : UInt64)
    (serializedValue : String)
    (options : RestoreOptions := {})
    : Async Unit := do
  let cmd := Command.restore key ttl serializedValue options
  let reply ← Client.execute client <| cmd.request
  cmd.decode reply

/--
Incrementally iterate the keyspace.

Example:
```lean
let page ← client.scan 0
```
-/
def Client.scan [Transport.Transport τ]
    (client : Client τ)
    (cursor : UInt64)
    (options : ScanOptions := {})
    : Async ScanResult := do
  let cmd := Command.scan cursor options
  let reply ← Client.execute client <| cmd.request
  cmd.decode reply

/--
Sort the elements in a list, set, or sorted set.

NOTE: When using the `store?` option, Redis returns the number of stored elements
rather than the sorted array. This method expects an array reply; use `execute` directly
when STORE is specified.

Example:
```lean
let elements ← client.sort "mylist"
```
-/
def Client.sort [Transport.Transport τ]
    (client : Client τ)
    (key : String)
    (options : SortOptions := {})
    : Async (Array String) := do
  let cmd := Command.sort key options
  let reply ← Client.execute client <| cmd.request
  cmd.decode reply

/--
Sort the elements in a list, set, or sorted set (read‑only variant).

Example:
```lean
let elements ← client.sortRo "mylist"
```
-/
def Client.sortRo [Transport.Transport τ]
    (client : Client τ)
    (key : String)
    (options : SortRoOptions := {})
    : Async (Array String) := do
  let cmd := Command.sortRo key options
  let reply ← Client.execute client <| cmd.request
  cmd.decode reply

/--
Touch one or more keys, updating their access time.

Example:
```lean
let touched ← client.touch #["key1", "key2"]
```
-/
def Client.touch [Transport.Transport τ]
    (client : Client τ)
    (keys : Array String)
    : Async Int := do
  let cmd := Command.touch keys
  let reply ← Client.execute client <| cmd.request
  cmd.decode reply

/--
Get the time to live for a key in seconds.

Example:
```lean
let ttl ← client.ttl "key"
```
-/
def Client.ttl [Transport.Transport τ]
    (client : Client τ)
    (key : String)
    : Async Int := do
  let cmd := Command.TTL key
  let reply ← Client.execute client <| cmd.request
  cmd.decode reply

/--
Determine the type of the value stored at a key.

Example:
```lean
let type ← client.type "key"
```
-/
def Client.type [Transport.Transport τ]
    (client : Client τ)
    (key : String)
    : Async String := do
  let cmd := Command.type key
  let reply ← Client.execute client <| cmd.request
  cmd.decode reply

/--
Delete one or more keys asynchronously (non‑blocking).

Example:
```lean
let unlinked ← client.unlink #["key1", "key2"]
```
-/
def Client.unlink [Transport.Transport τ]
    (client : Client τ)
    (keys : Array String)
    : Async Int := do
  let cmd := Command.unlink keys
  let reply ← Client.execute client <| cmd.request
  cmd.decode reply

end LeanRedis
