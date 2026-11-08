# `dodo.http.router`

HTTP request router with method dispatch + path parameters.

A ``Router`` is a ``Handler`` that dispatches each request to a
per-(method, path) inner handler. It supports:

- **Literal segments**: ``"/users"`` matches exactly ``/users``.
- **Parameter segments**: ``"{id}"`` matches one segment of any non-empty
  value; the captured value lands in ``req.params[name]``. A param fills
  the whole segment: ``"/a{id}"`` is an error.
- **Catch-all tail**: a final segment ``"{*rest}"`` matches the rest of
  the path (captured as ``req.param("rest")``, including path
  separators). It needs at least one remaining segment.
- **Decoded params**: captured values are percent-decoded once, and a bad
  escape returns **400**. A decoded value can hold ``/``, ``..`` or a NUL
  byte, so check it before using it as a file path. Literal segments are
  compared undecoded: ``/%75sers`` does not match ``/users``.
- **Method dispatch**: ``get`` / ``post`` / ``put`` / ``patch`` /
  ``delete`` / ``head`` register one handler per (method, path) pair.
  Registering a pair twice raises, and so does mounting a prefix twice.

Unknown paths return **404 Not Found**; known paths called with the
wrong method return **405 Method Not Allowed** with a synthesised
``Allow:`` header listing the supported methods.

Sub-router mounting (``mount(prefix, sub)``) attaches a whole nested
``Router`` under a literal path prefix (e.g. ``/api/v1``). The mounted
router is owned by value behind the same ``ArcPointer`` refcount the
struct-handler registry uses, so Router copies (one per worker) share
the mounted subtree without double-freeing it. A mounted prefix owns
its entire subtree: direct routes registered on the parent take
priority, and any unmatched request whose path starts with the prefix
is delegated (with the prefix stripped) to the sub-router, which runs
its own method dispatch and 404/405 synthesis.

Example:

```mojo
from dodo.http import Router, Request, Response, ok, not_found

def home(req: Request) raises -> Response:
    return ok("home")

def get_user(req: Request) raises -> Response:
    return ok("user " + req.param("id"))

def main() raises:
    var r = Router()
    r.get("/", home)
    r.get("/users/{id}", get_user)

    # `r` is a Handler; pass it to HttpServer.serve.
```

This first release uses a simple runtime match (linear scan per depth
plus a per-entry segment compare). A compile-time trie lives on the
roadmap; the public Router API will not change when the trie
lands, only the internal representation.

## Structs

### `Router`

```mojo
struct Router
```

HTTP router with method dispatch, path parameters, and nesting.

Accepts both plain ``def(Request) raises -> Response`` functions
(wrapped internally in ``FnHandler``) **and** arbitrary
``H: Handler & Copyable`` structs (boxed via ``_StructHandler``
with monomorphised serve / destroy thunks).
Use the latter to register
``Extracted[H]()``, app-state-bearing handlers, middleware
wrappers, and any other stateful Handler.

Routes are stored as ``(method, compiled-segments,
handler-kind, handler-index)`` quadruples; ``handler-kind``
selects ``_handlers`` (FnHandler list) or ``_struct_handlers``
(boxed Handler structs) for the actual call site.

Example:
```mojo
var r = Router()
r.get("/", home) # def(Request)
r.get("/users/{id}", Extracted[GetUser]()) # Handler struct
```

Implemented traits: `AnyType`, `Copyable`, `Defaultable`, `Deinitable`, `Handler`, `Movable`

Aliases:

- `BodyType = InlineBody`: The ``Body`` impl this handler authors its response with.

#### `Router.__init__`

```mojo
def __init__(out self)
```

Create an empty router (no routes).

#### `Router.get`

```mojo
def get(mut self, path: String, handler: def(Request) raises thin -> Response) raises
```

Register ``handler`` for ``GET path``.

Args:

- `path`: Route pattern (e.g. ``"/users/{id}"``).
- `handler`: The function to call on a match.

```mojo
def get[H: Handler & Copyable](mut self, path: String, var handler: H) raises
```

Register ``handler`` (a Handler struct) for ``GET path``.

``H`` is type-erased into ``_StructHandler`` via heap
allocation + monomorphised serve / destroy thunks; the
per-request dispatch is a direct call through the cached
thunk pointer with no trait-table lookup.

Use this overload to register ``Extracted[H]()``, app-state
handlers, middleware-wrapped handlers, and any user-defined
Handler struct. The ``def(Request) raises -> Response``
overload above continues to work unchanged.

Args:

- `path`: Route pattern (e.g. ``"/users/{id}"``).
- `handler`: A ``Handler & Copyable`` instance; ownership transfers into the Router (the Router owns the heap allocation and frees it in its destructor).

#### `Router.post`

```mojo
def post(mut self, path: String, handler: def(Request) raises thin -> Response) raises
```

Register ``handler`` for ``POST path``.

```mojo
def post[H: Handler & Copyable](mut self, path: String, var handler: H) raises
```

Register ``handler`` (a Handler struct) for ``POST path``. See ``get[H]`` for the type-erasure shape.

#### `Router.put`

```mojo
def put(mut self, path: String, handler: def(Request) raises thin -> Response) raises
```

Register ``handler`` for ``PUT path``.

```mojo
def put[H: Handler & Copyable](mut self, path: String, var handler: H) raises
```

Register ``handler`` (a Handler struct) for ``PUT path``. See ``get[H]`` for the type-erasure shape.

#### `Router.patch`

```mojo
def patch(mut self, path: String, handler: def(Request) raises thin -> Response) raises
```

Register ``handler`` for ``PATCH path``.

```mojo
def patch[H: Handler & Copyable](mut self, path: String, var handler: H) raises
```

Register ``handler`` (a Handler struct) for ``PATCH path``. See ``get[H]`` for the type-erasure shape.

#### `Router.delete`

```mojo
def delete(mut self, path: String, handler: def(Request) raises thin -> Response) raises
```

Register ``handler`` for ``DELETE path``.

```mojo
def delete[H: Handler & Copyable](mut self, path: String, var handler: H) raises
```

Register ``handler`` (a Handler struct) for ``DELETE path``. See ``get[H]`` for the type-erasure shape.

#### `Router.head`

```mojo
def head(mut self, path: String, handler: def(Request) raises thin -> Response) raises
```

Register ``handler`` for ``HEAD path``.

```mojo
def head[H: Handler & Copyable](mut self, path: String, var handler: H) raises
```

Register ``handler`` (a Handler struct) for ``HEAD path``. See ``get[H]`` for the type-erasure shape.

#### `Router.options`

```mojo
def options(mut self, path: String, handler: def(Request) raises thin -> Response) raises
```

Register ``handler`` for ``OPTIONS path``.

```mojo
def options[H: Handler & Copyable](mut self, path: String, var handler: H) raises
```

Register ``handler`` (a Handler struct) for ``OPTIONS path``. See ``get[H]`` for the type-erasure shape.

#### `Router.trace`

```mojo
def trace(mut self, path: String, handler: def(Request) raises thin -> Response) raises
```

Register ``handler`` for ``TRACE path``.

```mojo
def trace[H: Handler & Copyable](mut self, path: String, var handler: H) raises
```

Register ``handler`` (a Handler struct) for ``TRACE path``. See ``get[H]`` for the type-erasure shape.

#### `Router.connect`

```mojo
def connect(mut self, path: String, handler: def(Request) raises thin -> Response) raises
```

Register ``handler`` for ``CONNECT path``.

```mojo
def connect[H: Handler & Copyable](mut self, path: String, var handler: H) raises
```

Register ``handler`` (a Handler struct) for ``CONNECT path``. See ``get[H]`` for the type-erasure shape.

#### `Router.fallback`

```mojo
def fallback(mut self, handler: def(Request) raises thin -> Response)
```

Set a custom fallback handler.

Invoked when no registered route matched and no mounted
sub-router claimed the path. Replaces the default 404 body
(the 405 path for a known path under other methods still
fires first). Registering twice keeps the last handler.

#### `Router.mount`

```mojo
def mount[H: Handler & Copyable](mut self, prefix: String, var sub: H) raises
```

Mount the handler ``sub`` under the literal path ``prefix``.

Every request whose path starts with ``prefix`` (and which no
directly-registered route on this Router already handled) is
delegated to ``sub`` with ``prefix`` stripped, so ``sub`` sees
paths relative to its mount point. ``sub`` performs its own
method dispatch and 404/405 synthesis.

The sub-router is boxed into the shared struct-handler registry
(heap-allocated, monomorphised destroy thunk) so it is owned by
value and freed exactly once on the last Router drop -- the same
ownership model as struct handlers.

Args:

- `prefix`: A literal path prefix, e.g. ``"/api/v1"``. Param (``{id}``) and catch-all (``{*rest}``) segments are rejected.
- `sub`: The handler to mount, usually a ``Router`` or an ``App``; ownership transfers in.

#### `Router.route_count`

```mojo
def route_count(self) -> Int
```

Number of registered top-level routes (excludes mounts).

#### `Router.route_method`

```mojo
def route_method(self, i: Int) -> String
```

HTTP method of route ``i`` (uppercase, e.g. ``GET``).

#### `Router.route_openapi_template`

```mojo
def route_openapi_template(self, i: Int) -> String
```

Route ``i``'s path as an OpenAPI template: ``{id}`` stays ``{id}`` and ``{*rest}`` becomes ``{rest}`` (``/`` for the empty root).

#### `Router.route_list`

```mojo
def route_list(self) raises -> List[RouteInfo]
```

Every route, the routes of each mount under its prefix, then the fallback, in the order :meth:`serve` tries them.

#### `Router.route_path_params`

```mojo
def route_path_params(self, i: Int) -> List[String]
```

Names of route ``i``'s path parameters (``{name}`` and ``{*name}`` segments).

#### `Router.serve`

```mojo
def serve(self, req: Request) raises -> Response
```

Dispatch ``req`` to the matching handler.

Returns the handler's response, or a 404 / 405 if no
route matches.

#### `Router.may_block`

```mojo
def may_block(self) -> Bool
```

Whether some route or mount below this router is offloaded.

#### `Router.blocking`

```mojo
def blocking(self, req: Request) raises -> Bool
```

Whether the route ``req`` matches is offloaded.

Follows the same matching order as :meth:`serve`: direct routes,
then the first matching mount. 404, 405 and the fallback always
run inline.
