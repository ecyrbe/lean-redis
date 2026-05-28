# lean-redis

Lean Redis client library focused on:

- Redis 6/7/8 compatibility
- RESP2 and RESP3 support
- async public API
- IO-less internal protocol and state-machine design
- transport abstraction for TCP first, other transports later

## Build

Build the library and executables:

```bash
lake build
```

## Tests

Build the compile-time test target:

```bash
lake build LeanRedisTest
```

`lake build` also builds the test target by default.

The current tests live under `Test/` and are mainly pure Lean checks using `#guard_msgs` with `#eval`.

They are written in the style:

```lean
/-
info: <expected message>
-/
#guard_msgs in
#eval <test expression>
```

The plan is:

- pure protocol and state-machine tests in `Test/`
- future runtime `IO` tests once the async client and TCP transport exist

Current tests cover:

- RESP parser basic values
- incremental parsing across multiple chunks
- multi-value parsing from one buffer
- RESP command encoding
- bootstrap command encoding
- transport wiring and byte-oriented read results
- connection bootstrap execution over scripted transports
- reconnect-policy and disconnect-state behavior
- async client constructors and connection state
- typed async `AUTH`, `PING`, and `SELECT` client methods
- string command request encoding, option encoding, and typed async string command decoding
- hash command request encoding, full-hash decoding, and typed async `HSCAN` handling
- list command request encoding, typed list reply decoding, and `LPOS` option handling
- set command request encoding, set algebra decoding, and typed async `SSCAN` handling
- sorted-set command request encoding, score-bearing reply decoding, and typed async `ZSCAN` handling
