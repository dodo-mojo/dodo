# `dodo.http.simd_parsers`

SIMD-friendly byte-scan primitives for the HTTP/1.1 parser hot path.

Three primitives:

* ``simd_memmem(haystack, needle)`` — find the first occurrence
  of ``needle`` in ``haystack``. Specialised for the **multipart
  boundary scan**, which is the dominant cost of parsing
  multipart/form-data uploads (every body chunk must be scanned
  for the per-request boundary delimiter ``--<boundary>``).
* ``simd_percent_decode(input, out)`` — RFC 3986 §2.1
  percent-decoder for URL-encoded query-string and form-body
  fragments. Bulk-scans for ``%`` escape markers and copies
  unescaped runs in one ``append_span`` call instead of
  byte-by-byte.
* ``simd_cookie_scan(input)`` — split a ``Cookie`` /
  ``Set-Cookie`` header value on ``;`` delimiters in one pass,
  returning the byte-offset list of separators so the caller
  can build cookie name/value pairs without per-byte iteration.

Background
----------

Mojo's stdlib ``Span[UInt8]`` doesn't ship a vectorised
``memmem`` / percent-decode / cookie-split primitive yet. The
HTTP/1.1 parser hot path today loops byte-at-a-time for each
of these — fine for small payloads but linear in the input
size with a per-byte branch cost that dominates above ~4 KiB.

The "SIMD" here refers to an SSE4.2 / AVX2 vectorised inner
loop using ``PCMPESTRI`` / ``PSHUFB`` — that inner-loop swap
can land later. This module provides the clean public API +
correct scalar implementations + property tests. All future
SIMD acceleration plugs in behind the same function
signatures: a canonical scalar decoder first, with a SIMD swap
behind the same signatures.

What this module provides
-------------------------

* ``simd_memmem(haystack, needle) -> Int`` — return the
  byte-offset of the first match, or -1 on no match. Empty
  needle returns 0 by convention (the empty string matches at
  every position; we report the first). Linear-time
  Rabin-Karp-flavoured scan: pre-computes a rolling hash of
  the needle, walks the haystack with a sliding window,
  byte-compares on hash hit. Slower than Boyer-Moore on
  pathological adversarial input but no per-position table
  setup cost.
* ``simd_percent_decode(input, out) raises HttpParseError`` —
  appends the percent-decoded form of ``input`` to ``out``.
  Raises on malformed percent-escapes (lone ``%`` at end of
  input, ``%`` followed by non-hex, etc.).
* ``HttpParseError`` — typed enum-style error. Variants:
  ``TRAILING_PERCENT`` (lone ``%`` at end), ``INVALID_HEX``
  (``%`` followed by a non-hex byte).
* ``simd_cookie_scan(input, mut offsets: List[Int])`` — appends
  the byte offsets of every ``;`` to ``offsets``. Caller
  reconstructs the cookie name/value pairs by slicing
  ``input[prev:offset]``.

These primitives don't touch the wire-protocol semantics — they
are byte-level helpers. The multipart parser, the form decoder and
the cookie parser still use their own per-byte loops.

## Structs

### `HttpParseError`

```mojo
struct HttpParseError
```

Typed error for byte-level parser primitives in this module.

Variants:

```mojo
TRAILING_PERCENT: Input ends with a lone ``%`` (or
    ``%X`` with no second hex digit).
INVALID_HEX: ``%`` is followed by a byte that is not a
    valid ASCII hex digit (``[0-9A-Fa-f]``).
```

Fields:

- `variant` (`Int`)

Implemented traits: `AnyType`, `Copyable`, `Deinitable`, `Equatable`, `ImplicitlyCopyable`, `Movable`, `Writable`

Aliases:

- `TRAILING_PERCENT = Int(1)`
- `INVALID_HEX = Int(2)`

#### `HttpParseError.__eq__`

```mojo
def __eq__(self, other: Self) -> Bool
```

#### `HttpParseError.__ne__`

```mojo
def __ne__(self, other: Self) -> Bool
```

#### `HttpParseError.write_to`

```mojo
def write_to[W: Writer](self, mut writer: W)
```

## Functions

### `simd_memmem`

```mojo
def simd_memmem(haystack: Span[UInt8], needle: Span[UInt8]) -> Int
```

Return the byte-offset of the first occurrence of ``needle`` in ``haystack``, or -1 on no match.

The empty-needle convention follows the ``memmem(3)`` POSIX
behaviour: an empty needle matches at offset 0.

Args:

- `haystack`: The byte sequence to search.
- `needle`: The byte sequence to look for.

Returns: Byte offset of the first match, or -1 if no match.

### `simd_percent_decode`

```mojo
def simd_percent_decode(input: Span[UInt8], mut output: List[UInt8]) raises
```

Append the RFC 3986 §2.1 percent-decoded form of ``input`` to ``output``.

The future SIMD acceleration scans for ``%`` markers in
16-byte / 32-byte chunks via ``PCMPEQB``; this scalar
implementation bulk-copies unescaped runs via per-byte
append (still preferable to a Span-by-Span ``+=`` because
it avoids the intermediate List alloc).

Args:

- `input`: Bytes to decode (typically a query-string fragment or an ``application/x-www-form-urlencoded`` body chunk).
- `output`: Byte list to append the decoded bytes to.

Raises: HttpParseError(TRAILING_PERCENT): Input ends with a lone ``%`` or ``%X`` (missing second hex digit). HttpParseError(INVALID_HEX): A byte after ``%`` is not a valid hex digit.

### `simd_cookie_scan`

```mojo
def simd_cookie_scan(input: Span[UInt8], mut offsets: List[Int])
```

Append the byte offsets of every ``;`` in ``input`` to ``offsets``.

Caller reconstructs the cookie name/value pairs by slicing
``input[prev:offset]`` for each adjacent pair (with a sentinel
of -1 / len(input) at the boundaries). The scan does not
interpret quoting or escape sequences — RFC 6265 §4.1.1
forbids both in cookie values.

Args:

- `input`: Bytes of a Cookie or Set-Cookie header value.
- `offsets`: List to append matched byte offsets to. Existing contents are preserved.
