"""Handlers shared by count, so the offload pool can own any handler.

The offload pool keeps its own copy of a worker's handler, so a job
still running when the worker stops has a live handler after the worker
returns (ADR-0004). A handler that is not ``Copyable`` gets that copy
through these wrappers: the server moves it to the heap once, and every
copy of the wrapper points at it. The last copy dropped, the server's
or the pool's, frees it.
"""

from std.memory import ArcPointer

from .cancel import Cancel
from .handler import CancelHandler, Handler
from .request import Request
from .response import Response, ResponseImpl


struct SharedHandler[H: Handler](Copyable, Handler):
    """A ``Handler`` on the heap; copies share it."""

    comptime BodyType = Self.H.BodyType

    var inner: ArcPointer[Self.H]

    def __init__(out self, var handler: Self.H):
        self.inner = ArcPointer(handler^)

    def serve(self, req: Request) raises -> ResponseImpl[Self.BodyType]:
        return self.inner[].serve(req)

    def may_block(self) -> Bool:
        return self.inner[].may_block()

    def blocking(self, req: Request) raises -> Bool:
        return self.inner[].blocking(req)


struct SharedCancelHandler[CH: CancelHandler](CancelHandler, Copyable):
    """A ``CancelHandler`` on the heap; copies share it."""

    var inner: ArcPointer[Self.CH]

    def __init__(out self, var handler: Self.CH):
        self.inner = ArcPointer(handler^)

    def serve(self, req: Request, cancel: Cancel) raises -> Response:
        return self.inner[].serve(req, cancel)

    def may_block(self) -> Bool:
        return self.inner[].may_block()

    def blocking(self, req: Request) raises -> Bool:
        return self.inner[].blocking(req)
