import LeanRedis.Cache.Defs

namespace LeanRedis.Cache
open LeanRedis
open Std.Async
open Transport

  def new [Transport τ] (config : Config) : Async (Cache τ) := do
    let client : Client τ ← Client.new config
    client.connect
    let inflight ← Std.Mutex.new ({} : Std.HashMap String Inflight)
    return ⟨client,inflight⟩

  def newDefault (config : Config) : Async (Cache TCP) :=
    new config

  private def getSafe [Transport τ] (cache : Cache τ) (key : String) := do
    try
      cache.redis.get key
    catch err =>
      IO.eprintln s!"Error fetching key {key} from Redis: {err}"
      return none


  private def removeInflight (cache : Cache τ) (key : String) : IO Unit := do
    cache.inflight.atomically fun ref => do
      let map ← ref.get
      ref.set <| map.erase key

  private def resolveStatus [Transport τ] (cache : Cache τ) (key: String): Async CacheInflightStatus := do
    match ← cache.getSafe key with
    | some value => return .hit value
    | none =>
      cache.inflight.atomically fun ref => do
        let map ← ref.get
        match map[key]? with
        -- we should consume
        | some promise =>
            return .missInflight promise
        -- we should produce
        | none =>
            let promise: Inflight ← IO.Promise.new
            ref.set (map.insert key promise)
            return .miss promise


  private def getInflight? (cache : Cache τ) (key : String): IO (Option Inflight) :=
    cache.inflight.atomically fun ref => do
      let map ← ref.get
      return map[key]?

  private def consume (promise : Inflight) : Async String := do
    match promise.result?.get with
    | some (.ok value) => return value
    | some (.error err) => throw err
    | none => throw (IO.userError "Concurrent promise was dropped")

  private def produce
      [Transport τ]
      (cache : Cache τ)
      (key : String)
      (cb : Unit → Async String)
      (ttl: Option UInt64)
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
          discard <| match ttl with
          | some seconds => cache.redis.set key value { expiry? := some <| .relative <| .ex seconds}
          | none => cache.redis.set key value
        catch err =>
          IO.eprintln s!"Redis SET error for {key}: {err}"
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
      [Transport τ]
      (cache : Cache τ)
      (key : String)
      (cb : Unit → Async String)
      (ttl: Option UInt64 := none)
      : Async String := do
    match ← cache.getInflight? key with
    | some promise => consume promise
    | none =>
        match ← cache.resolveStatus key with
        | .hit value => return value
        | .missInflight promise => consume promise
        | .miss promise => cache.produce key cb ttl promise

end LeanRedis.Cache
