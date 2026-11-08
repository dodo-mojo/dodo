# `dodo.crypto.hmac`

HMAC-SHA256 + URL-safe base64 over the OpenSSL FFI.

The C-side wrapper (``dodo/tls/ffi/openssl_wrapper.cpp``) exports
``dodo_hmac_sha256`` and ``dodo_hmac_sha256_verify``; the latter
uses ``CRYPTO_memcmp`` so the verify path is constant-time. Both
are reached through an ``OwnedDLHandle`` against
``libdodo_tls.so`` (resolved by the same helper TLS uses).

This module is the only path through which dodo touches HMAC; the
``dodo.http.session`` layer composes ``hmac_sha256`` +
``base64url_*`` into ``SignedCookie`` / ``Session`` /
``SessionStore``.

## Base64 URL-safe (RFC 4648 paragraph 5)

``base64url_encode`` produces no padding; ``base64url_decode``
accepts both padded and unpadded inputs. The alphabet is
``A-Z a-z 0-9 - _``. Cookie bodies must avoid ``;`` / ``,`` / ``=``;
the no-padding URL-safe variant is the canonical choice (matches
JSON Web Signature compact serialisation).

## Functions

### `hmac_sha256`

```mojo
def hmac_sha256(key: List[UInt8], msg: List[UInt8]) raises -> List[UInt8]
```

Compute HMAC-SHA256(key, msg). Returns a 32-byte digest.

Args:

- `key`: Secret key bytes (any length, including empty per RFC 4231 vector 1).
- `msg`: Message bytes.

Returns: A ``List[UInt8]`` of length 32 holding the digest.

Raises: Error: If the underlying FFI call fails (e.g. OpenSSL misconfiguration).

### `hmac_sha256_verify`

```mojo
def hmac_sha256_verify(key: List[UInt8], msg: List[UInt8], mac: List[UInt8]) raises -> Bool
```

Verify an HMAC-SHA256 tag in constant time.

Args:

- `key`: Secret key bytes.
- `msg`: Message bytes.
- `mac`: Candidate 32-byte MAC tag.

Returns: ``True`` if ``mac`` is a valid HMAC-SHA256 tag for ``(key, msg)``. ``False`` for length mismatch, an empty ``key``, or any byte difference (the comparison is constant-time over the full 32-byte width).

Raises: Error: If the underlying FFI call fails.

### `base64url_encode`

```mojo
def base64url_encode(data: List[UInt8]) -> String
```

Encode bytes as URL-safe base64 (no padding).

Alphabet: ``A-Za-z0-9-_``. ``+`` / ``/`` from RFC 4648 paragraph 4
are replaced by ``-`` / ``_``; trailing ``=`` padding is stripped
so the output is cookie-safe.

### `base64url_decode`

```mojo
def base64url_decode(s: String) raises -> List[UInt8]
```

Decode URL-safe base64 (with or without trailing ``=``).

Args:

- `s`: Encoded string. Trailing ``=`` characters are tolerated.

Returns: Decoded byte list.

Raises: Error: When ``s`` contains a character outside the base64 alphabet, or its length is invalid.
