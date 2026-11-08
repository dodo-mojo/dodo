# `dodo.http.cache.middleware`

HTTP cache middleware (RFC 9111).

``Cache[Inner, S]`` wraps an inner :class:`~dodo.http.Handler` with
an RFC 9111-shaped HTTP cache backed by a pluggable
:class:`CacheStore`. On a request the middleware:

1. Computes the cache key from the request method + effective
   request URI, expanded by any prior ``Vary`` selection.
2. Looks the key up in the store. If hit + still fresh per
   :func:`is_fresh`, serves the stored response directly (no
   call into the inner handler, no parser run, no allocation
   beyond the response copy).
3. On miss or stale, calls the inner handler. If the response
   is cacheable (status code on the RFC 9111 §3 allow-list, no
   ``Cache-Control: no-store``, no ``Set-Cookie``), stores it
   with the parsed ``CacheControl`` + ``Vary`` carried alongside.

The middleware is generic over the store so callers can swap the
in-memory bounded store for a filesystem-backed or external
adapter without touching the handler graph. ``S`` only needs to
satisfy the :class:`CacheStore` trait.

The middleware intentionally does *not* drive conditional
revalidation (``If-None-Match`` / ``If-Modified-Since``) on its
own -- that surface lives in :class:`dodo.http.Conditional`, and
users compose the two as ``Cache[Conditional[Inner], S]`` when
they want both. The split keeps each concern testable.

The cache is request-scoped: only ``GET`` and ``HEAD`` requests
hit the cache. ``POST`` / ``PUT`` / ``DELETE`` / ``PATCH`` /
``CONNECT`` / ``OPTIONS`` / ``TRACE`` invalidate any stored entry
for the same key on completion of a successful response, but
do not themselves consult the cache (RFC 9111 §4 + §4.4).

References:
- RFC 9111 §3 (storing responses).
- RFC 9111 §4 (constructing responses from caches).
- RFC 9111 §4.4 (invalidating stored responses).
- RFC 9110 §15.1 (status code semantics).

## Structs

### `Cache`

```mojo
struct Cache[Inner: Handler & Copyable, S: CacheStore & Deinitable]
```

RFC 9111 HTTP cache middleware.

The middleware composes on top of any :class:`CacheStore`
implementation. The default :class:`InMemoryCacheStore` is a
bounded FIFO; callers that want stricter LRU eviction or an
external store (Redis / memcached) swap the store without
touching the rest of the chain.

The store lives on the heap (via :class:`dodo.runtime.Pool`)
and the middleware holds the address as an ``Int``; copies of
the middleware therefore share the same store, which matches
the per-worker singleton shape that ``Logger`` /
:class:`dodo.http.Metrics` already use. The cell is leaked
at process exit (worker pthreads live the lifetime of the
server, so nothing meaningful to free); a future
``ArcPointer`` upgrade can swap the leak for ref-counting.

Example::

```mojo
from dodo.http.cache import (
    Cache,
    InMemoryCacheStore,
)
var server = HttpServer(
    Cache[MyHandler, InMemoryCacheStore](
        inner=MyHandler(),
        store=InMemoryCacheStore.with_capacity(1024),
    )
)
```

Parameters:

- `Inner`: The inner handler.
- `S`: The cache store; must satisfy the :class:`CacheStore` trait.

Fields:

- `inner` (`Inner`): The wrapped handler.
- `store_addr` (`Int`): Heap address of the shared :class:`CacheStore` cell. Allocated in ``__init__``; intentionally leaked at process exit (see struct doc).

Implemented traits: `AnyType`, `Copyable`, `Deinitable`, `Handler`, `Movable`

Aliases:

- `BodyType = InlineBody`: The ``Body`` impl this handler authors its response with.

#### `Cache.__init__`

```mojo
def __init__(out self, var inner: Inner, var store: S)
```

#### `Cache.serve`

```mojo
def serve(self, req: Request) raises -> Response
```

#### `Cache.may_block`

```mojo
def may_block(self) -> Bool
```

#### `Cache.route_list`

```mojo
def route_list(self) raises -> List[RouteInfo]
```

#### `Cache.blocking`

```mojo
def blocking(self, req: Request) raises -> Bool
```
