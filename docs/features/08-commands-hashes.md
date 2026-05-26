# 08 - Hash Commands

## Goal

Implement mainstream non-blocking hash commands with typed results and support for hash iteration via `HSCAN`.

## Scope

- field reads and writes
- multi-field operations
- numeric field updates
- field existence and deletion
- full-hash retrieval helpers
- `HSCAN`

## Non-Goals

- blocking behavior
- module-specific hash extensions

## Design

The API should model Redis hashes as keyed field collections while preserving Redis semantics around missing keys and missing fields.

## Command Coverage

Planned mainstream commands include:

- `HGET`
- `HSET`
- `HMGET`
- `HMSET` only if still worth supporting for Redis 6/7/8 compatibility needs
- `HGETALL`
- `HDEL`
- `HEXISTS`
- `HLEN`
- `HKEYS`
- `HVALS`
- `HSTRLEN`
- `HINCRBY`
- `HINCRBYFLOAT`
- `HSETNX`
- `HRANDFIELD`
- `HSCAN`

The exact final list should be reconciled with current Redis 6/7/8 mainstream guidance during implementation.

## Typing Direction

Examples:

- `hget` -> `Option α`
- `hexists` -> `Bool`
- `hlen` -> integer type
- `hgetall` -> key-value collection type
- `hscan` -> cursor-oriented typed page or iterator-friendly result shape

## Public API Impact

Hashes are a common Redis data structure and should feel first-class rather than like manually parsed arrays.

## Dependencies

- [02 - Protocol Support](./02-protocol.md)
- [05 - Async Client API](./05-async-client-api.md)

## Acceptance Criteria

- mainstream non-blocking hash commands are available
- `HSCAN` has a usable typed API
- missing fields and missing hashes are represented clearly
- full-hash retrieval decodes cleanly into a predictable Lean collection type

## Example

```lean
let _ <- client.hSet "user:1" "name" "alice"
let name <- client.hGet "user:1" "name"
let fields <- client.hGetAll "user:1"
```

## Diagram

```text
Hash command API --> Redis hash command --> RESP reply --> typed field/value result
```
