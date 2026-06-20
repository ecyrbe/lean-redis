import LeanRedis.Cache.Defs

namespace LeanRedis.CacheSWR
open LeanRedis
open Std.Internal.IO.Async

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
      IO.eprintln s!"Calling callback after error fetching key {key} from Redis: {err}"
      pure #[]

  private def removeInflight (cache : CacheSWR τ) (key : String) : IO Unit := do
    cache.inflight.atomically fun ref => do
      let map ← ref.get
      ref.set <| map.erase key

  private def getNowSeconds : Async Int := do
    let ts ← Std.Time.Timestamp.now
    pure ts.toSecondsSinceUnixEpoch.val

  private def parseHMGetResult (result : Array (Option String)) : Option (String × String) := do
    match result with
    | #[some value, some expiresAtOpt] => return (value, expiresAtOpt)
    | _ => none

  private def geStatus [Transport.Transport τ] (cache : CacheSWR τ) (key : String) := do
    match ← getSafe cache key with
    | #[] =>
      cache.inflight.atomically fun ref => do
        let map ← ref.get
        match map[key]? with
        | some promise => return CacheSWRStatus.missInflight promise
        | none =>
          let promise : Inflight ← IO.Promise.new
          ref.set (map.insert key promise)
          return CacheSWRStatus.miss promise
    | result =>
      match parseHMGetResult result with
      | none =>
        cache.inflight.atomically fun ref => do
          let map ← ref.get
          match map[key]? with
          | some promise => return CacheSWRStatus.missInflight promise
          | none =>
            let promise : Inflight ← IO.Promise.new
            ref.set (map.insert key promise)
            return CacheSWRStatus.miss promise
      | some (value, expiresAt) =>
        let now ← getNowSeconds
        match expiresAt.toInt? with
        | none => return CacheSWRStatus.hit value
        | some expiresAtInt =>
          if now < expiresAtInt then
            return CacheSWRStatus.hit value
          else
            cache.inflight.atomically fun ref => do
              let map ← ref.get
              match map[key]? with
              | some _ => return CacheSWRStatus.staleInflight value
              | none =>
                let promise : Inflight ← IO.Promise.new
                ref.set (map.insert key promise)
                return CacheSWRStatus.stale value promise

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
          IO.println s!"Redis HMSET error for {key}: {err}"
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
     If a fresh value is found, it is returned immediately.
     If a stale value is found, it is returned immediately and
     a background refresh is triggered to update the cache.
     If no value is found, the callback will be called to populate it.
     The callback is executed exactly once for each key,
     even if multiple requests request the same key concurrently.
     Cache stampedes are prevented.
  -/
  @[inline, specialize]
  def get
      [Transport.Transport τ]
      (cache : CacheSWR τ)
      (key : String)
      (cb : Unit → Async String)
      (opts : CacheSWROptions)
      : Async String := do
    match ← geStatus cache key with
    | .hit value => return value
    | .staleInflight value => return value
    | .stale value promise =>
        refresh cache key cb opts promise
        return value
    | .missInflight promise => consume promise
    | .miss promise => produce cache key cb opts promise

end LeanRedis.CacheSWR
