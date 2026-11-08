# `dodo.http.encoding`

HTTP content-encoding helpers: gzip and deflate via zlib FFI.

Calls zlib through ``libdodo_zlib.so``, a thin C wrapper built automatically
on ``pixi install`` / environment activation via ``dodo/http/ffi/build.sh``.

**Why a C wrapper instead of calling zlib directly?**

The C wrapper exposes a single-call ``(const void*, int, void*, int, int) -> int``
API so Mojo never needs to re-read z_stream fields after a foreign call — Mojo's
JIT can serve stale stack-slot values for memory modified by external calls,
returning incorrect byte counts.

**Why helper functions with borrowed ``lib``?**

Mojo's ASAP (As Soon As Possible) destruction policy destroys an ``OwnedDLHandle``
immediately after its last *Mojo-visible* use, which is the ``get_function`` call
that retrieves the function pointer. ASAP then calls ``dlclose`` and unmaps the
library *before* the pointer is actually invoked, crashing the JIT on both macOS
ARM64 and Linux.

The fix: each public entry point opens ``lib``, then delegates to a private helper
that accepts ``lib`` as a ``read`` (borrowed) parameter. A borrow cannot be
ASAP-destroyed — it stays alive for the helper's entire execution, including every
C call inside it.

Public API surface:

- ``decompress_gzip(data)`` → ``List[UInt8]``
- ``decompress_deflate(data)`` → ``List[UInt8]``
- ``compress_gzip(data, level=6)`` → ``List[UInt8]``
- ``decode_content(data, encoding)`` → ``List[UInt8]``

## Aliases

### `DEFAULT_MAX_DECOMPRESSED_BYTES`

```mojo
comptime DEFAULT_MAX_DECOMPRESSED_BYTES = Int(16777216)
```

Default decompressed-size ceiling for a single body (16 MiB). A malicious server can ship a tiny compressed payload that inflates without bound (a "zip bomb"); the decoders bail with an Error before growing output past this cap. Mirrors the WS permessage-deflate cap (``dodo/ws/permessage_deflate.mojo``).

## Structs

### `Encoding`

```mojo
struct Encoding
```

HTTP ``Content-Encoding`` / ``Accept-Encoding`` token constants.

Implemented traits: `AnyType`, `Deinitable`, `Movable`

Aliases:

- `IDENTITY = String("identity")`: No encoding applied; pass-through.
- `GZIP = String("gzip")`: IETF gzip format (zlib + gzip wrapper, windowBits = 15 | 16).
- `DEFLATE = String("deflate")`: Raw deflate or zlib-wrapped deflate (windowBits = 15 or -15).
- `BR = String("br")`: Brotli encoding (libbrotlidec / libbrotlienc via libdodo_brotli).

## Functions

### `decompress_gzip`

```mojo
def decompress_gzip(data: Span[UInt8], max_out: Int = Int(16777216)) raises -> List[UInt8]
```

Decompress a gzip-encoded buffer using zlib.

Uses ``dodo_decompress`` with ``windowBits = 47`` (auto-detect gzip or
zlib-wrapped deflate).

Args:

- `data`: The compressed bytes to decompress.
- `max_out`: Decompressed-size ceiling; decompression bails with an Error before growing output past this (zip-bomb guard).

Returns: The decompressed bytes.

Raises: Error: If the input is not valid gzip data, decompression fails, or the output would exceed ``max_out``.

### `decompress_deflate`

```mojo
def decompress_deflate(data: Span[UInt8], max_out: Int = Int(16777216)) raises -> List[UInt8]
```

Decompress a deflate-encoded buffer using zlib.

Tries zlib-wrapped deflate first; falls back to raw deflate, matching
browser behaviour for the ambiguous ``deflate`` encoding.

Args:

- `data`: The compressed bytes to decompress.
- `max_out`: Decompressed-size ceiling (zip-bomb guard).

Returns: The decompressed bytes.

Raises: Error: If neither zlib-wrapped nor raw deflate succeeds, or the output would exceed ``max_out``.

### `compress_gzip`

```mojo
def compress_gzip(data: Span[UInt8], level: Int = Int(6)) raises -> List[UInt8]
```

Compress bytes using gzip via zlib.

Args:

- `data`: The plaintext bytes to compress.
- `level`: Compression level (1 = fastest, 9 = best; 6 = default).

Returns: The gzip-compressed bytes (including gzip header and trailer).

Raises: Error: If compression fails or the output buffer was unexpectedly small.

### `decode_content`

```mojo
def decode_content(data: Span[UInt8], encoding: String, max_out: Int = Int(16777216)) raises -> List[UInt8]
```

Decode ``data`` according to the ``Content-Encoding`` header value.

Args:

- `data`: The (possibly compressed) response body.
- `encoding`: The value of the HTTP ``Content-Encoding`` header.
- `max_out`: Decompressed-size ceiling for the compressed encodings (zip-bomb guard); ignored for identity.

Returns: Decoded bytes. If ``encoding`` is ``"identity"`` or ``""`` the original bytes are copied and returned.

Raises: Error: If the encoding is not supported, decompression fails, or the decompressed output would exceed ``max_out``.

### `compress_brotli`

```mojo
def compress_brotli(data: Span[UInt8], quality: Int = Int(5)) raises -> List[UInt8]
```

Compress bytes using brotli via ``libdodo_brotli``.

Args:

- `data`: Plaintext input bytes.
- `quality`: Brotli quality level 0-11 (5 = sensible default, 11 = max compression but slow). Out-of-range values are clamped by the C wrapper.

Returns: Brotli-compressed bytes.

Raises: Error: If the FFI call fails or the output buffer cannot be grown enough to hold the result.

### `decompress_brotli`

```mojo
def decompress_brotli(data: Span[UInt8], max_out: Int = Int(16777216)) raises -> List[UInt8]
```

Decompress brotli-encoded bytes.

Args:

- `data`: Brotli-encoded input.
- `max_out`: Decompressed-size ceiling (zip-bomb guard).

Returns: Decoded plaintext.

Raises: Error: If the FFI call fails, the input is not valid brotli, or the output would exceed ``max_out``.
