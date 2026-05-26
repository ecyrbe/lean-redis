# 02 - RESP2 and RESP3 Protocol Support

## Goal

Support Redis 6/7/8 servers with automatic RESP3 negotiation and RESP2 fallback.

## Scope

- RESP value model for RESP2 and RESP3
- request encoding
- incremental reply parsing
- bootstrap protocol negotiation
- server mode tracking within the session state

## Non-Goals

- pub/sub and RESP3 push messages in v1
- scripting or cluster-specific protocol extensions
- public exposure of raw RESP values

## Design

The protocol layer should support both:

- encoding outbound Redis commands into RESP request bytes
- decoding inbound RESP2 and RESP3 replies into an internal value model

The bootstrap sequence should be automatic and configuration-driven.

Recommended startup flow:

1. open transport
2. optionally authenticate if configured
3. send `HELLO 3`
4. if `HELLO 3` is unsupported, switch session mode to RESP2
5. optionally `SELECT` the configured database
6. mark the session ready

The parser must be incremental. It should be able to consume partial input across multiple reads and produce completed values only when sufficient bytes have arrived.

## Internal RESP Value Model

The internal model should be expressive enough for:

- simple strings
- blob strings
- errors
- integers
- nulls
- arrays
- maps
- sets
- booleans
- doubles
- big numbers if needed by RESP3 support

The exact final type can remain implementation-defined, but it must preserve enough structure to decode typed command responses accurately.

## Lean-Specific Direction

Use Lean native parser capabilities where practical for RESP decoding, but keep the parsing layer incremental and suitable for streaming transport input.

## Public API Impact

The public API should not require users to choose RESP2 or RESP3 manually in ordinary cases. Configuration may allow a preferred protocol mode, but normal behavior should be automatic.

## Dependencies

- [01 - Architecture and Module Boundaries](./01-architecture.md)
- [05 - Async Client API](./05-async-client-api.md)

## Acceptance Criteria

- outbound commands are encoded correctly for Redis servers
- parser can consume fragmented byte streams
- session automatically attempts `HELLO 3`
- unsupported `HELLO 3` cleanly falls back to RESP2
- protocol mode is tracked explicitly in session state
- typed command decoders can rely on the internal value model

## Example

A Redis 7 server should accept `HELLO 3` and return RESP3 replies. A Redis 6-compatible server that rejects the negotiation should still be usable via RESP2 for v1-supported commands.

## Diagram

```text
Connect
  |
  v
Optional AUTH
  |
  v
HELLO 3
  |
  +--> success -> RESP3 mode
  |
  +--> unsupported -> RESP2 mode
  |
  v
Optional SELECT
  |
  v
Ready
```
