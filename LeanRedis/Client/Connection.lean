import LeanRedis.Client.Basic
import LeanRedis.Command.Connection

namespace LeanRedis

open Std.Internal.IO.Async
open LeanRedis

/--
Send `PING` and decode the optional message payload returned by Redis.

Example:
```lean
let pong <- client.ping
let echoed <- client.ping (some "hello")
```
-/
def Client.ping [Transport.Transport τ]
    (client : Client τ)
    (message? : Option String := none)
    : Async (Option String) := do
  let cmd := Command.ping message?
  let reply <- Client.execute client <| cmd.request
  cmd.decode reply

/--
Send `AUTH` using the provided credentials.

Example:
```lean
let _ <- client.auth { password := "secret" }
```
-/
def Client.auth [Transport.Transport τ]
    (client : Client τ)
    (auth : AuthConfig)
    : Async Unit := do
  let cmd := Command.auth auth
  let reply <- Client.executeWithManagerUpdate client cmd.request fun manager _ =>
    pure {
      manager with
      config := { manager.config with auth? := some auth }
    }
  cmd.decode reply

/--
Send `SELECT` and update the tracked selected database on success.

Example:
```lean
let _ <- client.select 2
```
-/
def Client.select [Transport.Transport τ]
    (client : Client τ)
    (database : UInt32)
    : Async Unit := do
  let cmd := Command.select database
  let reply <- Client.executeWithManagerUpdate client cmd.request fun manager _ =>
    pure {
      manager with
      config := { manager.config with database? := some database }
    }
  cmd.decode reply

end LeanRedis
