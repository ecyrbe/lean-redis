# LeanRedis v1 Feature Index

This directory defines the v1 feature set for `lean-redis`.

The project goal is to build a clean, testable Lean Redis client with:

- Redis 6/7/8 compatibility
- RESP2 and RESP3 support
- automatic `HELLO 3` negotiation with RESP2 fallback
- a high-level async public API
- an internal IO-less protocol and state-machine core
- transport abstraction with TCP as the default transport
- strong typing where practical for mainstream Redis command families

This document is the master index for the feature docs and the naming glossary for the project.

## Reading Order

The file numbering indicates recommended implementation order.

1. [01 - Architecture and Module Boundaries](./01-architecture.md)
2. [02 - Protocol Support](./02-protocol.md)
3. [03 - Transport Abstraction and TCP](./03-transport.md)
4. [04 - Connection Management](./04-connection-management.md)
5. [05 - Async Client API](./05-async-client-api.md)
6. [06 - Connection Commands](./06-commands-connection.md)
7. [07 - String Commands](./07-commands-strings.md)
8. [08 - Hash Commands](./08-commands-hashes.md)
9. [09 - List Commands](./09-commands-lists.md)
10. [10 - Set Commands](./10-commands-sets.md)
11. [11 - Sorted Set Commands](./11-commands-sorted-sets.md)
12. [12 - Testing Strategy](./12-testing.md)
13. [13 - Non-Functional Requirements](./13-non-functional-requirements.md)

Implementation tracking lives in [TODO.md](./TODO.md).

## v1 Scope

Included in v1:

- async public API only
- TCP as the default transport
- transport abstraction designed so TLS can be added later
- connection bootstrap with optional auth and database selection
- reconnect handling with pluggable policies
- mainstream non-blocking Redis 6/7/8 commands for:
  - connection/auth/ping/select
  - strings
  - hashes
  - lists
  - sets
  - sorted sets
- scan commands in supported families
- scripted raw RESP frame tests

Out of scope for v1:

- sync public API
- low-level public escape hatch
- TLS transport
- pipelines
- transactions
- pub/sub
- cluster
- sentinel
- scripting
- proofs

## Definitions

### Client

The public async object used by application code. It owns configuration and exposes typed Redis commands.

### Connection Manager

The component above the transport that maintains connectivity, handles disconnect detection, drives reconnect policy, and coordinates request execution against a live session.

### Transport

The runtime-specific IO layer used to send and receive bytes. The transport is responsible for real network interaction. The transport is not responsible for Redis protocol semantics.

### Transport Factory

A configurable constructor used by the public API and connection manager to create fresh transport instances, especially during reconnect.

### Engine

The internal IO-less protocol driver. It consumes input bytes, produces output bytes, tracks pending requests, and advances protocol/session state without directly performing `IO` or `Async` actions.

### Session

The logical Redis conversation associated with one connected transport and one engine instance. A session begins at connect and ends at disconnect.

### State Machine

The deterministic internal logic that controls bootstrap, command encoding, reply parsing, error transitions, pending request matching, and reconnect boundaries.

### Codec

The RESP encoder and parser layer. It translates between bytes and internal protocol values.

### RESP Value

The internal representation of Redis protocol frames and replies. It is used internally for decoding and command result translation, even though v1 does not expose a low-level raw API publicly.

### Bootstrap

The automatic startup sequence after connect. In v1 this includes optional authentication, `HELLO 3`, RESP2 fallback when necessary, and optional database selection.

### Reconnect Policy

The pluggable strategy that decides when and how reconnect attempts occur after a disconnect.

### Retry Policy

The pluggable strategy that decides what happens to requests after disconnect and reconnect. In v1, retries may include mutating commands, but retry logic only begins once a disconnect has been detected.

## Proposed Module Map

The exact file names can evolve, but the architecture should trend toward this structure:

```text
LeanRedis
|- Client
|- Config
|- Error
|- Transport
|  |- Types
|  |- Tcp
|- Connection
|  |- Manager
|  |- Policy
|- Protocol
|  |- Resp
|  |  |- Value
|  |  |- Encode
|  |  |- Parse
|  |- Hello
|- Engine
|  |- State
|  |- RequestQueue
|  |- Session
|- Commands
|  |- Connection
|  |- Strings
|  |- Hashes
|  |- Lists
|  |- Sets
|  |- SortedSets
|- Testing
```

## Architecture Overview

```text
Application
    |
    v
Async Client API
    |
    v
Connection Manager
    |
    +---- Reconnect Policy
    |
    +---- Retry Policy
    |
    v
Transport Driver <---- TCP transport implementation
    |
    v
IO-less Engine
    |
    +---- Request / response state machine
    +---- Bootstrap state
    +---- Pending request tracking
    +---- RESP encode / parse integration
    |
    v
RESP Codec
```

## Document Convention

Each feature document uses the same sections:

- Goal
- Scope
- Non-Goals
- Design
- Public API Impact
- Dependencies
- Acceptance Criteria
- Example
- Diagram

This keeps the feature list implementation-ready.
