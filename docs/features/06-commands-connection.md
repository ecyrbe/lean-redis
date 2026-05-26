# 06 - Connection Commands

## Goal

Provide the high-level command surface needed for connection setup, liveness checks, and database selection.

## Scope

- auth-related command support needed for v1 bootstrap and public API
- `PING`
- `SELECT`
- protocol negotiation support where it affects command behavior

## Non-Goals

- pub/sub connection mode
- sentinel or cluster management commands
- advanced client metadata commands unless required for bootstrap

## Design

This feature covers the command family closest to the connection lifecycle.

Some commands will be used both:

- internally during bootstrap
- publicly through the async client API

The implementation should avoid duplicating bootstrap-only and public command logic where possible.

## Command Coverage

At minimum, support:

- `AUTH`
- `PING`
- `SELECT`
- `HELLO` as an internal protocol/bootstrap requirement, with public exposure only if it cleanly fits the API design

`QUIT` should not be a priority unless it materially improves public lifecycle semantics.

## Typing Direction

Use concrete result types where the result is stable and useful:

- `PING` -> unit or a small typed response depending on final API style
- `SELECT` -> unit
- `AUTH` -> unit

## Public API Impact

These commands define the baseline client experience and should be available early.

## Dependencies

- [02 - Protocol Support](./02-protocol.md)
- [04 - Connection Management](./04-connection-management.md)
- [05 - Async Client API](./05-async-client-api.md)

## Acceptance Criteria

- bootstrap can use auth and database selection automatically
- users can call `ping` and `select` through the public async API
- command decoding works in both RESP2 and RESP3 session modes for v1-supported servers

## Example

```lean
let _ <- client.ping
let _ <- client.select 2
```

## Diagram

```text
Client config
   |
   +--> AUTH if configured
   +--> HELLO 3
   +--> SELECT if configured
   v
Ready session
```
