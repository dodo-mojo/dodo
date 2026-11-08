# `dodo.http.header_view`

Borrowed header storage.

``HeaderMapView[origin]`` stores headers as ``(name_start, name_len,
value_start, value_len)`` offsets into a single byte buffer the
caller owns (typically ``ConnHandle.read_buf``). Lookups compare
against the buffer in place — no per-header ``String`` allocation
on the read path.

Owned ``HeaderMap`` (``dodo/http/headers.mojo``) stays the type of
record for response writers (``Response.headers``) and as the
``into_owned()`` target for handlers that need to keep headers
alive past one event-loop iteration.

This commit is **additive**: ``Request`` still carries an owned
``HeaderMap``, and ``_parse_http_request_bytes`` still allocates.
The ``HeaderMapView`` -> ``Request.headers`` wiring lands with the
``RequestView[origin]`` refactor; until then ``HeaderMapView``
is a standalone type usable for any byte-range header parsing
(WebSocket handshakes, HTTP/2 HEADERS frames, custom
protocol layering).

Example:

```mojo
var raw = "GET / HTTP/1.1\r\nHost: x\r\nX-A: 1\r\n\r\n".as_bytes()
var view = parse_header_view(Span[UInt8, _](raw))
assert_equal(view.get("host"), "x") # case-insensitive
assert_equal(view.get("X-A"), "1")
assert_equal(view.len(), 2)
var owned = view.into_owned() # one allocation, copies bytes
```

The header offsets list itself does allocate (Mojo's ``List``
manages its own backing buffer), but each lookup avoids the
per-header ``String`` copy that ``HeaderMap.get`` would have done.
For a 12-header request the parse path makes 12 + 12 + 1
String allocations (12 keys, 12 values, one HeaderMap struct
internally). The view path makes one ``List[Int]`` allocation
holding 4 * 12 ints.

## Structs

### `HeaderMapView`

```mojo
struct HeaderMapView[origin: Origin[mut=origin.mut]]
```

Borrowed header collection.

Holds offsets into a caller-owned byte buffer (``self.buf``)
plus a parallel ``List[Int]`` of ``(name_start, name_len,
value_start, value_len)`` quadruples (4 ints per header).

Lookups are case-insensitive ASCII; comparison runs against the
underlying ``buf`` in place.

The ``origin`` parameter ties the view's lifetime to the
buffer it borrows from. Mojo's borrow checker prevents the
view from outliving the buffer.

Fields:

- `buf` (`Span[UInt8, origin]`): The byte buffer the view borrows from. Typically ``ConnHandle.read_buf`` for the reactor read path; may be any ``Span[UInt8, ...]`` for tests / WS handshake / future HTTP/2 HEADERS frame readers.

Implemented traits: `AnyType`, `Deinitable`, `Movable`

#### `HeaderMapView.__init__`

```mojo
def __init__(out self, buf: Span[UInt8, origin])
```

Empty view bound to ``buf``. Use ``parse_header_view`` to populate from raw header bytes.

```mojo
def __init__(out self, buf: Span[UInt8, origin], var offsets: List[Int])
```

Populated view. ``len(offsets)`` must be a multiple of 4.

#### `HeaderMapView.len`

```mojo
def len(self) -> Int
```

Number of headers in the view.

#### `HeaderMapView.get`

```mojo
def get(self, name: String) -> StringSpan[origin_of(origin)]
```

Return the value of the first header named ``name``, case-insensitive. Returns an empty slice if not present.

The returned slice borrows from ``self.buf``; its lifetime
is tied to the view's ``origin``. No allocation.

#### `HeaderMapView.count`

```mojo
def count(self, name: String) -> Int
```

Number of header lines named ``name``, case-insensitive.

#### `HeaderMapView.contains`

```mojo
def contains(self, name: String) -> Bool
```

True if a header named ``name`` is present (case-insensitive).

#### `HeaderMapView.into_owned`

```mojo
def into_owned(self) raises -> HeaderMap
```

Materialise an owned ``HeaderMap`` by copying each header's bytes out of the borrowed buffer into ``String``s.

One allocation per header (key + value). Use this only when
the handler needs to keep headers alive past the connection's
event-loop iteration; the borrowed view itself does **not**
allocate per header.

## Functions

### `parse_header_view`

```mojo
def parse_header_view[origin: Origin[mut=origin.mut]](data: Span[UInt8, origin]) raises -> HeaderMapView[origin]
```

Parse CRLF-separated header lines into a ``HeaderMapView``.

Expects the request line + ``\r\n`` to already be stripped:
``data`` should start at the first header line and end at (or
after) the empty CRLF that terminates the header block. Stops
at the first empty line.

Header values are trimmed of leading / trailing OWS (SP / HTAB)
per RFC 7230 §3.2.4. The trim is offset arithmetic on the
underlying buffer — no allocation.

Raises ``Error`` on malformed lines (missing colon, empty header
name).

Args:

- `data`: Header bytes (may include CRLF terminators between lines and a trailing empty CRLF).

Returns: A populated ``HeaderMapView`` borrowing from ``data``.
