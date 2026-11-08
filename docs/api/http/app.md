# `dodo.http.app`

The App: one front door for routes, typed handlers, state and serving.

```mojo
from dodo import App, AppState, PathParams, Request

@fieldwise_init
struct Db(AppState):
    var name: String

@fieldwise_init
struct UserPath(PathParams):
    var id: Int

@fieldwise_init
struct User(Movable):
    var id: Int
    var db: String

def get_user(req: Request, path: UserPath, db: Db) raises -> User:
    return User(path.id, db.name)

def main() raises:
    var app = App(state=Db("people"))
    app.get["/users/{id}"](get_user)
    app.serve(port=8080)
```

A handler takes `Request` plus up to five typed arguments, each recognized by
its marker trait, and returns a `Response` or a struct sent as 200 JSON. Route
and signature mistakes fail the build. See ADR-0008.

## Structs

### `NoState`

```mojo
struct NoState
```

The state of an `App` created without one.

Implemented traits: `AnyType`, `AppState`, `Deinitable`, `Movable`

#### `NoState.__init__`

```mojo
def __init__(out self)
```

### `App`

```mojo
struct App[S: AppState = NoState]
```

Routes, one shared state and the server.

Copies share the routes and the state, so an `App` is cheap to hand to
each worker. It is a `Handler`, so stock middleware can wrap it:
`serve(Logger(app^), port=8080)`.

Pass `blocking=True` for a route whose handler blocks its thread (a
database query, a model call): `app.get["/users/{id}"](get_user,
blocking=True)`. It then runs on the offload pool, as `Offload` does
for a handler struct (ADR-0004), so the worker's event loop keeps
serving other connections. Its state must be safe to read from
several threads at once.

Implemented traits: `AnyType`, `Copyable`, `Deinitable`, `Handler`, `Movable`

Aliases:

- `BodyType = InlineBody`: The ``Body`` impl this handler authors its response with.

#### `App.__init__`

```mojo
def __init__(out self)
```

```mojo
def __init__(out self, *, var state: S)
```

#### `App.group`

```mojo
def group(self) -> Self
```

A new `App` with no routes that shares this one's state.

Mount it to give some routes their own middleware:
`app.mount("/admin", RequireAuth(admin^))`.

#### `App.mount`

```mojo
def mount[H: Handler & Copyable](mut self, prefix: String, var sub: H) raises
```

Serve `sub` under the literal path `prefix`, with the prefix stripped.

#### `App.serve`

```mojo
def serve(self, req: Request) raises -> Response
```

```mojo
def serve(self, *, port: UInt16 = UInt16(8080), host: String = "127.0.0.1", num_workers: Int = Int(0)) raises
```

Listen and serve until SIGINT, SIGTERM or SIGHUP, then let in-flight requests finish (`ServerConfig.shutdown_timeout_ms`) and return. `num_workers=0` uses every core.

#### `App.may_block`

```mojo
def may_block(self) -> Bool
```

#### `App.route_list`

```mojo
def route_list(self) raises -> List[RouteInfo]
```

Every route, mounts included, for `dodo routes`.

#### `App.blocking`

```mojo
def blocking(self, req: Request) raises -> Bool
```

#### `App.route`

```mojo
def route[path: String, R: Deinitable & Movable](mut self, method: String, handler: def(Request) raises thin -> R, blocking: Bool = False) raises
```

```mojo
def route[path: String, R: Deinitable & Movable, A0: Deinitable & Movable](mut self, method: String, handler: def(Request, A0) raises thin -> R, blocking: Bool = False) raises
```

```mojo
def route[path: String, R: Deinitable & Movable, A0: Deinitable & Movable, A1: Deinitable & Movable](mut self, method: String, handler: def(Request, A0, A1) raises thin -> R, blocking: Bool = False) raises
```

```mojo
def route[path: String, R: Deinitable & Movable, A0: Deinitable & Movable, A1: Deinitable & Movable, A2: Deinitable & Movable](mut self, method: String, handler: def(Request, A0, A1, A2) raises thin -> R, blocking: Bool = False) raises
```

```mojo
def route[path: String, R: Deinitable & Movable, A0: Deinitable & Movable, A1: Deinitable & Movable, A2: Deinitable & Movable, A3: Deinitable & Movable](mut self, method: String, handler: def(Request, A0, A1, A2, A3) raises thin -> R, blocking: Bool = False) raises
```

```mojo
def route[path: String, R: Deinitable & Movable, A0: Deinitable & Movable, A1: Deinitable & Movable, A2: Deinitable & Movable, A3: Deinitable & Movable, A4: Deinitable & Movable](mut self, method: String, handler: def(Request, A0, A1, A2, A3, A4) raises thin -> R, blocking: Bool = False) raises
```

#### `App.get`

```mojo
def get[path: String, R: Deinitable & Movable](mut self, handler: def(Request) raises thin -> R, blocking: Bool = False) raises
```

```mojo
def get[path: String, R: Deinitable & Movable, A0: Deinitable & Movable](mut self, handler: def(Request, A0) raises thin -> R, blocking: Bool = False) raises
```

```mojo
def get[path: String, R: Deinitable & Movable, A0: Deinitable & Movable, A1: Deinitable & Movable](mut self, handler: def(Request, A0, A1) raises thin -> R, blocking: Bool = False) raises
```

```mojo
def get[path: String, R: Deinitable & Movable, A0: Deinitable & Movable, A1: Deinitable & Movable, A2: Deinitable & Movable](mut self, handler: def(Request, A0, A1, A2) raises thin -> R, blocking: Bool = False) raises
```

```mojo
def get[path: String, R: Deinitable & Movable, A0: Deinitable & Movable, A1: Deinitable & Movable, A2: Deinitable & Movable, A3: Deinitable & Movable](mut self, handler: def(Request, A0, A1, A2, A3) raises thin -> R, blocking: Bool = False) raises
```

```mojo
def get[path: String, R: Deinitable & Movable, A0: Deinitable & Movable, A1: Deinitable & Movable, A2: Deinitable & Movable, A3: Deinitable & Movable, A4: Deinitable & Movable](mut self, handler: def(Request, A0, A1, A2, A3, A4) raises thin -> R, blocking: Bool = False) raises
```

#### `App.post`

```mojo
def post[path: String, R: Deinitable & Movable](mut self, handler: def(Request) raises thin -> R, blocking: Bool = False) raises
```

```mojo
def post[path: String, R: Deinitable & Movable, A0: Deinitable & Movable](mut self, handler: def(Request, A0) raises thin -> R, blocking: Bool = False) raises
```

```mojo
def post[path: String, R: Deinitable & Movable, A0: Deinitable & Movable, A1: Deinitable & Movable](mut self, handler: def(Request, A0, A1) raises thin -> R, blocking: Bool = False) raises
```

```mojo
def post[path: String, R: Deinitable & Movable, A0: Deinitable & Movable, A1: Deinitable & Movable, A2: Deinitable & Movable](mut self, handler: def(Request, A0, A1, A2) raises thin -> R, blocking: Bool = False) raises
```

```mojo
def post[path: String, R: Deinitable & Movable, A0: Deinitable & Movable, A1: Deinitable & Movable, A2: Deinitable & Movable, A3: Deinitable & Movable](mut self, handler: def(Request, A0, A1, A2, A3) raises thin -> R, blocking: Bool = False) raises
```

```mojo
def post[path: String, R: Deinitable & Movable, A0: Deinitable & Movable, A1: Deinitable & Movable, A2: Deinitable & Movable, A3: Deinitable & Movable, A4: Deinitable & Movable](mut self, handler: def(Request, A0, A1, A2, A3, A4) raises thin -> R, blocking: Bool = False) raises
```

#### `App.put`

```mojo
def put[path: String, R: Deinitable & Movable](mut self, handler: def(Request) raises thin -> R, blocking: Bool = False) raises
```

```mojo
def put[path: String, R: Deinitable & Movable, A0: Deinitable & Movable](mut self, handler: def(Request, A0) raises thin -> R, blocking: Bool = False) raises
```

```mojo
def put[path: String, R: Deinitable & Movable, A0: Deinitable & Movable, A1: Deinitable & Movable](mut self, handler: def(Request, A0, A1) raises thin -> R, blocking: Bool = False) raises
```

```mojo
def put[path: String, R: Deinitable & Movable, A0: Deinitable & Movable, A1: Deinitable & Movable, A2: Deinitable & Movable](mut self, handler: def(Request, A0, A1, A2) raises thin -> R, blocking: Bool = False) raises
```

```mojo
def put[path: String, R: Deinitable & Movable, A0: Deinitable & Movable, A1: Deinitable & Movable, A2: Deinitable & Movable, A3: Deinitable & Movable](mut self, handler: def(Request, A0, A1, A2, A3) raises thin -> R, blocking: Bool = False) raises
```

```mojo
def put[path: String, R: Deinitable & Movable, A0: Deinitable & Movable, A1: Deinitable & Movable, A2: Deinitable & Movable, A3: Deinitable & Movable, A4: Deinitable & Movable](mut self, handler: def(Request, A0, A1, A2, A3, A4) raises thin -> R, blocking: Bool = False) raises
```

#### `App.patch`

```mojo
def patch[path: String, R: Deinitable & Movable](mut self, handler: def(Request) raises thin -> R, blocking: Bool = False) raises
```

```mojo
def patch[path: String, R: Deinitable & Movable, A0: Deinitable & Movable](mut self, handler: def(Request, A0) raises thin -> R, blocking: Bool = False) raises
```

```mojo
def patch[path: String, R: Deinitable & Movable, A0: Deinitable & Movable, A1: Deinitable & Movable](mut self, handler: def(Request, A0, A1) raises thin -> R, blocking: Bool = False) raises
```

```mojo
def patch[path: String, R: Deinitable & Movable, A0: Deinitable & Movable, A1: Deinitable & Movable, A2: Deinitable & Movable](mut self, handler: def(Request, A0, A1, A2) raises thin -> R, blocking: Bool = False) raises
```

```mojo
def patch[path: String, R: Deinitable & Movable, A0: Deinitable & Movable, A1: Deinitable & Movable, A2: Deinitable & Movable, A3: Deinitable & Movable](mut self, handler: def(Request, A0, A1, A2, A3) raises thin -> R, blocking: Bool = False) raises
```

```mojo
def patch[path: String, R: Deinitable & Movable, A0: Deinitable & Movable, A1: Deinitable & Movable, A2: Deinitable & Movable, A3: Deinitable & Movable, A4: Deinitable & Movable](mut self, handler: def(Request, A0, A1, A2, A3, A4) raises thin -> R, blocking: Bool = False) raises
```

#### `App.delete`

```mojo
def delete[path: String, R: Deinitable & Movable](mut self, handler: def(Request) raises thin -> R, blocking: Bool = False) raises
```

```mojo
def delete[path: String, R: Deinitable & Movable, A0: Deinitable & Movable](mut self, handler: def(Request, A0) raises thin -> R, blocking: Bool = False) raises
```

```mojo
def delete[path: String, R: Deinitable & Movable, A0: Deinitable & Movable, A1: Deinitable & Movable](mut self, handler: def(Request, A0, A1) raises thin -> R, blocking: Bool = False) raises
```

```mojo
def delete[path: String, R: Deinitable & Movable, A0: Deinitable & Movable, A1: Deinitable & Movable, A2: Deinitable & Movable](mut self, handler: def(Request, A0, A1, A2) raises thin -> R, blocking: Bool = False) raises
```

```mojo
def delete[path: String, R: Deinitable & Movable, A0: Deinitable & Movable, A1: Deinitable & Movable, A2: Deinitable & Movable, A3: Deinitable & Movable](mut self, handler: def(Request, A0, A1, A2, A3) raises thin -> R, blocking: Bool = False) raises
```

```mojo
def delete[path: String, R: Deinitable & Movable, A0: Deinitable & Movable, A1: Deinitable & Movable, A2: Deinitable & Movable, A3: Deinitable & Movable, A4: Deinitable & Movable](mut self, handler: def(Request, A0, A1, A2, A3, A4) raises thin -> R, blocking: Bool = False) raises
```

## Traits

### `PathParams`

```mojo
trait PathParams
```

A struct filled from the route's `{name}` params, field by field.

Inherits from: `AnyType`, `Deinitable`, `Movable`

### `QueryParams`

```mojo
trait QueryParams
```

A struct filled from the query string. `Optional` fields may be absent.

Inherits from: `AnyType`, `Deinitable`, `Movable`

### `JsonBody`

```mojo
trait JsonBody
```

A struct read from the JSON request body.

Inherits from: `AnyType`, `Deinitable`, `Movable`

### `AppState`

```mojo
trait AppState
```

The app state: built once, then shared read-only by every worker.

Inherits from: `AnyType`, `Deinitable`, `Movable`

## Functions

### `routes_json`

```mojo
def routes_json(routes: List[RouteInfo]) raises -> String
```

`{"dodo_routes": [{"method", "path", "blocking", "kind"}, ...]}` on one line, so `dodo routes` can find it among whatever else `main` prints.

### `serve`

```mojo
def serve[H: Handler & Copyable](var handler: H, *, port: UInt16 = UInt16(8080), host: String = "127.0.0.1", num_workers: Int = Int(0)) raises
```

Listen and serve any handler, such as an `App` wrapped in middleware.
