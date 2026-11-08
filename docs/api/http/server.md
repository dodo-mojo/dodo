# `dodo.http.server`

HTTP server: HTTP/1.1 and HTTP/2, cleartext or TLS, on the reactor.

- Reads from the socket in chunks (default 8KB), not byte by byte.
- Scans for the header terminator (CRLFCRLF) before parsing.
- HTTP/1.1 keep-alive; HTTP/1.0 closes by default.
- Serialises the full response into one buffer for one write.
- Sets recv/send timeouts on accepted sockets.

## Structs

### `HttpServer`

```mojo
struct HttpServer
```

A non-blocking reactor HTTP server: HTTP/1.1, HTTP/2, TLS.

One ``serve`` call runs an event loop over ``kqueue`` / ``epoll``,
so many connections are in flight at
once rather than one per calling thread. Each accepted cleartext
connection is dispatched by peeking its first 24 bytes: the RFC 9113
§3.4 client preface selects the HTTP/2 handle, anything else the
HTTP/1.1 one. A server built by :meth:`bind_tls` handshakes on the
reactor and dispatches by ALPN instead.

``num_workers >= 2`` runs one reactor per worker thread, each with
its own copy of the handler, which is why that arity additionally
requires ``Copyable``.

Reads are buffered (default 8KB chunks) for efficient I/O.
HTTP/1.1 keep-alive is enabled by default.
Recv/send timeouts are set on accepted sockets to prevent DoS.

This type is ``Movable`` but not ``Copyable``.

Example:
```mojo
def handle(req: Request) raises -> Response:
    return Response(Status.OK, body="hello".as_bytes())

var srv = HttpServer.bind(SocketAddr.localhost(8080))
srv.serve(handle)
```

Fields:

- `config` (`ServerConfig`)

Implemented traits: `AnyType`, `Deinitable`, `Movable`

#### `HttpServer.__init__`

```mojo
def __init__(out self, var listener: TcpListener, var config: ServerConfig = ServerConfig(Int(8192), Int(8192), Int(10485760), Int(8192), True, Int(1000), Int(500), Int(5000), Int(5000), False, Int(30000), Int(30000), Int(0), Int(1024), Int(60000), Int(10000), Int(240), False, H1LeniencyConfig(allow_mixed_case_method=False, allow_ows_around_colon=False, allow_obs_fold=False, allow_oversized_request_uri=False, allow_oversized_header_list=False, accept_empty_chunk_extensions=False, allow_multiple_content_length=False, allow_te_chunked_when_cl_present=False, accept_obs_text_in_field_value=False, accept_invalid_chunk_extension_chars=False, allow_leading_whitespace_before_request_line=False), Int(0), WsUpgrade(), Http2Config()))
```

#### `HttpServer.__deinit__`

```mojo
def __deinit__(deinit self)
```

#### `HttpServer.bind`

```mojo
def bind(addr: SocketAddr, var config: ServerConfig = ServerConfig(Int(8192), Int(8192), Int(10485760), Int(8192), True, Int(1000), Int(500), Int(5000), Int(5000), False, Int(30000), Int(30000), Int(0), Int(1024), Int(60000), Int(10000), Int(240), False, H1LeniencyConfig(allow_mixed_case_method=False, allow_ows_around_colon=False, allow_obs_fold=False, allow_oversized_request_uri=False, allow_oversized_header_list=False, accept_empty_chunk_extensions=False, allow_multiple_content_length=False, allow_te_chunked_when_cl_present=False, accept_obs_text_in_field_value=False, accept_invalid_chunk_extension_chars=False, allow_leading_whitespace_before_request_line=False), Int(0), WsUpgrade(), Http2Config())) raises -> Self
```

Bind an HTTP server on ``addr``.

Args:

- `addr`: Local address to listen on.
- `config`: HTTP/1.1 server configuration (optional).

Returns: An ``HttpServer`` ready to call ``serve()``.

Raises: AddressInUse: If the port is already bound. NetworkError: For any other OS error.

```mojo
def bind(var addrs: List[SocketAddr], var config: ServerConfig = ServerConfig(Int(8192), Int(8192), Int(10485760), Int(8192), True, Int(1000), Int(500), Int(5000), Int(5000), False, Int(30000), Int(30000), Int(0), Int(1024), Int(60000), Int(10000), Int(240), False, H1LeniencyConfig(allow_mixed_case_method=False, allow_ows_around_colon=False, allow_obs_fold=False, allow_oversized_request_uri=False, allow_oversized_header_list=False, accept_empty_chunk_extensions=False, allow_multiple_content_length=False, allow_te_chunked_when_cl_present=False, accept_obs_text_in_field_value=False, accept_invalid_chunk_extension_chars=False, allow_leading_whitespace_before_request_line=False), Int(0), WsUpgrade(), Http2Config())) raises -> Self
```

Bind an HTTP server on multiple addresses simultaneously.

The list overload of :meth:`bind`.

Each address gets its own ``TcpListener`` fd; the unified
reactor loop accepts on all of them and dispatches each
accepted connection through the same handler. Useful for
binding the same service on both IPv4 and IPv6, on
multiple ports for split traffic classes (e.g. internal
admin port + public service port). UNIX sockets are not
accepted here.

``addrs`` must be non-empty. The first address is the
"primary" listener (used by ``local_addr()`` and any
legacy single-listener call site); the remainder become
extras. All addresses bind in order before any returns,
so a partial-bind failure leaves no half-bound state
(already-bound listeners are dropped + closed by the
``TcpListener.__deinit__``).

Composes with multi-worker serving: ``serve(handler,
num_workers=M)`` on a multi-address server gives N addresses
x M workers, where each pairing owns its own
``SO_REUSEPORT`` listener (N*M in total, bound serially on
the scheduler thread). The listeners created here carry
``SO_REUSEPORT`` and go to worker 0, so no address is ever
left without a listener.

Still single-listener: ``serve_streaming``, which raises when
extras are present rather than leaving an address unserved.

Example:

```mojo
var srv = HttpServer.bind(
    [SocketAddr.localhost(8080), SocketAddr.localhost(8081)],
)
srv.serve(handler)
```

Args:

- `addrs`: One or more local addresses to listen on. Order matters: ``addrs[0]`` is the primary.
- `config`: HTTP/1.1 server configuration (optional).

Returns: An ``HttpServer`` whose ``serve()`` accepts on every listener concurrently.

Raises: Error: If ``addrs`` is empty. AddressInUse: If any port is already bound. NetworkError: For any other OS error.

#### `HttpServer.local_addrs`

```mojo
def local_addrs(self) -> List[SocketAddr]
```

Return the bound addresses, primary first then extras in the order they were passed to :meth:`bind`. Always returns at least one entry.

#### `HttpServer.bind_tls`

```mojo
def bind_tls(addr: SocketAddr, cert_file: String, key_file: String, var alpn: List[String] = List(), var config: ServerConfig = ServerConfig(Int(8192), Int(8192), Int(10485760), Int(8192), True, Int(1000), Int(500), Int(5000), Int(5000), False, Int(30000), Int(30000), Int(0), Int(1024), Int(60000), Int(10000), Int(240), False, H1LeniencyConfig(allow_mixed_case_method=False, allow_ows_around_colon=False, allow_obs_fold=False, allow_oversized_request_uri=False, allow_oversized_header_list=False, accept_empty_chunk_extensions=False, allow_multiple_content_length=False, allow_te_chunked_when_cl_present=False, accept_obs_text_in_field_value=False, accept_invalid_chunk_extension_chars=False, allow_leading_whitespace_before_request_line=False), Int(0), WsUpgrade(), Http2Config())) raises -> Self
```

Bind an HTTPS (TLS-terminated HTTP/1.1) server on ``addr``.

Loads ``cert_file`` / ``key_file`` into a server ``SSL_CTX`` and
stashes it on the returned server; :meth:`serve` then drives
each accepted connection through a non-blocking
:class:`dodo.http._reactor.tls_conn_handle.TlsConnHandle`
(handshake + ``SSL_read`` / ``SSL_write``) before dispatching the
decrypted request to the handler. The plaintext reactor path is
untouched.

Args:

- `addr`: Local address to listen on.
- `cert_file`: Path to the PEM server certificate (chain).
- `key_file`: Path to the PEM server private key.
- `alpn`: ALPN protocol identifiers to advertise, in preference order (e.g. ``["h2", "http/1.1"]``). Empty (the default) advertises no ALPN and serves HTTP/1.1. Offering ``h2`` is served: the connection is handshaken on the reactor and the negotiated identifier selects the HTTP/2 or HTTP/1.1 handle.
- `config`: HTTP/1.1 server configuration (optional).

Returns: An ``HttpServer`` ready to call :meth:`serve`.

Raises: AddressInUse: If the port is already bound. NetworkError: For any other OS error. Error: If the cert / key fails to load.

```mojo
def bind_tls(addr: SocketAddr, var tls: TlsServerConfig, var config: ServerConfig = ServerConfig(Int(8192), Int(8192), Int(10485760), Int(8192), True, Int(1000), Int(500), Int(5000), Int(5000), False, Int(30000), Int(30000), Int(0), Int(1024), Int(60000), Int(10000), Int(240), False, H1LeniencyConfig(allow_mixed_case_method=False, allow_ows_around_colon=False, allow_obs_fold=False, allow_oversized_request_uri=False, allow_oversized_header_list=False, accept_empty_chunk_extensions=False, allow_multiple_content_length=False, allow_te_chunked_when_cl_present=False, accept_obs_text_in_field_value=False, accept_invalid_chunk_extension_chars=False, allow_leading_whitespace_before_request_line=False), Int(0), WsUpgrade(), Http2Config())) raises -> Self
```

Bind an HTTPS server from a full :class:`TlsServerConfig`.

The context is built by :class:`TlsAcceptor`, so everything the
config carries applies to the reactor's handshakes: ALPN, client
certificate verification (mTLS), the minimum protocol version and
the session-ticket policy (off unless enabled). The cert/key form
of :meth:`bind_tls` reached none of these. A misconfiguration
raises here, at bind time.

#### `HttpServer.reload_tls`

```mojo
def reload_tls(self) raises
```

Re-read every certificate and key file the server was bound with and serve them to new handshakes. Safe to call from another thread while :meth:`serve` runs; connections already up keep their certificate. A pair that fails to load raises, and that pair stays as it was.

#### `HttpServer.advertised_alpn_protocols`

```mojo
def advertised_alpn_protocols(self) -> List[String]
```

Return the ALPN identifier list this server advertises on its TLS handshakes, highest preference first, as :func:`dodo.http.alpn_dispatch.negotiate_alpn` consumes it.

#### `HttpServer.route_alpn`

```mojo
def route_alpn(self, alpn: String) raises -> Int
```

Map a negotiated ALPN identifier to a :class:`dodo.http.alpn_dispatch.WireProtocol` codepoint.

Args:

- `alpn`: The ALPN identifier returned by the TLS handshake (empty string == "no ALPN advertised").

Returns: One of :class:`WireProtocol`.

Raises: Error: If the identifier is one dodo doesn't serve.

#### `HttpServer.serve`

```mojo
def serve(mut self, handler: def(Request) raises thin -> Response, num_workers: Int = Int(1), pin_cores: Bool = True) raises
```

Run the reactor loop, calling ``handler`` per request.

Plain-function overload: pass a ``def(Request) raises -> Response``
and the server wraps it in a ``FnHandler`` internally. This is
the -compatible shape; the argument list is extended with
``num_workers`` / ``pin_cores`` to match the Handler-typed
overload below so every user has one entry point to learn.

- ``num_workers == 1`` (default): single-threaded reactor
  (kqueue on macOS, epoll on Linux). Same hot path as the
  ``serve``.
- ``num_workers >= 2``: multicore — N workers
  via ``dodo.runtime.scheduler.Scheduler``. By default
  each worker binds its own ``SO_REUSEPORT`` listener
  (the kernel hashes new 4-tuples to one of N listeners;
  matches actix_web's listener strategy and gives the
  highest steady-state throughput). Export
  ``DODO_REUSEPORT_WORKERS=0`` before launch to switch
  back to the single shared listener with
  ``EPOLLEXCLUSIVE`` (Linux >= 4.5). The exclusive wakeup
  goes to one waiting worker per event, so connections are not spread
  evenly: a lightly loaded server may keep landing them on the
  same worker (see ``Reactor.register_exclusive``).

For Router / middleware / stateful-struct handlers, use the
Handler-typed overload ``serve[H: Handler & Copyable]``.

Args:

- `handler`: Called once per parsed request.
- `num_workers`: Worker count. ``<= 0`` is coerced to 1. Values > 256 are rejected (see ``Scheduler.start``).
- `pin_cores`: On Linux, pin worker N to core ``N % num_cpus``. Ignored when ``num_workers == 1``. No-op on macOS.

Raises: NetworkError: On fatal listener errors; per-connection errors close the offending connection silently. Error: If a worker fails to spawn when ``num_workers >= 2``.

```mojo
def serve[H: Handler](mut self, var handler: H) raises
```

Run the single-worker reactor loop with any ``Handler``.

The arity-1 overload that accepts ``Handler``-only types
without requiring ``Copyable``. This is the right entry
point for ``Router`` (which carries heap-allocated boxed
struct handlers and is not safely ``Copyable`` for every
struct shape), middleware-wrapping handler chains whose
innermost element is a ``Router``, or any other
``Handler``-only struct.

For multi-worker mode (``num_workers >= 2``), the handler
type must be ``Copyable`` because each worker gets its
own ``H.copy()``. Use the parametric ``serve[H: Handler &
Copyable](handler, num_workers, pin_cores)`` overload
below for that.

A handler that is not ``Copyable`` is moved into a
:class:`SharedHandler`, so the offload pool can keep it alive for
a job still running after this returns.

Args:

- `handler`: The request handler (ownership transferred).

Raises: NetworkError: On fatal listener errors; per-connection errors close the offending connection silently.

```mojo
def serve[H: Handler & Copyable](mut self, var handler: H, num_workers: Int, pin_cores: Bool = True) raises
```

Run the multi-worker reactor loop with a ``Copyable Handler``.

Each worker gets its own ``H.copy()`` and runs an independent
reactor on its own thread; they share a single listener fd
via ``dodo.runtime.scheduler.Scheduler``. ``Copyable`` is
required here because of the per-worker copy.

- ``num_workers == 1``: routed back to the single-worker
  overload; this overload's ``Copyable`` constraint is
  stricter than necessary but the dispatch is still
  correct.
- ``num_workers >= 2``: multicore — N workers
  sharing a single listener fd via
  ``dodo.runtime.scheduler.Scheduler``.

Args:

- `handler`: The request handler (ownership transferred).
- `num_workers`: Worker count. ``<= 0`` is coerced to 1. Values > 256 are rejected (see ``Scheduler.start``).
- `pin_cores`: On Linux, pin worker N to core ``N % num_cpus``. Ignored when ``num_workers == 1``. No-op on macOS.

Raises: NetworkError: On fatal listener errors; per-connection errors close the offending connection silently. Error: If a worker fails to spawn when ``num_workers >= 2``.

#### `HttpServer.attach_ws_h2`

```mojo
def attach_ws_h2[W: WsH2Handler](mut self, var ws_handler: W) raises
```

Bridge RFC 8441 Extended CONNECT tunnels to ``ws_handler``.

Serves ordinary HTTP through whatever handler :meth:`serve` is
given and, on the same HTTP/2 server, routes ``:protocol=
websocket`` tunnels to this sidecar. Advertising
``SETTINGS_ENABLE_CONNECT_PROTOCOL`` is turned on for you.

Call before :meth:`serve`. One instance serves every tunnel on a
worker; with several workers each serves its own copy. A
single-worker server bound to several addresses cannot carry it
(``serve`` raises).

The sidecar is a property of the server, not an argument to
:meth:`serve`.

Args:

- `ws_handler`: The WS-over-h2 sidecar (ownership transferred).

#### `HttpServer.serve_streaming`

```mojo
def serve_streaming[H: StreamHandler](mut self, var handler: H, max_in_flight: Int = Int(0), retry_after_s: Int = Int(1)) raises
```

Run the single-threaded streaming reactor loop.

The typed-streaming counterpart of ``serve``: instead of a
request/response ``Handler``, it drives a ``StreamHandler``
through the per-connection lifecycle (``on_open`` /
``on_writable`` / ``on_upstream`` / ``on_close``) over the
reactor, owning the EPOLLOUT-driven outbound drain so the front
never blocks the event loop. Use this for multiplexing /
streaming fronts (e.g. a streaming proxy).

Single-listener, single-worker. Extra ``bind(List[SocketAddr])`` listeners
and multi-worker mode are not supported here yet.

A front hands a blocking request to the offload pool with
``conn.offload(stack, req)`` and gets the response in
``on_offload_done``; the server's ``offload_threads``,
``offload_queue_depth``, ``handler_timeout_ms`` and
``shutdown_timeout_ms`` apply.

Args:

- `handler`: The streaming front (ownership transferred). One instance services every connection.
- `max_in_flight`: Admission cap; ``0`` (default) = unlimited. When the live-connection count is at the cap, a new connection is refused with a 503 + ``Retry-After`` instead of hanging in the accept backlog.
- `retry_after_s`: ``Retry-After`` seconds advertised in the 503.

Raises: NetworkError: On fatal listener / reactor errors; per-connection errors close the offending connection.

```mojo
def serve_streaming[H: StreamHandler & Copyable](mut self, var handler: H, num_workers: Int, pin_cores: Bool = True, max_in_flight: Int = Int(0), retry_after_s: Int = Int(1)) raises
```

Multi-worker streaming reactor (N workers over the scheduler).

The :trait:`StreamHandler` twin of ``serve(handler, num_workers)``:
each worker runs its own copy of ``handler`` on its own reactor +
connection table (state is fully per-worker; the ``H: Copyable``
bound clones the handler once per worker before spawn). Listener
sharing (per-worker SO_REUSEPORT vs one EPOLLEXCLUSIVE fd) is the
scheduler's decision via ``DODO_REUSEPORT_WORKERS``.

``num_workers <= 1`` falls through to the single-worker loop.
Single-listener only: extra ``bind(List[SocketAddr])`` listeners are rejected
(multi-worker uses SO_REUSEPORT, not multi-address).

#### `HttpServer.serve_until_signal`

```mojo
def serve_until_signal[H: Handler & Copyable](mut self, var handler: H, num_workers: Int, pin_cores: Bool = True) raises
```

Serve like :meth:`serve` until SIGINT, SIGTERM or SIGHUP, then drain: stop accepting, give in-flight requests up to ``config.shutdown_timeout_ms`` to finish, and return.

This is what ``App.serve`` runs, so Ctrl-C, ``docker stop`` and
``dodo dev`` restarts never cut a response off halfway. The
signal handlers are only installed for the call and the default
ones come back when it returns.

Args:

- `handler`: The request handler (ownership transferred).
- `num_workers`: Worker count, at least 1. One worker still runs on its own thread, so this thread can wait for the signal.
- `pin_cores`: On Linux, pin worker N to core ``N % num_cpus``.

#### `HttpServer.serve_cancellable`

```mojo
def serve_cancellable[CH: CancelHandler](mut self, var handler: CH) raises
```

Run the cancel-aware reactor loop with a ``CancelHandler``.

Single-threaded entry point. The reactor allocates one
``CancelCell`` per connection, hands a ``Cancel`` handle bound
to it into ``handler.serve(req, cancel)``, and flips the cell
on:

- ``CancelReason.PEER_CLOSED`` -- peer FIN observed before the
  response was queued.
- ``CancelReason.TIMEOUT`` -- idle-timeout driven.
- ``CancelReason.SHUTDOWN`` -- listener stop requested.

For plain ``Handler``s that don't observe cancellation, wrap
with ``WithCancel[H](inner=h)`` to plug them into this entry
point unchanged. This is the **shared-middleware path** for the
cancel-aware reactor: a full ``Handler`` middleware stack over a
``Router`` composes directly, because every middleware layer is
itself a ``Handler`` and ``WithCancel`` bridges the whole stack
in one wrap (cancel-awareness composes with routing)::

```mojo
var r = Router()
r.get("/", home)
var stack = Logger(RequestId(r^), prefix="[app]")
var srv = HttpServer.bind(SocketAddr.localhost(8080))
srv.serve_cancellable(WithCancel(stack^))
```

To run the *same* stack inside a streaming front (one process,
one logging/auth/routing stack behind both a REST control plane
and a token-streaming endpoint), call ``stack.serve(req)`` in the
``StreamHandler`` and frame the result with
``StreamConn.send_response`` (see
:mod:`dodo.http.streaming_server`).

Args:

- `handler`: Cancel-aware request handler (ownership transferred).

Raises: NetworkError: On fatal listener errors. Error: If a TLS context is bound, or ``bind`` was given several addresses (this loop serves one listener; use ``serve``).

#### `HttpServer.local_addr`

```mojo
def local_addr(self) -> SocketAddr
```

Return the local address the server is bound to.

#### `HttpServer.close`

```mojo
def close(mut self)
```

Stop accepting new connections and break the reactor loop.

**Hard stop.** In-flight handlers may be cut mid-write — there
is no wait. Use ``drain(timeout_ms)`` for a graceful tear-down.

Idempotent. The loop finishes processing in-flight events before
returning; a concurrent caller from another thread can use this to
request graceful shutdown (the reactor's wakeup fd will be notified
automatically next iteration).

#### `HttpServer.drain`

```mojo
def drain(mut self, timeout_ms: Int) raises -> ShutdownReport
```

Graceful shutdown.

Closes the listening socket so no new connections are accepted,
keeps the reactor running for ``timeout_ms`` milliseconds so
in-flight requests and responses can finish, then breaks the
reactor loop. When the loop stops it flips ``Cancel.SHUTDOWN``
on whatever is still live and closes it.

Wires ``ServerConfig.shutdown_timeout_ms`` into a real
wait-for-drain loop.

Notes:
``drain`` is called from another thread than the one
running ``serve()``, and it blocks the caller for the whole
``timeout_ms`` -- it cannot return early when the last
connection finishes, because the reactor publishes no
live-connection count on this path (idle keep-alive
connections would also count as live). Pass the longest
wait you can tolerate.

The single-threaded reactor cannot preempt a synchronous
handler -- the handler runs to completion even if it
ignores ``Cancel.SHUTDOWN``. Cancel-aware handlers
(``CancelHandler``) observe the ``CancelReason.SHUTDOWN``
flip and short-circuit on their next ``cancel.cancelled()``
poll once the window has elapsed.

Args:

- `timeout_ms`: Milliseconds to keep serving in-flight connections. ``0`` is a hard stop (equivalent to ``close()``). Negative values are clamped to ``0``.

Returns: A ``ShutdownReport``. On this single-threaded path the counts are all zero: ``serve()`` owns the serving thread, so ``drain`` has no vantage point from which to observe per-connection progress. ``Scheduler.drain`` (multi-worker) joins its workers and reports measured counts per worker.

Raises: NetworkError: If the listener cannot be closed.
