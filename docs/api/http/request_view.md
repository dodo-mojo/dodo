# `dodo.http.request_view`

Zero-copy HTTP request view.

``RequestView[origin]`` borrows method, URL, headers, and body
from the connection's ``read_buf`` rather than owning them. For a
13-byte plaintext request the difference is invisible (a few
``String`` allocations vs. a few offsets); for a 1MB / 16MB
multipart upload it's the difference between one ``memcpy`` of
the whole body and zero.

Pieces in place:

- ``RequestView[origin]`` value type (this file).
- ``parse_request_view(data: Span[UInt8, origin]) raises ->
  RequestView[origin]`` parser that scans the request line +
  headers + body slice without per-header / per-token
  allocations.
- ``RequestView.into_owned() raises -> Request`` materialises a
  ``Request`` for handlers that need to keep request
  state past one event-loop iteration.

No server loop parses into ``RequestView`` yet. The performance pass
decides whether the unified loop adopts it or it is deleted (see
``TODO.md``).

Example:

```mojo
var raw = "GET /a?q=1 HTTP/1.1\r\nHost: x\r\n\r\n".as_bytes()
var view = parse_request_view(Span[UInt8, _](raw))
print(view.method) # GET
print(view.url) # /a?q=1
print(view.headers.get("Host")) # x
print(len(view.body)) # 0

# Materialise an owned ``Request`` if you need one:
var owned = view.into_owned()
```

## Structs

### `RequestView`

```mojo
struct RequestView[origin: Origin[mut=origin.mut]]
```

Borrowed HTTP request.

Stores **one** ``Span[UInt8, origin]`` (the underlying buffer)
plus offset-and-length pairs for the URL, body, and the
individual headers. Per-field accessors (``url()``,
``body()``, ``header(name)``) reconstruct the borrowed slice
on demand from the buffer. This avoids Mojo's borrow-checker
rejection of "two ``[origin]``-tied fields aliasing the same
memory" that a flatter design (one ``StringSlice`` for URL +
one ``Span`` for body + one ``HeaderMapView`` for headers)
triggers.

Fields:
    method: ASCII method token (``"GET"``, ``"POST"``,
                   ...). Owned ``String``.
    version: HTTP version (``"HTTP/1.1"``). Owned.
    peer: Kernel-reported peer ``SocketAddr``.
    expose_errors: Whether 4xx response bodies may echo
                   handler-error messages.
    buf: Underlying byte buffer borrowed from the
                   caller (typically ``ConnHandle.read_buf``).
    url_start / url_len: Byte range of the request URL
                           within ``buf``.
    body_start / body_len: Byte range of the request body
                           within ``buf``.
    header_offsets: Flat ``List[Int]`` of stride 4
                           (name_start, name_len, value_start,
                           value_len) — the same shape
                           ``HeaderMapView`` uses internally.

Fields:

- `method` (`String`)
- `version` (`String`)
- `peer` (`SocketAddr`)
- `expose_errors` (`Bool`)
- `buf` (`Span[UInt8, origin]`)
- `url_start` (`Int`)
- `url_len` (`Int`)
- `body_start` (`Int`)
- `body_len` (`Int`)
- `header_offsets` (`List[Int]`)

Implemented traits: `AnyType`, `Deinitable`, `Movable`

#### `RequestView.__init__`

```mojo
def __init__(out self, method: String, version: String, peer: SocketAddr, expose_errors: Bool, buf: Span[UInt8, origin], url_start: Int, url_len: Int, body_start: Int, body_len: Int, var header_offsets: List[Int])
```

#### `RequestView.url`

```mojo
def url(self) -> StringSpan[origin_of(origin)]
```

Borrowed URL slice.

#### `RequestView.body`

```mojo
def body(self) -> Span[UInt8, origin]
```

Borrowed body slice.

#### `RequestView.headers`

```mojo
def headers(self) -> HeaderMapView[origin]
```

Build a ``HeaderMapView`` over this view's headers.

Cheap: copies the offsets list (typically a few ints) and
re-binds the buffer span. The returned view shares the
same ``origin``.

#### `RequestView.into_owned`

```mojo
def into_owned(self) raises -> Request
```

Materialise a ``Request`` whose fields are owned copies of the borrowed bytes.

Use when a handler needs to keep request state past one
event-loop iteration (background work, audit logging,
cross-request bookkeeping). Allocates: one ``String`` for
the URL, one ``HeaderMap`` worth of headers, one
``List[UInt8]`` for the body.

## Functions

### `parse_request_view`

```mojo
def parse_request_view[origin: Origin[mut=origin.mut]](data: Span[UInt8, origin], max_header_size: Int = Int(8192), max_body_size: Int = Int(10485760), max_uri_length: Int = Int(8192), peer: SocketAddr = SocketAddr(IpAddr(String("127.0.0.1"), False), UInt16(0)), expose_errors: Bool = False, body_len_override: Int = Int(-1)) raises -> RequestView[origin]
```

Parse an HTTP/1.1 request from a byte buffer into a ``RequestView`` borrowing into the buffer.

Mirrors ``_parse_http_request_bytes`` in shape and validation
rules but produces a borrowed view: no per-header ``String``
allocation, no body copy. The body slice points into ``data``.

Args:

- `data`: Raw HTTP/1.1 request bytes (request line + headers + body, terminated or not).
- `max_header_size`: Cap on header bytes; raises if exceeded.
- `max_body_size`: Cap on body length; raises if Content-Length exceeds.
- `max_uri_length`: Cap on URI length; raises if exceeded.
- `peer`: Kernel-reported peer address; threaded onto the view.
- `expose_errors`: Whether 4xx response bodies may echo handler error messages.
- `body_len_override`: When non-negative, the body is the ``body_len_override`` bytes that start right after the header block, whatever ``Content-Length`` says. The reactor uses this after decoding a chunked body in place.

Returns: A ``RequestView`` borrowing every byte-range field from ``data``. The view's lifetime is tied to ``data``'s ``origin``.

Raises: Error: On malformed request line (no spaces / wrong number of components), URI exceeding the cap, headers exceeding the cap, body exceeding the cap, or the ``HeaderMapView`` parser rejecting a header line.
