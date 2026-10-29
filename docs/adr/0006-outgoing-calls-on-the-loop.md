# ADR-0006: Outgoing calls on the event loop

- Status: proposed
- Date: 2026-10-27

## Context

A handler that calls other services (another API, a model server, later a database) uses the blocking `HttpClient`. Inline, that blocks its whole worker. Wrapped in `Offload` (ADR-0004), it works but holds a pool thread per call, and a handler that needs three calls makes them one after another. At scale this is the main thing missing: thousands of requests each waiting on other services should cost connections and buffers, not threads.

Mojo has no stable async/await, so the design must not depend on it (design section 3.1).

## Decision

1. **A client on the worker's loop.** Outgoing HTTP/1.1 and HTTP/2 connections (cleartext and TLS) live on the same event loop as incoming ones, pooled per worker.
2. **Park and resume.** A handler starts one or more calls, and the request parks the same way an offloaded request does (ADR-0004: the H1 connection or the H2 stream). The loop drives the calls side by side and resumes the handler with all the results when the last one answers. The handler is a struct with steps (start calls, then finish with the results), since closures cannot be suspended.
3. **Same rules as offload.** `handler_timeout_ms` and the client's own timeouts answer `503`/`504` and cancel the outgoing calls; a client that goes away cancels them with `PEER_CLOSED`; graceful shutdown waits up to `shutdown_timeout_ms`.
4. **Room for more.** Database drivers later use the same park-and-resume mechanism. If Mojo's async/await becomes stable, `async def` handlers sit on top of it without changing the I/O layer.

## Consequences

- Fan-out costs no threads: a handler can wait on many calls at once while its worker serves other requests.
- Handlers that make outgoing calls are written as steps until Mojo has async/await.
- The client now has two forms, blocking and on the loop, which need the same parsing, TLS and limits.

## Alternatives considered

- Keep using `Offload` with the blocking client: works today, but one thread per waiting call and no parallel calls.
- Wait for async/await in Mojo: no date.
- A thread per outgoing call inside the handler: same thread cost, and threads can't capture the handler's state today.
