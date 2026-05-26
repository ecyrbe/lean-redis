# 04 - Connection Management and Reconnect Policies

## Goal

Provide integrated connection management that detects disconnects, reconnects using pluggable policies, and coordinates request execution across connection loss.

## Scope

- session lifecycle management
- disconnect detection
- reconnect initiation
- retry policy hooks
- clean separation between session state and transport lifecycle

## Non-Goals

- pooling
- multiplexing guarantees beyond the chosen async command execution model
- cluster redirection or topology tracking

## Design

Connection management should sit above transport and below the public async API.

It should own:

- session lifecycle
- bootstrap on new connections
- detection of broken sessions
- reconnect attempts after disconnect
- coordination of retry behavior according to policy

Retry should only begin after a disconnect is detected. It should not speculate on transient failures while the session is still considered connected.

## Policies

The design should support pluggable policies from the start.

Minimum policy shapes needed in v1:

- reconnect policy: decides when to attempt the next connection
- retry policy: decides what happens to requests affected by disconnect

Useful built-in policy directions to document even if only one is implemented first:

- fail immediately
- reconnect and retry automatically

Because you explicitly want later policy flexibility, the connection manager should treat policy as a first-class dependency rather than hard-coded behavior.

## Request Handling Across Disconnect

The connection manager should define clear rules for:

- requests not yet written when disconnect happens
- requests written but not yet answered
- requests issued after disconnect but before reconnect succeeds

The exact semantics can be refined during implementation, but the design must reserve explicit handling points for these states.

## Public API Impact

Users should be able to configure reconnect behavior through client configuration, without manually rebuilding clients on ordinary disconnects.

## Dependencies

- [01 - Architecture and Module Boundaries](./01-architecture.md)
- [02 - Protocol Support](./02-protocol.md)
- [03 - Transport Abstraction and TCP](./03-transport.md)
- [05 - Async Client API](./05-async-client-api.md)

## Acceptance Criteria

- disconnects are detected and transition the session out of ready state
- reconnect attempts are policy-driven
- bootstrap reruns on each fresh session
- retry behavior is policy-driven rather than embedded in command modules
- command code does not own reconnect logic

## Example

If a TCP socket closes between two commands, the connection manager should create a new transport, rerun bootstrap, and resume serving commands according to the configured retry policy.

## Diagram

```text
Ready
  |
  +--> disconnect detected
          |
          v
      Session failed
          |
          v
      Reconnect policy
          |
          v
      New transport
          |
          v
      Bootstrap
          |
          v
      Ready
```
