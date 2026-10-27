"""``Offload``: run a blocking handler on the offload pool (ADR-0004).

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
once. Middleware around it runs on the pool thread too.

Served by the unified loop (the default for ``serve``), cleartext and
TLS. Other loops (the opt-in io_uring buffer ring) run it inline.
"""

from .handler import Handler
from .request import Request
from .response import ResponseImpl


struct Offload[Inner: Handler & Copyable](Copyable, Handler):
    """Marks ``Inner`` as blocking, so the server runs it on the offload
    pool instead of the worker's event loop."""

    comptime BodyType = Self.Inner.BodyType

    var inner: Self.Inner
    """The blocking handler."""

    def __init__(out self, var inner: Self.Inner):
        self.inner = inner^

    def serve(self, req: Request) raises -> ResponseImpl[Self.BodyType]:
        """Run the handler. The server calls this on a pool thread."""
        return self.inner.serve(req)

    def may_block(self) -> Bool:
        return True

    def blocking(self, req: Request) raises -> Bool:
        return True
