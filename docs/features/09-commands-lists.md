# 09 - List Commands

## Goal

Implement mainstream non-blocking list commands with typed results.

## Scope

- push and pop operations
- indexed access
- range queries
- insertion and trimming
- length and removal operations

## Non-Goals

- blocking list commands such as `BLPOP` and `BRPOP`
- pub/sub-like streaming behavior

## Design

List support should focus on Redis list operations that fit cleanly into the async request/response model without blocking the connection.

## Command Coverage

Planned mainstream commands include:

- `LPUSH`
- `RPUSH`
- `LPUSHX`
- `RPUSHX`
- `LPOP`
- `RPOP`
- `LLEN`
- `LINDEX`
- `LRANGE`
- `LSET`
- `LTRIM`
- `LREM`
- `LINSERT`
- `LMOVE`
- `LMPOP` if considered mainstream and non-blocking enough for the final v1 cut
- `LPOS`

Blocking variants are explicitly out of scope.

## Typing Direction

Examples:

- `lpop` -> `Option α`
- `llen` -> integer type
- `lrange` -> collection type
- `lset` -> unit

## Public API Impact

List commands should expose readable types and option records for commands that otherwise have positional Redis arguments.

## Dependencies

- [02 - Protocol Support](./02-protocol.md)
- [05 - Async Client API](./05-async-client-api.md)

## Acceptance Criteria

- mainstream non-blocking list commands are covered
- blocking commands are explicitly absent from v1
- option-bearing commands use typed options where appropriate
- list results decode consistently in RESP2 and RESP3 sessions

## Example

```lean
let _ <- client.rPush "jobs" #["a", "b", "c"]
let head <- client.lPop "jobs"
let items <- client.lRange "jobs" 0 (-1)
```

## Diagram

```text
Typed list command --> encoded Redis command --> parsed reply --> typed list result
```
