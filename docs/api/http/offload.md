# `dodo.http.offload`

``Offload``: run a blocking handler on the offload pool (ADR-0004).

Handlers run on the worker's event loop, so one that blocks (a model
call, a GPU job, a slow query) stalls every connection on that worker.
Wrapping it in ``Offload`` moves each call to a pool of OS threads; the
worker parks the HTTP/1.1 connection (or only the HTTP/2 stream) and
keeps serving everything else until the response comes back.

```mojo
from dodo.http import Offload, Router

var r = Router()
r.post("/chat", Offload(ChatHandler(model)))
```

Behaviour, set by ``ServerConfig``:

- ``offload_threads`` pool threads (default one per CPU core), shared by
  every worker in the process.
- ``offload_queue_depth`` requests may wait for a thread (default 1024).
  Past that the client gets ``503`` with ``Retry-After: 1`` at once.
- ``handler_timeout_ms`` bounds each offloaded call: the client gets
  ``503``, ``req.cancel`` flips to ``TIMEOUT`` and the late result is
  dropped. Inline handlers still can't be interrupted.
- A client that leaves (connection closed, or ``RST_STREAM`` on HTTP/2)
  flips ``req.cancel`` to ``PEER_CLOSED``; its result is dropped.

The handler runs on a pool thread while other requests run on the
workers, so its state must be safe to read from several threads at
once. Middleware around it runs on the pool thread too. Each worker's
port keeps its own copy of the server's handler, so a handler still
running when the server stops finishes on that copy and ``serve``
returns after ``shutdown_timeout_ms`` without waiting for it. A
top-level handler that is not ``Copyable`` can't be copied: then
``serve`` waits for it.

Every server loop runs it on the pool: the unified HTTP/1.1 and HTTP/2
loop, cleartext and TLS; ``serve_cancellable`` (wrap the stack in
``WithCancel``); and the HTTP/1.1-only multi-worker loop.

## Structs

### `Offload`

```mojo
struct Offload[Inner: Handler & Copyable]
```

Marks ``Inner`` as blocking, so the server runs it on the offload pool instead of the worker's event loop.

Fields:

- `inner` (`Inner`): The blocking handler.

Implemented traits: `AnyType`, `Copyable`, `Deinitable`, `Handler`, `Movable`

Aliases:

- `BodyType = Inner.BodyType`

#### `Offload.__init__`

```mojo
def __init__(out self, var inner: Inner)
```

#### `Offload.serve`

```mojo
def serve(self, req: Request) raises -> ResponseImpl[Self.BodyType]
```

Run the handler. The server calls this on a pool thread.

#### `Offload.may_block`

```mojo
def may_block(self) -> Bool
```

#### `Offload.route_list`

```mojo
def route_list(self) raises -> List[RouteInfo]
```

#### `Offload.blocking`

```mojo
def blocking(self, req: Request) raises -> Bool
```
