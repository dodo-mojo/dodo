# `dodo.http.cache`

``dodo.http.cache`` — RFC 9111 HTTP cache primitives.

This package ships the data model + in-memory store layer that a
cache middleware composes on top of. The full RFC 9111 conformance
surface (Vary header negotiation, stale-while-revalidate /
stale-if-error refresh policy, validator-driven conditional
revalidation) is staged incrementally; this package currently
provides:

- :class:`CacheControl` — parsed ``Cache-Control`` directive set.
- :func:`parse_cache_control` — header parser.
- :func:`parse_vary_header` — ``Vary`` header field-name parser.
- :func:`is_fresh` — RFC 9111 §4.2 freshness check, honours both
  response- and request-side ``Cache-Control``.
- :class:`CacheKey` — request → cache lookup key derivation.
- :class:`CacheEntry` — stored response wrapper carrying the
  parsed :class:`CacheControl` + ``Vary`` value alongside the
  wire bytes.
- :class:`InMemoryCacheStore` — minimal LRU-bounded store.

The middleware shim that *uses* this layer, ``Cache[Inner, S]``,
ships and is exported from the root package alongside
:class:`InMemoryCacheStore`.

## Modules

- [`dodo.http.cache.control`](control.md): ``Cache-Control`` header parser (RFC 9111 §5.2).
- [`dodo.http.cache.key`](key.md): Cache key derivation (RFC 9111 §4 "Constructing Responses from Caches").
- [`dodo.http.cache.middleware`](middleware.md): HTTP cache middleware (RFC 9111).
- [`dodo.http.cache.store`](store.md): Cache store trait + in-memory implementation.
