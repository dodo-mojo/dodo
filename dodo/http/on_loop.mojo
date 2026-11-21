"""``OnLoop``: serve a handler in steps, so its outgoing calls run on the
worker's event loop (ADR-0006).

```mojo
from dodo.http import OnLoop, Router

var r = Router()
r.get("/dash", OnLoop(Dash()))
```

``Dash`` implements :trait:`Calling`: ``start`` asks for calls, the
calls run side by side while the worker serves other requests, and
``finish`` gets the replies (see :mod:`dodo.http.calls`).

Where a server loop cannot run calls yet, ``serve`` runs the same steps
with the blocking ``HttpClient``, one call after another. The answer is
the same; only the cost differs.
"""

from std.collections import Optional

from .calls import (
    CallError,
    CallReply,
    Calls,
    OutgoingCall,
    no_response_and_no_calls,
)
from .client import HttpClient
from .handler import Handler, RouteInfo
from .request import Request
from .response import Response


trait Calling(Copyable, Deinitable, Movable):
    """A handler written in steps because it calls other services.

    ``start`` runs first. It returns the response, or asks ``calls``
    for one or more calls and returns ``None``. Once every reply is back,
    ``finish`` runs: it returns the response, or asks for the next round
    and returns ``None`` again. Wrap it in :class:`OnLoop` to route it.
    """

    def start(self, req: Request, mut calls: Calls) raises -> Optional[Response]:
        """The first step; see the trait."""
        ...

    def finish(
        self, req: Request, mut calls: Calls
    ) raises -> Optional[Response]:
        """The step after each round of replies; see the trait."""
        ...


struct OnLoop[Inner: Calling](Copyable, Handler):
    """Serves ``Inner`` in steps, so the worker runs its outgoing calls on
    the event loop."""

    var inner: Self.Inner
    """The handler that makes the calls."""

    def __init__(out self, var inner: Self.Inner):
        self.inner = inner^

    def serve(self, req: Request) raises -> Response:
        """Run every step here, with blocking calls. A server loop that
        runs calls on the loop calls ``start`` and ``finish`` instead."""
        return serve_steps_blocking(self, req)

    def may_call(self) -> Bool:
        return True

    def calling(self, req: Request) raises -> Bool:
        return True

    def start(self, req: Request, mut calls: Calls) raises -> Optional[Response]:
        return self.inner.start(req, calls)

    def finish(
        self, req: Request, mut calls: Calls
    ) raises -> Optional[Response]:
        return self.inner.finish(req, calls)

    def route_list(self) raises -> List[RouteInfo]:
        return [RouteInfo("*", "/{*path}", False, True, "handler")]


def serve_steps_blocking[H: Handler](handler: H, req: Request) raises -> Response:
    """Serve ``req`` with ``handler``'s steps, making each round's calls
    with the blocking ``HttpClient``, one after another.

    ``OnLoop.serve`` uses this. It also runs a whole middleware stack's
    steps, which is how tests check a stack without a server.
    """
    if not handler.calling(req):
        return handler.serve(req).lower()
    var calls = Calls()
    var answer = handler.start(req, calls)
    while not answer:
        if calls.waiting() == 0:
            raise no_response_and_no_calls()
        _run_round_blocking(calls, req)
        answer = handler.finish(req, calls)
    return answer.take()


def _run_round_blocking(mut calls: Calls, req: Request) raises:
    """Make the waiting calls one by one and record their replies. Once
    ``req`` is cancelled, the rest are not sent."""
    var waiting = calls.take_waiting()
    for i in range(len(waiting)):
        if req.cancel.cancelled():
            calls.add_reply(
                CallReply(
                    error=CallError.CANCELLED,
                    message="the request was cancelled first",
                )
            )
        else:
            calls.add_reply(_call_blocking(waiting[i]))
    calls.end_round()


def _call_blocking(call: OutgoingCall) -> CallReply:
    """Send one call with a client of its own; a failure becomes a reply.

    ``timeout_ms`` bounds the connect and each read, since the blocking
    client has no deadline for the whole call.
    """
    try:
        var client = HttpClient(timeout_ms=call.timeout_ms).with_read_timeout(
            call.timeout_ms
        )
        return CallReply(client.send(call.request))
    except e:
        var message = String(e)
        return CallReply(error=_error_kind(message), message=message)


def _error_kind(message: String) -> Int:
    """The ``CallError`` for a blocking client's error message.

    The client raises plain ``Error`` values, so the kind is read from the
    name each error writes first.
    """
    if message.startswith("NetworkError: all addresses failed"):
        return CallError.CONNECT
    if message.startswith("DnsError"):
        return CallError.CONNECT
    if message.startswith("Timeout"):
        return CallError.TIMEOUT
    if message.startswith("UrlParseError"):
        return CallError.BAD_URL
    return CallError.FAILED
