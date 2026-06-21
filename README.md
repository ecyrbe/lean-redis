<div align="center">

# LeanRedis

[![Lean](https://img.shields.io/badge/Lean-4.31.0-0f4c81)](https://lean-lang.org/)
[![Lake](https://img.shields.io/badge/build-Lake-blue)](https://github.com/leanprover/lake)
[![Version](https://img.shields.io/badge/version-0.3.0-2ea44f)](./lakefile.toml)
[![Redis](https://img.shields.io/badge/Redis-6%20%7C%207%20%7C%208-red)](https://redis.io/)
[![License](https://img.shields.io/badge/license-MIT-green)](./LICENSE)

Async Redis client library for Lean 4.

Typed commands, RESP2/RESP3 support, native async TCP, and a design built for explicit state transitions and scripted testability.

</div>

## Highlights

- 🚀 Async-only public client API
- 🔌 Native Lean TCP transport built on `Std.Async`
- 🧠 RESP2 and RESP3 parsing, encoding, and protocol fallback
- 🔄 Opt-in background reconnect with fixed-interval or exponential backoff strategies
- 📣 Async connection lifecycle event callbacks for disconnect and reconnect logging
- 🧪 Transport abstraction makes mocked and scripted transports easy to use in tests
- 🗂️ Typed command families for generic, strings, hashes, lists, sets, and sorted sets
- 🔗 Pipeline API for batching commands over a single connection with typed, positional result unpacking
- 🧩 Heterogeneous result lists (`HList`) pair each pipeline command's return type with its position in the result tuple
- 🧪 Scripted tests for protocol, transport, connection, and typed command decoding
- 🛠️ Modular internal layout split by command family for easier review and maintenance
- 🛡️ **Cache** — cache-aside with Redis backend and built-in cache-stampede prevention

## Command families

- 🔐 Connection: `AUTH`, `PING`, `SELECT`
- 📝 Strings: `GET`, `SET`, `MGET`, `MSET`, `INCR`, `DECR`, `GETEX`, and related commands
- 🧾 Hashes: `HGET`, `HSET`, `HMGET`, `HMSET`, `HGETALL`, `HSCAN`, and related commands
- 📚 Lists: `LPUSH`, `RPUSH`, `LPOP`, `RPOP`, `LRANGE`, `LPOS`, and related commands
- 🧩 Sets: `SADD`, `SREM`, `SMEMBERS`, `SINTER`, `SUNION`, `SSCAN`, and related commands
- 📈 Sorted sets: `ZADD`, `ZSCORE`, `ZRANGE`, `ZINTER`, `ZUNION`, `ZSCAN`, and related commands
- 🔑 Generic: `DEL`, `EXISTS`, `EXPIRE`, `TTL`, `KEYS`, `TYPE`, `SCAN`, `SORT`, `RENAME`, `COPY`, and related commands

Current non-goals for v1:
- sync API
- blocking Redis command variants
- pub/sub mode
- cluster / sentinel support
- TLS transport

## Feature Snapshot

| Area | Status | Notes |
| --- | --- | --- |
| RESP2 support | Yes | parser, encoder, bootstrap fallback |
| RESP3 support | Yes | parser, encoder, typed reply handling |
| Async client API | Yes | public API is async-only |
| Native TCP transport | Yes | built on `Std.Async` |
| Mockable custom transports | Yes | transport is a typeclass over the concrete handle type |
| Connection bootstrap | Yes | auth, HELLO negotiation, DB select |
| Background reconnect | Yes | opt-in client-owned reconnect worker with pluggable strategies |
| Connection event callbacks | Yes | async handlers, fire-and-forget delivery |
| Generic commands | Yes | key lifecycle, lookup, and server-side operations |
| String commands | Yes | mainstream v1 coverage |
| Hash commands | Yes | includes `HSCAN` |
| List commands | Yes | non-blocking mainstream coverage |
| Set commands | Yes | includes `SSCAN` |
| Sorted set commands | Yes | includes `ZSCAN` |
| Scripted transport tests | Yes | protocol, runtime, manager, client |
| Pipelines  | Yes | typed, uses `HList` for positional result unpacking |
| Cache (stampede prevention) | Yes | cache-aside with inflight request deduplication |
| CacheSWR (stale-while-revalidate) | Yes | serves stale values, background refresh, inflight dedup |
| Transactions | No | not part of v1 |
| Pub/Sub | No | not part of v1 |
| TLS | No | intended as future extension |
| Cluster / Sentinel | No | not part of v1 |

## Requirements

- Lean `4.31.0`
- Lake

Toolchain is pinned in `lean-toolchain`.

## Installation

This repository is currently install-from-source.

1. Clone the repository.
2. Build the project:

```bash
lake build
```

3. Build and run the test target:

```bash
lake test
```

## Quick Start

```lean
import LeanRedis

open LeanRedis
open Std.Async

def example : Async (Option String) := do
  let client ← Client.newDefault {
    endpoint := { host := "127.0.0.1", port := 6379 }
    reconnectStrategy := .exponentialBackoff {}
  }
  let _ ← client.connect
  let _ ← client.set "greeting" "hello"
  client.get "greeting"
```

## Examples

Basic connection commands:

```lean
def pingExample : Async (Option String) := do
  let client ← LeanRedis.Client.newDefault {
    endpoint := { host := "127.0.0.1", port := 6379 }
  }
  let _ ← client.connect
  client.ping
```

Reconnect and event callbacks:

```lean
def reconnectingExample : Async Unit := do
  let client ← LeanRedis.Client.newDefault {
    endpoint := { host := "127.0.0.1", port := 6379 }
    reconnectStrategy := .exponentialBackoff {
      baseDelayMs := 100
      maxDelayMs := 5_000
      jitter := true
    }
  }
  let _sub ← client.onEvent fun event => do
    IO.println s!"redis event: {repr event}"
  let _ ← client.connect
  pure ()
```

String operations:

```lean
def stringExample : Async (Option String) := do
  let client ← LeanRedis.Client.newDefault {
    endpoint := { host := "127.0.0.1", port := 6379 }
  }
  let _ ← client.connect
  let _ ← client.set "counter" "1"
  let _ ← client.incr "counter"
  client.get "counter"
```

Hash operations:

```lean
def hashExample : Async (Array (String × String)) := do
  let client ← LeanRedis.Client.newDefault {
    endpoint := { host := "127.0.0.1", port := 6379 }
  }
  let _ ← client.connect
  let _ ← client.hSet "user:1" #[("name", "alice"), ("role", "admin")]
  client.hGetAll "user:1"
```

Sorted set operations:

```lean
def sortedSetExample : Async (Array LeanRedis.SortedSetEntry) := do
  let client ← LeanRedis.Client.newDefault {
    endpoint := { host := "127.0.0.1", port := 6379 }
  }
  let _ ← client.connect
  let _ ← client.zAdd "scores" #[
    { score := "10", member := "alice" },
    { score := "20", member := "bob" }
  ]
  client.zRangeWithScores "scores" 0 (-1)
```

Pipeline operations:

```lean
def pipelineExample : Async (Option String × Bool × Option String) := do
  let client ← Client.newDefault {
    endpoint := { host := "127.0.0.1", port := 6379 }
  }
  client.connect
  let [a, b, c]ₕ ← client.runPipeline <|
    Pipeline.empty
      |>.get "greeting"
      |>.set "key" "val"
      |>.get "key"
  return (a, b, c)
```

Results are unpacked positionally via `HList`. The example above destructures into
`(some_string, set_ok, some_string, ())` matching the return types of `GET`, `SET`, and `GET`.

Pipeline command families mirror the single-command client API — strings, hashes, lists,
sets, sorted sets, generics, and connection commands are all supported inside a pipeline.

### Cache (cache-aside with stampede prevention)

The `Cache` module implements a cache-aside pattern backed by Redis. When a requested key is not
found in Redis, the provided callback is invoked to compute the value, which is then stored in
Redis and returned. **Cache-stampede prevention** ensures the callback runs exactly once per key,
even when multiple concurrent requests arrive for the same missing key — subsequent callers wait
for the first response instead of recomputing.

```lean
import LeanRedis

open LeanRedis
open Std.Async

def cacheExample : Async String := do
  let cache ← Cache.newDefault {
    endpoint := { host := "127.0.0.1", port := 6379 }
  }
  -- On a cache miss the callback populates the cache.
  -- On a cache hit the cached value is returned immediately.
  cache.get "mykey" fun _ => do
    pure "expensive computation result"
```

The optional `ttl` parameter controls the Redis key expiration:

```lean
cache.get "mykey" (fun _ => pure "computed") (ttl := some 60)
```

### CacheSWR (stale-while-revalidate)

`CacheSWR` extends the cache-aside pattern with **stale-while-revalidate**. Values are stored
alongside an `expiresAt` timestamp in a Redis hash. When a value is still fresh, it is returned
immediately (hit). When the value is stale, it is returned immediately **and** a background
refresh is triggered — the caller never waits for the refresh. Cache-stampede prevention applies
to both fresh misses and stale-value refreshes.

```lean
import LeanRedis

open LeanRedis
open Std.Async

def cacheSWRExample : Async String := do
  let cache ← CacheSWR.newDefault {
    endpoint := { host := "127.0.0.1", port := 6379 }
  }
  -- On a hit: returns the fresh value.
  -- On a stale: returns the stale value and triggers a background refresh.
  -- On a miss: calls the callback, stores the result, returns it.
  cache.get "mykey" (fun _ => pure "refreshed value") { staleTtl := 60 }
```

`staleTtl` controls how many seconds a value is considered fresh. After that, the value is stale
and a background refresh fires on the next read. The optional `ttl` field sets an overall Redis
key TTL (defaults to `staleTtl * 2`):

```lean
cache.get "mykey" (fun _ => pure "refreshed") { staleTtl := 60, ttl := some 300 }
```

Mocked transport for tests:

```lean
import LeanRedis

open LeanRedis
open Std.Async

structure FakeTransport where
  replies : IO.Ref (Array ByteArray)

private def popReply (ref : IO.Ref (Array ByteArray)) : IO ByteArray := do
  let replies ← ref.get
  match replies[0]? with
  | some reply =>
      ref.set (replies.extract 1 replies.size)
      pure reply
  | none =>
      pure ByteArray.empty

instance : Transport.Transport FakeTransport where
  connect _ := do
    let replies ← IO.mkRef #["+PONG\r\n".toUTF8]
    pure { replies }

  recv transport _ := do
    let bytes ← popReply transport.replies
    if bytes.isEmpty then
      pure { bytes := ByteArray.empty, disconnect? := some .closedByPeer }
    else
      pure { bytes }

  send _ _ := pure ()
  close _ := pure ()

def pingWithMock : Async (Option String) := do
  let client : Client FakeTransport ← Client.new {
    endpoint := { host := "mock", port := 0 }
  }
  let _ ← client.connect
  client.ping
```

This is the same mechanism used by the library test suite for scripted bootstrap, partial replies, and disconnect scenarios.

## License

MIT License. See [`LICENSE`](./LICENSE).
