# ADR-0007: Remove the io_uring backend

- Status: accepted
- Date: 2026-10-29

## Context

The import (ADR-0003) brought an io_uring engine and an HTTP/1.1 loop on top of it that reads into a kernel buffer ring. Linux 6.0 or later, opt-in through `ServerConfig.use_bufring` or `DODO_BUFRING_HANDLER=1`. With the engine, the loop, its fuzzers and its tests, it was about 9,000 lines.

The loop did much less than the epoll and kqueue loops:

- It armed no timers and had no connection cap, so `serve` refused it unless every timeout was off and `max_connections` was unset. The default config never chose it.
- No WebSocket, no TLS, no HTTP/2, one listener only.
- `Request.peer` was a loopback placeholder.
- Each feature added to the reactor (offload, lingering close, the head-size cap) needed a second version for it.

No benchmark in the repo shows it beating epoll for dodo's workload. The performance pass has not run yet.

## Decision

Delete the io_uring engine, the buffer-ring loop, `use_bufring`, `DODO_BUFRING_HANDLER`, `Frontend.requires_per_worker_listener`, and their tests and fuzzers. Linux uses epoll and macOS uses kqueue.

## Consequences

- One reactor design to maintain, test and optimize. New reactor features land on every loop at once.
- Nothing is lost for users: no default config ever ran the loop.
- If the performance pass finds epoll is the bottleneck on Linux, io_uring comes back as a new ADR, built against the current `ConnHandle` and with every feature the other loops have. Git history keeps the old code for reference.

## Alternatives considered

- **Make the buffer-ring loop complete (timers, connection cap, TLS, WebSocket, peer address).** Lost: a large job for a speedup nobody has measured, before the performance pass.
- **Keep it as is, opt-in.** Lost: thousands of lines nobody can turn on with a normal config, and every reactor change would need a second version.
