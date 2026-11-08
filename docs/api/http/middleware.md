# `dodo.http.middleware`

Generic middleware library for .

The ``Handler`` trait is already a perfectly good middleware
abstraction: a middleware is a handler that wraps another handler.
This module bundles the middlewares every dodo app eventually
needs:

- ``Logger[Inner]`` — log method / url / status / latency.
- ``RequestId[Inner]`` — attach an opaque request id (read on
  inbound, echo on outbound).
- ``Compress[Inner]`` — content-encoding negotiation
  (``Accept-Encoding`` q-values per RFC 9110 paragraph 12.5.3),
  encoding the response body in gzip or brotli.
- ``CatchPanic[Inner]`` — turn any ``raise`` from the inner
  handler into a sanitised 500 response so the connection is not
  torn down (the ``HttpServer`` already does this; ``CatchPanic``
  is for inner-only middleware stacks where the server isn't
  reached).

Each middleware is generic over its inner ``Handler`` so the chain
stays monomorphised — no virtual dispatch, no allocation per
request.

## Structs

### `Logger`

```mojo
struct Logger[Inner: Handler & Copyable]
```

Log method, url, status, and latency around the inner handler.

Output goes to stdout via ``print``. The format is intentionally
machine-grep-friendly so you can pipe it through ``jq`` /
``awk`` without a structured-logging dep.

Fields:

- `inner` (`Inner`): The wrapped handler.
- `prefix` (`String`): Prefix prepended to every log line; defaults to ``"[dodo]"``.

Implemented traits: `AnyType`, `Copyable`, `Deinitable`, `Handler`, `Movable`

Aliases:

- `BodyType = InlineBody`: The ``Body`` impl this handler authors its response with.

#### `Logger.__init__`

```mojo
def __init__(out self, var inner: Inner, prefix: String = "[dodo]")
```

#### `Logger.serve`

```mojo
def serve(self, req: Request) raises -> Response
```

#### `Logger.may_block`

```mojo
def may_block(self) -> Bool
```

#### `Logger.route_list`

```mojo
def route_list(self) raises -> List[RouteInfo]
```

#### `Logger.blocking`

```mojo
def blocking(self, req: Request) raises -> Bool
```

### `RequestId`

```mojo
struct RequestId[Inner: Handler & Copyable]
```

Echo the inbound ``X-Request-Id`` header back on the response.

If absent on the inbound side, a deterministic id derived from
``perf_counter_ns`` is generated. Useful for request tracing
when paired with the upstream gateway / load balancer.

Fields:

- `inner` (`Inner`)

Implemented traits: `AnyType`, `Copyable`, `Deinitable`, `Handler`, `Movable`

Aliases:

- `BodyType = InlineBody`: The ``Body`` impl this handler authors its response with.

#### `RequestId.__init__`

```mojo
def __init__(out self, var inner: Inner)
```

#### `RequestId.serve`

```mojo
def serve(self, req: Request) raises -> Response
```

#### `RequestId.may_block`

```mojo
def may_block(self) -> Bool
```

#### `RequestId.route_list`

```mojo
def route_list(self) raises -> List[RouteInfo]
```

#### `RequestId.blocking`

```mojo
def blocking(self, req: Request) raises -> Bool
```

### `Compress`

```mojo
struct Compress[Inner: Handler & Copyable]
```

Negotiate ``Content-Encoding`` per RFC 9110 paragraph 12.5.3.

Inspects the inbound ``Accept-Encoding`` header, picks the
highest-q entry from {``br``, ``gzip``, ``identity``}, and
encodes the inner response body accordingly. Sets
``Content-Encoding`` on the response. ``Vary: Accept-Encoding``
is set on every response whose representation depends on the
request (body at least ``min_size_bytes``, not already encoded,
not partial), including those left as identity, so shared caches
never serve the identity variant to a client that accepts gzip.

Bodies smaller than ``min_size_bytes`` (default 1024) are passed
through untouched — the per-request encoder overhead beats the
transfer-time savings on small bodies. Partial-content responses
(status 206, or any response carrying ``Content-Range``, such as
``FileServer`` answering a ``Range:`` request) are passed through
unencoded so ``Content-Range`` keeps matching the body.

Fields:

- `inner` (`Inner`)
- `min_size_bytes` (`Int`)
- `brotli_quality` (`Int`)
- `gzip_level` (`Int`)

Implemented traits: `AnyType`, `Copyable`, `Deinitable`, `Handler`, `Movable`

Aliases:

- `BodyType = InlineBody`: The ``Body`` impl this handler authors its response with.

#### `Compress.__init__`

```mojo
def __init__(out self, var inner: Inner, min_size_bytes: Int = Int(1024), brotli_quality: Int = Int(5), gzip_level: Int = Int(6))
```

#### `Compress.serve`

```mojo
def serve(self, req: Request) raises -> Response
```

#### `Compress.may_block`

```mojo
def may_block(self) -> Bool
```

#### `Compress.route_list`

```mojo
def route_list(self) raises -> List[RouteInfo]
```

#### `Compress.blocking`

```mojo
def blocking(self, req: Request) raises -> Bool
```

### `CatchPanic`

```mojo
struct CatchPanic[Inner: Handler & Copyable]
```

Convert any ``raise`` from the inner handler into a 500.

Useful when stacking middleware below the server's own
error-sanitisation layer (e.g. inside a router branch). The
server's ``HttpServer.serve`` path already wraps the top-level
handler this way; this is for inner stacks.

Fields:

- `inner` (`Inner`)
- `body` (`String`)

Implemented traits: `AnyType`, `Copyable`, `Deinitable`, `Handler`, `Movable`

Aliases:

- `BodyType = InlineBody`: The ``Body`` impl this handler authors its response with.

#### `CatchPanic.__init__`

```mojo
def __init__(out self, var inner: Inner, body: String = "Internal Server Error")
```

#### `CatchPanic.serve`

```mojo
def serve(self, req: Request) raises -> Response
```

#### `CatchPanic.may_block`

```mojo
def may_block(self) -> Bool
```

#### `CatchPanic.route_list`

```mojo
def route_list(self) raises -> List[RouteInfo]
```

#### `CatchPanic.blocking`

```mojo
def blocking(self, req: Request) raises -> Bool
```

## Functions

### `negotiate_encoding`

```mojo
def negotiate_encoding(accept: String, brotli_ok: Bool) -> _AcceptEncodingPick
```

Pick the best ``Content-Encoding`` for an ``Accept-Encoding``.

Walks every comma-separated entry, parses ``;q=<weight>`` per
RFC 9110 paragraph 12.5.3, and returns the highest-q coding from
{``br``, ``gzip``, ``identity``} that the client accepts. Ties
break on brotli > gzip > identity (matches nginx default).

A coding's weight is the largest weight of an entry naming it; a
coding with no entry of its own takes the weight of ``*`` ("any
content coding not explicitly listed"), so the result does not
depend on entry order and ``identity;q=0, *`` never selects the
refused identity. When every weight is 0 the pick is
``identity`` with quality 0.

Args:

- `accept`: Raw ``Accept-Encoding`` header value.
- `brotli_ok`: Whether brotli is linkable on this build.

Returns: ``_AcceptEncodingPick`` with the chosen encoding (defaults to ``identity`` / q=1000 when the header is absent).
