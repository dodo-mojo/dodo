# `dodo.tls.stream`

TLS stream: encrypts a TcpStream via OpenSSL FFI.

The shared library ``libdodo_tls.so`` is built automatically on pixi
activation via ``dodo/tls/ffi/build.sh`` and installed to
``$CONDA_PREFIX/lib/`` when using the packaged distribution.

Opaque C pointers (SSL_CTX*, SSL*) are held as ``Int`` values since Mojo
requires all ``Pointer`` type parameters to have an explicit
``mut`` parameter which is not inferable for ``NoneType``. Using ``Int``
(64-bit on all supported platforms) stores pointer values safely.

Security defaults enforced unconditionally:
- TLS 1.2 minimum (TLS 1.0 / 1.1 disabled at the protocol level)
- Forward-secret AEAD cipher suites only (ECDHE + AES-GCM / ChaCha20)
- Certificate verification REQUIRED (opt-out via ``TlsConfig.insecure()``)
- SNI always sent for hostname targets

Example:
    ```mojo
    from dodo.tls import TlsStream, TlsConfig

    var stream = TlsStream.connect("example.com", 443, TlsConfig())
    stream.write_all("GET / HTTP/1.1\r\nHost: example.com\r\n\r\n".as_bytes())
    var buf = List[UInt8](capacity=4096)
    buf.resize(4096, 0)
    var n = stream.read(buf.unsafe_ptr(), len(buf))
    ```

## OwnedDLHandle / ASAP-destruction discipline

Mojo's ASAP destruction policy reclaims an ``OwnedDLHandle`` right
after its last Mojo-visible use. In a naive ``var lib =
OwnedDLHandle(...); var fn = lib.get_function(...); fn(...)``
sequence the runtime considers ``lib`` dead immediately after
``get_function`` returns and runs the destructor (``dlclose``)
before ``fn`` is invoked, leaving the cached function pointer
dangling into freed memory.

Discipline this file follows: every FFI call goes through a
``_do_ssl_*(imm lib: OwnedDLHandle, ...)`` borrow helper that
does both ``get_function`` and the invocation inside the borrow.
Public methods open ``lib`` once and pass it through to a chain
of helpers; the borrow keeps the dylib mapped across the whole
sequence. Same idiom as
``dodo.http.encoding._do_compress`` /
``dodo.http.middleware._dodo_fs_access`` /
``dodo.tls._server_ffi._do_ssl_ctx_new_server``.

## Structs

### `TlsSession`

```mojo
struct TlsSession
```

Opaque, reusable TLS session handle (RFC 5077 / RFC 8446 §4.6.1) captured from a completed TLS handshake.

Constructed exclusively by :meth:`TlsStream.session`, which
returns the most recent session OpenSSL surfaced via the
``new_session_cb`` callback for the underlying ``SSL_CTX``.
Pass back to :meth:`TlsStream.connect_resumed` to skip the
expensive part of the handshake on the next connect to the
same origin.

This type is ``Movable`` but not ``Copyable`` — duplicating
an ``SSL_SESSION*`` would require an explicit
``SSL_SESSION_up_ref`` / drop pair which doesn't compose with
Mojo's ASAP destruction. Move into the next call site;
re-capture per round-trip if you want to share across
threads.

The handle owns the underlying ``SSL_SESSION*`` via
``SSL_SESSION_free`` on drop. Callers don't normally see the
raw addr; ``session_addr()`` is exposed for advanced FFI use.

Fields:

- `origin` (`String`): ``host:port`` of the connection the session came from, the name that connection verified. :meth:`TlsStream.connect_resumed` offers the session only to that same origin.

Implemented traits: `AnyType`, `Deinitable`, `Movable`

#### `TlsSession.__init__`

```mojo
def __init__(out self, var lib: OwnedDLHandle, addr: Int, var origin: String = "")
```

#### `TlsSession.__deinit__`

```mojo
def __deinit__(deinit self)
```

#### `TlsSession.session_addr`

```mojo
def session_addr(self) -> Int
```

Underlying ``SSL_SESSION*`` as an ``Int``. For advanced FFI integration only — most callers should pass the whole :class:`TlsSession` to :meth:`TlsStream.connect_resumed`.

### `TlsStream`

```mojo
struct TlsStream
```

An encrypted TCP stream using TLS (via OpenSSL FFI).

Wraps a ``TcpStream`` with OpenSSL's SSL session. The TLS handshake is
performed in ``connect``; all subsequent I/O is routed through OpenSSL.

Opaque C pointers (``SSL_CTX*``, ``SSL*``) are stored as ``Int`` values —
the canonical approach in Mojo for FFI-managed handles.

The connection is shut down with a ``close_notify`` alert when destroyed
or when ``close()`` is called explicitly.

This type is ``Movable`` but not ``Copyable`` — an SSL session cannot
be duplicated.

Security defaults:

```mojo
- TLS 1.2 minimum (TLS 1.0 / 1.1 disabled via protocol version + options)
- Forward-secret AEAD ciphers only (ECDHE + AES-GCM / ChaCha20)
- Certificate verification on by default
- SNI always sent for hostname targets
```

Thread safety:

```mojo
Not thread-safe.
```

Example:
```mojo
var stream = TlsStream.connect("httpbin.org", 443, TlsConfig())
stream.write_all("GET /get HTTP/1.1\r\nHost: httpbin.org\r\n\r\n".as_bytes())
```

Implemented traits: `AnyType`, `Deinitable`, `Movable`, `Readable`

#### `TlsStream.__init__`

```mojo
def __init__(out self, var tcp: TcpStream, ctx: Int, ssl: Int, var origin: String = "") raises
```

Internal constructor — use ``TlsStream.connect`` instead.

Args:

- `tcp`: Connected TCP stream (fd used by ssl after handshake).
- `ctx`: SSL_CTX* stored as Int.
- `ssl`: SSL* stored as Int (handshake already complete).
- `origin`: ``host:port`` the handshake verified, stamped on the sessions :meth:`session` hands out.

#### `TlsStream.__deinit__`

```mojo
def __deinit__(deinit self)
```

Send ``close_notify`` and free OpenSSL objects (best-effort).

#### `TlsStream.__enter__`

```mojo
def __enter__(var self) -> Self
```

Transfer ownership of ``self`` into the ``with`` block.

Returns: This ``TlsStream`` (moved).

#### `TlsStream.connect`

```mojo
def connect(host: String, port: UInt16, config: TlsConfig) raises -> Self
```

Open a TLS connection to ``host:port``.

Resolves the hostname (IPv4), opens a ``TcpStream``, configures
OpenSSL, and performs the TLS handshake.

When ``config.verify == TlsVerify.NONE``, a security warning is
printed to stderr on every call (intentional).

Args:

- `host`: Hostname or IP string. SNI is derived from this value.
- `port`: Destination TCP port (typically 443 for HTTPS).
- `config`: TLS configuration (verification mode, CA bundle, mTLS).

Returns: A ``TlsStream`` with the TLS handshake complete.

Raises: NetworkError: DNS resolution or TCP connect failure. TlsHandshakeError: Generic TLS handshake failure. CertificateExpired: Server cert has passed its notAfter. CertificateHostnameMismatch: Hostname does not match the cert. CertificateUntrusted: Cert not trusted by any CA in bundle.

#### `TlsStream.connect_timeout`

```mojo
def connect_timeout(host: String, port: UInt16, config: TlsConfig, timeout_ms: Int) raises -> Self
```

Connect with TLS, failing after ``timeout_ms`` milliseconds.

Uses ``TcpStream.connect_timeout`` for the TCP phase. The TLS
handshake is bounded separately, by arming ``SO_RCVTIMEO`` on
the connected socket for its duration: ``timeout_ms`` is
therefore a bound on each phase, not one budget shared across
both. Without it a peer that completes the TCP handshake and
then says nothing parks the caller inside ``SSL_connect``
forever -- which is what a bound listener that never calls
``accept`` produces, since the kernel finishes the handshake
out of the backlog.

The option is cleared again once the handshake completes, so a
returned stream reads unbounded unless the caller arms its own
timeout via :meth:`set_recv_timeout`.

Args:

- `host`: Hostname or IP string.
- `port`: Destination TCP port.
- `config`: TLS configuration.
- `timeout_ms`: Maximum milliseconds for the TCP connect, and again for the TLS handshake that follows it.

Returns: A ``TlsStream`` with the handshake complete.

Raises: ConnectionTimeout: If the deadline expires during TCP. Timeout: If the deadline expires during the TLS handshake. NetworkError: DNS resolution failure. TlsHandshakeError: Generic TLS handshake failure. CertificateExpired: Server cert expired. CertificateHostnameMismatch: Hostname does not match the cert. CertificateUntrusted: Cert not trusted by any CA.

#### `TlsStream.connect_over_tcp`

```mojo
def connect_over_tcp(var tcp: TcpStream, host: String, config: TlsConfig) raises -> Self
```

Run the TLS handshake over an already-connected ``tcp``.

Unlike :meth:`connect` / :meth:`connect_timeout` (which dial the
TCP themselves), this takes an existing stream -- e.g. a proxy
``CONNECT`` tunnel -- and performs the client handshake on its
fd. ``host`` is used as the default SNI + cert-hostname when
``config.server_name`` is empty.

#### `TlsStream.read`

```mojo
def read(mut self, buf: Pointer[UInt8], size: Int) raises -> Int
```

Decrypt and read up to ``size`` bytes into ``buf``.

Returns 0 on clean TLS closure (``close_notify`` received).

Reads through ``dodo_ssl_read_blocking`` so the retryable case
is classified rather than flattened: with ``SO_RCVTIMEO`` armed
(see :meth:`set_recv_timeout`) an expiry reaches OpenSSL as
``recv`` returning ``EAGAIN``, which ``SSL_read`` reports as
``SSL_ERROR_WANT_READ`` on an empty error queue. The plain
``dodo_ssl_read`` turns that into a ``NetworkError`` whose
reason is the empty string; here it raises ``Timeout``, so a
stalled TLS read reads the same as a stalled cleartext one.
It is never reported as a 0-byte read, which would truncate a
body into a parsed response. End of stream is unchanged, an
unclean one included.

Args:

- `buf`: Destination buffer; the caller must provide at least ``size`` bytes of valid storage.
- `size`: Maximum number of bytes to read.

Returns: Bytes placed in ``buf``, or 0 on clean EOF.

Raises: Timeout: If a socket-level send/receive timeout expired mid-record. NetworkError: On I/O or decryption error.

#### `TlsStream.eof_was_unclean`

```mojo
def eof_was_unclean(self) -> Bool
```

Whether :meth:`read` returned end of stream without the peer's close_notify.

TLS signs the end of a stream with close_notify so that an
attacker who can reset the TCP connection cannot cut a message
short and have it pass for complete. Only a caller whose framing
is the end of the stream needs this: a length or chunked body
already fails when it stops early.

#### `TlsStream.read_exact`

```mojo
def read_exact(mut self, buf: Pointer[UInt8], size: Int) raises
```

Read exactly ``size`` bytes into ``buf``.

Args:

- `buf`: Destination buffer; must have at least ``size`` bytes.
- `size`: Number of bytes to read.

Raises: NetworkError: If EOF arrives before the buffer is full, or on error.

#### `TlsStream.set_recv_timeout`

```mojo
def set_recv_timeout(self, ms: Int) raises
```

Bound blocking reads on the underlying TCP socket.

``SO_RCVTIMEO`` applies to the socket, not to the TLS record
layer: OpenSSL sees the expiry as ``SSL_ERROR_WANT_READ``.
:meth:`read` maps that to ``Timeout``, so a stalled read raises
after ``ms`` milliseconds without data on the wire and reads
the same as a stalled cleartext read -- the case a half-open
connection produces when the network drops mid-response.

Args:

- `ms`: Timeout in milliseconds. ``0`` disables the timeout.

Raises: NetworkError: If ``setsockopt(2)`` fails.

#### `TlsStream.write`

```mojo
def write(self, data: Span[UInt8]) raises -> Int
```

Encrypt and send bytes.

Args:

- `data`: Bytes to encrypt and transmit.

Returns: Number of bytes written (may be less than ``len(data)``).

Raises: NetworkError: On I/O or encryption error.

#### `TlsStream.write_all`

```mojo
def write_all(self, data: Span[UInt8]) raises
```

Encrypt and send all of ``data``.

Loops until all bytes are transmitted or an error occurs.

Args:

- `data`: Bytes to transmit completely.

Raises: NetworkError: On I/O or encryption error.

#### `TlsStream.tls_version`

```mojo
def tls_version(self) -> String
```

Return the negotiated TLS version string.

Returns: E.g. ``"TLSv1.3"`` or ``"TLSv1.2"``. Returns ``"unknown"`` if called before the handshake or if the library cannot be loaded.

#### `TlsStream.cipher_suite`

```mojo
def cipher_suite(self) -> String
```

Return the negotiated cipher suite name.

Returns: E.g. ``"TLS_AES_256_GCM_SHA384"`` or ``"unknown"``.

#### `TlsStream.peer_cert_subject`

```mojo
def peer_cert_subject(self) raises -> String
```

Return the subject DN of the server's certificate.

Args are described above. Do NOT use for security decisions —
use ``config.verify`` for that.

Returns: E.g. ``"/CN=example.com/O=Example Inc/C=US"``.

Raises: NetworkError: If no peer certificate is available.

#### `TlsStream.alpn_selected`

```mojo
def alpn_selected(self) raises -> String
```

Return the ALPN protocol the server selected, or ``""`` if ALPN was not negotiated.

Calls ``dodo_ssl_get_alpn_selected`` (RFC 7301) on the
live SSL session. Useful for clients that advertise
multiple protocols via :attr:`dodo.tls.TlsConfig.alpn`
(e.g. ``["h2", "http/1.1"]``) and need to know which one
the server picked before kicking off the higher-level
protocol driver.

Raises: NetworkError: When the underlying call fails (almost always means the SSL session is closed).

#### `TlsStream.session`

```mojo
def session(self) raises -> TlsSession
```

Return the most recent TLS session OpenSSL surfaced for this connection's ``SSL_CTX``.

Useful sequence:

1. ``var s = TlsStream.connect(host, port, cfg)``
2. write a request, read the response (so the peer's
   NewSessionTicket arrives and the C-side
   ``new_session_cb`` fires).
3. ``var sess = s.session()`` -- captures the cached
   session.
4. Hand ``sess`` to the next connect via
   :meth:`connect_resumed` to skip the expensive part
   of the handshake.

The returned :class:`TlsSession` owns the underlying
``SSL_SESSION*`` (drop runs ``SSL_SESSION_free``). For
TLS 1.3 the ticket arrives interleaved with application
data, so calling ``session()`` immediately after
:meth:`connect` returns may yield an empty handle (its
``session_addr() == 0``) -- do at least one I/O round
trip first, or accept the empty handle and fall back to
a full handshake on the next connect.

Raises: NetworkError: When the underlying FFI surface refuses (almost always means the SSL session is already closed).

#### `TlsStream.was_session_reused`

```mojo
def was_session_reused(self) -> Bool
```

Return True if the most recent handshake on this ``TlsStream`` resumed a prior session (peer-acked, full handshake skipped). Mirrors OpenSSL's ``SSL_session_reused``.

#### `TlsStream.connect_resumed`

```mojo
def connect_resumed(host: String, port: UInt16, config: TlsConfig, var session: TlsSession) raises -> Self
```

Open a TLS connection and offer ``session`` for resumption. If the server accepts, the handshake skips the certificate exchange and key derivation -- a 1-RTT savings on TLS 1.2, even more on TLS 1.3 (resumption flow uses the early-data shape).

Falls back to a full handshake silently if the server
refuses the session (e.g. ticket expired, key rotated).
Use :meth:`was_session_reused` after the call to verify
the resumption took.

Args:

- `host`: Hostname or IP string. SNI is derived from this value (or from ``config.server_name`` when set).
- `port`: Destination TCP port (typically 443 for HTTPS).
- `config`: TLS configuration. ``enable_session_resumption`` must be True (the default) for the new ctx to be ready to capture the next session.
- `session`: Previously-captured session via :meth:`session`. Ownership is consumed.

Returns: A ``TlsStream`` with the TLS handshake complete.

Raises: NetworkError: DNS / TCP / handshake failure. TlsHandshakeError: Generic handshake failure.

#### `TlsStream.close`

```mojo
def close(mut self)
```

Send ``close_notify`` and close the underlying TCP stream.

Idempotent — safe to call multiple times. The destructor also calls
this, so explicit ``close()`` is not required.
