<div align="center">

# LeanRedis

[![Lean](https://img.shields.io/badge/Lean-4.30.0-0f4c81)](https://lean-lang.org/)
[![Lake](https://img.shields.io/badge/build-Lake-blue)](https://github.com/leanprover/lake)
[![Version](https://img.shields.io/badge/version-0.1.0-2ea44f)](./lakefile.lean)
[![Redis](https://img.shields.io/badge/Redis-6%20%7C%207%20%7C%208-red)](https://redis.io/)
[![License](https://img.shields.io/badge/license-MIT-green)](./LICENSE)

Async Redis client library for Lean 4.

Typed commands, RESP2/RESP3 support, native async TCP, and a design built for explicit state transitions and scripted testability.

</div>

## Highlights

- 🚀 Async-only public client API
- 🔌 Native Lean TCP transport built on `Std.Internal.IO.Async`
- 🧠 RESP2 and RESP3 parsing, encoding, and protocol fallback
- 🧱 Clear layering: `Client` -> `Connection.Manager` -> `Connection.Runtime` -> RESP codec
- 🔄 Opt-in background reconnect with fixed-interval or exponential backoff strategies
- 📣 Async connection lifecycle event callbacks for disconnect and reconnect logging
- 🧪 Transport abstraction makes mocked and scripted transports easy to use in tests
- 🗂️ Typed command families for generic, strings, hashes, lists, sets, and sorted sets
- 🧪 Scripted tests for protocol, transport, connection, and typed command decoding
- 🛠️ Modular internal layout split by command family for easier review and maintenance

## Supported Features

Core:
- RESP parser and encoder
- RESP2 / RESP3 bootstrap negotiation
- default TCP transport
- connection bootstrap and opt-in background reconnect
- async client lifecycle, reconnect events, and connection state inspection

Command families:
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
- pipelines / transactions
- cluster / sentinel support
- TLS transport

## Feature Snapshot

| Area | Status | Notes |
| --- | --- | --- |
| RESP2 support | Yes | parser, encoder, bootstrap fallback |
| RESP3 support | Yes | parser, encoder, typed reply handling |
| Async client API | Yes | public API is async-only |
| Native TCP transport | Yes | built on `Std.Internal.IO.Async` |
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
| Pipelines / transactions | No | not part of v1 |
| Pub/Sub | No | not part of v1 |
| TLS | No | intended as future extension |
| Cluster / Sentinel | No | not part of v1 |

## Requirements

- Lean `4.30.0`
- Lake

Toolchain is pinned in `lean-toolchain`.

## Installation

This repository is currently install-from-source.

1. Clone the repository.
2. Build the project:

```bash
lake build
```

3. Build the test target:

```bash
lake build LeanRedisTest
```

## Quick Start

```lean
import LeanRedis

open LeanRedis
open Std.Internal.IO.Async

def example : Async (Option String) := do
  let client <- Client.newDefault {
    endpoint := { host := "127.0.0.1", port := 6379 }
    reconnectStrategy := .exponentialBackoff {}
  }
  let _ <- client.connect
  let _ <- client.set "greeting" "hello"
  client.get "greeting"
```

## Examples

Basic connection commands:

```lean
def pingExample : Async (Option String) := do
  let client <- LeanRedis.Client.newDefault {
    endpoint := { host := "127.0.0.1", port := 6379 }
  }
  let _ <- client.connect
  client.ping
```

Reconnect and event callbacks:

```lean
def reconnectingExample : Async Unit := do
  let client <- LeanRedis.Client.newDefault {
    endpoint := { host := "127.0.0.1", port := 6379 }
    reconnectStrategy := .exponentialBackoff {
      baseDelayMs := 100
      maxDelayMs := 5_000
      jitter := true
    }
  }
  let _sub <- client.onEvent fun event => do
    IO.println s!"redis event: {repr event}"
  let _ <- client.connect
  pure ()
```

String operations:

```lean
def stringExample : Async (Option String) := do
  let client <- LeanRedis.Client.newDefault {
    endpoint := { host := "127.0.0.1", port := 6379 }
  }
  let _ <- client.connect
  let _ <- client.set "counter" "1"
  let _ <- client.incr "counter"
  client.get "counter"
```

Hash operations:

```lean
def hashExample : Async (Array (String × String)) := do
  let client <- LeanRedis.Client.newDefault {
    endpoint := { host := "127.0.0.1", port := 6379 }
  }
  let _ <- client.connect
  let _ <- client.hSet "user:1" #[("name", "alice"), ("role", "admin")]
  client.hGetAll "user:1"
```

Sorted set operations:

```lean
def sortedSetExample : Async (Array LeanRedis.SortedSetEntry) := do
  let client <- LeanRedis.Client.newDefault {
    endpoint := { host := "127.0.0.1", port := 6379 }
  }
  let _ <- client.connect
  let _ <- client.zAdd "scores" #[
    { score := "10", member := "alice" },
    { score := "20", member := "bob" }
  ]
  client.zRangeWithScores "scores" 0 (-1)
```

Mocked transport for tests:

```lean
import LeanRedis

open LeanRedis
open Std.Internal.IO.Async

structure FakeTransport where
  replies : IO.Ref (Array ByteArray)

private def popReply (ref : IO.Ref (Array ByteArray)) : IO ByteArray := do
  let replies <- ref.get
  match replies[0]? with
  | some reply =>
      ref.set (replies.extract 1 replies.size)
      pure reply
  | none =>
      pure ByteArray.empty

instance : Transport.Transport FakeTransport where
  connect _ := do
    let replies <- IO.mkRef #["+PONG\r\n".toUTF8]
    pure { replies }

  recv transport _ := do
    let bytes <- popReply transport.replies
    if bytes.isEmpty then
      pure { bytes := ByteArray.empty, disconnect? := some .closedByPeer }
    else
      pure { bytes }

  send _ _ := pure ()
  close _ := pure ()

def pingWithMock : Async (Option String) := do
  let client : Client FakeTransport <- Client.new {
    endpoint := { host := "mock", port := 0 }
  }
  let _ <- client.connect
  client.ping
```

This is the same mechanism used by the library test suite for scripted bootstrap, partial replies, and disconnect scenarios.

## API Overview

Main public entry points:

- `Client.new`
- `Client.newDefault`
- `Client.connect`
- `Client.disconnect`
- `Client.isConnected`
- `Client.connectionStatus`
- `Client.onEvent`
- `Client.offEvent`
- `Client.currentState`

Design notes:

- `new*` allocates client state only
- `new*` is `IO` because it allocates mutable client state, but it does not open a connection
- `connect` performs transport setup and Redis bootstrap
- commands fail fast while disconnected or reconnecting
- remote disconnects trigger background reconnect only when `reconnectStrategy` is enabled
- `onEvent` and `offEvent` are lightweight `IO` registration calls; callback delivery is fire-and-forget
- command methods are typed and async
- command families are split into dedicated modules internally

## Testing

Build the test target with:

```bash
lake build LeanRedisTest
```

The test suite covers:

- RESP parser basics
- incremental parsing across fragmented inputs
- command encoding
- bootstrap encoding and negotiation behavior
- scripted transport behavior
- connection bootstrap and reconnect scenarios
- typed client decoding for all implemented command families
- runtime-level scripted partial-read and disconnect handling

Tests live under `Test/` and are primarily Lean-native `#guard_msgs` / `#eval` checks.

## Project Layout

Public modules:

- `LeanRedis`
- `LeanRedis.Command`
- `LeanRedis.Client`

Internal command layout:

- `LeanRedis/Command/Base.lean`
- `LeanRedis/Command/Connection.lean`
- `LeanRedis/Command/String.lean`
- `LeanRedis/Command/Hash.lean`
- `LeanRedis/Command/List.lean`
- `LeanRedis/Command/Set.lean`
- `LeanRedis/Command/SortedSet.lean`
- `LeanRedis/Command/Generic.lean`

Internal client layout:

- `LeanRedis/Client/Internal.lean`
- `LeanRedis/Client/Connection.lean`
- `LeanRedis/Client/String.lean`
- `LeanRedis/Client/Hash.lean`
- `LeanRedis/Client/List.lean`
- `LeanRedis/Client/Set.lean`
- `LeanRedis/Client/SortedSet.lean`
- `LeanRedis/Client/Generic.lean`

## Status

Implemented and verified:

- architecture and module boundaries
- RESP protocol support
- transport abstraction and default TCP transport
- connection management
- async public client API
- connection, generic, string, hash, list, set, and sorted-set command families

Tracking details live in `docs/features/TODO.md`.

## License

MIT License. See [`LICENSE`](./LICENSE).
