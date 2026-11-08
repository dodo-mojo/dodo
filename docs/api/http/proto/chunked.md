# `dodo.http.proto.chunked`

Sans-I/O framing for ``Transfer-Encoding: chunked`` request bodies.

RFC 9112 sec 7.1. Two questions the server reactor needs answered, both
pure functions over a byte buffer:

- :func:`scan_chunked_end` -- has the whole body arrived yet? The
  reactor cannot use ``Content-Length`` to size a chunked request, so
  without this it has no completeness signal at all and treats the
  request as finished the moment the headers land.
- :func:`decode_chunked_body` -- turn the framed bytes into the body the
  handler sees, plus any trailer fields.

Kept in the sans-I/O sublayer so both the server reactor and any future
client sharing can use it without either importing the other's
transport code. No sockets, no allocation beyond the output buffer.

Chunk-size lines are hex, optionally followed by ``;ext=val``
parameters, which are skipped per RFC 9112 sec 7.1.1. Trailer fields
after the terminating chunk are walked over so the end offset is
correct, but not surfaced -- no inbound caller needs them yet. A size
line or trailer line that contains a bare LF is malformed: an LF-splitting
front end would end the line (and so the body) somewhere else.

## Aliases

### `CHUNKED_INCOMPLETE`

```mojo
comptime CHUNKED_INCOMPLETE = Int(-1)
```

``scan_chunked_end``: more bytes needed.

### `CHUNKED_MALFORMED`

```mojo
comptime CHUNKED_MALFORMED = Int(-2)
```

``scan_chunked_end``: the framing is invalid; reject with 400.

### `TE_ABSENT`

```mojo
comptime TE_ABSENT = Int(0)
```

``request_te_framing``: no ``Transfer-Encoding`` field; frame by ``Content-Length`` (or no body).

### `TE_CHUNKED`

```mojo
comptime TE_CHUNKED = Int(1)
```

``request_te_framing``: exactly ``chunked``; frame by chunk size lines.

### `TE_INVALID`

```mojo
comptime TE_INVALID = Int(-1)
```

``request_te_framing``: the framing is ambiguous or malformed; 400.

### `TE_UNSUPPORTED`

```mojo
comptime TE_UNSUPPORTED = Int(-2)
```

``request_te_framing``: a transfer coding other than ``chunked`` was applied; dodo does not decode those, so 501 (RFC 9112 sec 6.1).

### `CHUNK_LINE_MAX`

```mojo
comptime CHUNK_LINE_MAX = Int(4096)
```

Longest chunk-size line (size plus extensions) or trailer line accepted. Without a cap, a peer can send extension bytes that never reach CRLF and keep a request incomplete for as long as the connection lives. The cap is on the line's content, CRLF excluded, and applies the same whether the line arrives whole or in pieces.

## Functions

### `classify_transfer_coding`

```mojo
def classify_transfer_coding(value: String) -> Int
```

Classify a ``Transfer-Encoding`` value as a request framing.

``value`` is every ``Transfer-Encoding`` field of the message joined
with ``,`` -- RFC 9110 sec 5.3 makes repeated fields and a comma
list the same thing, so the decision must look at all of them, not
the first or the last.

Returns: ``TE_CHUNKED`` when the list is exactly ``chunked``; ``TE_UNSUPPORTED`` when ``chunked`` is last but another coding precedes it; ``TE_INVALID`` when ``chunked`` is not the final coding, appears twice, or the list is empty. RFC 9112 sec 6.3 requires a 400 for a request whose final coding is not chunked, since its length cannot be determined.

### `request_te_framing`

```mojo
def request_te_framing(buf: Span[UInt8], headers_end: Int, allow_content_length: Bool = False) -> Int
```

Decide ``Transfer-Encoding`` framing from the raw header block.

A byte scan rather than a ``HeaderMap`` lookup, because the reactor
has to answer this *before* it parses and the minimal-parser path
never builds a ``HeaderMap``. It reads header lines the way the
parser does -- field name anchored at the start of a line (lines end
at LF, a preceding CR dropped) and followed by ``:``, with optional
SP/HTAB in between -- and it reads *every* ``Transfer-Encoding``
line, so it cannot disagree with the parser about which one counts.

Args:

- `buf`: Buffer holding the request head.
- `headers_end`: Offset one past the ``CRLFCRLF`` terminator.
- `allow_content_length`: When False (strict), a ``Content-Length`` alongside ``Transfer-Encoding`` is ``TE_INVALID``: the two framings disagree and a front end may have used the other.

Returns: One of ``TE_ABSENT``, ``TE_CHUNKED``, ``TE_INVALID``, ``TE_UNSUPPORTED``.

### `header_says_chunked`

```mojo
def header_says_chunked(buf: Span[UInt8], headers_end: Int) -> Bool
```

True when the request is framed by ``Transfer-Encoding: chunked``.

Kept for callers that only need the yes/no answer. Anything that
must also reject a malformed or unsupported coding should call
:func:`request_te_framing` instead.

### `scan_chunked_end`

```mojo
def scan_chunked_end(buf: Span[UInt8], start: Int, max_body: Int) -> Int
```

Return the offset one past a complete chunked body.

Walks the chunk-size lines without copying any payload. Returns
``CHUNKED_INCOMPLETE`` when more bytes are needed,
``CHUNKED_MALFORMED`` on invalid framing or when the decoded size
would exceed ``max_body``, otherwise the absolute end offset
(after the terminating chunk and its trailer section).

``max_body`` is checked against the running decoded total, not the
wire total, and is checked *during* the walk -- a chunked upload
must not be allowed to grow the read buffer past the configured
limit before anyone notices.

Stateless: every call walks from ``start``. A caller that polls
the same growing buffer should use :func:`scan_chunked_resume`.

### `scan_chunked_resume`

```mojo
def scan_chunked_resume(buf: Span[UInt8], mut cursor: Int, mut decoded_total: Int, max_body: Int) -> Int
```

``scan_chunked_end`` that remembers how far it got.

``cursor`` and ``decoded_total`` are advanced past every chunk that
has fully arrived, so the next call starts at the first incomplete
chunk instead of at the top of the body. The reactor re-polls
after every read; restarting from the top made a body of many
small chunks, delivered in many small segments, quadratic in its
length.

Args:

- `buf`: Buffer holding the request.
- `cursor`: On entry, where the next unscanned chunk-size line starts (``headers_end`` for a fresh request). Advanced in place.
- `decoded_total`: Payload bytes in the chunks before ``cursor``. Advanced in place.
- `max_body`: Cap on the decoded body.

Returns: As for :func:`scan_chunked_end`.

### `decode_chunked_trailers`

```mojo
def decode_chunked_trailers(buf: Span[UInt8], start: Int, mut trailers: HeaderMap) raises
```

Append the trailer fields of the chunked body at ``start`` that may be kept (:func:`trailer_field_allowed`) to ``trailers``. A trailer line that is not ``name: value`` with a token name raises. Assumes :func:`scan_chunked_end` accepted the buffer.

### `decode_chunked_body`

```mojo
def decode_chunked_body(buf: Span[UInt8], start: Int, mut out: List[UInt8]) raises -> Int
```

Append the decoded body to ``out``; return the end offset.

Assumes :func:`scan_chunked_end` already accepted this buffer, so
framing errors here raise rather than being reported as a status.
Trailer fields are skipped; use :func:`decode_chunked_trailers` if
the caller wants them.
