# `dodo.http.structured_logger`

Structured (JSON-shaped) request logger middleware.

The plain ``Logger[Inner]`` middleware in :mod:`dodo.http.middleware`
emits one space-delimited line per request:

```mojo
[dodo] GET /users 200 12ms
```

That's grep-friendly, ``jq``-friendly with a parser, and zero-dep —
but it's not the shape modern observability stacks want. Datadog,
Elastic, Loki, Splunk, and CloudWatch Logs Insights all key on
JSON-per-line so they can build automatic dashboards on the
``status`` / ``latency_ms`` / ``method`` / ``url`` fields without
custom regex.

``StructuredLogger[Inner]`` is the additive sibling that emits one
JSON object per request with the same fields plus a few extras
(timestamp, request_id, peer-address). Surface stays tiny + the
inner ``Logger`` is unchanged: callers that prefer the line shape
keep using ``Logger[Inner]``.

Example output (one line per request):

```mojo
{"ts":"2026-05-01T15:39:01.123Z","method":"GET","url":"/users","status":200,"latency_ms":12,"request_id":"req-7f3","peer":"192.168.1.5:56324"}
```

Field selection rationale (vs Apache common log / nginx default):

- ``ts``: ISO-8601 UTC second-precision (``YYYY-MM-DDTHH:MM:SSZ``).
  Most ingest pipelines auto-detect this shape; nanos / millis are
  available if needed but the default is seconds + millisecond
  precision in the value to keep the line compact.
- ``method`` / ``url`` / ``status``: the obvious request triple.
- ``latency_ms``: ``perf_counter_ns`` delta divided by 1_000_000.
  Same shape the plain ``Logger`` already emits — but as a number,
  not a "12ms" string.
- ``request_id``: pulled from ``X-Request-Id`` on the response
  (the same header the existing ``RequestId[Inner]`` middleware
  echoes). Skipped from the line if absent. Lets a downstream
  pipeline join logs to traces without an extractor.
- ``peer``: pulled from ``Request.peer`` if set. Skipped if not.
  Useful for per-IP rate-limit forensics on a system without an
  upstream reverse-proxy access log.
- ``error``: only present on error path; carries the exception
  message verbatim (caller-controlled — the inner handler decides
  what to ``raise(...)``).

JSON-escape rules per RFC 8259:

- ``"`` → ``\"``
- ``\`` → ``\\``
- ``\b`` / ``\f`` / ``\n`` / ``\r`` / ``\t`` → escaped form
- Other control bytes (< 0x20) → ``\u00XX`` form
- All other UTF-8 bytes pass through unchanged

The escaper is single-pass, byte-by-byte, no allocator beyond the
output ``String``'s own grow buffer. For typical 100-byte URLs
this is well under 1µs/req — invisible against the inner
handler's latency budget.

## Structs

### `StructuredLogger`

```mojo
struct StructuredLogger[Inner: Handler & Copyable]
```

JSON-per-line request logger around the inner handler.

Emits one line of JSON per request to stdout:

```mojo
{"ts":"...","method":"GET","url":"/users","status":200,
 "latency_ms":12,"request_id":"req-7f3","peer":"1.2.3.4:5678"}
```

Fields that are absent (no ``X-Request-Id`` header set; no
``Request.peer``) are skipped from the line so the JSON object
stays compact. On the error path, the line carries an
``"error":"<exception message>"`` field instead of ``status``
/ ``latency_ms``.

Construct via the default factory or with an explicit
inner handler, mirroring the plain ``Logger`` shape:

```mojo
``StructuredLogger[Router](Router())``
```

Wraps ``Inner.serve`` with the timing / error catch /
line-emit, exactly like ``Logger`` does — one extra
allocation per request for the JSON line buffer.

Fields:

- `inner` (`Inner`)

Implemented traits: `AnyType`, `Copyable`, `Deinitable`, `Handler`, `Movable`

Aliases:

- `BodyType = InlineBody`: The ``Body`` impl this handler authors its response with.

#### `StructuredLogger.__init__`

```mojo
def __init__(out self, var inner: Inner)
```

#### `StructuredLogger.serve`

```mojo
def serve(self, req: Request) raises -> Response
```

#### `StructuredLogger.may_block`

```mojo
def may_block(self) -> Bool
```

#### `StructuredLogger.route_list`

```mojo
def route_list(self) raises -> List[RouteInfo]
```

#### `StructuredLogger.blocking`

```mojo
def blocking(self, req: Request) raises -> Bool
```
