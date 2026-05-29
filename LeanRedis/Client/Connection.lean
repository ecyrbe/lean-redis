import LeanRedis.Client.Internal

namespace LeanRedis

open Std.Internal.IO.Async

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
  let reply <- Client.execute client <| CommandRequest.ping message?
  Client.expectPong reply

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
  let reply <- Client.executeWithManagerUpdate client (CommandRequest.auth auth) fun manager _ =>
    pure {
      manager with
      config := { manager.config with auth? := some auth }
    }
  Client.expectOk reply

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
  let reply <- Client.executeWithManagerUpdate client (CommandRequest.select database) fun manager _ =>
    pure {
      manager with
      config := { manager.config with database? := some database }
    }
  Client.expectOk reply

end LeanRedis
