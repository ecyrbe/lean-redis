import LeanRedis.Client.Internal

namespace LeanRedis

open Std.Internal.IO.Async

def Client.ping [Transport.Transport τ]
    (client : Client τ)
    (message? : Option String := none)
    : Async (Option String) := do
  let reply <- Client.execute client <| CommandRequest.ping message?
  Client.expectPong reply

def Client.auth [Transport.Transport τ]
    (client : Client τ)
    (auth : AuthConfig)
    : Async Unit := do
  let reply <- Client.execute client <| CommandRequest.auth auth
  Client.expectOk reply

def Client.select [Transport.Transport τ]
    (client : Client τ)
    (database : UInt32)
    : Async Unit := do
  let reply <- Client.execute client <| CommandRequest.select database
  Client.expectOk reply

end LeanRedis
