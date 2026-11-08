# `dodo.http.auth_extract`

Server-side authentication extractors + CSRF helper.

The :mod:`dodo.http.auth` module ships ``BasicAuth`` and
``BearerAuth`` for the **client** side — they apply credentials
to an outbound request's ``Authorization`` header.

This module provides the symmetric **server-side** primitives:

- ``BearerExtract`` — pulls the Bearer token out of the inbound
  request's ``Authorization`` header and exposes it to handlers
  via the ``Extractor`` trait (drop-in for ``Extracted[H]``).
- ``BasicExtract`` — decodes the inbound Basic credentials
  (``Authorization: Basic <base64-username:password>``) into
  ``username`` / ``password`` strings.
- ``parse_bearer_token`` / ``parse_basic_credentials`` — the
  underlying parsers, exposed for callers who want to assemble
  their own auth flow without going through ``Extracted``.
- ``CsrfToken`` — encode / verify constant-time comparison
  for double-submit-cookie CSRF protection (OWASP Cheat Sheet
  §3.1.1, "Double Submit Cookie pattern").

Why server-side parsers, separate from the client-side
applicators:

- An ``HttpServer`` handler that needs to authenticate the
  caller has to *parse* an ``Authorization`` header, not write
  one. The ``BasicAuth.apply`` shape doesn't fit (writes vs
  reads are different operations on the same header name).
- Symmetry with the existing ``Header[T, name]`` extractor
  pattern: callers who put ``var token: BearerExtract`` on
  their ``Extracted[H]`` struct get the same auto-injection
  semantics they get for path / query / header extractors.
- CSRF lives here because every server-side auth pattern
  needs it (or needs to deliberately opt out of it). Bundling
  it with the auth extractors keeps the surface tight and
  the imports obvious.

Spec compliance:

- ``BearerExtract`` follows RFC 6750 §2.1: token = ``b64token``
  per the Augmented BNF, which permits ``A-Z a-z 0-9 - . _ ~ +
  /`` and trailing ``=`` padding. We pass the token through
  verbatim — the resource server is responsible for token
  introspection / signature verification.
- ``BasicExtract`` follows RFC 7617 §2: ``user-pass = userid ":"
  password`` after base64 decode, where ``userid`` may not
  contain ``:`` but ``password`` may. We split on the first
  ``:`` only.
- ``CsrfToken`` follows OWASP guidance: 32-byte random token,
  base64url-encoded, constant-time compare. Token generation
  uses ``urandom``-fed bytes (caller responsibility — we
  accept the bytes; we don't seed a PRNG ourselves so the
  randomness contract stays explicit).

Error handling:

The parsers (``parse_bearer_token``, ``parse_basic_credentials``,
``_b64_decode``) raise the typed :class:`AuthError` so callers
can pattern-match on the failure mode:

```mojo
from dodo.http import unauthorized, bad_request
from dodo.http.auth_extract import parse_bearer_token, AuthError

try:
    var tok = parse_bearer_token(req.headers.get("authorization"))
except e:
    if e == AuthError.MISSING_HEADER:
        return unauthorized("login required")
    elif e == AuthError.WRONG_SCHEME:
        return bad_request("Bearer required")
```

When a ``BearerExtract`` / ``BasicExtract`` is used as an
``Extracted[H]`` field, the framework does this mapping for you: a
raised :class:`AuthError` becomes a sanitized ``401 Unauthorized``
with a ``WWW-Authenticate: Bearer`` challenge (see
``dodo.http.extract._extractor_error_response``).

The ``BearerExtract`` / ``BasicExtract`` extractors keep the
:class:`dodo.http.extract.Extractor` trait's bare-``raises``
shape (the trait is widely implemented across path / query /
header extractors and changing it would break every impl), but
the :class:`AuthError` raised inside is preserved by the Mojo
runtime — calling ``String(e)`` on the caught error still
produces the typed ``AuthError(VARIANT): detail`` rendering.

## Aliases

### `CSRF_TOKEN_MIN_CHARS`

```mojo
comptime CSRF_TOKEN_MIN_CHARS = Int(16)
```

Shortest token :func:`csrf_token_compare` will accept on either side (16 base64url characters is 96 bits).

## Structs

### `AuthError`

```mojo
struct AuthError
```

Typed error raised by the ``Authorization`` header parsers in this module (``parse_bearer_token``, ``parse_basic_credentials``, ``_b64_decode``).

Enumerated (``_variant`` Int field) with ``comptime`` aliases
per condition. Equatable so callers can pattern-match with
``e == AuthError.MISSING_HEADER`` etc. The ``detail`` field
carries human-readable extra context (the offending
character, the unexpected scheme, ...) — empty when the
variant is self-explanatory.

Variants:

- ``MISSING_HEADER`` — ``Authorization`` header absent.
- ``EMPTY_VALUE`` — header present but empty after the colon.
- ``TOO_SHORT`` — header value too short to start with the
  expected scheme prefix (``Bearer `` is 7 bytes, ``Basic ``
  is 6).
- ``WRONG_SCHEME`` — scheme prefix doesn't match the parser
  called (e.g. ``Basic `` passed to ``parse_bearer_token``).
- ``EMPTY_TOKEN`` — scheme present but no token / credentials
  after it.
- ``B64_BAD_LENGTH`` — RFC 4648 base64 input length not a
  multiple of 4.
- ``B64_TOO_MUCH_PADDING`` — more than 2 ``=`` pad bytes.
- ``B64_INVALID_CHAR`` — character outside the base64
  alphabet.
- ``B64_PADDING_BEFORE_TAIL`` — ``=`` pad byte appears in a
  block that isn't the final block.
- ``MISSING_SEPARATOR`` — RFC 7617 Basic credentials decoded
  without a ``:`` separator between userid and password.

Fields:

- `detail` (`String`)

Implemented traits: `AnyType`, `Copyable`, `Deinitable`, `Equatable`, `ImplicitlyCopyable`, `Movable`, `Writable`

Aliases:

- `MISSING_HEADER = AuthError(Int(1), String(""))`
- `EMPTY_VALUE = AuthError(Int(2), String(""))`
- `TOO_SHORT = AuthError(Int(3), String(""))`
- `WRONG_SCHEME = AuthError(Int(4), String(""))`
- `EMPTY_TOKEN = AuthError(Int(5), String(""))`
- `B64_BAD_LENGTH = AuthError(Int(6), String(""))`
- `B64_TOO_MUCH_PADDING = AuthError(Int(7), String(""))`
- `B64_INVALID_CHAR = AuthError(Int(8), String(""))`
- `B64_PADDING_BEFORE_TAIL = AuthError(Int(9), String(""))`
- `MISSING_SEPARATOR = AuthError(Int(10), String(""))`

#### `AuthError.__eq__`

```mojo
def __eq__(self, other: Self) -> Bool
```

Compare on the ``_variant`` tag only — ``detail`` is human-readable context, not part of the identity.

#### `AuthError.__ne__`

```mojo
def __ne__(self, other: Self) -> Bool
```

#### `AuthError.variant_name`

```mojo
def variant_name(self) -> String
```

#### `AuthError.write_to`

```mojo
def write_to[W: Writer](self, mut writer: W)
```

### `BasicCredentials`

```mojo
struct BasicCredentials
```

Decoded RFC 7617 Basic credentials.

Fields:

- `username` (`String`)
- `password` (`String`)

Implemented traits: `AnyType`, `Copyable`, `Deinitable`, `Movable`

### `BearerExtract`

```mojo
struct BearerExtract
```

Extracts the Bearer token from the inbound ``Authorization`` header.

Raises typed :class:`AuthError` (preserved at runtime through
the bare-``raises`` :class:`Extractor` trait per Mojo doc
§ "Avoid bare raises with typed errors"). Callers that catch
this extractor's error directly via a wrapping ``try`` see
the typed error's ``write_to`` rendering through ``String(e)``.

Specifically raises:

- ``AuthError.MISSING_HEADER`` if no ``Authorization`` header
  is present
- any of :func:`parse_bearer_token`'s failure modes for an
  empty / too-short / wrong-scheme / empty-token header

Fields:

- `token` (`String`)

Implemented traits: `AnyType`, `Copyable`, `Defaultable`, `Deinitable`, `Extractor`, `Movable`

#### `BearerExtract.__init__`

```mojo
def __init__(out self)
```

#### `BearerExtract.apply`

```mojo
def apply(mut self, req: Request) raises
```

#### `BearerExtract.extract`

```mojo
def extract(req: Request) raises -> Self
```

### `BasicExtract`

```mojo
struct BasicExtract
```

Extracts RFC 7617 Basic credentials from the inbound ``Authorization`` header.

Raises typed :class:`AuthError` (preserved at runtime through
the bare-``raises`` :class:`Extractor` trait):

- ``AuthError.MISSING_HEADER`` if no ``Authorization`` header
- any of :func:`parse_basic_credentials`'s failure modes
  (empty / too-short / wrong-scheme / B64_* / missing
  separator)

Fields:

- `username` (`String`)
- `password` (`String`)

Implemented traits: `AnyType`, `Copyable`, `Defaultable`, `Deinitable`, `Extractor`, `Movable`

#### `BasicExtract.__init__`

```mojo
def __init__(out self)
```

#### `BasicExtract.apply`

```mojo
def apply(mut self, req: Request) raises
```

#### `BasicExtract.extract`

```mojo
def extract(req: Request) raises -> Self
```

### `CsrfToken`

```mojo
struct CsrfToken
```

A CSRF token pair (cookie value + form value) ready for constant-time comparison.

Caller fills the ``cookie`` and ``submitted`` fields from the
request (typically: ``cookie`` from the
``Cookie: csrf=<value>`` header, ``submitted`` from the form
field or ``X-CSRF-Token`` header). The :func:`verify` method
folds them through :func:`csrf_token_compare` for the final
check.

:func:`new_csrf_token` makes a token from the OS CSPRNG; a caller
with its own entropy source can feed bytes to
:func:`csrf_token_b64url` instead. Tokens shorter than
``CSRF_TOKEN_MIN_CHARS`` never verify.

Fields:

- `cookie` (`String`)
- `submitted` (`String`)

Implemented traits: `AnyType`, `Copyable`, `Deinitable`, `Movable`

#### `CsrfToken.verify`

```mojo
def verify(self) -> Bool
```

Return True iff the cookie and submitted token match in constant time.

## Functions

### `parse_bearer_token`

```mojo
def parse_bearer_token(authz: String) raises -> String
```

Return the token portion of an ``Authorization: Bearer X`` header value, raising :class:`AuthError` on malformed input.

Tolerates leading whitespace and a single space between the
scheme and the token (per RFC 6750 §2.1 "credentials =
auth-scheme 1*SP token"). The scheme match is
case-insensitive per RFC 7235 §2.1.

Raises :class:`AuthError`:

- ``EMPTY_VALUE`` — the input string is empty
- ``TOO_SHORT`` — too short for the ``Bearer `` prefix
- ``WRONG_SCHEME`` — scheme is not ``Bearer``
- ``EMPTY_TOKEN`` — scheme present but no token follows

### `parse_basic_credentials`

```mojo
def parse_basic_credentials(authz: String) raises -> BasicCredentials
```

Decode an ``Authorization: Basic <base64>`` header value into a :class:`BasicCredentials` pair.

Splits the post-decode bytes on the first ``:`` per RFC 7617
§2: ``user-pass = userid ":" password``, where ``userid``
may not contain ``:`` but ``password`` may.

Raises :class:`AuthError`:

- ``EMPTY_VALUE`` — the input string is empty
- ``TOO_SHORT`` — too short for the ``Basic `` prefix
- ``WRONG_SCHEME`` — scheme is not ``Basic``
- ``EMPTY_TOKEN`` — scheme present but no credentials follow
- ``B64_*`` — base64 decode failure (see :func:`_b64_decode`)
- ``MISSING_SEPARATOR`` — decoded credentials lack a ``:``

### `csrf_token_b64url`

```mojo
def csrf_token_b64url(token_bytes: List[UInt8]) -> String
```

Render a raw CSRF token (typically 32 random bytes from ``urandom``) as a URL-safe base64 string suitable for embedding in an HTML form / cookie.

The output is unpadded (RFC 4648 §5 with the recommendation
"implementations MUST include appropriate padding" treated
as MAY for cookie values, matching the Django / Express
CSRF cookie shape).

### `new_csrf_token`

```mojo
def new_csrf_token() raises -> String
```

A fresh CSRF token: 32 CSPRNG bytes, base64url-encoded.

### `csrf_token_compare`

```mojo
def csrf_token_compare(a: String, b: String) -> Bool
```

Constant-time string comparison for CSRF token check.

Returns ``False`` immediately on length mismatch (the length
itself is not a secret per OWASP). Otherwise XORs every byte
pair and folds into an accumulator so the runtime is
independent of the position of the first differing byte —
blocking BREACH-style timing oracles against the token
cookie.

Either token shorter than ``CSRF_TOKEN_MIN_CHARS`` fails. Two
empty strings used to compare equal, so a victim with no CSRF
cookie yet, targeted by a form that omitted the field, passed.
