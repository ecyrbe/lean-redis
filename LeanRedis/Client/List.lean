import LeanRedis.Client.Internal

namespace LeanRedis

open Std.Internal.IO.Async

def Client.lPush [Transport.Transport τ]
    (client : Client τ)
    (key : String)
    (values : Array String)
    : Async Int := do
  let reply <- Client.execute client <| CommandRequest.lPush key values
  Client.expectInteger "LPUSH" reply

def Client.rPush [Transport.Transport τ]
    (client : Client τ)
    (key : String)
    (values : Array String)
    : Async Int := do
  let reply <- Client.execute client <| CommandRequest.rPush key values
  Client.expectInteger "RPUSH" reply

def Client.lPushX [Transport.Transport τ]
    (client : Client τ)
    (key value : String)
    : Async Int := do
  let reply <- Client.execute client <| CommandRequest.lPushX key value
  Client.expectInteger "LPUSHX" reply

def Client.rPushX [Transport.Transport τ]
    (client : Client τ)
    (key value : String)
    : Async Int := do
  let reply <- Client.execute client <| CommandRequest.rPushX key value
  Client.expectInteger "RPUSHX" reply

def Client.lPop [Transport.Transport τ]
    (client : Client τ)
    (key : String)
    : Async (Option String) := do
  let reply <- Client.execute client <| CommandRequest.lPop key
  Client.expectOptionalString "LPOP" reply

def Client.rPop [Transport.Transport τ]
    (client : Client τ)
    (key : String)
    : Async (Option String) := do
  let reply <- Client.execute client <| CommandRequest.rPop key
  Client.expectOptionalString "RPOP" reply

def Client.lLen [Transport.Transport τ]
    (client : Client τ)
    (key : String)
    : Async Int := do
  let reply <- Client.execute client <| CommandRequest.lLen key
  Client.expectInteger "LLEN" reply

def Client.lIndex [Transport.Transport τ]
    (client : Client τ)
    (key : String)
    (index : Int)
    : Async (Option String) := do
  let reply <- Client.execute client <| CommandRequest.lIndex key index
  Client.expectOptionalString "LINDEX" reply

def Client.lRange [Transport.Transport τ]
    (client : Client τ)
    (key : String)
    (start stop : Int)
    : Async (Array String) := do
  let reply <- Client.execute client <| CommandRequest.lRange key start stop
  Client.expectPlainStringArray "LRANGE" reply

def Client.lSet [Transport.Transport τ]
    (client : Client τ)
    (key : String)
    (index : Int)
    (value : String)
    : Async Unit := do
  let reply <- Client.execute client <| CommandRequest.lSet key index value
  Client.expectOk reply

def Client.lTrim [Transport.Transport τ]
    (client : Client τ)
    (key : String)
    (start stop : Int)
    : Async Unit := do
  let reply <- Client.execute client <| CommandRequest.lTrim key start stop
  Client.expectOk reply

def Client.lRem [Transport.Transport τ]
    (client : Client τ)
    (key : String)
    (count : Int)
    (value : String)
    : Async Int := do
  let reply <- Client.execute client <| CommandRequest.lRem key count value
  Client.expectInteger "LREM" reply

def Client.lInsert [Transport.Transport τ]
    (client : Client τ)
    (key : String)
    (position : LInsertPosition)
    (pivot value : String)
    : Async Int := do
  let reply <- Client.execute client <| CommandRequest.lInsert key position pivot value
  Client.expectInteger "LINSERT" reply

def Client.lMove [Transport.Transport τ]
    (client : Client τ)
    (source destination : String)
    (fromWhere toWhere : LMoveWhere)
    : Async (Option String) := do
  let reply <- Client.execute client <| CommandRequest.lMove source destination fromWhere toWhere
  Client.expectOptionalString "LMOVE" reply

def Client.lPos [Transport.Transport τ]
    (client : Client τ)
    (key element : String)
    (options : LPosOptions := {})
    : Async (Option Int) := do
  if options.count?.isSome then
    Error.raise <| .decode "LPOS with COUNT returns multiple positions; use lPosMany"
  let reply <- Client.execute client <| CommandRequest.lPos key element options
  match reply with
  | .null => pure none
  | .number value => pure (some value)
  | .simpleError message => Error.raise <| .server message
  | _ => Error.raise <| .decode "unexpected LPOS reply"

def Client.lPosMany [Transport.Transport τ]
    (client : Client τ)
    (key element : String)
    (options : LPosOptions)
    : Async (Array Int) := do
  match options.count? with
  | none => Error.raise <| .decode "lPosMany requires COUNT"
  | some _ =>
      let reply <- Client.execute client <| CommandRequest.lPos key element options
      Client.expectIntegerArray "LPOS" reply

end LeanRedis
