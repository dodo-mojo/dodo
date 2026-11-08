# `dodo.http.routes`

Comptime-compiled route table and ``ComptimeRouter``.

``Router`` in ``dodo.http.router`` is a runtime-driven
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

A malformed pattern (see ``dodo.http._route_path``)
is a compile error carrying the parser's message, and so is a method
and path listed twice.

Same status-code contract as ``Router``: unknown path → 404, known
path wrong method → 405 with a synthesised ``Allow:`` header. Path
parameters captured by a match land in ``req.params_mut()``
percent-decoded, and a bad escape returns 400, just like the runtime
router.

## Structs

### `ComptimeRoute`

```mojo
struct ComptimeRoute
```

A comptime-known ``(method, pattern, handler)`` triple.

All three fields share a common function-pointer signature
(``def(Request) raises -> Response``), so a homogeneous
``List[ComptimeRoute]`` can live as a comptime value and be
unrolled by ``ComptimeRouter.serve`` at compile time.

Fields:

- `method` (`StaticString`)
- `pattern` (`StaticString`)
- `handler` (`def(Request) raises thin -> Response`)

Implemented traits: `AnyType`, `Copyable`, `Deinitable`, `Movable`

### `ComptimeRouter`

```mojo
struct ComptimeRouter[routes: List[ComptimeRoute]]
```

A ``Handler`` whose route table is comptime-parametric.

``ComptimeRouter`` carries no runtime handler table — the
handlers are part of the comptime ``routes`` parameter — so the
struct is zero-size (``__init__`` is a no-op). Pass it to
``HttpServer.serve`` the same way as the runtime ``Router``.

Parameters:

- `routes`: Comptime-known list of ``(method, pattern, handler)`` triples. Segment parsing happens at compile time; the dispatch loop unrolls via ``comptime for`` so each iteration sees the route's pattern and handler as comptime values and the compiler can inline both.

Implemented traits: `AnyType`, `Copyable`, `Deinitable`, `Handler`, `Movable`

Aliases:

- `BodyType = InlineBody`: The ``Body`` impl this handler authors its response with.

#### `ComptimeRouter.__init__`

```mojo
def __init__(out self)
```

#### `ComptimeRouter.serve`

```mojo
def serve(self, req: Request) raises -> Response
```

Dispatch ``req`` by walking the comptime routes table.

Same contract as ``Router.serve``: first matching route wins;
404 on no match; 405 with ``Allow:`` header on method mismatch.

#### `ComptimeRouter.route_list`

```mojo
def route_list(self) raises -> List[RouteInfo]
```

Every route, in table order, for `dodo routes`.
