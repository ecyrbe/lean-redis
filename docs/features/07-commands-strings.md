# 07 - String Commands

## Goal

Implement mainstream non-blocking string commands with typed results suitable for ordinary Redis application usage.

## Scope

- single-key string reads and writes
- multi-key non-blocking string operations
- numeric increment and decrement operations
- expiration-related options where they belong to mainstream string command usage

## Non-Goals

- blocking operations
- Lua-backed helpers
- module-specific extensions

## Design

String commands should provide strongly typed results where the Redis response shape is stable enough to do so cleanly.

Where command result shapes vary with options, prefer a practical API design similar in spirit to established Redis client libraries rather than forcing over-engineered types.

## Command Coverage

The exact final list can be refined against Redis 6/7/8 docs during implementation, but v1 should target mainstream non-blocking commands such as:

- `GET`
- `SET`
- `MGET`
- `MSET`
- `MSETNX`
- `GETDEL`
- `GETEX`
- `GETRANGE`
- `GETSET`
- `SETRANGE`
- `STRLEN`
- `APPEND`
- `INCR`
- `INCRBY`
- `INCRBYFLOAT`
- `DECR`
- `DECRBY`
- `SETNX`
- `SETEX`
- `PSETEX`

Implementation should remove duplicates and finalize option types carefully.

## Typing Direction

Examples of likely typed outcomes:

- `get` -> `Option α` or `Option String`/`Option ByteArray` depending on conversion design
- `set` -> unit or bool depending on option semantics
- `mget` -> collection of optional values
- `incr` -> integer type
- `incrByFloat` -> float type

## Public API Impact

String operations are core to the first usable release and should be prioritized early in command implementation.

## Dependencies

- [02 - Protocol Support](./02-protocol.md)
- [05 - Async Client API](./05-async-client-api.md)

## Acceptance Criteria

- mainstream non-blocking string commands across Redis 6/7/8 are covered
- typed results are consistent and practical
- option-heavy commands use clear Lean types rather than stringly typed arguments
- command behavior works in RESP2 and RESP3 sessions

## Example

```lean
let _ <- client.set "name" "alice"
let name <- client.get "name"
let count <- client.incr "counter"
```

## Diagram

```text
Typed string command
    |
    v
Command encoder
    |
    v
RESP request bytes
    |
    v
RESP reply value
    |
    v
Typed string result
```
