# Feature Implementation TODO

This file tracks implementation status for the v1 feature set.

Status values:

- `planned`: documented but not implemented
- `in_progress`: currently being implemented
- `done`: implemented and verified
- `blocked`: waiting on another feature or design decision

## Core

| ID | Feature | Status | Notes |
| --- | --- | --- | --- |
| 00 | Master index and glossary | done | Documentation set created |
| 01 | Architecture and module boundaries | done | Core module scaffold compiles |
| 02 | RESP2/RESP3 protocol support | done | Value model, parser, encoder, fallback logic, and protocol tests implemented |
| 03 | Transport abstraction and default TCP transport | done | Byte-oriented transport, default Std.Internal TCP, and custom factory wiring verified |
| 04 | Connection management and reconnect policies | done | Bootstrap execution, disconnect state transitions, and policy-driven reconnect hooks verified |
| 05 | Async public client API | done | Async client constructors, typed ping/select methods, and non-blocking state access verified |

## Commands

| ID | Feature | Status | Notes |
| --- | --- | --- | --- |
| 06 | Connection commands | done | Shared AUTH command construction plus public async AUTH, PING, and SELECT methods verified across RESP2/RESP3 bootstrap flows |
| 07 | String commands | done | Mainstream string command builders plus typed async GET/SET/MGET/MSET/MSETNX/GETDEL/GETEX/GETRANGE/GETSET/SETRANGE/STRLEN/APPEND/INCR/INCRBY/INCRBYFLOAT/DECR/DECRBY/SETNX/SETEX/PSETEX verified |
| 08 | Hash commands | done | Mainstream hash command builders plus typed async HGET/HSET/HMGET/HMSET/HGETALL/HDEL/HEXISTS/HLEN/HKEYS/HVALS/HSTRLEN/HINCRBY/HINCRBYFLOAT/HSETNX/HRANDFIELD/HSCAN verified |
| 09 | List commands | done | Mainstream list command builders plus typed async LPUSH/RPUSH/LPUSHX/RPUSHX/LPOP/RPOP/LLEN/LINDEX/LRANGE/LSET/LTRIM/LREM/LINSERT/LMOVE/LPOS verified; blocking variants remain out of scope |
| 10 | Set commands | planned | Includes SSCAN |
| 11 | Sorted set commands | planned | Includes ZSCAN |

## Quality

| ID | Feature | Status | Notes |
| --- | --- | --- | --- |
| 12 | Testing strategy | planned | Scripted raw RESP frame tests |
| 13 | Non-functional requirements | planned | Performance, determinism, testability |

## How To Use This File

When implementation starts:

1. Mark the feature `in_progress`.
2. Add short notes when the implementation scope changes.
3. Mark the feature `done` only after code and tests are complete.
4. Mark dependent features `blocked` when another unfinished feature prevents progress.
