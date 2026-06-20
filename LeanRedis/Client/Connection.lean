import LeanRedis.Client.Basic
import LeanRedis.Command.Connection

namespace LeanRedis

open Std.Async
open LeanRedis

/--
Send `PING` and decode the optional message payload returned by Redis.

Example:
```lean
let pong ← client.ping
let echoed ← client.ping (some "hello")
```
-/
def Client.ping [Transport.Transport τ]
    (client : Client τ)
    (message? : Option String := none)
    : Async (Option String) := do
  let cmd := Command.ping message?
  let reply ← Client.execute client cmd.request
  cmd.decode reply

private def Client.updateConfig [Transport.Transport τ]
    (client : Client τ)
    (f : Config → Config)
    : Async Unit :=
  client.state.atomically fun ref => do
    let state ← ref.get
    ref.set { state with config := f state.config }

/--
Send `AUTH` using the provided credentials.

Example:
```lean
let _ ← client.auth { password := "secret" }
```
-/
def Client.auth [Transport.Transport τ]
    (client : Client τ)
    (auth : AuthConfig)
    : Async Unit := do
  let cmd := Command.auth auth
  let reply ← Client.execute client cmd.request
  cmd.decode reply
  client.updateConfig fun c => { c with auth? := some auth }

/--
Send `SELECT` and update the tracked selected database on success.

Example:
```lean
let _ ← client.select 2
```
-/
def Client.select [Transport.Transport τ]
    (client : Client τ)
    (database : UInt32)
    : Async Unit := do
  let cmd := Command.select database
  let reply ← Client.execute client cmd.request
  cmd.decode reply
  client.updateConfig fun c => { c with database? := some database }

end LeanRedis
