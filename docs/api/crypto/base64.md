# `dodo.crypto.base64`

``dodo.crypto.base64`` -- RFC 4648 §4 standard base64 encode/decode.

Consolidates three identical near-duplicate encoders: the
standard-alphabet base64 implementation lived in three places
before -- ``_b64_encode`` in ``dodo.http.auth``,
``_base64_encode`` in ``dodo.ws.client``, ``_b64_encode_srv`` in
``dodo.ws.server`` -- each with the same RFC 4648 §4 table and
the same chunk-of-3 / pad-tail loop. This module is the single
canonical home; the three call sites now import from here.

The URL-safe (RFC 4648 §5, no padding) variant for cookies and
JWT lives at :mod:`dodo.crypto.hmac`
(:func:`base64url_encode` / :func:`base64url_decode`); the two
alphabets diverge on ``+`` / ``/`` vs ``-`` / ``_`` and on
padding behaviour. The HTTP-side ``Basic`` auth header
(RFC 7617) and the WebSocket ``Sec-WebSocket-Accept`` derivation
(RFC 6455 §4.2.2) require the standard alphabet *with* ``=``
padding, which is what this module provides.

## Public API

```mojo
from dodo.crypto.base64 import base64_encode, base64_decode
```

* :func:`base64_encode(data: Span[UInt8, _]) -> String` --
  alphabet ``A-Za-z0-9+/`` with ``=`` padding to a multiple of 4.
* :func:`base64_decode(s: String) raises -> List[UInt8]` --
  inverse; tolerates missing padding, raises on invalid bytes.

## Functions

### `base64_encode`

```mojo
def base64_encode(data: Span[UInt8]) -> String
```

Encode bytes as standard RFC 4648 §4 base64 with ``=`` padding.

Alphabet ``A-Za-z0-9+/``. Output length is always a multiple
of 4; ``=`` is appended so the ``2/3 -> 4`` round-up is
preserved.

Args:

- `data`: Input bytes.

Returns: Base64-encoded string (with ``=`` padding).

### `base64_decode`

```mojo
def base64_decode(s: String) raises -> List[UInt8]
```

Decode standard RFC 4648 §4 base64 (with or without ``=``).

Args:

- `s`: Encoded string; trailing ``=`` characters are tolerated but not required.

Returns: Decoded byte list.

Raises: Error: When ``s`` contains a character outside the base64 alphabet, or its length is otherwise invalid.
