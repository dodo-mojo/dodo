# `dodo.tls.error`

TLS-specific error types for ``dodo.tls``.

All error types implement ``Copyable`` (which implies ``Movable``) and
``Writable`` so they can be raised, caught, printed, and logged
uniformly.

## Structs

### `TlsHandshakeError`

```mojo
struct TlsHandshakeError
```

The TLS handshake failed (generic failure not covered by cert errors).

Fields:
    message: Human-readable OpenSSL error string.

Fields:

- `message` (`String`)

Implemented traits: `AnyType`, `Copyable`, `Deinitable`, `Movable`, `Writable`

#### `TlsHandshakeError.__init__`

```mojo
def __init__(out self, message: String)
```

Create a TlsHandshakeError.

Args:

- `message`: Error detail from the OpenSSL error queue.

#### `TlsHandshakeError.write_to`

```mojo
def write_to[W: Writer](self, mut writer: W)
```

Write ``"TlsHandshakeError: <message>"`` to ``writer``.

Args:

- `writer`: Destination writer.

### `CertificateExpired`

```mojo
struct CertificateExpired
```

The server certificate has passed its ``notAfter`` date.

Fields:
    subject: Certificate subject DN from ``X509_NAME_oneline``.

Fields:

- `subject` (`String`)

Implemented traits: `AnyType`, `Copyable`, `Deinitable`, `Movable`, `Writable`

#### `CertificateExpired.__init__`

```mojo
def __init__(out self, subject: String = "")
```

Create a CertificateExpired error.

Args:

- `subject`: Certificate subject DN string (may be empty).

#### `CertificateExpired.write_to`

```mojo
def write_to[W: Writer](self, mut writer: W)
```

Write the error to ``writer``.

Args:

- `writer`: Destination writer.

### `CertificateHostnameMismatch`

```mojo
struct CertificateHostnameMismatch
```

The server certificate's CN/SAN does not match the target hostname.

Fields:
    expected: The hostname that was required.
    subject: The certificate's subject DN.

Fields:

- `expected` (`String`)
- `subject` (`String`)

Implemented traits: `AnyType`, `Copyable`, `Deinitable`, `Movable`, `Writable`

#### `CertificateHostnameMismatch.__init__`

```mojo
def __init__(out self, expected: String, subject: String = "")
```

Create a CertificateHostnameMismatch error.

Args:

- `expected`: The hostname the client tried to connect to.
- `subject`: Certificate subject DN (may be empty if unavailable).

#### `CertificateHostnameMismatch.write_to`

```mojo
def write_to[W: Writer](self, mut writer: W)
```

Write the error to ``writer``.

Args:

- `writer`: Destination writer.

### `CertificateUntrusted`

```mojo
struct CertificateUntrusted
```

The server certificate is not trusted by any CA in the bundle.

Raised for self-signed certs, expired CAs, or missing CA chains.

Fields:
    reason: OpenSSL verification failure reason string.

Fields:

- `reason` (`String`)

Implemented traits: `AnyType`, `Copyable`, `Deinitable`, `Movable`, `Writable`

#### `CertificateUntrusted.__init__`

```mojo
def __init__(out self, reason: String = "")
```

Create a CertificateUntrusted error.

Args:

- `reason`: OpenSSL verification error string.

#### `CertificateUntrusted.write_to`

```mojo
def write_to[W: Writer](self, mut writer: W)
```

Write the error to ``writer``.

Args:

- `writer`: Destination writer.
