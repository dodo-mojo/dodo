# `dodo.tls`

TLS/SSL layer — wraps `TcpStream` with OpenSSL encryption.

Provides TLS 1.2 and TLS 1.3 over any `TcpStream`. The OpenSSL C wrapper
shared library is built automatically on `pixi install` via
`dodo/tls/ffi/build.sh`.

## Public API

```mojo
from dodo.tls import TlsConfig, TlsVerify, TlsStream
from dodo.tls import (
    TlsHandshakeError, CertificateExpired,
    CertificateHostnameMismatch, CertificateUntrusted,
)
```

- `TlsConfig` — Certificate/key/CA bundle configuration.
- `TlsVerify` — Peer verification mode constants.
- `TlsStream` — Encrypted TCP stream (handshake + read/write).
- `TlsHandshakeError` — Generic TLS handshake failure.
- `CertificateExpired` — Server cert has passed its `notAfter` date.
- `CertificateHostnameMismatch` — Cert CN/SAN does not match the target host.
- `CertificateUntrusted` — Cert not trusted by any CA in the bundle.

## Example

```mojo
from dodo.tls import TlsStream, TlsConfig

def main() raises:
    # HTTPS request using system CA bundle (default)
    var stream = TlsStream.connect("example.com", 443, TlsConfig())
    _ = stream.write(
        "GET / HTTP/1.1\r\nHost: example.com\r\nConnection: close\r\n\r\n"
        .as_bytes()
    )
    var buf = List[UInt8](capacity=8192)
    buf.resize(8192, 0)
    var n = stream.read(buf.unsafe_ptr(), len(buf))
    print(String(buf[:n]))
    stream.close()
```

## Packages

- [`dodo.tls.ffi`](ffi/index.md)

## Modules

- [`dodo.tls.acceptor`](acceptor.md): Server-side TLS acceptor.
- [`dodo.tls.config`](config.md): TLS configuration: certificates, keys, and verification policy.
- [`dodo.tls.error`](error.md): TLS-specific error types for ``dodo.tls``.
- [`dodo.tls.stream`](stream.md): TLS stream: encrypts a TcpStream via OpenSSL FFI.
