# `dodo.http.proto.ascii`

``dodo.http.proto.ascii`` -- zero-validation ASCII helpers.

Promoted out of :mod:`dodo.http.server` (which was the originating
site for the helper but is the wrong layer -- it is the reactor-
coupled dispatcher, not the sans-I/O parser surface).

Why it lives here

The pattern -- "construct a Mojo ``String`` from a byte span without
re-running the stdlib's full UTF-8 validator" -- belongs in the
proto layer because every consumer is parser-shaped: HTTP/1.1 wire
artefacts (method, URL, version, header name, header value),
HTTP/2 control frame fields, WebSocket control-frame text payloads,
gRPC ``trailers-only`` field names, and so on. The bytes have
already passed the protocol's own RFC 7230 / RFC 9110 / RFC 7540 /
RFC 6455 token / VCHAR / TCHAR check upstream, so the additional
stdlib UTF-8 validation is dead work.

The helper showed up as the single hottest user-space symbol in
``perf record`` against the H1 plaintext bench (~5% of CPU); this
module is the namespace it lives in so every parser layer can
reach for it consistently.

Caller contract

Inputs MUST already be valid ASCII (every byte ``< 0x80``). The
helper does not check; calling it on non-ASCII bytes produces an
incorrectly-encoded ``String`` (each byte becomes a one-byte UTF-8
sequence, which is correct iff every byte is < 0x80). HTTP/1.1
wire artefacts satisfy this through the parser's RFC 7230 token /
VCHAR check; HTTP/2 token-shaped fields satisfy it through HPACK's
RFC 7541 §4 ASCII-only contract; WebSocket text frames do *not*
satisfy it (those carry UTF-8 by spec) -- the codec there must
keep using ``String(unsafe_from_utf8=...)``.

Public API

* :func:`ascii_unchecked_string(span: Span[UInt8, _]) -> String` --
  construct a ``String`` of the same byte length from ``span`` via
  ``String(unsafe_uninit_length=n)`` + ``memcpy``. Empty input
  returns ``String("")``.
* :func:`ascii_lower(s: String) -> String` -- return an ASCII-
  lowercase copy of ``s`` using a single ``unsafe_uninit_length``
  allocation. The pure-ASCII fast path skips the per-byte branch.

## Functions

### `ascii_unchecked_string`

```mojo
def ascii_unchecked_string(span: Span[UInt8]) -> String
```

Construct a ``String`` from ASCII bytes without UTF-8 validation.

``String(unsafe_from_utf8=span)`` unconditionally runs
``_is_valid_utf8_runtime`` even though the constructor name
suggests it skips validation -- a ``perf record`` on the H1
plaintext bench surfaced ``_is_valid_utf8_runtime`` as the
single hottest user-space symbol (~5% of CPU). This helper
allocates an uninitialised ``String`` of the exact length and
memcpy's the bytes directly into its buffer, sidestepping the
validator entirely.

Caller contract: the bytes MUST already be valid ASCII (each
byte ``< 0x80``). HTTP/1.1 wire artefacts -- method, URL,
version, header name, header value -- all satisfy this via
the RFC 7230 token / VCHAR checks the parser already runs
upstream; we never get here with a non-ASCII byte.

Args:

- `span`: Source bytes. Caller guarantees every byte is < 0x80.

Returns: A freshly-allocated ``String`` of length ``len(span)`` with the bytes copied verbatim.

### `ascii_eq_ignore_case`

```mojo
def ascii_eq_ignore_case(s: String, lowercase_literal: StringSpan) -> Bool
```

Case-insensitive ASCII equality against an already-lowercase literal.

Folds each byte of ``s`` to lower case inline and compares it to
``lowercase_literal`` without allocating. The literal MUST already
be lower case (callers pass a compile-time constant such as
``"content-length"``); only ``s`` is folded so the common case is
a length check plus one fold-and-compare pass.

Replaces the ``s.lower() == "literal"`` idiom on parser hot paths,
where the throwaway lowercased ``String`` showed up as the top
user-space symbol (``to_lowercase`` ~3% of CPU) in ``perf record``
against the H1 plaintext bench: every header name on every request
allocated a lowercased copy purely to compare against a constant.

Caller contract: ``s`` MUST already be valid ASCII (the parser's
RFC 7230 token check guarantees this for header names).

Args:

- `s`: Source ASCII string (folded to lower case during compare).
- `lowercase_literal`: The already-lowercase target to match.

Returns: ``True`` iff ``s`` equals ``lowercase_literal`` ignoring ASCII case.

### `ascii_lower`

```mojo
def ascii_lower(s: String) -> String
```

Return an ASCII-lowercase copy of ``s``.

Allocates a single ``unsafe_uninit_length`` ``String`` of the
input's byte length and fills it via a tight pointer loop. A
fast path scans ``s`` for any upper-case ASCII byte first and
delegates to :func:`ascii_unchecked_string` when none is present
-- the keep-alive request path's per-``Connection:`` lookup
pays roughly the cost of one length probe in the common
already-lowercase case.

Caller contract: ``s`` MUST already be valid ASCII. The output
is non-meaningful for bytes ``>= 0x80`` (those pass through
unchanged).

Args:

- `s`: Source ASCII string.

Returns: A freshly-allocated ``String`` of length ``s.byte_length()`` with each upper-case ASCII byte lowered.
