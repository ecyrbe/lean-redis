# 04 - Connection Management and Background Reconnect

## Goal

Provide integrated connection management that detects remote disconnects, reconnects in the background using pluggable strategies, and surfaces connection lifecycle events.

## Scope

- session lifecycle management
- disconnect detection
- reconnect initiation
- reconnect scheduling
- event publication
- clean separation between session state and transport lifecycle

## Non-Goals

- pooling
- multiplexing guarantees beyond the chosen async command execution model
- cluster redirection or topology tracking

## Design

Connection management should sit above transport and below the public async API.

The client-facing connection layer should own:

- lifecycle status
- bootstrap on new connections
- detection of broken sessions
- background reconnect attempts after remote disconnect
- event callbacks for disconnect and reconnect transitions

It should not automatically retry user commands.

The implemented split is:

- `Connection.Manager` owns bootstrap and the current runtime handle
- `Connection.Runtime` owns one live transport plus parser state
- `Client` owns serialized request execution, richer lifecycle state, event fanout, and the reconnect worker

Reconnect only begins after a remote disconnect is detected. Initial connect failures do not start background reconnect because they may be caused by invalid user configuration.

## Reconnect Strategy

Reconnect is configured through `Config.reconnectStrategy`.

Built-in strategies:

- `disabled`
- `fixedInterval delayMs maxAttempts?`
- `exponentialBackoff config maxAttempts?`

Exponential backoff supports:

- base delay
- max delay
- optional jitter

## Request Handling Across Disconnect

The implemented rules are:

- in-flight commands fail immediately on remote disconnect
- commands issued while disconnected or reconnecting fail immediately with `unavailable`
- user commands are never auto-retried
- successful `AUTH` and `SELECT` update reconnect-safe bootstrap state for future reconnects

## Events

Users can register async callbacks through `client.onEvent` and remove them with `client.offEvent`.

Supported events include:

- initial connect failed
- remote disconnected
- reconnect attempt started
- reconnect attempt failed
- reconnect scheduled
- reconnected
- reconnect stopped
- explicitly disconnected

## Public API Impact

Users should be able to configure reconnect behavior through client configuration, without manually rebuilding clients on ordinary disconnects.

## Dependencies

- [01 - Architecture and Module Boundaries](./01-architecture.md)
- [02 - Protocol Support](./02-protocol.md)
- [03 - Transport Abstraction and TCP](./03-transport.md)
- [05 - Async Client API](./05-async-client-api.md)

## Acceptance Criteria

- disconnects are detected and transition the session out of ready state
- reconnect attempts are strategy-driven
- bootstrap reruns on each fresh session
- commands fail fast while reconnect is in progress
- no automatic command replay occurs
- event callbacks surface disconnect and reconnect transitions
- command code does not own reconnect logic

## Example

If a TCP socket closes between two commands, the client should mark itself reconnecting, notify subscribers, create a new transport in the background according to the configured reconnect strategy, rerun bootstrap, and return to ready state when that succeeds.

## Diagram

```text
Ready
  |
  +--> disconnect detected
          |
          v
      Reconnecting
          |
          v
      Reconnect strategy
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
