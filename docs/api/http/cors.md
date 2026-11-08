# `dodo.http.cors`

``Cors[Inner]`` middleware (Cross-Origin Resource Sharing).

Implements the algorithmic core of the CORS protocol (Fetch
Living Standard paragraph 3.2 / RFC 6454):

- Inbound ``Origin`` is checked against ``allowed_origins``; mismatches
  produce a plain inner-handler response with no CORS headers. Every
  response, stamped or not, carries ``Vary: Origin`` (Fetch 3.2.5).
- ``OPTIONS`` preflight requests with ``Access-Control-Request-Method``
  short-circuit before reaching the inner handler and respond
  with ``Access-Control-Allow-Methods`` /
  ``Access-Control-Allow-Headers`` / ``Access-Control-Max-Age``
  derived from the config.
- Simple (non-preflight) requests reach the inner handler; the
  middleware then attaches ``Access-Control-Allow-Origin`` to the
  outbound response.
- ``allow_credentials=True`` switches the wildcard ``*`` semantics
  off (the spec requires echoing the exact origin when credentials
  are sent).

The middleware is generic over the inner ``Handler`` so the CORS
layer is monomorphised into the handler chain.

## Structs

### `CorsConfig`

```mojo
struct CorsConfig
```

Configuration knobs for ``Cors[Inner]``.

Default policy: deny everything (every list empty,
``allow_credentials=False``). Mutate via the named-arg
constructor or by setting fields after default-construction.

Fields:

- `allowed_origins` (`List[String]`): Origins permitted to send cross-origin requests. ``["*"]`` is the wildcard. Empty list -> no origin allowed.
- `allowed_methods` (`List[String]`): Methods echoed in ``Access-Control-Allow-Methods`` on preflight. Defaults to ``["GET", "HEAD", "POST"]``.
- `allowed_headers` (`List[String]`): Headers echoed in ``Access-Control-Allow-Headers`` on preflight. Empty -> echoed from the inbound ``Access-Control-Request-Headers``.
- `exposed_headers` (`List[String]`): Headers attached to ``Access-Control-Expose-Headers`` on actual responses (so JS can read them).
- `max_age_seconds` (`Int`): ``Access-Control-Max-Age`` (seconds the preflight result is cacheable). Default 600.
- `allow_credentials` (`Bool`): When ``True``, ``Access-Control-Allow-Credentials: true`` is set; the wildcard origin is *not* used (spec requirement).

Implemented traits: `AnyType`, `Copyable`, `Defaultable`, `Deinitable`, `Movable`

#### `CorsConfig.__init__`

```mojo
def __init__(out self)
```

#### `CorsConfig.permissive`

```mojo
def permissive() -> Self
```

Wildcard-everything config — convenient for local dev / public APIs without credentials.

### `Cors`

```mojo
struct Cors[Inner: Handler & Copyable]
```

CORS middleware. Wraps ``Inner`` with the spec'd preflight + response-header machinery.

Fields:

- `inner` (`Inner`)
- `config` (`CorsConfig`)

Implemented traits: `AnyType`, `Copyable`, `Deinitable`, `Handler`, `Movable`

Aliases:

- `BodyType = InlineBody`: The ``Body`` impl this handler authors its response with.

#### `Cors.__init__`

```mojo
def __init__(out self, var inner: Inner, config: CorsConfig)
```

#### `Cors.serve`

```mojo
def serve(self, req: Request) raises -> Response
```

#### `Cors.may_block`

```mojo
def may_block(self) -> Bool
```

#### `Cors.route_list`

```mojo
def route_list(self) raises -> List[RouteInfo]
```

#### `Cors.blocking`

```mojo
def blocking(self, req: Request) raises -> Bool
```
