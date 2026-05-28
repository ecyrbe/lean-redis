import LeanRedis.Client.Internal

namespace LeanRedis

open Std.Internal.IO.Async

def Client.hGet [Transport.Transport τ]
    (client : Client τ)
    (key field : String)
    : Async (Option String) := do
  let reply <- Client.execute client <| CommandRequest.hGet key field
  Client.expectOptionalString "HGET" reply

def Client.hSet [Transport.Transport τ]
    (client : Client τ)
    (key : String)
    (entries : Array (String × String))
    : Async Int := do
  let reply <- Client.execute client <| CommandRequest.hSet key entries
  Client.expectInteger "HSET" reply

def Client.hMGet [Transport.Transport τ]
    (client : Client τ)
    (key : String)
    (fields : Array String)
    : Async (Array (Option String)) := do
  let reply <- Client.execute client <| CommandRequest.hMGet key fields
  Client.expectStringArray "HMGET" reply

def Client.hMSet [Transport.Transport τ]
    (client : Client τ)
    (key : String)
    (entries : Array (String × String))
    : Async Unit := do
  let reply <- Client.execute client <| CommandRequest.hMSet key entries
  Client.expectOk reply

def Client.hGetAll [Transport.Transport τ]
    (client : Client τ)
    (key : String)
    : Async (Array (String × String)) := do
  let reply <- Client.execute client <| CommandRequest.hGetAll key
  Client.expectStringPairs "HGETALL" reply

def Client.hDel [Transport.Transport τ]
    (client : Client τ)
    (key : String)
    (fields : Array String)
    : Async Int := do
  let reply <- Client.execute client <| CommandRequest.hDel key fields
  Client.expectInteger "HDEL" reply

def Client.hExists [Transport.Transport τ]
    (client : Client τ)
    (key field : String)
    : Async Bool := do
  let reply <- Client.execute client <| CommandRequest.hExists key field
  Client.expectBoolean "HEXISTS" reply

def Client.hLen [Transport.Transport τ]
    (client : Client τ)
    (key : String)
    : Async Int := do
  let reply <- Client.execute client <| CommandRequest.hLen key
  Client.expectInteger "HLEN" reply

def Client.hKeys [Transport.Transport τ]
    (client : Client τ)
    (key : String)
    : Async (Array String) := do
  let reply <- Client.execute client <| CommandRequest.hKeys key
  Client.expectPlainStringArray "HKEYS" reply

def Client.hVals [Transport.Transport τ]
    (client : Client τ)
    (key : String)
    : Async (Array String) := do
  let reply <- Client.execute client <| CommandRequest.hVals key
  Client.expectPlainStringArray "HVALS" reply

def Client.hStrLen [Transport.Transport τ]
    (client : Client τ)
    (key field : String)
    : Async Int := do
  let reply <- Client.execute client <| CommandRequest.hStrLen key field
  Client.expectInteger "HSTRLEN" reply

def Client.hIncrBy [Transport.Transport τ]
    (client : Client τ)
    (key field : String)
    (amount : Int)
    : Async Int := do
  let reply <- Client.execute client <| CommandRequest.hIncrBy key field amount
  Client.expectInteger "HINCRBY" reply

def Client.hIncrByFloat [Transport.Transport τ]
    (client : Client τ)
    (key field amount : String)
    : Async String := do
  let reply <- Client.execute client <| CommandRequest.hIncrByFloat key field amount
  Client.expectString "HINCRBYFLOAT" reply

def Client.hSetNx [Transport.Transport τ]
    (client : Client τ)
    (key field value : String)
    : Async Bool := do
  let reply <- Client.execute client <| CommandRequest.hSetNx key field value
  Client.expectBoolean "HSETNX" reply

def Client.hRandField [Transport.Transport τ]
    (client : Client τ)
    (key : String)
    : Async (Option String) := do
  let reply <- Client.execute client <| CommandRequest.hRandField key
  Client.expectOptionalString "HRANDFIELD" reply

def Client.hRandFields [Transport.Transport τ]
    (client : Client τ)
    (key : String)
    (count : Int)
    : Async (Array String) := do
  let reply <- Client.execute client <| CommandRequest.hRandFields key count
  Client.expectPlainStringArray "HRANDFIELD" reply

def Client.hRandFieldsWithValues [Transport.Transport τ]
    (client : Client τ)
    (key : String)
    (count : Int)
    : Async (Array (String × String)) := do
  let reply <- Client.execute client <| CommandRequest.hRandFieldsWithValues key count
  Client.expectStringPairs "HRANDFIELD" reply

def Client.hScan [Transport.Transport τ]
    (client : Client τ)
    (key : String)
    (cursor : UInt64)
    (options : HScanOptions := {})
    : Async HashScanResult := do
  let reply <- Client.execute client <| CommandRequest.hScan key cursor options
  Client.expectHScanResult reply

end LeanRedis
