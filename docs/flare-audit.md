# Flare audit

Audit of [Flare](https://github.com/ehsanmok/flare) to decide whether dodo builds on it.
Date: 2026-10-26. Version: v0.13.0, commit `8fe83c5` (2026-10-23). License: MIT. Toolchain: Mojo 1.2.0, the same as dodo.

## Summary

- **Own tests:** all 3,232 tests and 74 examples pass. The TLS suites first need a self-signed cert from `pixi run -e bench bench-tls-setup`, which the test runner does not create (F8).
- **Lightbug benchmark:** Flare fixes every critical and high Lightbug finding (C1–C5, H1–H8). Its request-smuggling defenses are stricter than the RFC requires.
- **Under attack:** no crash or hang in about 70 malformed-request probes, connection resets, slow clients, 1,000 idle connections, or 20,000 mutated requests. Every fuzz response was well-formed HTTP. 1 and 4 workers behave the same.
- **Speed:** up to 412,000 req/s at 4 workers and 1,000 connections (p99 4 ms), with no errors and no fd leaks.
- **New findings:** no critical ones. One medium finding matters behind a proxy: `Upgrade: h2c` is always honoured on plain TCP (F1). The rest are small fixes.
- **For dodo:** slow handlers block a worker, and `handler_timeout_ms` is not enforced yet (F7). Flare has the hook dodo needs to fix this itself: an async source that parks a connection until an fd fires.
- **Risk:** one maintainer wrote about 97% of the commits (F9). The MIT license means we can fork at any time.
- **Recommendation:** option 1, build on Flare. See the end of this file.

Everything below was reproduced. The scripts are in [research/flare-audit](../research/flare-audit).

## How it was tested

| Test | Tool | File |
|---|---|---|
| Flare's own suite: 20 test aggregates and 74 examples | `pixi run -e bench tests` | (Flare's own) |
| 26 Lightbug probes plus 45 new ones: chunk overflow, TE variants, header limits, h2c and WebSocket upgrade, PROXY protocol, pipelining | Python raw sockets | `probe.py`, `extra_probes.py`, `probe_server.mojo` |
| Slow clients, 1,000 idle connections, disconnect mid-body, 50×40 concurrent requests | Python | `probe2.py` |
| Connections reset before `accept()` | Python | `rst.py` |
| Network fuzzing: 4 × 2,500 mutated requests per run, with a liveness check every 200 | Python | `net_fuzz.py` |
| Load test at 1, 10, 50 and 1,000 connections | `wrk` | `run_w4_and_load.sh` |
| Stall check with a monotonic clock | Python | `stall.py` |

Each test ran against 1 worker and 4 workers.

## Lightbug findings, rechecked

| ID | Lightbug problem | Flare |
|---|---|---|
| C1 | Non-UTF-8 header byte crashes the server | **Fixed.** 400. |
| C2 | Connection reset before `accept()` kills the server | **Fixed.** Serves normally after 20 resets. |
| C3 | One idle client blocks everyone | **Fixed.** Others are served at once; a half-sent request is closed after 0.2 s; 1,000 idle connections are fine. |
| C4 | Chunk size ≥ 2^63 overflows | **Fixed.** 400 for 2^63, 2^64+5 and negative sizes. |
| C5 | Bare-LF request hangs | **Mostly fixed.** Closed after 0.5 s with no response. A chunked body with bare LFs waits for the body timeout (F5). |
| H1 | Response splitting | **Fixed.** `headers.set` rejects CR/LF (the handler gets an error, the client a 500). `set_unchecked` still lets it through (F2). |
| H2 | Chunked bodies dropped | **Fixed.** Decoded, including extensions and trailers. |
| H3 | TE and CL together | **Fixed.** 400. |
| H4 | Duplicate `Content-Length` | **Fixed.** 400, even when the values match. |
| H5 | Invalid `Content-Length` | **Fixed.** 400 for `-5`, `+5`, `5abc`, lists and huge values. |
| H6 | obs-fold | **Fixed.** 400. |
| H7 | Non-UTF-8 in path or headers | **Fixed.** 400. |
| H8 | Wrong socket constants, slow restarts | **Fixed.** The server restarted on the same port within 2 s, many times. |
| M1 | No keep-alive, pipelining broken | **Fixed.** 10 pipelined requests get 10 responses in order. |
| M2 | Error responses claim keep-alive | **Fixed.** Errors send `Connection: close`. |
| M3 | Missing `Host` accepted | **Still open** (F3). |
| M4 | Absolute-form targets rejected | **Fixed.** |
| M5 | Wrong status codes | **Mostly fixed.** 413 and 501 are used. Oversized headers get 400 or a reset, not 431 (F10). |
| M8 | No TLS | **Fixed.** TLS 1.2/1.3, mTLS, SNI and cert reload. 140 TLS tests pass. |
| M9 | Slow, crashes under load | **Fixed.** See Load. |

## New findings

| ID | Severity | Finding | Fix |
|---|---|---|---|
| F1 | Medium | **`Upgrade: h2c` is always honoured on plain TCP**, and no config turns it off (`_unified_reactor_impl.mojo:662`). Behind a proxy that forwards `Upgrade` headers, a client can switch to HTTP/2 and get past the proxy's path rules ("h2c smuggling"). | Upstream PR: an `Http2Config` flag. dodo turns it off by default. |
| F2 | Low | `HeaderMap.set_unchecked` writes CR/LF to the wire, so a careless caller can still split responses. | dodo never exposes it. |
| F3 | Low | HTTP/1.1 requests without `Host` are accepted. The RFC requires a 400. | Upstream PR or a dodo middleware. |
| F4 | Low | Lenient request lines: `HTTP/1.9` is served as 1.1. `CONNECT` and `OPTIONS *` reach the handler. `Expect: bogus` is not answered with 417. | dodo's router rejects methods and targets it doesn't route. |
| F5 | Low | Bare-LF requests are closed without a 400. A chunked body with bare LFs waits for the body timeout. | Upstream issue. |
| F6 | Medium | **A client sending the body one byte at a time holds the connection for 66 s** (`request_timeout_ms` 60 s). `max_connections` defaults to unlimited, so many such clients can use up memory and fds. | dodo sets lower defaults and a connection cap. A proxy also absorbs this. |
| F7 | Medium for dodo | `handler_timeout_ms` is documented as not enforced, and there is no thread pool for blocking handlers. A slow GPU or LLM call blocks every connection on that worker. | dodo builds its offload pool on `AsyncChunkSource`: the handler queues the job and returns a source that is `pending(fd)`; the pool signals an eventfd when done. |
| F8 | Trivial | `pixi run tests` fails the TLS suites unless `bench-tls-setup` ran first. | Upstream PR: make it a dependency of `tests`. |
| F9 | Project risk | One maintainer has 1,309 of about 1,340 commits. | Pin a version, contribute upstream, keep Flare behind dodo's own API so a fork stays cheap. |
| F10 | Low | A 64 KB header line gets 400 instead of 431. 900 KB of headers gets a connection reset. | Upstream issue. |

Not findings: `/../../etc/passwd` and `%00` reach the handler unchanged, which is correct for a server. dodo's router and static-file code must normalise and reject these (to test in Phase 1).

## Fuzzing

| Workers | Inputs | Server alive | Malformed responses |
|---|---|---|---|
| 1 | 10,000 | yes | 0 |
| 4 | 10,000 | yes | 0 |

Responses were 400 (most), 200, 501, 413, 101 (upgrades), and 500 when a mutation hit the probe server's `/raise` route. The rest were closed connections, which is correct for garbage input.

## Load

`wrk`, 10 s per run, keep-alive, against the probe server's plain-text route. `wrk` and the server shared one 16-thread machine under WSL2, so these numbers are a floor.

| Connections | 1 worker: req/s | p99 | 4 workers: req/s | p99 |
|---|---|---|---|---|
| 1 | 12,300 | 0.18 ms | 12,000 | 0.17 ms |
| 10 | 32,400 | 0.48 ms | 89,000 | 0.21 ms |
| 50 | 57,000 | 1.8 ms | 217,000 | 0.53 ms |
| 1,000 | 42,500 | 29 ms | 412,000 | 4.0 ms |

- No socket errors in any run. Open fds returned to the baseline after each run, so connections don't leak.
- Memory grew from 14 MB to 32 MB (1 worker) and 104 MB (4 workers) after load, and stayed there. This looks like retained buffers, not a leak; to confirm with a long soak in Phase 1.
- For comparison, Lightbug managed about 6,300 req/s at 1 connection and crashed at 50.

**WSL2 benchmarking trap:** some runs showed a p99 of about 1.7 s. That was not Flare. WSL2 resyncs its wall clock in 2–3 s jumps, and `wrk` times requests with the wall clock. A client timed with a monotonic clock (`stall.py`) saw zero requests over 200 ms in 875,000. Those runs were discarded.

## Recommendation: option 1, build on Flare

Flare passes the audit that Lightbug failed. It also already has what dodo planned to write for Phases 1–2: HTTP/1.1, 2 and 3, TLS, WebSocket, SSE, a router, typed extractors, middleware and metrics. Building our own core (option 3) would cost months to reach where Flare is today. Forking now (option 2) adds maintenance with no benefit, because nothing in Flare blocks dodo's AI and GPU goals.

**Decided (2026-10-26):** a hard fork, not a dependency. The code is imported once, renamed to dodo and maintained as ours ([ADR-0003](adr/0003-fork-flare-core.md)). The findings above (F1–F10) are fixed in dodo itself, along with an offload pool for blocking handlers (F7), safer defaults (F6) and a router that rejects what it doesn't route (F4).
