# ADR-0004: Offload pool for blocking handlers

- Status: proposed
- Date: 2026-10-27

## Context

Each worker runs one event loop, and handlers run inline on it. A handler that blocks (a model call, a GPU job, a slow database query) stalls every other connection on that worker until it returns. `handler_timeout_ms` can't be enforced either, because nothing can interrupt a running handler (audit finding F7).

`block_in_pool` exists, but the handler still waits for the result, so the worker is blocked all the same. The design (section 3.1) calls for `app.blocking(...)`: run the work on a thread pool and wake the loop through an eventfd when it is done.

Mojo constraints: capturing closures can't be passed to another thread today, and there is no async/await. Work handed to a pool thread must be a function with no captures plus plain data, or a handler struct.

## Decision (proposed)

1. **API: wrap a handler struct.** `Offload(handler)` marks a handler as blocking. The handler struct carries its own state (a loaded model, a DB pool), so this lines up with typed state injection in the planned `App` API (`app.post("/chat", chat, state=..., blocking=True)` becomes `Offload` underneath). Router routes can take it like any other handler.
2. **Mechanism.**
   - A process-wide pool of OS threads, sized by `ServerConfig.offload_threads` (default: the number of CPU cores).
   - When an offloaded handler is reached, the worker queues the request and the handler's address, and parks the connection: it stops reading from it and arms a timer for `handler_timeout_ms`.
   - A pool thread runs `handler.serve(req)`, puts the response on the worker's completion queue, and writes the worker's wake eventfd (the reactor already has one).
   - The worker drains completions on wake-up and writes each response as usual.
3. **Timeouts.** If `handler_timeout_ms` passes first, the client gets `503 Service Unavailable` and the request's `Cancel` is set to `TIMEOUT`, so a handler that checks it can stop early. The late result is dropped. Inline handlers still can't be interrupted; the docs say so.
4. **Client gone.** If the client closes while the job runs, `Cancel` is set to `PEER_CLOSED` and the result is dropped.
5. **Scope of v1.** HTTP/1.1 on the unified loop. HTTP/2 streams run offloaded handlers inline until v2, which parks the stream instead of the connection.

## Consequences

- One slow route no longer slows the whole worker, and `handler_timeout_ms` works for offloaded routes.
- A pool thread costs memory and a context switch per offloaded request, so fast handlers should stay inline. `dodo.prof` will flag inline handlers that hold the loop too long.
- Handlers run on two kinds of threads, so a handler's state must be safe to read from several threads at once.

## Alternatives considered

- `offload(req, fn)` called inside a handler with a capture-free function: smallest change, but the function can't reach state such as a loaded model without globals, which Mojo doesn't have.
- A route flag on the router only: the same mechanism, but it ties offloading to the router, and plain function handlers couldn't use it.
- Wait for async/await in Mojo: no date, and the design must not depend on it (section 3.1).
