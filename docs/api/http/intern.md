# `dodo.http.intern`

Interned ``StaticString`` table for HTTP method names + common header values.

Replaces the parser hot path's per-request ``String`` allocation
for the 9 RFC 7231 method names (GET, POST, PUT, PATCH, DELETE,
HEAD, OPTIONS, CONNECT, TRACE) and a small set of frequently-seen
header *values* (``text/html`` / ``text/plain`` / ``application/
json`` / ``application/octet-stream`` / ``gzip`` / ``br`` /
``deflate`` / ``identity`` / ``keep-alive`` / ``close``,
``HTTP/1.0`` / ``HTTP/1.1``) with shared ``StaticString``
constants.

Background
----------

`dodo.http.server._parse_http_request_bytes` allocates the
method String *twice* per request today (the
``String(String(unsafe_from_utf8=...))`` double-wrap on line ~803
of ``server.mojo``). Under TFB plaintext at 220K req/s + 4
workers, that's ~1.7M allocations / s for the method string
alone, with ~99 % of them being one of "GET" or "POST". Folding
those into a shared ``StaticString`` constant drops the allocation
to a single ``String.copy()`` of a 3-4 byte SSO buffer (which is
free on every Mojo target where short-string-optimisation kicks
in below the inline-String threshold).

The savings on the value-side are smaller per-call but
compounding: every ``Compress[Inner]`` middleware response sets
``Content-Encoding: gzip`` (or ``br``); every keep-alive response
sets ``Connection: keep-alive``; every JSON response sets
``Content-Type: application/json``. Caching those as
``StaticString`` lets future hot-path serializers compare against
the interned shape without an allocation.

What this module provides
-------------------------

* ``MethodIntern`` — namespace struct holding the 9 method
  ``StaticString`` constants. Mirrors the
  ``dodo.http.request.Method`` namespace but with
  ``StaticString``-typed fields so the constants can be passed
  into ``intern_method_bytes`` lookups without a round-trip
  through ``String``.
* ``ValueIntern`` — namespace struct holding the common
  Content-Type / Content-Encoding / Connection / version
  ``StaticString`` constants.
* ``intern_method_bytes(Span[UInt8, _]) -> Optional[String]`` —
  returns ``Optional[String]`` built from the interned
  ``StaticString`` when ``slice`` exactly equals one of the
  9 method names, otherwise ``None``. Caller that gets ``None``
  back falls back to its existing String-construction path.
* ``intern_common_value(Span[UInt8, _]) -> Optional[String]``
  — same shape for the value table.
* Both lookups are O(1) per slice — first dispatched by length,
  then a tiny per-length switch (most lengths have ≤ 2
  candidates).

The request parser interns the method through
``intern_method_bytes``. ``intern_common_value`` has no caller in the
server.

Implementation notes
--------------------

Lookup is **length-first dispatch + byte compare**. ``GET`` /
``PUT`` (length 3) and ``POST`` / ``HEAD`` (length 4) cover
~95 % of real-world traffic; the longer methods (PATCH / DELETE
/ OPTIONS / CONNECT / TRACE) are fall-through. The branch
predictor learns "length=3 → GET" within the first few requests
on any given connection. No hash table, no Dict, no
multiplication.

The value table is similarly length-dispatched. Lengths uniquely
identify most candidates (``br`` is the only 2-char encoding,
``gzip`` the only 4-char one; ``HTTP/1.0`` and ``HTTP/1.1``
share length 8 and are differentiated by the last byte; etc.).

Measured, not adopted for header *values*.
``intern_common_value`` in the header-parse loop showed no consistent
effect (-0.8 %, +5.2 %, -13.1 % across three paired 30 s runs; median
worse). The reason is that ``_string_from_static`` returns
``String(s)``, which for a value short enough to be worth interning is
covered by short-string optimisation -- so both paths avoid the heap
and the lookup is pure added work.

``intern_method_bytes`` stays wired on the request line: the method set
is tiny and the dispatch is a single length compare.

## Structs

### `MethodIntern`

```mojo
struct MethodIntern
```

Interned ``StaticString`` constants for the 9 RFC 7231 method names.

Mirrors the ``dodo.http.request.Method`` namespace but with
``StaticString``-typed fields. Use the constants directly when
you need a static literal of a method name; use
:func:`intern_method_bytes` when you have a byte slice and want
to know whether it matches a known method without paying for
a fresh ``String`` allocation.

Implemented traits: `AnyType`, `Deinitable`, `Movable`

Aliases:

- `GET = StringSpan("GET")`
- `POST = StringSpan("POST")`
- `PUT = StringSpan("PUT")`
- `PATCH = StringSpan("PATCH")`
- `DELETE = StringSpan("DELETE")`
- `HEAD = StringSpan("HEAD")`
- `OPTIONS = StringSpan("OPTIONS")`
- `CONNECT = StringSpan("CONNECT")`
- `TRACE = StringSpan("TRACE")`

### `ValueIntern`

```mojo
struct ValueIntern
```

Interned ``StaticString`` constants for header values that show up on virtually every HTTP response.

Categories:

* **Content-Type**: text/html, text/plain, application/json,
  application/octet-stream.
* **Content-Encoding**: gzip, br, deflate, identity.
* **Connection**: keep-alive, close.
* **HTTP version**: HTTP/1.0, HTTP/1.1.

Add to this list (here, not at the call site) when bench
profiles surface a value that's allocated > 100K / s.

Implemented traits: `AnyType`, `Deinitable`, `Movable`

Aliases:

- `CONTENT_TYPE_TEXT_HTML = StringSpan("text/html")`
- `CONTENT_TYPE_TEXT_PLAIN = StringSpan("text/plain")`
- `CONTENT_TYPE_JSON = StringSpan("application/json")`
- `CONTENT_TYPE_OCTET = StringSpan("application/octet-stream")`
- `ENCODING_GZIP = StringSpan("gzip")`
- `ENCODING_BR = StringSpan("br")`
- `ENCODING_DEFLATE = StringSpan("deflate")`
- `ENCODING_IDENTITY = StringSpan("identity")`
- `CONNECTION_KEEP_ALIVE = StringSpan("keep-alive")`
- `CONNECTION_CLOSE = StringSpan("close")`
- `VERSION_1_0 = StringSpan("HTTP/1.0")`
- `VERSION_1_1 = StringSpan("HTTP/1.1")`

## Functions

### `intern_method_bytes`

```mojo
def intern_method_bytes(slice: Span[UInt8]) -> Optional[String]
```

Return the interned method name as ``Optional[String]`` if ``slice`` exactly matches one of the 9 RFC 7231 methods, otherwise ``None``.

Length-first dispatch keeps the common case (``GET`` / ``POST``)
on a single byte-length compare + 3-4 byte memcmp.

Args:

- `slice`: Byte slice — typically the method-name region of an HTTP/1.1 request line.

Returns: ``Some(String)`` for a known method (``"GET"`` / ``"POST"`` / ...); ``None`` otherwise. The returned ``String`` is built from the interned ``StaticString`` so the byte contents come from a process-lifetime constant rather than the per-request request buffer.

### `intern_common_value`

```mojo
def intern_common_value(slice: Span[UInt8]) -> Optional[String]
```

Return the interned header value as ``Optional[String]`` if ``slice`` matches one of the well-known content-type / content-encoding / connection / version values, otherwise ``None``.

Same length-first dispatch as :func:`intern_method_bytes`.

Args:

- `slice`: Byte slice — typically a header value in the request / response wire form.

Returns: ``Some(String)`` for a recognised value; ``None`` otherwise.

### `intern_method_string`

```mojo
def intern_method_string(s: String) -> Optional[String]
```

``String``-typed convenience wrapper around :func:`intern_method_bytes`.

For callers that already have a ``String`` and want to
canonicalise it; the byte-slice form is preferred on the
parser hot path.

### `intern_common_value_string`

```mojo
def intern_common_value_string(s: String) -> Optional[String]
```

``String``-typed convenience wrapper around :func:`intern_common_value`.
