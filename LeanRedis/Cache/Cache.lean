import LeanRedis.Client

def Inflight := IO.Promise (Except IO.Error String)

structure Cache (τ : Type) where
  redis : LeanRedis.Client τ
  inflight : Std.Mutex (Std.HashMap String Inflight)

namespace Cache
open LeanRedis
open Std.Internal.IO.Async

  def new [Transport.Transport τ] (config : Config) : Async (Cache τ) := do
    let client : Client τ ← Client.new config
    client.connect
    let inflight ← Std.Mutex.new ({} : Std.HashMap String Inflight)
    return ⟨client,inflight⟩

  def newDefault (config : Config) : Async (Cache Transport.TCP) :=
    new config

  private def getSafe [Transport.Transport τ] (cache : Cache τ) (key : String) := do
    try
      cache.redis.get key
    catch err =>
      IO.eprintln s!"Calling callback after error fetching key {key} from Redis: {err}"
      pure none


  private def removeInflight (cache : Cache τ) (key : String) : IO Unit := do
    cache.inflight.atomically fun ref => do
      let map ← ref.get
      ref.set <| map.erase key

  private def consume_or_produce (cache : Cache τ) (key: String) :=
    cache.inflight.atomically fun ref => do
      let map ← ref.get
      match map[key]? with
      -- we should consume
      | some promise =>
          return (Sum.inl promise)
      -- we should produce
      | none =>
          let promise: Inflight ← IO.Promise.new
          ref.set (map.insert key promise)
          return (Sum.inr promise)

  private def getInflight? (cache : Cache τ) (key : String): IO (Option Inflight) :=
    cache.inflight.atomically fun ref => do
      let map ← ref.get
      match map[key]? with
      | some promise => return some promise
      | none => return none

  private def consume (promise : Inflight) : Async String := do
    match promise.result?.get with
    | some (.ok value) => return value
    | some (.error err) => throw err
    | none => throw (IO.userError "Concurrent promise was dropped")

  private def produce
      [Transport.Transport τ]
      (cache : Cache τ)
      (key : String)
      (cb : Unit → Async String)
      (options : SetOptions)
      (promise : Inflight)
      : Async String := do
    try
      let value ← cb ()
      promise.resolve (.ok value)
      -- set the redis cache in background
      -- to evoid waiting for it and hold
      -- the resolved value until set is complete
      -- so that incoming request can still get it
      background do
        try
          discard <| cache.redis.set key value options
        catch err =>
          IO.println s!"Redis SET error for {key}: {err}"
        finally
          cache.removeInflight key
      return value
    catch err =>
      promise.resolve (Except.error err)
      removeInflight cache key
      throw err

  /--
     Gets a value from the cache by key.
     If no value is found, the callback will be called to populate it.
     The callback is executed exactly once for each key,
     even if multiple threads request the same key concurrently.
     Cache stampedes are prevented
  -/
  @[inline, specialize]
  def get
      [Transport.Transport τ]
      (cache : Cache τ)
      (key : String)
      (cb : Unit → Async String)
      (options : SetOptions := {})
      : Async String := do

    match ← cache.getInflight? key with
    | some promise => consume promise
    | none =>
        match ← cache.getSafe key with
        | some value => return value
        | none =>
            let decision ← cache.consume_or_produce key
            match decision with
            | Sum.inl promise => consume promise
            | Sum.inr promise => cache.produce key cb options promise

end Cache
