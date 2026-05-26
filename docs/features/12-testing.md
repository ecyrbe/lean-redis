# 12 - Testing Strategy

## Goal

Define a testing approach that validates protocol correctness and client behavior without requiring real network IO for core coverage.

## Scope

- scripted raw RESP frame tests
- parser and encoder tests
- engine state-machine tests
- command decoding tests
- reconnect scenario tests at the manager layer where possible

## Non-Goals

- full fake Redis server state engine in v1
- exhaustive end-to-end real server integration matrix in this feature doc

## Design

The architecture is intentionally designed to make most correctness testable below the transport layer.

Primary v1 testing method:

- scripted raw RESP frames

This should allow tests to simulate:

- fragmented server replies
- bootstrap negotiation outcomes
- command success and error responses
- disconnect during request or response handling
- reconnect and replay policy behavior

## Test Layers

1. codec tests
   - request encoding
   - fragmented reply parsing
   - RESP2 and RESP3 coverage

2. engine tests
   - bootstrap state transitions
   - pending request matching
   - disconnect handling

3. client and manager tests
   - reconnect behavior driven by scripted transport events
   - policy-driven retry outcomes

4. command tests
   - typed decoding for each supported command family

## Public API Impact

Strong internal testability is one of the main reasons for the IO-less engine design. This doc should be treated as a core feature requirement, not an afterthought.

## Dependencies

- [01 - Architecture and Module Boundaries](./01-architecture.md)
- [02 - Protocol Support](./02-protocol.md)
- [04 - Connection Management](./04-connection-management.md)
- all command-family docs

## Acceptance Criteria

- scripted frame tests can simulate partial reads
- bootstrap success and fallback paths are covered
- reconnect scenarios can be tested without real sockets
- each command family has typed decoding tests
- protocol and engine tests do not require direct network IO

## Example

A test can feed bytes for a partial RESP3 `HELLO` response in multiple chunks and verify that the parser and engine remain in bootstrap state until the full reply arrives.

## Diagram

```text
Scripted transport events
        |
        v
Connection manager / engine
        |
        v
Observed state transitions and typed results
```
