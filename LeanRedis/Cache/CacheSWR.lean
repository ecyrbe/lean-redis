import LeanRedis.Cache.Defs

namespace LeanRedis.CacheSWR
open LeanRedis
open Std.Async

  def new [Transport.Transport τ] (config : Config) : Async (CacheSWR τ) := do
    let client : Client τ ← Client.new config
    client.connect
    let inflight ← Std.Mutex.new ({} : Std.HashMap String Inflight)
    return ⟨client, inflight⟩

  def newDefault (config : Config) : Async (CacheSWR Transport.TCP) :=
    new config

  private def getSafe [Transport.Transport τ] (cache : CacheSWR τ) (key : String) := do
    try
      cache.redis.hMGet key #["value", "expiresAt"]
    catch err =>
      IO.eprintln s!"Error fetching key {key} from Redis: {err}"
      pure #[]

  private def removeInflight (cache : CacheSWR τ) (key : String) : IO Unit := do
    cache.inflight.atomically fun ref => do
      let map ← ref.get
      ref.set <| map.erase key

  private def getNowSeconds : IO Int := do
    let ts ← Std.Time.Timestamp.now
    return ts.toSecondsSinceUnixEpoch.val

  private def parseHMGetResult (result : Array (Option String)) : Option (String × String) := do
    match result with
    | #[some value, some expiresAt] => return (value, expiresAt)
    | _ => none

  private def acquireInflight (cache : CacheSWR τ) (key : String) : IO (Inflight × Bool) :=
    cache.inflight.atomically fun ref => do
      let map ← ref.get
      match map[key]? with
      | some promise => return (promise, false)
      | none =>
        let promise : Inflight ← IO.Promise.new
        ref.set (map.insert key promise)
        return (promise, true)

  private def resolveStatus [Transport.Transport τ] (cache : CacheSWR τ) (key : String): Async CacheSWRStatus := do
    let cached ← getSafe cache key
    match parseHMGetResult cached with
    | none => match ← acquireInflight cache key with
      | (promise, true) => return .miss promise
      | (promise, false) => return .missInflight promise
    | some (value, expiresAt) =>
      let now ← getNowSeconds
      match expiresAt.toInt? with
      | none => return .hit value
      | some expiresAtInt =>
        if now < expiresAtInt then
          return .hit value
        else
          match ← acquireInflight cache key with
          | (promise, true) => return .stale value promise
          | (_, false) => return .staleInflight value

  private def consume (promise : Inflight) : Async String := do
    match promise.result?.get with
    | some (.ok value) => return value
    | some (.error err) => throw err
    | none => throw (IO.userError "Concurrent promise was dropped")

  private def storeInRedis
      [Transport.Transport τ]
      (cache : CacheSWR τ)
      (key : String)
      (value : String)
      (opts : CacheSWROptions)
      : Async Unit := do
    let ts ← Std.Time.Timestamp.now
    let expiresAt := toString (ts.toSecondsSinceUnixEpoch.val + (opts.staleTtl.toNat : Int))
    discard <| cache.redis.hMSet key #[("value", value), ("expiresAt", expiresAt)]
    match opts.ttl with
    | some secs => discard <| cache.redis.expire key secs
    | none => discard <| cache.redis.expire key (opts.staleTtl * 2)

  private def produce
      [Transport.Transport τ]
      (cache : CacheSWR τ)
      (key : String)
      (cb : Unit → Async String)
      (opts : CacheSWROptions)
      (promise : Inflight)
      : Async String := do
    try
      let value ← cb ()
      promise.resolve (.ok value)
      background do
        try
          storeInRedis cache key value opts
        catch err =>
          IO.eprintln s!"Redis HMSET error for {key}: {err}"
        finally
          removeInflight cache key
      return value
    catch err =>
      promise.resolve (Except.error err)
      removeInflight cache key
      throw err

  private def refresh
      [Transport.Transport τ]
      (cache : CacheSWR τ)
      (key : String)
      (cb : Unit → Async String)
      (opts : CacheSWROptions)
      (promise : Inflight)
      : Async Unit :=
    background do
      try
        let value ← cb ()
        promise.resolve (.ok value)
        storeInRedis cache key value opts
      catch err =>
        promise.resolve (Except.error err)
      finally
        removeInflight cache key

  /--
     Gets a value from the cache by key.

     - If a fresh value is found, it is returned immediately.
     - If a stale value is found, it is returned immediately and
     a background refresh is triggered to update the cache.
     - If no value is found, the callback will be called to populate it.
     The callback is executed exactly once for each key,
     even if multiple requests request the same key concurrently.
     - Cache stampedes are prevented.
   -/
  @[inline, specialize]
  def get
      [Transport.Transport τ]
      (cache : CacheSWR τ)
      (key : String)
      (cb : Unit → Async String)
      (opts : CacheSWROptions)
      : Async String := do
    match ← resolveStatus cache key with
    | .hit value => return value
    | .staleInflight value => return value
    | .stale value promise =>
        refresh cache key cb opts promise
        return value
    | .missInflight promise => consume promise
    | .miss promise => produce cache key cb opts promise

end LeanRedis.CacheSWR
