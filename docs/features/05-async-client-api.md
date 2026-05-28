# 05 - Async Public Client API

## Goal

Define a clear async-only public API that exposes typed Redis commands while hiding protocol and transport complexity.

## Scope

- client configuration
- async command entry points
- default TCP constructors
- error model at the public boundary

## Non-Goals

- sync API
- public raw RESP query interface
- pipeline or transaction API

## Design

The public API should be optimized for ordinary application usage.

It should provide:

- a configuration type for endpoint, credentials, database, timeouts, and policies
- a client constructor using TCP by default
- typed async command methods grouped by Redis command families
- integration with Lean's async and custom IO error capabilities

The public API should not require users to reason about RESP frames, manual bootstrap, or transport lifecycle details.

Internally, request execution should not be owned directly by the connection manager.

Recommended split:

- `Connection.Manager` owns session lifecycle, reconnect policy, bootstrap, and live-connection replacement
- `Connection.Runtime` owns one live transport plus parser state for that connection
- `Client` and command-facing helpers build requests, execute them through a ready runtime, and decode typed replies

This keeps reconnect logic above request execution while still allowing the client to recover cleanly from disconnects.

## API Direction

The user experience should feel high-level and ergonomic.

Examples of desired capabilities:

- construct client from host/port or a config record
- await typed command results directly
- let configuration control auth, database selection, reconnect policy, and protocol preferences

The API can still be modular internally, but the external experience should look like a coherent Redis client rather than a protocol toolkit.

## Error Handling

Public operations should integrate with Lean's `IO` custom error capabilities.

The public error model should distinguish at least:

- transport or disconnect failures
- protocol errors
- Redis server errors
- response decoding or type mismatch errors
- connection bootstrap failures

## Public API Impact

This is the main user-facing deliverable of the library, so clarity matters more than exposing every low-level knob directly.

## Dependencies

- [01 - Architecture and Module Boundaries](./01-architecture.md)
- [02 - Protocol Support](./02-protocol.md)
- [03 - Transport Abstraction and TCP](./03-transport.md)
- [04 - Connection Management](./04-connection-management.md)
- all command-family docs

## Acceptance Criteria

- the public API is async-only
- a default TCP-based constructor exists
- command methods return typed results where practical
- users configure auth, protocol preference, reconnect policy, and initial DB through client configuration
- public methods surface structured errors through Lean-compatible IO error facilities

## Example

```lean
-- Illustrative shape only.
let client <- LeanRedis.Client.connect cfg
let _ <- client.set "key" "value"
let value <- client.get "key"
```

## Diagram

```text
Client Config --> Async Client --> Typed Command Method --> Connection Manager --> Connection Runtime --> RESP Codec
```
