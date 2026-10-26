# Lightbug audit

Audit of [Lightbug](https://github.com/Lightbug-HQ/lightbug_http) as a source of reusable code for dodo.
Date: 2026-10-26. Commit audited: `04d303e` (tag `v26.2.0`). License: MIT, Copyright (c) 2023 Valentin Erokhin.

## Summary

- **Status:** archived on 2026-05-12, not maintained, and its README says it isn't production-ready.
- **Toolchain:** pinned to Mojo 0.26.2, which predates 1.0. It doesn't compile on Mojo 1.x (current: 1.2.0). Mojo 1.x removed `fn` (888 definitions in Lightbug) and deprecated `UnsafePointer` (81 uses), so every file needs porting.
- **Unit tests:** 116/116 pass on the pinned toolchain.
- **Under attack:** the server can be crashed remotely in at least two ways, and blocked indefinitely by a single idle client. Details below.
- **Verdict:** reuse the libc/socket bindings, address parsing, byte reader/writer, chunked decoder, cookies and date code after fixing them. Rewrite the server core, header model and request/response API.

Everything below was reproduced. The scripts are in [research/lightbug-audit](../research/lightbug-audit).

## How it was tested

| Test | Tool | File |
|---|---|---|
| Unit tests | `pixi run -e unit-tests test` | (Lightbug's own) |
| 26 malformed and edge-case requests against a live server | Python raw sockets | `probe.py` + `probe_server.mojo` |
| Slow client, disconnect mid-body, RST, 50×40 concurrent requests | Python | `probe2.py` |
| Connections reset before `accept()` | Python | `rst.py` |
| Load test | `wrk` at 1, 10 and 50 connections | — |
| Mutation fuzzing (300k inputs each) of the header parser and chunked decoder, plus targeted overflow cases | Mojo, `-D ASSERT=all` | `fuzz.mojo` |

## Findings

### Critical: crashes and denial of service

| # | Finding | Evidence | Where |
|---|---|---|---|
| C1 | **One 30-byte request kills the server.** A header value ending in a non-UTF-8 byte (`Host: x\x88`) makes the whitespace-trim code slice a `String` mid-codepoint, which aborts the process. | The fuzzer found it within 300k inputs. The live release build died on `printf 'GET / HTTP/1.1\r\nHost: x\x88\r\n\r\n'`. | `http/parsing.mojo:284` |
| C2 | **A client that connects and resets kills the server.** `getpeername` fails with `ENOTCONN`, the error escapes `accept()`, and `listen_and_serve` exits. Normal load also triggers it: the server died under `wrk -c50`. | `rst.py` and `wrk -c50` both left "Unhandled exception … getpeername (ENOTCONN)" and a dead process. | `connection.mojo` accept path |
| C3 | **One idle connection blocks every other client indefinitely.** The server is single-threaded and blocking, and never sets a receive timeout on accepted sockets. | With one half-sent request open, a second client timed out after 5 s. | `server.mojo:493`; `set_recv_timeout` is never called |
| C4 | **Chunk size ≥ 2^63 causes an out-of-bounds index.** `bytes_left_in_chunk` overflows to a negative value. This path is the HTTP client (response decoding), so a malicious server could trigger it. | Assert: `index (-9223372036854775790) valid range: -21 <= index < 21`. 300k random mutations found nothing; only the targeted case hit it. | `http/chunked.mojo` |
| C5 | **Requests ending in a bare LF hang.** The parser accepts LF line endings, but `find_header_end` only looks for `\r\n\r\n`. Combined with C3, this stalls the server. | `GET / HTTP/1.1\nHost: x\n\n` got no response within 3 s. | `header.mojo:613` |

### High: protocol and security

| # | Finding | Evidence |
|---|---|---|
| H1 | **Response splitting.** CR/LF in header values is written to the wire unchanged. | A handler setting `X-Echo: "a\r\nSet-Cookie: evil=1"` produced a real `Set-Cookie` header. |
| H2 | **Chunked request bodies are silently dropped.** | A POST with `Transfer-Encoding: chunked` reached the handler with `bodylen=0`. |
| H3 | **When TE and CL are both present, CL wins.** RFC 9112 §6.1 says to reject the request, or use TE and close the connection. This is a request-smuggling risk behind proxies. | `bodylen=3 te=chunked` |
| H4 | **Conflicting duplicate `Content-Length`: the last one wins.** The RFC requires a 400. | `CL: 5` then `CL: 2` → `bodylen=2` |
| H5 | **Invalid `Content-Length` is treated as 0 instead of a 400** (`-5`, `5abc`), and `+5` is accepted. | probes `neg-CL`, `garbage-CL`, `plus-CL` |
| H6 | **obs-fold continuation lines are stored as a header with an empty name.** The RFC requires a 400, or replacing them with a space. | `emptyname= folded-line` |
| H7 | **Non-UTF-8 bytes are copied into Mojo `String`s** (path and header values). This breaks the `String` invariant, and C1 is one consequence. | path `/\xff\xfe\xc3` reached the handler |
| H8 | **Socket options use BSD constants on Linux** (`SOL_SOCKET=0xFFFF`, `SO_REUSEADDR=4`, `SO_RCVTIMEO=0x1006`), so the calls fail silently. Restarts are blocked by TIME_WAIT for about 17 s, and the bind loop retries forever instead of failing. | Measured 17 s bind retry; port-in-use test was still retrying after 5 s. |

### Medium: correctness and performance

| # | Finding |
|---|---|
| M1 | Every response is `Connection: close`, so there is no keep-alive. The second of two pipelined requests is dropped because the buffer is cleared. |
| M2 | Error responses send `connection: keep-alive`, then close the connection. |
| M3 | HTTP/1.1 requests without `Host` are accepted (the RFC requires a 400). |
| M4 | Absolute-form targets (`GET http://host/path`) are rejected, but servers must accept them. |
| M5 | Wrong status codes: too many headers gets 400 instead of 431, and a body that's too large gets 400 instead of 413. |
| M6 | The server is IPv4-only. |
| M7 | Allocation-heavy: a new buffer per `read()`, the body is copied byte by byte, every header lookup lowercases (allocates), and repeated headers collapse to the last value. |
| M8 | No TLS. |
| M9 | Throughput is about 6.3k req/s at 1 connection with a new connection per request. It can't be measured at 50 connections because the server crashes (C2). |

### What held up

- All 116 unit tests pass.
- 300k mutated chunked-decoder inputs produced no invalid outputs.
- Rejected cleanly: URIs over 8 KB (414), bad method tokens, a space before the colon, the HTTP/2 preface, more than 100 headers.
- It survived clients disconnecting mid-body, and an RST after accept.
- Handler exceptions return a 500 instead of crashing.
- It responds to HTTP/1.0.
- The error-type design (typed `Variant` errors per layer) is clean and worth copying.

## Reuse decisions

| Lightbug component | Lines | Decision | Work needed |
|---|---|---|---|
| `c/` libc FFI: sockets, network, errno mapping (`socket_error.mojo`) | ~3,660 | **Reuse + fix** | Port to 1.x. Use per-target constants (`CompilationTarget.is_linux()` / `is_macos()`) to fix H8. Add `epoll`/`kqueue`, `accept4`, `SO_REUSEPORT`, `TCP_NODELAY`, `writev`. |
| `address.mojo`: host/port parsing, IPv4/IPv6 | 945 | **Reuse** | Port. Its 18 tests pass. |
| `io/bytes.mojo`: ByteReader/ByteWriter | 332 | **Reuse** | Port. Its 12 tests pass. |
| `http/parsing.mojo`: picohttpparser port | 516 | **Reuse the state machine, rewrite the output** | Parse into byte spans (offsets) and only build validated strings at the edge. Fixes C1, C5, H5, H6, H7. Strict mode is the default. |
| `http/chunked.mojo`: chunked decoder | 225 | **Reuse + fix** | Overflow check on chunk size (C4). Add an encoder (needed for streaming responses). Wire into server request bodies (H2, H3). |
| `uri.mojo` | 327 | **Reuse + fix** | Absolute-form (M4), UTF-8 validation after percent-decoding. |
| `cookie/` | 512 | **Reuse** | Port. |
| `http/date.mojo` | 111 | **Reuse** | Cache the formatted date once per second. |
| `header.mojo`: `Headers` | 645 | **Rewrite** | Ordered multi-value storage, case-insensitive comparison without allocating, CR/LF/NUL validation on set (H1), keep the `HeaderKey` constants. |
| `server.mojo`, `connection.mojo`: blocking state machine | 1,238 | **Rewrite** | Non-blocking, one event loop per core, timeouts everywhere, keep-alive, pipelining, back-pressure. Keep the state names and the "provision pool" idea. |
| `http/request.mojo`, `response.mojo`, `common_response.mojo` | 794 | **Redesign** | New API: typed extractors, streaming bodies, no full-body buffering by default. |
| `service.mojo` (`HTTPService` trait) | 75 | **Replace** | Router and handler model (see design doc). |
| `utils/owning_list.mojo` | 517 | **Drop** | Use the stdlib `List` on 1.x. |
| Tests | ~2,200 | **Reuse all** | Port the 116 tests and add the probe and fuzz suites from this audit as regression tests. |

Attribution: copied or adapted files keep the MIT notice, and the repo gets a `THIRD_PARTY_NOTICES.md` entry for Lightbug.
