# 01 - Architecture and Module Boundaries

## Goal

Define a clean architecture for an async Redis client whose internals are transport-independent and IO-less.

## Scope

- internal layering rules
- ownership boundaries between client, connection manager, transport, engine, and codec
- deterministic state-machine design
- module-level responsibilities

## Non-Goals

- concrete API signatures for every public function
- command-level typing details
- TLS or cluster architecture

## Design

The architecture should separate runtime concerns from protocol concerns.

The public async layer performs real `IO` and integrates with Lean's async facilities. Everything below that layer should be designed so the Redis protocol logic can be advanced using ordinary data transformations and explicit state transitions.

Core principle:

- public async API drives transport IO
- transport reads and writes bytes
- engine decides what bytes should be written and how incoming bytes change session state
- codec parses and encodes RESP values

This makes the Redis logic testable without sockets and without direct dependency on a specific runtime.

## Layering Rules

1. `Client` depends on configuration, connection management, command modules, and public error types.
2. `Connection.Manager` depends on transport factories, reconnect and retry policies, and the engine.
3. `Transport` depends on async runtime capabilities, but not on Redis command semantics.
4. `Engine` depends on protocol modules and request bookkeeping, but not on network IO.
5. `Protocol.Resp` depends only on parsing, encoding, and protocol value types.

## State Machine Requirements

The engine should represent explicit states such as:

- disconnected
- connecting bootstrap pending
- authenticating
- negotiating protocol
- selecting database
- ready
- failed session

The engine should also track:

- pending outbound commands
- commands awaiting replies
- bootstrap progress
- detected server protocol mode
- disconnect boundaries

No hidden control flow should exist in transport code. Protocol progress must be visible in the engine state.

## Public API Impact

This design supports:

- a simple async user-facing API
- default TCP usage
- future transport extensions without rewriting command logic
- reconnection management without baking reconnect logic into every command

## Dependencies

- [02 - Protocol Support](./02-protocol.md)
- [03 - Transport Abstraction and TCP](./03-transport.md)
- [04 - Connection Management](./04-connection-management.md)
- [05 - Async Client API](./05-async-client-api.md)

## Acceptance Criteria

- every major subsystem has a single clear responsibility
- Redis protocol logic is testable without sockets
- transport implementations can be replaced without changing command modules
- reconnect logic sits above transport and below the public API
- internal state transitions are explicit and deterministic

## Example

An async `set` call should not directly parse bytes or manage handshake details. It should submit a typed request to the client layer, which delegates execution to the connection manager, which uses the engine to produce bytes and interpret the reply.

## Diagram

```text
Client API
   |
   v
Connection Manager
   |
   +--> Reconnect / Retry Policies
   |
   v
Transport
   |
   v
Engine
   |
   v
RESP Codec
```
