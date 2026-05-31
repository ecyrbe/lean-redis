import LeanRedis.Client.Internal
import LeanRedis.Tools.ExpectResult

namespace LeanRedis

open Std.Internal.IO.Async

/--
Copy a key to a new key.

Example:
```lean
let copied <- client.copy "src" "dst"
```
-/
def Client.copy [Transport.Transport τ]
    (client : Client τ)
    (source destination : String)
    (options : CopyOptions := {})
    : Async Bool := do
  let reply ← Client.execute client <| CommandRequest.copy source destination options
  expectBoolean "COPY" reply

/--
Delete one or more keys.

Example:
```lean
let removed <- client.del #["key1", "key2"]
```
-/
def Client.del [Transport.Transport τ]
    (client : Client τ)
    (keys : Array String)
    : Async Int := do
  let reply ← Client.execute client <| CommandRequest.del keys
  expectInteger "DEL" reply

/--
Dump a serialised version of the value stored at a key.

Example:
```lean
let serialized <- client.dump "key"
```
-/
def Client.dump [Transport.Transport τ]
    (client : Client τ)
    (key : String)
    : Async String := do
  let reply ← Client.execute client <| CommandRequest.dump key
  expectString "DUMP" reply

/--
Determine whether one or more keys exist.

Example:
```lean
let count <- client.exists #["key1", "key2"]
```
-/
def Client.exists [Transport.Transport τ]
    (client : Client τ)
    (keys : Array String)
    : Async Int := do
  let reply ← Client.execute client <| CommandRequest.exists keys
  expectInteger "EXISTS" reply

/--
Set a key's time to live in seconds.

Example:
```lean
let set <- client.expire "key" 60
```
-/
def Client.expire [Transport.Transport τ]
    (client : Client τ)
    (key : String)
    (seconds : UInt64)
    (option : Option ExpireOption := none)
    : Async Bool := do
  let reply ← Client.execute client <| CommandRequest.expire key seconds option
  expectBoolean "EXPIRE" reply

/--
Set a key's time to live as a Unix timestamp in seconds.

Example:
```lean
let set <- client.expireAt "key" timestamp
```
-/
def Client.expireAt [Transport.Transport τ]
    (client : Client τ)
    (key : String)
    (timestamp : Std.Time.Timestamp)
    (option : Option ExpireOption := none)
    : Async Bool := do
  let reply ← Client.execute client <| CommandRequest.expireAt key timestamp option
  expectBoolean "EXPIREAT" reply

/--
Get the expiration time of a key as a Unix timestamp in seconds.

Example:
```lean
let ts <- client.expireTime "key"
```
-/
def Client.expireTime [Transport.Transport τ]
    (client : Client τ)
    (key : String)
    : Async Int := do
  let reply ← Client.execute client <| CommandRequest.expireTime key
  expectInteger "EXPIRETIME" reply

/--
Find all keys matching the given pattern.

Example:
```lean
let keys <- client.keys "user:*"
```
-/
def Client.keys [Transport.Transport τ]
    (client : Client τ)
    (pattern : String)
    : Async (Array String) := do
  let reply ← Client.execute client <| CommandRequest.keys pattern
  expectPlainStringArray "KEYS" reply

/--
Move a key to another database.

Example:
```lean
let moved <- client.move "key" 1
```
-/
def Client.move [Transport.Transport τ]
    (client : Client τ)
    (key : String)
    (destinationDb : UInt32)
    : Async Bool := do
  let reply ← Client.execute client <| CommandRequest.move key destinationDb
  expectBoolean "MOVE" reply

/--
Get the internal encoding of a key's value.

Example:
```lean
let encoding <- client.objectEncoding "key"
```
-/
def Client.objectEncoding [Transport.Transport τ]
    (client : Client τ)
    (key : String)
    : Async String := do
  let reply ← Client.execute client <| CommandRequest.objectEncoding key
  expectString "OBJECT ENCODING" reply

/--
Get the logarithmic access frequency counter of a key's value.

Example:
```lean
let freq <- client.objectFreq "key"
```
-/
def Client.objectFreq [Transport.Transport τ]
    (client : Client τ)
    (key : String)
    : Async Int := do
  let reply ← Client.execute client <| CommandRequest.objectFreq key
  expectInteger "OBJECT FREQ" reply

/--
Get the idle time of a key in seconds.

Example:
```lean
let idle <- client.objectIdleTime "key"
```
-/
def Client.objectIdleTime [Transport.Transport τ]
    (client : Client τ)
    (key : String)
    : Async Int := do
  let reply ← Client.execute client <| CommandRequest.objectIdleTime key
  expectInteger "OBJECT IDLETIME" reply

/--
Get the reference count of a key's value.

Example:
```lean
let refcount <- client.objectRefCount "key"
```
-/
def Client.objectRefCount [Transport.Transport τ]
    (client : Client τ)
    (key : String)
    : Async Int := do
  let reply ← Client.execute client <| CommandRequest.objectRefCount key
  expectInteger "OBJECT REFCOUNT" reply

/--
Remove the expiration from a key.

Example:
```lean
let removed <- client.persist "key"
```
-/
def Client.persist [Transport.Transport τ]
    (client : Client τ)
    (key : String)
    : Async Bool := do
  let reply ← Client.execute client <| CommandRequest.persist key
  expectBoolean "PERSIST" reply

/--
Set a key's time to live in milliseconds.

Example:
```lean
let set <- client.pexpire "key" 5000
```
-/
def Client.pexpire [Transport.Transport τ]
    (client : Client τ)
    (key : String)
    (milliseconds : UInt64)
    (option : Option ExpireOption := none)
    : Async Bool := do
  let reply ← Client.execute client <| CommandRequest.pexpire key milliseconds option
  expectBoolean "PEXPIRE" reply

/--
Set a key's time to live as a Unix timestamp in milliseconds.

Example:
```lean
let set <- client.pexpireAt "key" timestamp
```
-/
def Client.pexpireAt [Transport.Transport τ]
    (client : Client τ)
    (key : String)
    (timestamp : Std.Time.Timestamp)
    (option : Option ExpireOption := none)
    : Async Bool := do
  let reply ← Client.execute client <| CommandRequest.pexpireAt key timestamp option
  expectBoolean "PEXPIREAT" reply

/--
Get the time to live for a key in milliseconds.

Example:
```lean
let ttl <- client.pttl "key"
```
-/
def Client.pttl [Transport.Transport τ]
    (client : Client τ)
    (key : String)
    : Async Int := do
  let reply ← Client.execute client <| CommandRequest.pttl key
  expectInteger "PTTL" reply

/--
Return a random key from the keyspace.

Example:
```lean
let key <- client.randomKey
```
-/
def Client.randomKey [Transport.Transport τ]
    (client : Client τ)
    : Async (Option String) := do
  let reply ← Client.execute client CommandRequest.randomKey
  expectOptionalString "RANDOMKEY" reply

/--
Rename a key.

Example:
```lean
let _ <- client.rename "old" "new"
```
-/
def Client.rename [Transport.Transport τ]
    (client : Client τ)
    (key newKey : String)
    : Async Unit := do
  let reply ← Client.execute client <| CommandRequest.rename key newKey
  expectOk reply

/--
Rename a key only when the target key does not exist.

Example:
```lean
let renamed <- client.renameNx "old" "new"
```
-/
def Client.renameNx [Transport.Transport τ]
    (client : Client τ)
    (key newKey : String)
    : Async Bool := do
  let reply ← Client.execute client <| CommandRequest.renameNx key newKey
  expectBoolean "RENAMENX" reply

/--
Restore a serialised value previously obtained with DUMP.

Example:
```lean
let _ <- client.restore "key" 0 serialized
```
-/
def Client.restore [Transport.Transport τ]
    (client : Client τ)
    (key : String)
    (ttl : UInt64)
    (serializedValue : String)
    (options : RestoreOptions := {})
    : Async Unit := do
  let reply ← Client.execute client <| CommandRequest.restore key ttl serializedValue options
  expectOk reply

/--
Incrementally iterate the keyspace.

Example:
```lean
let page <- client.scan 0
```
-/
def Client.scan [Transport.Transport τ]
    (client : Client τ)
    (cursor : UInt64)
    (options : ScanOptions := {})
    : Async ScanResult := do
  let reply ← Client.execute client <| CommandRequest.scan cursor options
  expectScanResult reply

/--
Sort the elements in a list, set, or sorted set.

NOTE: When using the `store?` option, Redis returns the number of stored elements
rather than the sorted array. This method expects an array reply; use `execute` directly
when STORE is specified.

Example:
```lean
let elements <- client.sort "mylist"
```
-/
def Client.sort [Transport.Transport τ]
    (client : Client τ)
    (key : String)
    (options : SortOptions := {})
    : Async (Array String) := do
  let reply ← Client.execute client <| CommandRequest.sort key options
  expectPlainStringArray "SORT" reply

/--
Sort the elements in a list, set, or sorted set (read‑only variant).

Example:
```lean
let elements <- client.sortRo "mylist"
```
-/
def Client.sortRo [Transport.Transport τ]
    (client : Client τ)
    (key : String)
    (options : SortRoOptions := {})
    : Async (Array String) := do
  let reply ← Client.execute client <| CommandRequest.sortRo key options
  expectPlainStringArray "SORT_RO" reply

/--
Touch one or more keys, updating their access time.

Example:
```lean
let touched <- client.touch #["key1", "key2"]
```
-/
def Client.touch [Transport.Transport τ]
    (client : Client τ)
    (keys : Array String)
    : Async Int := do
  let reply ← Client.execute client <| CommandRequest.touch keys
  expectInteger "TOUCH" reply

/--
Get the time to live for a key in seconds.

Example:
```lean
let ttl <- client.ttl "key"
```
-/
def Client.ttl [Transport.Transport τ]
    (client : Client τ)
    (key : String)
    : Async Int := do
  let reply ← Client.execute client <| CommandRequest.TTL key
  expectInteger "TTL" reply

/--
Determine the type of the value stored at a key.

Example:
```lean
let type <- client.type "key"
```
-/
def Client.type [Transport.Transport τ]
    (client : Client τ)
    (key : String)
    : Async String := do
  let reply ← Client.execute client <| CommandRequest.type key
  expectString "TYPE" reply

/--
Delete one or more keys asynchronously (non‑blocking).

Example:
```lean
let unlinked <- client.unlink #["key1", "key2"]
```
-/
def Client.unlink [Transport.Transport τ]
    (client : Client τ)
    (keys : Array String)
    : Async Int := do
  let reply ← Client.execute client <| CommandRequest.unlink keys
  expectInteger "UNLINK" reply

end LeanRedis
