import LeanRedis.Client.Internal

namespace LeanRedis

open Std.Internal.IO.Async

def Client.get [Transport.Transport τ]
    (client : Client τ)
    (key : String)
    : Async (Option String) := do
  let reply <- Client.execute client <| CommandRequest.get key
  Client.expectOptionalString "GET" reply

def Client.set [Transport.Transport τ]
    (client : Client τ)
    (key value : String)
    (options : SetOptions := {})
    : Async Bool := do
  let reply <- Client.execute client <| CommandRequest.set key value options
  Client.expectStored reply

def Client.mGet [Transport.Transport τ]
    (client : Client τ)
    (keys : Array String)
    : Async (Array (Option String)) := do
  let reply <- Client.execute client <| CommandRequest.mGet keys
  Client.expectStringArray "MGET" reply

def Client.mSet [Transport.Transport τ]
    (client : Client τ)
    (entries : Array (String × String))
    : Async Unit := do
  let reply <- Client.execute client <| CommandRequest.mSet entries
  Client.expectOk reply

def Client.mSetNx [Transport.Transport τ]
    (client : Client τ)
    (entries : Array (String × String))
    : Async Bool := do
  let reply <- Client.execute client <| CommandRequest.mSetNx entries
  Client.expectBoolean "MSETNX" reply

def Client.getDel [Transport.Transport τ]
    (client : Client τ)
    (key : String)
    : Async (Option String) := do
  let reply <- Client.execute client <| CommandRequest.getDel key
  Client.expectOptionalString "GETDEL" reply

def Client.getEx [Transport.Transport τ]
    (client : Client τ)
    (key : String)
    (mode? : Option GetExMode := none)
    : Async (Option String) := do
  let reply <- Client.execute client <| CommandRequest.getEx key mode?
  Client.expectOptionalString "GETEX" reply

def Client.getRange [Transport.Transport τ]
    (client : Client τ)
    (key : String)
    (start stop : Int)
    : Async String := do
  let reply <- Client.execute client <| CommandRequest.getRange key start stop
  Client.expectString "GETRANGE" reply

def Client.getSet [Transport.Transport τ]
    (client : Client τ)
    (key value : String)
    : Async (Option String) := do
  let reply <- Client.execute client <| CommandRequest.getSet key value
  Client.expectOptionalString "GETSET" reply

def Client.setRange [Transport.Transport τ]
    (client : Client τ)
    (key : String)
    (offset : UInt64)
    (value : String)
    : Async Int := do
  let reply <- Client.execute client <| CommandRequest.setRange key offset value
  Client.expectInteger "SETRANGE" reply

def Client.strLen [Transport.Transport τ]
    (client : Client τ)
    (key : String)
    : Async Int := do
  let reply <- Client.execute client <| CommandRequest.strLen key
  Client.expectInteger "STRLEN" reply

def Client.append [Transport.Transport τ]
    (client : Client τ)
    (key value : String)
    : Async Int := do
  let reply <- Client.execute client <| CommandRequest.append key value
  Client.expectInteger "APPEND" reply

def Client.incr [Transport.Transport τ]
    (client : Client τ)
    (key : String)
    : Async Int := do
  let reply <- Client.execute client <| CommandRequest.incr key
  Client.expectInteger "INCR" reply

def Client.incrBy [Transport.Transport τ]
    (client : Client τ)
    (key : String)
    (amount : Int)
    : Async Int := do
  let reply <- Client.execute client <| CommandRequest.incrBy key amount
  Client.expectInteger "INCRBY" reply

def Client.incrByFloat [Transport.Transport τ]
    (client : Client τ)
    (key amount : String)
    : Async String := do
  let reply <- Client.execute client <| CommandRequest.incrByFloat key amount
  Client.expectString "INCRBYFLOAT" reply

def Client.decr [Transport.Transport τ]
    (client : Client τ)
    (key : String)
    : Async Int := do
  let reply <- Client.execute client <| CommandRequest.decr key
  Client.expectInteger "DECR" reply

def Client.decrBy [Transport.Transport τ]
    (client : Client τ)
    (key : String)
    (amount : Int)
    : Async Int := do
  let reply <- Client.execute client <| CommandRequest.decrBy key amount
  Client.expectInteger "DECRBY" reply

def Client.setNx [Transport.Transport τ]
    (client : Client τ)
    (key value : String)
    : Async Bool := do
  let reply <- Client.execute client <| CommandRequest.setNx key value
  Client.expectBoolean "SETNX" reply

def Client.setEx [Transport.Transport τ]
    (client : Client τ)
    (key : String)
    (seconds : UInt64)
    (value : String)
    : Async Unit := do
  let reply <- Client.execute client <| CommandRequest.setEx key seconds value
  Client.expectOk reply

def Client.pSetEx [Transport.Transport τ]
    (client : Client τ)
    (key : String)
    (milliseconds : UInt64)
    (value : String)
    : Async Unit := do
  let reply <- Client.execute client <| CommandRequest.pSetEx key milliseconds value
  Client.expectOk reply

end LeanRedis
