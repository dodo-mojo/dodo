# `dodo.http.cache.control`

``Cache-Control`` header parser (RFC 9111 §5.2).

The ``Cache-Control`` header carries a comma-separated list of
directives. Each directive is either a bare token (e.g.
``no-cache``, ``no-store``, ``public``, ``private``) or a
token=value pair (e.g. ``max-age=3600``, ``s-maxage=300``,
``stale-while-revalidate=60``).

Tokens are case-insensitive; this parser normalises to lowercase.
Unknown directives are surfaced through ``unknown_directives`` so
middleware can decide whether to honour or skip them (e.g.
``immutable`` is RFC 8246, not RFC 9111).

Reference:
- RFC 9111 §5.2 "Cache-Control".
- RFC 9111 §4.2 "Freshness".
- RFC 9111 §4.1 "Calculating Secondary Keys with Vary".
- RFC 9110 §6.6.1 "Date".
- RFC 8246 (``immutable``).

## Structs

### `CacheControl`

```mojo
struct CacheControl
```

Parsed Cache-Control directive set.

Boolean directives are True when present; numeric directives
are Optional[Int] (None when absent, ``Some(seconds)`` when
present with a value). Negative or unparseable numeric values
are silently dropped per RFC 9111 §5.2 ("If the value is
invalid, it should be treated as if it were not present").

Fields:

- `no_cache` (`Bool`)
- `no_store` (`Bool`)
- `no_transform` (`Bool`)
- `public` (`Bool`)
- `private` (`Bool`)
- `must_revalidate` (`Bool`)
- `proxy_revalidate` (`Bool`)
- `immutable` (`Bool`)
- `max_age` (`Optional[Int]`)
- `s_maxage` (`Optional[Int]`)
- `stale_while_revalidate` (`Optional[Int]`)
- `stale_if_error` (`Optional[Int]`)
- `unknown_directives` (`List[String]`)

Implemented traits: `AnyType`, `Copyable`, `Defaultable`, `Deinitable`, `Movable`

#### `CacheControl.__init__`

```mojo
def __init__(out self)
```

#### `CacheControl.copy`

```mojo
def copy(self) -> Self
```

## Functions

### `parse_cache_control`

```mojo
def parse_cache_control(value: String) -> CacheControl
```

Parse a Cache-Control header value into a structured directive set.

The parser is permissive per RFC 9111 §5.2: malformed numeric
values silently drop, unknown directives are surfaced through
``unknown_directives`` rather than rejected. Callers that
want strict behaviour can inspect ``unknown_directives``
after the fact.

### `parse_vary_header`

```mojo
def parse_vary_header(value: String) -> List[String]
```

Parse a ``Vary`` response header into its constituent field names per RFC 9111 §4.1 (secondary-key derivation).

The header is a comma-separated list of header names; tokens
are case-insensitive and stripped of surrounding whitespace
on output. A single ``*`` value (RFC 9110 §12.5.5) signals
that the response varies on aspects the cache cannot see and
callers must treat the entry as unconditionally non-reusable;
we surface it explicitly in the returned list so the caller
can short-circuit, rather than silently dropping it.

### `is_fresh`

```mojo
def is_fresh(response_cc: CacheControl, inserted_at_ms: Int64, date_ms: Optional[Int64], request_headers: HeaderMap, now_ms: UInt64) -> Bool
```

Return True if a stored response is still fresh at ``now_ms`` under the RFC 9111 §4.2 freshness model.

The check honours, in order:

1. Request-side ``Cache-Control: no-cache`` -> never fresh
   (RFC 9111 §5.2.1.4).
2. Response-side ``no-store`` / ``no-cache`` /
   ``must-revalidate`` -> never fresh.
3. Request-side ``max-age=N`` -> the entry is fresh iff
   ``age <= min(request_max_age, response_freshness_lifetime)``
   (RFC 9111 §5.2.1.1). ``max-age=0`` is the standard "force
   revalidation" override.
4. Response-side ``s-maxage`` (if shared cache) or
   ``max-age`` (otherwise) -> the freshness lifetime.
5. ``immutable`` (RFC 8246) -> always fresh while
   freshness lifetime is non-zero.

Freshness is computed as for a private cache: ``s-maxage`` is
honoured only when ``max-age`` is absent. *What gets stored* is
decided with shared-cache rules, since one ``Cache`` store serves
every client of the process: ``private`` responses, and responses
to Authorization- or Cookie-bearing requests that do not opt in,
are never stored (see ``Cache._store_response``).

The function does not consult the ``Expires`` header
(RFC 9110 §5.3) because ``Cache-Control: max-age`` always
overrides it (RFC 9111 §5.3) and modern responses set the
former; a future commit can add ``Expires`` for the long tail
of legacy origins.
