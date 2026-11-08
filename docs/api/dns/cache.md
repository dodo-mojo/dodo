# `dodo.dns.cache`

TTL-bounded DNS resolution cache.

An additive layer over the sync :func:`dodo.dns.resolve`: a value-type
cache the caller owns and threads through repeated lookups. Within a
host's TTL a lookup is served from memory with no ``getaddrinfo(3)``
syscall; past the TTL the next lookup re-resolves and refreshes the
entry. The sync ``resolve`` / ``resolve_v4`` / ``resolve_v6`` functions
are untouched -- callers that do not want caching pay nothing.

```mojo
from dodo.dns import DnsCache

var cache = DnsCache(ttl_ms=30_000)
var a = cache.resolve("example.com")   # one syscall
var b = cache.resolve("example.com")   # served from cache, no syscall
print(cache.resolve_count())            # 1
```

Entries live for the cache's own ``ttl_ms`` (``Int.MAX`` means "until
evicted": the expiry saturates instead of wrapping). ``getaddrinfo(3)`` does
not report the record's DNS TTL, so a record whose TTL is shorter than
``ttl_ms`` is served past it; pick ``ttl_ms`` with that in mind. Host
names are matched case-insensitively and without a trailing dot, as DNS
matches them. The cache holds at most ``max_entries`` hosts; when it is
full, expired entries go first, then the one closest to expiry.

This is a single-threaded value type (the owner serializes access); it
has no internal lock. A shared cache across reactor workers could reuse
the same pointer-backed interior-mutable handle pattern as
``dodo.http._client.cookie_store.CookieStore`` plus a mutex, layered on top
of this pure cache without changing its logic.

## Structs

### `DnsCache`

```mojo
struct DnsCache
```

A TTL-bounded resolution cache over the sync resolver.

Fields are owned by the caller; the cache mutates through ``mut
self`` (no interior mutability), so it composes anywhere the caller
already holds it mutably (a client's dial path, a worker loop).

Implemented traits: `AnyType`, `Deinitable`, `Movable`

#### `DnsCache.__init__`

```mojo
def __init__(out self, ttl_ms: Int = Int(30000), max_entries: Int = Int(1024))
```

Create a cache with the given per-entry TTL in milliseconds (default 30 s) holding at most ``max_entries`` hosts. ``ttl_ms <= 0`` makes every entry immediately stale (every lookup re-resolves). The bound is new: a process that looked up many distinct names grew the cache without limit.

#### `DnsCache.resolve`

```mojo
def resolve(mut self, host: String) raises -> List[IpAddr]
```

Return the addresses for ``host``, served from cache when a fresh entry exists, else re-resolved (and cached) via :func:`dodo.dns.resolve`.

Raises: DnsError / AddressParseError: propagated from the underlying resolver on a miss; failures are not cached.

#### `DnsCache.resolve_async`

```mojo
def resolve_async(mut self, host: String, cancel: Cancel) raises -> List[IpAddr]
```

Cache-aware off-reactor resolve: serve a fresh entry from memory (no thread spawn), else resolve on a pool thread via :func:`dodo.dns.resolve_async` and cache the result.

Same caching semantics as :meth:`resolve`; only the miss path
differs (off-thread, cancellable). Failures are not cached.

#### `DnsCache.resolve_ordered`

```mojo
def resolve_ordered(mut self, host: String) raises -> List[IpAddr]
```

Like :meth:`resolve` but returns the addresses in RFC 8305 happy-eyeballs connection-attempt order (interleaved IPv6/IPv4, starting with the family of the resolver's first address) so a dialer can race the families.

#### `DnsCache.invalidate`

```mojo
def invalidate(mut self, host: String)
```

Drop any cached entry for ``host`` (e.g. after a dial to the cached address failed). No-op if absent.

#### `DnsCache.clear`

```mojo
def clear(mut self)
```

Drop all cached entries.

#### `DnsCache.resolve_count`

```mojo
def resolve_count(self) -> Int
```

Number of underlying resolver syscalls performed so far.

#### `DnsCache.hit_count`

```mojo
def hit_count(self) -> Int
```

Number of lookups served from a fresh cache entry.

#### `DnsCache.size`

```mojo
def size(self) -> Int
```

Number of hosts currently cached (fresh or stale).
