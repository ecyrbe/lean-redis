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
| 03 | Transport abstraction and default TCP transport | planned | TLS explicitly out of scope for v1 |
| 04 | Connection management and reconnect policies | planned | Includes pluggable policies |
| 05 | Async public client API | in_progress | Minimal client and manager scaffold exists |

## Commands

| ID | Feature | Status | Notes |
| --- | --- | --- | --- |
| 06 | Connection commands | planned | AUTH, HELLO bootstrap, PING, SELECT, QUIT-like behavior if needed |
| 07 | String commands | planned | Mainstream non-blocking Redis 6/7/8 coverage |
| 08 | Hash commands | planned | Includes HSCAN |
| 09 | List commands | planned | Blocking commands out of scope |
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
