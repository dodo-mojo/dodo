# `dodo.tls.acceptor`

Server-side TLS acceptor.

``TlsAcceptor`` is the server-side counterpart to ``TlsStream`` —
it wraps a ``TcpListener`` and produces ``TlsStream`` connections
after completing the TLS handshake against a server certificate
chain. ``TlsServerConfig`` carries the acceptor's policy: cert /
key paths, ALPN protocols to advertise, optional CA bundle for
mTLS client-cert verification.

The HTTPS server builds its ``SSL_CTX`` here (``into_ctx``) and runs
each handshake without blocking inside the reactor
(``dodo/http/_reactor/tls_conn_handle.mojo``). ``handshake_fd`` is a
blocking handshake for one fd, used by tests and simple tools.

Public API:

```mojo
from dodo.tls import (
    TlsServerConfig, TlsAcceptor, TlsInfo,
    TlsServerError,
)

var cfg = TlsServerConfig(
    cert_file="/etc/letsencrypt/live/example.com/fullchain.pem",
    key_file="/etc/letsencrypt/live/example.com/privkey.pem",
    alpn=["h2", "http/1.1"], # served preference order
    require_client_cert=False, # mTLS off by default
    client_ca_bundle="",
)
var acceptor = TlsAcceptor(cfg^)
var ssl_and_info = acceptor.handshake_fd(fd)
```

## Aliases

### `TLS_PROTOCOL_TLS12`

```mojo
comptime TLS_PROTOCOL_TLS12 = Int(771)
```

### `TLS_PROTOCOL_TLS13`

```mojo
comptime TLS_PROTOCOL_TLS13 = Int(772)
```

## Structs

### `TlsServerError`

```mojo
struct TlsServerError
```

Generic server-side TLS failure (handshake, cert load, etc.).

``message`` describes the failure in human-readable form;
``code`` carries the underlying OpenSSL error code if
available (0 if not).

Fields:

- `message` (`String`)
- `code` (`Int`)

Implemented traits: `AnyType`, `Copyable`, `Deinitable`, `Movable`, `Writable`

#### `TlsServerError.__init__`

```mojo
def __init__(out self, message: String, code: Int = Int(0))
```

#### `TlsServerError.write_to`

```mojo
def write_to[W: Writer](self, mut writer: W)
```

### `TlsSniCert`

```mojo
struct TlsSniCert
```

A certificate served to clients whose SNI matches ``host`` (an exact name, or ``*.example.com`` for one label).

Fields:

- `host` (`String`)
- `cert_file` (`String`)
- `key_file` (`String`)

Implemented traits: `AnyType`, `Copyable`, `Deinitable`, `Movable`

### `TlsServerConfig`

```mojo
struct TlsServerConfig
```

Server-side TLS policy.

Fields:
    cert_file: Path to the server certificate chain
                         in PEM format (full chain — leaf
                         first, then intermediates). Required.
    key_file: Path to the server private key in
                         PEM format. Required.
    alpn: ALPN protocol identifiers to
                         advertise during the handshake. Order
                         is preference order (the OpenSSL
                         callback selects the first
                         intersection with the client's
                         advertised list). Empty = no ALPN.
    require_client_cert: Whether to require a client
                         certificate (mTLS). Defaults False.
                         When True, ``client_ca_bundle`` must
                         also be set.
    client_ca_bundle: Path to a PEM bundle of trust anchors
                         for verifying client certificates
                         (mTLS). Empty = use OpenSSL's default
                         trust store.
    min_protocol: Minimum TLS protocol version to
                         negotiate. Default
                         ``TLS_PROTOCOL_TLS12``. TLS 1.0 / 1.1
                         are explicitly rejected.

Reload semantics: ``cert_file`` / ``key_file`` are re-read at
every call to ``TlsAcceptor.reload()``; the config struct
itself is value-copied at acceptor construction time.

Fields:

- `cert_file` (`String`)
- `key_file` (`String`)
- `alpn` (`List[String]`)
- `require_client_cert` (`Bool`)
- `client_ca_bundle` (`String`)
- `min_protocol` (`Int`)
- `enable_session_tickets` (`Bool`): Opt-in; default ``False``. When True the acceptor's ``SSL_CTX`` issues RFC 5077 session tickets (TLS 1.2) / RFC 8446 §4.6.1 NewSessionTicket frames (TLS 1.3) so peers can resume on subsequent connects. When False the context sends no tickets and keeps no server session cache, so no session is issued and none can be resumed (every connection is a full handshake). The ticket key lives as long as the ``SSL_CTX``; :meth:`TlsAcceptor.reload` builds a new context, so it rotates the key and invalidates every ticket and cached session issued before it.
- `ticket_lifetime_s` (`Int`): Session ticket lifetime in seconds. Default 7200 (two hours). Maps to ``SSL_CTX_set_timeout`` and the embedded TLS 1.3 ``ticket_lifetime`` field. Production deployments should keep this short and rotate ticket keys via an out-of-band secret-management path.
- `sni_certs` (`List[TlsSniCert]`): Certificates chosen by SNI; a client whose SNI matches none, or that sends none, gets ``cert_file``.
- `handshake_timeout_ms` (`Int`): Wall-clock cap (milliseconds) on a single blocking ``SSL_accept`` drive in ``TlsAcceptor.handshake_fd``. Default 10_000 (10 s). A slow or stalled client that never completes the handshake is aborted at the deadline so it cannot hold the worker indefinitely (slow-loris-on-handshake DoS bound). Measured against a monotonic clock, not an iteration count, so the time spent in each ``SSL_accept`` call counts too. ``0`` disables the cap.

Implemented traits: `AnyType`, `Copyable`, `Deinitable`, `Movable`

#### `TlsServerConfig.__init__`

```mojo
def __init__(out self, cert_file: String, key_file: String, var alpn: List[String] = List(), require_client_cert: Bool = False, client_ca_bundle: String = "", min_protocol: Int = Int(771), enable_session_tickets: Bool = False, ticket_lifetime_s: Int = Int(7200), handshake_timeout_ms: Int = Int(10000), var sni_certs: List[TlsSniCert] = List()) raises
```

Construct the config; validates inter-field invariants.

Raises: Error: When ``require_client_cert=True`` is set without a ``client_ca_bundle`` (mTLS without trust anchors is meaningless — the verify callback would have nothing to verify against). Prevents the misconfiguration foot-gun by failing at construction time rather than at handshake time.

### `TlsInfo`

```mojo
struct TlsInfo
```

Per-connection TLS metadata returned by :meth:`TlsAcceptor.handshake_fd`.

Available when the connection terminated TLS at dodo's
``TlsAcceptor``. Plain-HTTP connections never see this struct
(the reactor only constructs it on the TLS handshake path).

Fields:
    protocol: Negotiated protocol version
                        (e.g. ``"TLSv1.3"``).
    cipher: Cipher suite name
                        (e.g. ``"TLS_AES_128_GCM_SHA256"``).
    sni_host: Client-Hello SNI hostname, or empty
                        string if the client didn't send one.
    alpn_protocol: Negotiated ALPN protocol
                        (e.g. ``"h2"``, ``"http/1.1"``), or
                        empty string if ALPN didn't fire.
    client_cert_subject: Subject DN of the client certificate
                         when mTLS is on; empty string
                         otherwise.

Fields:

- `protocol` (`String`)
- `cipher` (`String`)
- `sni_host` (`String`)
- `alpn_protocol` (`String`)
- `client_cert_subject` (`String`)

Implemented traits: `AnyType`, `Copyable`, `Deinitable`, `Movable`

#### `TlsInfo.__init__`

```mojo
def __init__(out self, protocol: String = "", cipher: String = "", sni_host: String = "", alpn_protocol: String = "", client_cert_subject: String = "")
```

### `TlsAcceptor`

```mojo
struct TlsAcceptor
```

Server-side TLS acceptor.

Wraps a ``TlsServerConfig`` and a real ``ServerCtx`` (the
OpenSSL ``SSL_CTX*``). The constructor
validates the cert + key + ALPN + mTLS config and raises if
any are bad, so configuration errors fail at server-bind
time rather than at the first inbound handshake.

Per-connection use:

1. The HTTPS server takes the context with ``into_ctx`` and
   handshakes inside the reactor without blocking.
2. ``handshake_fd(fd)`` drives ``SSL_accept`` to completion in
   blocking mode, for tests and simple tools.

Cert reload:

``acceptor.reload()`` re-reads the cert + key from the paths
in ``config`` and atomically swaps them on the underlying
``SSL_CTX``. In-flight sessions hold the old cert via
``SSL_use_certificate``; new handshakes pick up the new one.

Fields:

- `config` (`TlsServerConfig`): The acceptor's policy. Mutable via ``reload()`` for cert rotation without restart.

Implemented traits: `AnyType`, `Deinitable`, `Movable`

#### `TlsAcceptor.__init__`

```mojo
def __init__(out self, var config: TlsServerConfig) raises
```

Construct an acceptor.

Loads the cert + key, configures min-protocol + cipher
list, sets up ALPN if non-empty, sets up mTLS verification
if ``require_client_cert``. Raises on any FFI failure —
configuration errors are caught at construction time.

#### `TlsAcceptor.into_ctx`

```mojo
def into_ctx(deinit self) -> ServerCtx
```

Hand over the configured ``SSL_CTX`` (ALPN, mTLS, minimum version, session-ticket policy applied), e.g. to the HTTP reactor, which drives its own non-blocking handshakes.

#### `TlsAcceptor.reload`

```mojo
def reload(mut self) raises
```

Re-read the cert + key files from ``config`` and swap in a freshly built ``SSL_CTX``.

The replacement context is constructed from ``config`` first
and only then installed, so a failed reload (unreadable file,
cert / key mismatch) raises and leaves the running context
untouched. In-flight sessions keep their reference to the
old context and finish with the old cert; new handshakes
pick up the new one.

A new ``SSL_CTX`` has its own random session-ticket keys and
an empty session cache, so a reload also rotates the ticket
key: a ticket or cached session issued before the reload does
not resume after it (the peer falls back to a full
handshake). This is what ``docs/threat-model.md`` promises.

#### `TlsAcceptor.handshake_fd`

```mojo
def handshake_fd(mut self, fd: Int) raises -> Tuple[Int, TlsInfo]
```

Drive the ``SSL_accept`` state machine on ``fd`` to completion (or fatal error) in blocking-poll mode. Sleeps in 1ms slices between WANT_READ / WANT_WRITE returns.

Returns ``(ssl_addr, tls_info)`` — the caller owns the
``ssl_addr`` and is responsible for calling
``server_ssl_free(ctx, ssl_addr)`` when done. The
``TlsInfo`` carries the negotiated ALPN protocol + SNI
hostname (live-populated from the OpenSSL handle).

Args:

- `fd`: The accepted TCP fd (as returned by ``TcpListener.accept().raw_fd()`` or similar).

Returns: A ``(ssl_addr, tls_info)`` tuple.

Raises: Error: On fatal handshake failure (cert mismatch, client refused, etc.).
