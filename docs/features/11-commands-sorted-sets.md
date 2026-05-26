# 11 - Sorted Set Commands

## Goal

Implement mainstream non-blocking sorted set commands with typed results and support for `ZSCAN`.

## Scope

- add, remove, score, and cardinality operations
- rank and range operations
- score-based queries
- lex queries where mainstream support makes sense
- set combination operations
- `ZSCAN`

## Non-Goals

- blocking sorted-set commands
- geo or stream-related features

## Design

Sorted set APIs should balance type clarity with Redis command breadth. Commands with many options should use Lean records or enums rather than raw positional arguments.

## Command Coverage

Planned mainstream commands include:

- `ZADD`
- `ZREM`
- `ZCARD`
- `ZSCORE`
- `ZMSCORE`
- `ZRANK`
- `ZREVRANK`
- `ZRANGE`
- `ZREVRANGE`
- `ZRANGEBYSCORE`
- `ZREVRANGEBYSCORE`
- `ZRANGEBYLEX`
- `ZREVRANGEBYLEX`
- `ZCOUNT`
- `ZLEXCOUNT`
- `ZREMRANGEBYRANK`
- `ZREMRANGEBYSCORE`
- `ZREMRANGEBYLEX`
- `ZINCRBY`
- `ZRANDMEMBER`
- `ZDIFF`
- `ZDIFFSTORE`
- `ZINTER`
- `ZINTERCARD`
- `ZINTERSTORE`
- `ZUNION`
- `ZUNIONSTORE`
- `ZSCAN`

Final naming should follow Redis command names while adapting to Lean style.

## Typing Direction

Examples:

- `zscore` -> `Option Float`
- `zrank` -> `Option Nat`
- `zrange` -> collection of members or member-score pairs depending on options
- `zadd` -> count or typed response depending on selected options

## Public API Impact

Sorted sets are one of the richest command families in v1, so this area will likely drive several shared option and response helper types.

## Dependencies

- [02 - Protocol Support](./02-protocol.md)
- [05 - Async Client API](./05-async-client-api.md)

## Acceptance Criteria

- mainstream non-blocking sorted set commands are available
- `ZSCAN` is supported
- range and option-heavy commands use typed option structures
- score-bearing responses decode predictably and clearly

## Example

```lean
let _ <- client.zAdd "scores" #[({ score := 10.0, member := "alice" })]
let top <- client.zRange "scores" 0 (-1)
let score <- client.zScore "scores" "alice"
```

## Diagram

```text
Sorted-set API --> options encoding --> RESP reply --> typed range/score result
```
