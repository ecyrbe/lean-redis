import LeanRedis.Client

namespace LeanRedis
  open LeanRedis
open Std.Async

def Inflight := IO.Promise (Except IO.Error String)

/--
  Cache Aside pattern with a Redis backend.
  When a cache miss occurs, we fetch from the source callback and store it in Redis.
  Cache Stampete prevention with inflight request detection.
-/
structure Cache (τ : Type) where
  redis : LeanRedis.Client τ
  inflight : Std.Mutex (Std.HashMap String Inflight)

/--
  Simple Inflight Status of a key
  - hit: The value is cached
  - missInflight: The value is not cached, but a request to retrieve it is pending
  - miss: The value is not cached, we need to create a request to retrieve it
-/
inductive CacheInflightStatus where
| hit (value : String)
| missInflight (consume: Inflight)
| miss (produce: Inflight)

/--
  Options for CacheSWR operations.
  - staleTtl: seconds after which a cached value is considered stale
  - ttl: optional overall Redis key TTL for eviction (default: staleTtl * 2)
-/
structure CacheSWROptions where
  staleTtl : UInt64
  ttl : Option UInt64 := none
  deriving Inhabited, BEq, Repr

/--
  Cache Aside pattern with a Redis backend with stale while revalidate.
  When a cache stale occurs, we return the stale value and fetch from the source callback in the background.
  When a cache miss occurs, we fetch from the source callback and store it in Redis.
  Cache Stampete prevention with inflight request detection.
-/
structure CacheSWR (τ : Type) where
  redis : LeanRedis.Client τ
  inflight : Std.Mutex (Std.HashMap String Inflight)

/--
  Advanced Status for stale while revalidate pattern.
  - hit: The value is cached and fresh
  - stale: The value is cached but stale, we need to refresh it with the given promise
  - staleInflight: The value is cached but stale, and a refresh is already in flight
  - missInflight: The value is not cached, but a request to retrieve it is pending
  - miss: The value is not cached, we need to create a request to retrieve it
-/
inductive CacheSWRStatus where
| hit (value : String)
| staleInflight (value : String)
| stale (value : String) (produce : Inflight)
| missInflight (consume: Inflight)
| miss (produce: Inflight)

end LeanRedis
