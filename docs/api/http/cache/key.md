# `dodo.http.cache.key`

Cache key derivation (RFC 9111 §4 "Constructing Responses from Caches").

A cache key uniquely identifies a stored response. The minimum
inputs are the request method + the effective request URI; the
``Vary`` response header expands this with selected request
headers so two requests to the same URI with different
``Accept-Language`` headers store separate entries.

This module produces a deterministic string key from those
inputs. The serialisation format is internal; consumers should
treat keys as opaque tokens. Concrete store implementations may
hash the key into a fixed-width identifier.

## Structs

### `CacheKey`

```mojo
struct CacheKey
```

Opaque cache key. ``raw`` is the deterministic string used by store implementations.

Fields:

- `raw` (`String`)

Implemented traits: `AnyType`, `Copyable`, `Deinitable`, `Movable`

#### `CacheKey.__eq__`

```mojo
def __eq__(self, other: Self) -> Bool
```

## Functions

### `derive_cache_key`

```mojo
def derive_cache_key(method: String, scheme: String, authority: String, path: String, vary_headers: List[Tuple[String, String]] = List()) -> CacheKey
```

Build a cache key for a request.

``vary_headers`` is the resolved set of ``(header-name,
header-value)`` pairs the caller computed by inspecting a
prior response's ``Vary`` header (RFC 9111 §4.1). Header
names are case-insensitive; the caller should lowercase
before passing them in so two writers building keys for the
same logical request produce identical strings.
