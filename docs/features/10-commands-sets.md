# 10 - Set Commands

## Goal

Implement mainstream non-blocking set commands with typed results and support for `SSCAN`.

## Scope

- membership operations
- element addition and removal
- cardinality queries
- random element operations
- set algebra commands
- `SSCAN`

## Non-Goals

- blocking commands
- cluster-optimized set routing

## Design

Set commands should expose natural Lean collection-oriented results where this does not obscure Redis behavior.

## Command Coverage

Planned mainstream commands include:

- `SADD`
- `SREM`
- `SCARD`
- `SISMEMBER`
- `SMISMEMBER`
- `SMEMBERS`
- `SPOP`
- `SRANDMEMBER`
- `SMOVE`
- `SDIFF`
- `SDIFFSTORE`
- `SINTER`
- `SINTERCARD`
- `SINTERSTORE`
- `SUNION`
- `SUNIONSTORE`
- `SSCAN`

## Typing Direction

Examples:

- `sadd` -> integer count of inserted members
- `sismember` -> `Bool`
- `smembers` -> collection type
- `sscan` -> cursor-oriented typed page or iterator-friendly shape

## Public API Impact

Set commands should feel direct and unsurprising while preserving count-oriented Redis responses where they matter.

## Dependencies

- [02 - Protocol Support](./02-protocol.md)
- [05 - Async Client API](./05-async-client-api.md)

## Acceptance Criteria

- mainstream non-blocking set commands are available
- set algebra commands have clear typed results
- `SSCAN` is supported with a usable API
- membership and count commands decode consistently in both RESP modes

## Example

```lean
let _ <- client.sAdd "tags" #["lean", "redis"]
let hasLean <- client.sIsMember "tags" "lean"
let tags <- client.sMembers "tags"
```

## Diagram

```text
Set API --> command encoding --> RESP reply --> bool/count/collection result
```
