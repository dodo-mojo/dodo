# `dodo.http.on_loop`

``OnLoop``: serve a handler in steps, so its outgoing calls run on the worker's event loop (ADR-0006).

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

## Structs

### `OnLoop`

```mojo
struct OnLoop[Inner: Calling]
```

Serves ``Inner`` in steps, so the worker runs its outgoing calls on the event loop.

Fields:

- `inner` (`Inner`): The handler that makes the calls.

Implemented traits: `AnyType`, `Copyable`, `Deinitable`, `Handler`, `Movable`

Aliases:

- `BodyType = InlineBody`: The ``Body`` impl this handler authors its response with.

#### `OnLoop.__init__`

```mojo
def __init__(out self, var inner: Inner)
```

#### `OnLoop.serve`

```mojo
def serve(self, req: Request) raises -> Response
```

Run every step here, with blocking calls. A server loop that runs calls on the loop calls ``start`` and ``finish`` instead.

#### `OnLoop.may_call`

```mojo
def may_call(self) -> Bool
```

#### `OnLoop.calling`

```mojo
def calling(self, req: Request) raises -> Bool
```

#### `OnLoop.start`

```mojo
def start(self, req: Request, mut calls: Calls) raises -> Optional[ResponseImpl]
```

#### `OnLoop.finish`

```mojo
def finish(self, req: Request, mut calls: Calls) raises -> Optional[ResponseImpl]
```

#### `OnLoop.route_list`

```mojo
def route_list(self) raises -> List[RouteInfo]
```

## Traits

### `Calling`

```mojo
trait Calling
```

A handler written in steps because it calls other services.

``start`` runs first. It returns the response, or asks ``calls``
for one or more calls and returns ``None``. Once every reply is back,
``finish`` runs: it returns the response, or asks for the next round
and returns ``None`` again. Wrap it in :class:`OnLoop` to route it.

Inherits from: `AnyType`, `Copyable`, `Deinitable`, `Movable`

#### `Calling.start`

```mojo
def start(self, req: Request, mut calls: Calls) raises -> Optional[ResponseImpl]
```

The first step; see the trait.

#### `Calling.finish`

```mojo
def finish(self, req: Request, mut calls: Calls) raises -> Optional[ResponseImpl]
```

The step after each round of replies; see the trait.

## Functions

### `serve_steps_blocking`

```mojo
def serve_steps_blocking[H: Handler](handler: H, req: Request) raises -> Response
```

Serve ``req`` with ``handler``'s steps, making each round's calls with the blocking ``HttpClient``, one after another.

``OnLoop.serve`` uses this. It also runs a whole middleware stack's
steps, which is how tests check a stack without a server.
