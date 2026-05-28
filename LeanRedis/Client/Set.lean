import LeanRedis.Client.Internal

namespace LeanRedis

open Std.Internal.IO.Async

def Client.sAdd [Transport.Transport τ]
    (client : Client τ)
    (key : String)
    (members : Array String)
    : Async Int := do
  let reply <- Client.execute client <| CommandRequest.sAdd key members
  Client.expectInteger "SADD" reply

def Client.sRem [Transport.Transport τ]
    (client : Client τ)
    (key : String)
    (members : Array String)
    : Async Int := do
  let reply <- Client.execute client <| CommandRequest.sRem key members
  Client.expectInteger "SREM" reply

def Client.sCard [Transport.Transport τ]
    (client : Client τ)
    (key : String)
    : Async Int := do
  let reply <- Client.execute client <| CommandRequest.sCard key
  Client.expectInteger "SCARD" reply

def Client.sIsMember [Transport.Transport τ]
    (client : Client τ)
    (key member : String)
    : Async Bool := do
  let reply <- Client.execute client <| CommandRequest.sIsMember key member
  Client.expectBoolean "SISMEMBER" reply

def Client.sMIsMember [Transport.Transport τ]
    (client : Client τ)
    (key : String)
    (members : Array String)
    : Async (Array Bool) := do
  let reply <- Client.execute client <| CommandRequest.sMIsMember key members
  match reply with
  | .array items =>
      items.mapM (Client.expectBoolean "SMISMEMBER")
  | .simpleError message => Error.raise <| .server message
  | _ => Error.raise <| .decode "unexpected SMISMEMBER reply"

def Client.sMembers [Transport.Transport τ]
    (client : Client τ)
    (key : String)
    : Async (Array String) := do
  let reply <- Client.execute client <| CommandRequest.sMembers key
  Client.expectPlainStringArray "SMEMBERS" reply

def Client.sPop [Transport.Transport τ]
    (client : Client τ)
    (key : String)
    : Async (Option String) := do
  let reply <- Client.execute client <| CommandRequest.sPop key
  Client.expectOptionalString "SPOP" reply

def Client.sPopMany [Transport.Transport τ]
    (client : Client τ)
    (key : String)
    (count : UInt64)
    : Async (Array String) := do
  let reply <- Client.execute client <| CommandRequest.sPopCount key count
  Client.expectPlainStringArray "SPOP" reply

def Client.sRandMember [Transport.Transport τ]
    (client : Client τ)
    (key : String)
    : Async (Option String) := do
  let reply <- Client.execute client <| CommandRequest.sRandMember key
  Client.expectOptionalString "SRANDMEMBER" reply

def Client.sRandMembers [Transport.Transport τ]
    (client : Client τ)
    (key : String)
    (count : Int)
    : Async (Array String) := do
  let reply <- Client.execute client <| CommandRequest.sRandMembers key count
  match (← Client.expectOptionalStringOrArray "SRANDMEMBER" reply) with
  | .inl none => pure #[]
  | .inl (some value) => pure #[value]
  | .inr values => pure values

def Client.sMove [Transport.Transport τ]
    (client : Client τ)
    (source destination member : String)
    : Async Bool := do
  let reply <- Client.execute client <| CommandRequest.sMove source destination member
  Client.expectBoolean "SMOVE" reply

def Client.sDiff [Transport.Transport τ]
    (client : Client τ)
    (keys : Array String)
    : Async (Array String) := do
  let reply <- Client.execute client <| CommandRequest.sDiff keys
  Client.expectPlainStringArray "SDIFF" reply

def Client.sDiffStore [Transport.Transport τ]
    (client : Client τ)
    (destination : String)
    (keys : Array String)
    : Async Int := do
  let reply <- Client.execute client <| CommandRequest.sDiffStore destination keys
  Client.expectInteger "SDIFFSTORE" reply

def Client.sInter [Transport.Transport τ]
    (client : Client τ)
    (keys : Array String)
    : Async (Array String) := do
  let reply <- Client.execute client <| CommandRequest.sInter keys
  Client.expectPlainStringArray "SINTER" reply

def Client.sInterCard [Transport.Transport τ]
    (client : Client τ)
    (keys : Array String)
    : Async Int := do
  let reply <- Client.execute client <| CommandRequest.sInterCard keys
  Client.expectInteger "SINTERCARD" reply

def Client.sInterStore [Transport.Transport τ]
    (client : Client τ)
    (destination : String)
    (keys : Array String)
    : Async Int := do
  let reply <- Client.execute client <| CommandRequest.sInterStore destination keys
  Client.expectInteger "SINTERSTORE" reply

def Client.sUnion [Transport.Transport τ]
    (client : Client τ)
    (keys : Array String)
    : Async (Array String) := do
  let reply <- Client.execute client <| CommandRequest.sUnion keys
  Client.expectPlainStringArray "SUNION" reply

def Client.sUnionStore [Transport.Transport τ]
    (client : Client τ)
    (destination : String)
    (keys : Array String)
    : Async Int := do
  let reply <- Client.execute client <| CommandRequest.sUnionStore destination keys
  Client.expectInteger "SUNIONSTORE" reply

def Client.sScan [Transport.Transport τ]
    (client : Client τ)
    (key : String)
    (cursor : UInt64)
    (options : SScanOptions := {})
    : Async SetScanResult := do
  let reply <- Client.execute client <| CommandRequest.sScan key cursor options
  Client.expectSetScanResult reply

end LeanRedis
