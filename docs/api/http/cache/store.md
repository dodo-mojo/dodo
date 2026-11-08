# `dodo.http.cache.store`

Cache store trait + in-memory implementation.

A ``CacheStore`` is the persistence layer behind the cache
middleware: it accepts ``(key, entry)`` pairs and returns the
entry on lookup. Concrete implementations choose their own
eviction policy + capacity bound.

The :class:`InMemoryCacheStore` ships here. The trait keeps the
middleware decoupled from the storage choice, so a filesystem or
external-cache store can implement it.

## Structs

### `CacheEntry`

```mojo
struct CacheEntry
```

A stored cache entry.

Bodies are owned by the entry so the store can outlive the
handler that produced them. ``inserted_at_ms`` is a monotonic
timestamp (milliseconds) the middleware uses to compute age;
callers pass the value at insertion time so the store stays
decoupled from the clock source.

The parsed :class:`CacheControl` + ``Vary`` header value are
carried alongside the wire bytes so the freshness check
(:func:`dodo.http.cache.is_fresh`) and the secondary key
derivation can run without re-parsing on every lookup.
``date_ms`` is the value of the response's ``Date`` header at
insertion time (RFC 9110 §6.6.1) — None when the response did
not advertise one, in which case ``inserted_at_ms`` stands in
as the response's wire time. ``Age:`` accumulation
(RFC 9111 §4.2.3) starts from whichever is set.

Fields:

- `status` (`Int`)
- `headers` (`List[Tuple[String, String]]`)
- `body` (`List[UInt8]`)
- `inserted_at_ms` (`Int64`)
- `cache_control` (`CacheControl`)
- `vary` (`String`)
- `date_ms` (`Optional[Int64]`)

Implemented traits: `AnyType`, `Copyable`, `Deinitable`, `Movable`

#### `CacheEntry.basic`

```mojo
def basic(status: Int, var headers: List[Tuple[String, String]], var body: List[UInt8], inserted_at_ms: Int64) -> Self
```

Build a ``CacheEntry`` with empty/defaulted freshness metadata. Used by callers that don't yet care about RFC 9111 freshness (single-shot tests, naïve middleware wrappers). The :func:`Cache` middleware builds entries via the explicit constructor with parsed fields.

#### `CacheEntry.copy`

```mojo
def copy(self) -> Self
```

### `InMemoryCacheStore`

```mojo
struct InMemoryCacheStore
```

Bounded LRU-style in-memory cache store.

Eviction is approximate: when ``len() >= capacity`` a new put
drops the oldest-inserted entry. This is intentionally simpler
than a strict LRU (no recency tracking on get) so the lookup
path stays branch-light; profile-driven upgrades to a true
LRU policy can land later.

Implemented traits: `AnyType`, `CacheStore`, `Copyable`, `Defaultable`, `Deinitable`, `Movable`

#### `InMemoryCacheStore.__init__`

```mojo
def __init__(out self)
```

```mojo
def __init__(out self, *, copy: Self)
```

#### `InMemoryCacheStore.with_capacity`

```mojo
def with_capacity(capacity: Int) -> Self
```

#### `InMemoryCacheStore.get`

```mojo
def get(self, key: CacheKey) raises -> Optional[CacheEntry]
```

#### `InMemoryCacheStore.put`

```mojo
def put(mut self, key: CacheKey, entry: CacheEntry) raises
```

#### `InMemoryCacheStore.remove`

```mojo
def remove(mut self, key: CacheKey) raises
```

#### `InMemoryCacheStore.len`

```mojo
def len(self) -> Int
```

#### `InMemoryCacheStore.capacity`

```mojo
def capacity(self) -> Int
```

## Traits

### `CacheStore`

```mojo
trait CacheStore
```

Persistence interface for cached responses.

Implementations must accept concurrent reads/writes from the
reactor; the in-memory store delegates to an internal lock.
The trait is intentionally simple (get / put / remove) to
keep adapter integration low-friction.

Inherits from: `AnyType`, `Copyable`, `Defaultable`, `Movable`

#### `CacheStore.get`

```mojo
def get(self, key: CacheKey) raises -> Optional[CacheEntry]
```

#### `CacheStore.put`

```mojo
def put(mut self, key: CacheKey, entry: CacheEntry) raises
```

#### `CacheStore.remove`

```mojo
def remove(mut self, key: CacheKey) raises
```

#### `CacheStore.len`

```mojo
def len(self) -> Int
```
