"""Comptime-compiled route table and ``ComptimeRouter``.

``Router`` in [`dodo.http.router`](./router.mojo) is a runtime-driven
dispatcher: patterns are parsed into segment lists at registration
time and scanned linearly on every request. That's a fine default
when routes are registered dynamically or come from user input, but
it leaves two concrete wins on the table when the route table is
known at compile time:

1. **Zero start-up work.** Segment parsing for every route happens at
   compile time via ``comptime for`` over the comptime ``routes``
   list. Nothing allocates at module import time.
2. **Monomorphised dispatch.** The serve loop unrolls per-route via
   ``comptime for`` so each iteration's literal / param / catch-all
   decision is a compile-time constant and the compiler can inline
   the per-route work. No ``List[_Route]`` iteration at runtime.

Usage mirrors the runtime ``Router``:

```mojo
from dodo.http import (
    ComptimeRoute, ComptimeRouter, Request, Response, Method, ok,
)

def home(req: Request) raises -> Response:
    return ok("home")

def get_user(req: Request) raises -> Response:
    return ok("user=" + req.param("id"))

comptime ROUTES: List[ComptimeRoute] = [
    ComptimeRoute(Method.GET, "/", home),
    ComptimeRoute(Method.GET, "/users/{id}", get_user),
]

def main() raises:
    var r = ComptimeRouter[ROUTES]()
    # r is a Handler; pass to HttpServer.serve.
```

All three fields of ``ComptimeRoute`` (method, pattern, handler) are
comptime values, so the dispatch loop monomorphises fully per route.
Because every handler shares a common ``def(Request) raises ->
Response`` signature, the list is homogeneous and can live as a
comptime constant — no separate ``set_handler`` step, no runtime
handler-index book-keeping.

A malformed pattern (see [`dodo.http._route_path`](./_route_path.mojo))
is a compile error carrying the parser's message.

Same status-code contract as ``Router``: unknown path → 404, known
path wrong method → 405 with a synthesised ``Allow:`` header. Path
parameters captured by a match land in ``req.params_mut()`` just
like the runtime router.
"""

from .handler import Handler
from .headers import HeaderMap
from .proto.ascii import ascii_unchecked_string
from .request import Request, Method, _child_request
from .response import Response, Status
from ._route_path import parse_route_path
from .router import _match, _split_path


# ── Public comptime route metadata ──────────────────────────────────────────


@fieldwise_init
struct ComptimeRoute(Copyable):
    """A comptime-known ``(method, pattern, handler)`` triple.

    All three fields share a common function-pointer signature
    (``def(Request) raises -> Response``), so a homogeneous
    ``List[ComptimeRoute]`` can live as a comptime value and be
    unrolled by ``ComptimeRouter.serve`` at compile time.
    """

    var method: StaticString
    var pattern: StaticString
    var handler: def(Request) raises thin -> Response


# ── Request path helper ─────────────────────────────────────────────────────


comptime _QMARK: UInt8 = 63


@always_inline
def _path_only(url: String) -> String:
    """Return the path portion of ``url`` (strip query string)."""
    var n = url.byte_length()
    var p = url.unsafe_ptr()
    for i in range(n):
        if p[unsafe_offset=i] == _QMARK:
            return ascii_unchecked_string(url.as_bytes()[0:i])
    return url


# ── ComptimeRouter ──────────────────────────────────────────────────────────


struct ComptimeRouter[routes: List[ComptimeRoute]](Copyable, Handler):
    """A ``Handler`` whose route table is comptime-parametric.

    Parameters:
        routes: Comptime-known list of ``(method, pattern, handler)``
            triples. Segment parsing happens at compile time; the
            dispatch loop unrolls via ``comptime for`` so each
            iteration sees the route's pattern and handler as
            comptime values and the compiler can inline both.

    ``ComptimeRouter`` carries no runtime handler table — the
    handlers are part of the comptime ``routes`` parameter — so the
    struct is zero-size (``__init__`` is a no-op). Pass it to
    ``HttpServer.serve`` the same way as the runtime ``Router``.
    """

    def __init__(out self):
        pass

    def serve(self, req: Request) raises -> Response:
        """Dispatch ``req`` by walking the comptime routes table.

        Same contract as ``Router.serve``: first matching route wins;
        404 on no match; 405 with ``Allow:`` header on method mismatch.
        """
        var url_path = _path_only(req.url)
        var seg_in = _split_path(url_path)

        var allowed = List[String]()

        # Walk the comptime route table. ``comptime for`` unrolls the
        # loop: each iteration's pattern segments, method, and handler
        # are comptime values the compiler can inline directly.
        comptime n_routes = len(Self.routes)
        comptime for i in range(n_routes):
            comptime r = Self.routes[i]
            comptime parsed = parse_route_path(String(r.pattern))
            comptime assert len(parsed.error.as_bytes()) == 0, parsed.error
            var rt_pat = materialize[parsed.segs]()
            var matched = _match(seg_in, rt_pat)
            if matched.matched:
                if r.method == req.method:
                    if len(matched.params) == 0 and not req.has_params():
                        return r.handler(req)
                    var child = _child_request(req, req.url)
                    if len(matched.params) > 0:
                        for kv in matched.params.items():
                            child.params_mut()[kv.key] = kv.value
                    return r.handler(child)
                else:
                    var m = String(r.method)
                    if not _contains(allowed, m):
                        allowed.append(m)

        if len(allowed) > 0:
            return _method_not_allowed(allowed)
        return _not_found(req.url)


# ── Response helpers ────────────────────────────────────────────────────────


def _not_found(url: String) raises -> Response:
    var msg = "Not Found"
    if url.byte_length() > 0:
        msg = "Not Found: " + url
    var body = List[UInt8](capacity=msg.byte_length())
    for b in msg.as_bytes():
        body.append(b)
    var resp = Response(status=Status.NOT_FOUND, reason="Not Found", body=body^)
    resp.headers.set("Content-Type", "text/plain")
    return resp^


def _method_not_allowed(allowed: List[String]) raises -> Response:
    var allow_value = String("")
    for i in range(len(allowed)):
        if i > 0:
            allow_value += ", "
        allow_value += allowed[i]
    var body = List[UInt8]()
    var msg = "Method Not Allowed"
    for b in msg.as_bytes():
        body.append(b)
    var resp = Response(
        status=Status.METHOD_NOT_ALLOWED,
        reason="Method Not Allowed",
        body=body^,
    )
    resp.headers.set("Content-Type", "text/plain; charset=utf-8")
    resp.headers.set("Allow", allow_value)
    return resp^


@always_inline
def _contains(xs: List[String], x: String) -> Bool:
    for i in range(len(xs)):
        if xs[i] == x:
            return True
    return False
