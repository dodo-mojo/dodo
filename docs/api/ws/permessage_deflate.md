# `dodo.ws.permessage_deflate`

WebSocket permessage-deflate extension (RFC 7692).

Per-message DEFLATE compression for WebSocket data frames. The
extension is negotiated via ``Sec-WebSocket-Extensions`` during
the opening handshake (see :mod:`dodo.ws.extensions`); after a
successful negotiation the peers compress every TEXT/BINARY data
frame individually -- the RSV1 bit signals that the payload is
DEFLATE-encoded (RFC 7692 §6).

Wire shape (RFC 7692 §7.2):

- The compressed payload is a *raw* DEFLATE stream (no zlib or
  gzip header) terminated with a sync flush.
- The encoder MUST drop the trailing 4 bytes ``0x00 0x00 0xff 0xff``
  before placing the bytes on the wire (the spec calls this
  "removing the empty deflate block").
- The decoder MUST append the same 4 bytes back to the payload
  before passing it to ``inflate``.

Two codec paths are exposed:

- **No-context-takeover** (the default; safest under RFC
  7692 §7.1.1.1 / §7.1.1.2): every message is compressed against
  a fresh sliding window. The free functions
  :func:`compress_message` and :func:`decompress_message`
  re-initialise the LZ77 state per call; no z_stream lives
  between messages.

- **Context-takeover** (RFC 7692 §7.1.1 default mode): the LZ77
  sliding window persists across messages on both sides. Use
  :class:`PermessageDeflateContext`; each instance owns a pair
  of heap-allocated z_streams (one for the encoder, one for the
  decoder). Carrying context typically halves the compressed
  size on small repetitive payloads at the cost of ~256 KiB of
  zlib state per connection.

Shared invariants:

- ``max_window_bits`` is fixed at 15 (the default); any
  smaller-window offer is silently negotiated up to 15.
- A per-message decompressed-size cap (default 16 MiB) is
  enforced before any allocation -- the same zip-bomb defense
  applied across the rest of dodo's compression paths.
- The compressor uses :data:`DEFAULT_DEFLATE_LEVEL` = 6 (zlib's
  default); callers may override per-direction via
  :class:`PermessageDeflateConfig` (no-context) or via
  :meth:`PermessageDeflateContext.__init__` (with-context).

Public surface:

- :class:`PermessageDeflateConfig` -- per-side knobs.
- :func:`compress_message(plaintext, level)` -> ``List[UInt8]``.
- :func:`decompress_message(compressed, max_decompressed_bytes)`
  -> ``List[UInt8]``; raises if the cap is exceeded.
- :class:`PermessageDeflateContext` -- persistent compressor +
  decompressor for the context-takeover branch.

Higher-level frame integration (RSV1 dispatch on send/recv) lives
in :mod:`dodo.ws.client_h2` for the h2 path and as a flag on
:class:`dodo.ws.frame.WsFrame.rsv1` for the h1 path -- the codec
side is fully isolated here so the compression-oracle hardening
review only needs to scrutinise this single file.

## Aliases

### `DEFAULT_DEFLATE_LEVEL`

```mojo
comptime DEFAULT_DEFLATE_LEVEL = Int(6)
```

``zlib``'s default compression level (1..9, where 9 is slowest / densest). Used when :class:`PermessageDeflateConfig` doesn't override per-direction.

### `DEFAULT_MAX_DECOMPRESSED_BYTES`

```mojo
comptime DEFAULT_MAX_DECOMPRESSED_BYTES = Int(16777216)
```

Per-message decompressed-size cap (16 MiB). The decoder bails with an Error before allocating output past this size; callers should treat the failure as a protocol violation and close the connection with :data:`WsCloseCode.MESSAGE_TOO_BIG` (1009). This is the simplest defense against zip-bomb / compression-oracle payloads -- attackers who can pick the plaintext can otherwise inflate a few-byte ciphertext into many MiB of decompressed output, exhausting the server.

## Structs

### `PermessageDeflateConfig`

```mojo
struct PermessageDeflateConfig
```

Per-side knobs for the permessage-deflate extension.

All four RFC 7692 §7.1 parameters are surfaced for negotiation
+ symmetry, even though the codec implementation always
runs with ``no_context_takeover`` on both sides (see module
docstring). ``max_window_bits`` <= 15 is accepted; the codec
never produces output that violates the cap because raw
deflate with windowBits = -15 already keeps the window at
most 32 KiB.

Fields:

- `enabled` (`Bool`): Master switch. ``False`` (the default) means the extension is neither offered (client) nor accepted (server) during the handshake.
- `server_no_context_takeover` (`Bool`): Whether the server MUST reset its LZ77 context at the end of each message. The codec always enforces ``True`` regardless of this value -- surfaced for handshake honesty.
- `client_no_context_takeover` (`Bool`): Whether the client MUST reset its LZ77 context at the end of each message. The codec always enforces ``True`` regardless of this value -- surfaced for handshake honesty.
- `server_max_window_bits` (`Int`): Max bits in the LZ77 sliding window the server is willing to use. Range 8..15; the codec always operates at 15.
- `client_max_window_bits` (`Int`): Same as :attr:`server_max_window_bits` for the client side.
- `compression_level` (`Int`): ``zlib`` compression level for outgoing messages (1..9, 0 = no compression, -1 = zlib default). Defaults to :data:`DEFAULT_DEFLATE_LEVEL`.
- `max_decompressed_bytes` (`Int`): Per-message decompressed-size cap (bytes). Defaults to :data:`DEFAULT_MAX_DECOMPRESSED_BYTES` (16 MiB). Set to a smaller value on memory-constrained servers; do **not** raise above 64 MiB without first auditing the rest of the request-pipeline for unbounded buffering.

Implemented traits: `AnyType`, `Copyable`, `Defaultable`, `Deinitable`, `Movable`

#### `PermessageDeflateConfig.__init__`

```mojo
def __init__(out self)
```

### `PermessageDeflateContext`

```mojo
struct PermessageDeflateContext
```

Persistent compressor + decompressor for permessage-deflate with **context-takeover** (RFC 7692 §7.1).

Owns one ``z_stream`` per direction; the LZ77 sliding window
survives across :meth:`compress` / :meth:`decompress` calls
so subsequent messages benefit from the dictionary built up
by earlier ones. This is the default mode of RFC 7692 -- the
``server_no_context_takeover`` / ``client_no_context_takeover``
extension parameters are the *opt-out* knobs.

Lifetime: one instance per direction-pair per connection.
The destructor calls ``deflateEnd`` / ``inflateEnd`` and
``free`` so leaking an instance leaks ~256 KiB of zlib state
plus the LZ77 dictionary. The struct is :class:`Movable` but
deliberately not :class:`Copyable`: copying a live handle
would double-free.

Single-threaded per instance. Two threads calling
:meth:`compress` simultaneously is undefined behaviour
(matches zlib's own contract). The WebSocket adapter
serialises send + receive per-connection, so this constraint
is cheap to honour.

Fields:

- `max_decompressed_bytes` (`Int`): Per-message decompressed-size cap. Set at construction; enforced on every :meth:`decompress` call.

Implemented traits: `AnyType`, `Deinitable`, `Movable`

#### `PermessageDeflateContext.__init__`

```mojo
def __init__(out self, level: Int = Int(6), window_bits: Int = Int(-15), max_decompressed_bytes: Int = Int(16777216)) raises
```

Allocate a persistent compressor + decompressor pair.

Args:

- `level`: ``zlib`` compression level (1..9; 0 = no compression; -1 = zlib default).
- `window_bits`: Negative for raw deflate, matching the RFC 7692 §7.1.2.1 negotiated max-window-bits value. Default ``-15`` = 32 KiB sliding window.
- `max_decompressed_bytes`: Per-message decompressed-size cap; defaults to :data:`DEFAULT_MAX_DECOMPRESSED_BYTES` (16 MiB).

Raises: Error: If either ``dodo_pmd_*_new`` returns a zlib error code, or the heap allocation fails.

```mojo
def __init__(out self, *, deinit move: Self)
```

Transfer ownership; the source is consumed via ``deinit`` so its destructor is never invoked.

#### `PermessageDeflateContext.__deinit__`

```mojo
def __deinit__(deinit self)
```

Release both z_streams through the FFI; safe to call on a moved-from instance (handles are zero).

#### `PermessageDeflateContext.compress`

```mojo
def compress(mut self, data: Span[UInt8]) raises -> List[UInt8]
```

Compress one message fragment with context-takeover.

The LZ77 dictionary built up by prior calls is preserved,
so subsequent messages benefit from cross-message
repetition. The trailing ``0x00 0x00 0xff 0xff`` sync
marker is stripped before return per RFC 7692 §7.2.1.

Args:

- `data`: Plaintext bytes.

Returns: Compressed payload, ready for the wire (with RSV1=1).

Raises: Error: If zlib returns a negative error code.

#### `PermessageDeflateContext.decompress`

```mojo
def decompress(mut self, data: Span[UInt8]) raises -> List[UInt8]
```

Decompress one message fragment with context-takeover.

Re-appends the ``0x00 0x00 0xff 0xff`` sync marker the
encoder stripped, then inflates against the persistent
z_stream. The output is capped at
:attr:`max_decompressed_bytes` to defuse zip-bomb /
compression-oracle payloads.

Args:

- `data`: On-wire compressed payload (sync marker stripped).

Returns: Decompressed plaintext.

Raises: Error: If the cap is exceeded or zlib reports a non-recoverable error.

## Functions

### `compress_message`

```mojo
def compress_message(data: Span[UInt8], level: Int = Int(6)) raises -> List[UInt8]
```

Compress one WebSocket message per RFC 7692 §7.2.1.

Returns the raw-DEFLATE-encoded bytes with the trailing
``0x00 0x00 0xff 0xff`` sync marker stripped. The caller
places the result in a WS data frame with the RSV1 bit set
(RFC 7692 §6).

Args:

- `data`: Plaintext message bytes.
- `level`: ``zlib`` compression level (1..9; 0 = no compression; -1 = zlib default).

Returns: The compressed payload, ready for the wire.

Raises: Error: If the underlying zlib call reports an error.

### `decompress_message`

```mojo
def decompress_message(data: Span[UInt8], max_decompressed_bytes: Int = Int(16777216)) raises -> List[UInt8]
```

Decompress one WebSocket message per RFC 7692 §7.2.2.

Re-appends the ``0x00 0x00 0xff 0xff`` sync marker the encoder
stripped, then runs raw DEFLATE inflate. The decompressed
output is capped at ``max_decompressed_bytes`` to defuse
zip-bomb / compression-oracle payloads -- exceeding the cap
raises an Error and the caller MUST close the connection
with status code 1009 (MESSAGE_TOO_BIG).

Args:

- `data`: The on-wire compressed payload (sync marker stripped).
- `max_decompressed_bytes`: The per-message size cap. Defaults to :data:`DEFAULT_MAX_DECOMPRESSED_BYTES` (16 MiB).

Returns: The plaintext message bytes.

Raises: Error: If the cap is exceeded or zlib reports a non-recoverable error.
