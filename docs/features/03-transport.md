# 03 - Transport Abstraction and Default TCP Transport

## Goal

Define a transport abstraction that cleanly separates byte IO from Redis protocol handling, with TCP as the default v1 transport.

## Scope

- transport interface responsibilities
- transport factory design
- default TCP transport
- reconnect-friendly transport creation

## Non-Goals

- TLS implementation
- Unix sockets
- transport-specific command semantics

## Design

The transport abstraction should operate only at the byte level.

It should provide the minimum capabilities needed by the connection manager:

- connect to an endpoint
- read incoming bytes
- write outgoing bytes
- close or observe disconnect

Transport instances should be created via a transport factory so reconnect can create a fresh transport cleanly.

TCP should be the default transport used by the main public constructors.

## Responsibilities

Transport responsibilities:

- establishing a live byte stream
- reading and writing byte buffers
- surfacing IO failure and disconnect conditions

Non-responsibilities:

- command encoding
- reply parsing
- protocol negotiation
- request matching
- retry decisions

## Future Compatibility Constraint

Although TLS is out of scope for v1, the abstraction must not assume plain TCP-only semantics in the engine or client API. Future TLS support should be addable as another transport implementation or wrapped transport layer.

## Public API Impact

The public client API should:

- use TCP by default
- allow advanced users to supply a custom transport factory

This preserves a simple entry point while keeping the system extensible.

## Dependencies

- [01 - Architecture and Module Boundaries](./01-architecture.md)
- [04 - Connection Management](./04-connection-management.md)
- [05 - Async Client API](./05-async-client-api.md)

## Acceptance Criteria

- the transport interface is byte-oriented and protocol-agnostic
- default client constructors use TCP without extra configuration
- reconnect can create fresh transport instances through a factory boundary
- transport failures are surfaced clearly to the connection manager

## Example

A user can create a client with host and port only, and the library will use TCP automatically. An advanced test or adapter can provide a custom transport factory without changing command code.

## Diagram

```text
Client Config
   |
   +--> default TCP transport factory
   |
   +--> custom transport factory
             |
             v
         Transport Instance
             |
         bytes in/out
```
