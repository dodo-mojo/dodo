"""HTTP server: HTTP/1.1 and HTTP/2, cleartext or TLS, on the reactor.

- Reads from the socket in chunks (default 8KB), not byte by byte.
- Scans for the header terminator (CRLFCRLF) before parsing.
- HTTP/1.1 keep-alive; HTTP/1.0 closes by default.
- Serialises the full response into one buffer for one write.
- Sets recv/send timeouts on accepted sockets.
"""

# This file is long because Mojo can't split one struct's methods across
# files.

from std.memory import unsafe_memcpy, stack_allocation
from std.ffi import c_int, c_uint, external_call

from json import dumps, Value as JsonValue

from ..runtime._libc_time import libc_nanosleep_ms, monotonic_now_ms

from std.collections import Optional
from std.sys import stderr

from .handler import Handler, CancelHandler, ViewHandler
from .cancel import Cancel
from .streaming_server import StreamHandler
from .intern import intern_method_bytes
from .request import Request, Method
from .response import Response, Status
from .headers import HeaderMap
from .proto.ascii import ascii_unchecked_string, ascii_eq_ignore_case
from .static_response import StaticResponse
from ._server.config import (
    ServerConfig,
    WsUpgrade,
    _resolve_bufring_handler_env,
    bufring_gap,
)
from .alpn_dispatch import (
    ALPN_HTTP_1_1,
    ALPN_HTTP_2,
    WireProtocol,
    dispatch_alpn,
)
from ..http2.server import Http2Config
from ..ws.server_h2 import WsH2Handler, WsH2Hooks
from ..errors import map_handler_error, log_handler_error
from ..net import IpAddr, SocketAddr, NetworkError, BrokenPipe, Timeout
from ..tcp import TcpListener, TcpStream
from ..tls._server_ffi import ServerCtx
from ..tls.acceptor import TlsAcceptor, TlsServerConfig, TlsSniCert


# Re-exported so ``dodo.http.ShutdownReport`` works.
from dodo.runtime.scheduler import ShutdownReport


# ── HttpServer ────────────────────────────────────────────────────────────────


struct HttpServer(Movable):
    """A non-blocking reactor HTTP server: HTTP/1.1, HTTP/2, TLS.

    One ``serve`` call runs an event loop over ``kqueue`` / ``epoll``
    (opt-in ``io_uring`` on Linux), so many connections are in flight at
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
    """

    var _listener: TcpListener
    var _extra_listener_fds: List[Int]
    """Raw fds of additional listeners attached via
    the list overload of :meth:`bind`. Empty when constructed via the single-
    address :meth:`bind` (the default; preserves the original
    single-listener behaviour byte-for-byte).

    These fds are owned by the ``HttpServer`` -- they're closed
    via libc ``close(2)`` in ``HttpServer.__deinit__`` (see
    :meth:`_close_extras`). Stored as raw fds rather than
    ``TcpListener`` because ``TcpListener`` is not ``Copyable``
    and ``List[T]`` requires ``Copyable``; the multi-listener
    accept loop only needs the fd anyway (it routes through
    ``_accept_loop_unified_fd``). The original
    :class:`SocketAddr` per fd is kept in
    :attr:`_extra_local_addrs` for diagnostics and the
    :meth:`local_addrs` accessor."""
    var _extra_local_addrs: List[SocketAddr]
    """Local addresses for the extras in :attr:`_extra_listener_fds`,
    in the same order. Lets ``local_addrs()`` enumerate every
    bound address without an extra ``getsockname(2)`` syscall."""
    var config: ServerConfig
    var _stopping: Bool
    """Set by ``close()`` to break the reactor loop. Read from the loop
    itself each iteration."""
    var _tls_ctx: Optional[ServerCtx]
    """Optional server-side ``SSL_CTX`` for the HTTPS (TLS-terminated)
    path. ``None`` (the default) for the plaintext flows; set to a loaded
    :class:`dodo.tls._server_ffi.ServerCtx` by :meth:`bind_tls`, and
    consumed by :meth:`serve` to spawn a per-connection
    :class:`dodo.http._reactor.tls_conn_handle.TlsConnHandle`. Kept
    ``Optional`` so the plaintext server carries no TLS/OpenSSL cost."""
    var _tls_certs: List[TlsSniCert]
    """Every certificate pair the TLS context serves (host ``""`` is
    the default), re-read by :meth:`reload_tls`."""

    var _ws_h2_hooks: Optional[WsH2Hooks]
    """Boxed RFC 8441 WebSocket-over-h2 sidecar, set by
    :meth:`attach_ws_h2` and consumed by :meth:`serve`. ``None`` (the
    default) means Extended CONNECT is not advertised. The box is torn
    down by :meth:`_drop_ws_h2_hooks` once serving returns."""

    @always_inline
    def _tls_ctx_addr(self) -> Int:
        """Address of the shared ``SSL_CTX``, or 0 when plaintext.

        The reactor takes the context by address rather than by value:
        OpenSSL designs ``SSL_CTX*`` for shared read-only use across
        threads (each connection gets its own ``SSL`` via ``SSL_new``),
        and ``ServerCtx`` is move-only, so every worker borrows the one
        the server owns instead of cloning it.
        """
        if self._tls_ctx:
            return Int(Pointer(to=self._tls_ctx.value()))
        return 0

    def __init__(
        out self,
        var listener: TcpListener,
        var config: ServerConfig = ServerConfig(),
    ):
        self._listener = listener^
        self._extra_listener_fds = List[Int]()
        self._extra_local_addrs = List[SocketAddr]()
        self.config = config^
        self._stopping = False
        self._tls_ctx = None
        self._tls_certs = List[TlsSniCert]()
        self._ws_h2_hooks = None

    def __deinit__(deinit self):
        self._listener.close()
        self._close_extras()
        # The Optional[ServerCtx] destructor runs dodo_ssl_ctx_free
        # when an HTTPS context was bound; no-op otherwise.
        _ = self._tls_ctx^

    def _close_extras(mut self):
        """Close every fd in :attr:`_extra_listener_fds` via
        libc ``close(2)``. Safe to call from ``__deinit__``; idempotent
        because cleared after closing.
        """
        for i in range(len(self._extra_listener_fds)):
            var fd = self._extra_listener_fds[i]
            if fd >= 0:
                _ = external_call["close", Int32](Int32(fd))
        self._extra_listener_fds.clear()
        self._extra_local_addrs.clear()

    @staticmethod
    def bind(
        addr: SocketAddr,
        var config: ServerConfig = ServerConfig(),
    ) raises -> HttpServer:
        """Bind an HTTP server on ``addr``.

        Args:
            addr: Local address to listen on.
            config: HTTP/1.1 server configuration (optional).

        Returns:
            An ``HttpServer`` ready to call ``serve()``.

        Raises:
            AddressInUse: If the port is already bound.
            NetworkError: For any other OS error.
        """
        var listener = TcpListener.bind(addr)
        return HttpServer(listener^, config^)

    @staticmethod
    def bind(
        var addrs: List[SocketAddr],
        var config: ServerConfig = ServerConfig(),
    ) raises -> HttpServer:
        """Bind an HTTP server on multiple addresses simultaneously.

        The list overload of :meth:`bind`.

        Each address gets its own ``TcpListener`` fd; the unified
        reactor loop accepts on all of them and dispatches each
        accepted connection through the same handler. Useful for
        binding the same service on both IPv4 and IPv6, on
        multiple ports for split traffic classes (e.g. internal
        admin port + public service port), or on a UNIX socket
        plus a TCP socket sharing one process (after the upcoming
        ``UdsListener`` integration).

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
        the scheduler thread). The listeners created here are closed
        first, because ``SO_REUSEPORT`` only composes with other
        ``SO_REUSEPORT`` sockets and these are plain binds.

        Still single-listener: ``serve_streaming``, which raises when
        extras are present rather than leaving an address unserved.

        Args:
            addrs: One or more local addresses to listen on.
                Order matters: ``addrs[0]`` is the primary.
            config: HTTP/1.1 server configuration (optional).

        Returns:
            An ``HttpServer`` whose ``serve()`` accepts on every
            listener concurrently.

        Raises:
            Error: If ``addrs`` is empty.
            AddressInUse: If any port is already bound.
            NetworkError: For any other OS error.

        Example:

        ```mojo
        var srv = HttpServer.bind(
            [SocketAddr.localhost(8080), SocketAddr.localhost(8081)],
        )
        srv.serve(handler)
        ```
        """
        from dodo.net.socket import INVALID_FD

        if len(addrs) == 0:
            raise Error("HttpServer.bind: addrs must be non-empty")
        var primary = TcpListener.bind(addrs[0])
        # Bind extras up-front; if any fails, the partially-bound
        # ``TcpListener`` instances we already moved to ``primary``
        # / consumed in this loop close themselves via __deinit__.
        var extra_fds = List[Int]()
        var extra_addrs = List[SocketAddr]()
        for i in range(1, len(addrs)):
            var l = TcpListener.bind(addrs[i])
            extra_fds.append(Int(l._socket.fd))
            extra_addrs.append(l._socket.local_addr())
            # Detach the fd from ``l`` so its __deinit__ doesn't close
            # what HttpServer now owns. RawSocket lacks an explicit
            # ``release_fd()``; setting ``fd = INVALID_FD`` is the
            # equivalent contract used elsewhere (e.g. the move
            # constructor) so the destructor sees "already closed".
            l._socket.fd = INVALID_FD
        var srv = HttpServer(primary^, config^)
        srv._extra_listener_fds = extra_fds^
        srv._extra_local_addrs = extra_addrs^
        return srv^

    def local_addrs(self) -> List[SocketAddr]:
        """Return the bound addresses, primary first then extras
        in the order they were passed to :meth:`bind`. Always
        returns at least one entry.
        """
        var out = List[SocketAddr]()
        out.append(self._listener.local_addr())
        for i in range(len(self._extra_local_addrs)):
            out.append(self._extra_local_addrs[i].copy())
        return out^

    @staticmethod
    def bind_tls(
        addr: SocketAddr,
        cert_file: String,
        key_file: String,
        var alpn: List[String] = List[String](),
        var config: ServerConfig = ServerConfig(),
    ) raises -> HttpServer:
        """Bind an HTTPS (TLS-terminated HTTP/1.1) server on ``addr``.

        Loads ``cert_file`` / ``key_file`` into a server ``SSL_CTX`` and
        stashes it on the returned server; :meth:`serve` then drives
        each accepted connection through a non-blocking
        :class:`dodo.http._reactor.tls_conn_handle.TlsConnHandle`
        (handshake + ``SSL_read`` / ``SSL_write``) before dispatching the
        decrypted request to the handler. The plaintext reactor path is
        untouched.

        Args:
            addr: Local address to listen on.
            cert_file: Path to the PEM server certificate (chain).
            key_file: Path to the PEM server private key.
            alpn: ALPN protocol identifiers to advertise, in preference
                order (e.g. ``["h2", "http/1.1"]``). Empty (the default)
                advertises no ALPN and serves HTTP/1.1. Offering ``h2``
                is served: the connection is handshaken on the reactor
                and the negotiated identifier selects the HTTP/2 or
                HTTP/1.1 handle.
            config: HTTP/1.1 server configuration (optional).

        Returns:
            An ``HttpServer`` ready to call :meth:`serve`.

        Raises:
            AddressInUse: If the port is already bound.
            NetworkError: For any other OS error.
            Error: If the cert / key fails to load.
        """
        var listener = TcpListener.bind(addr)
        var ctx = ServerCtx.new(cert_file, key_file)
        if len(alpn) > 0:
            var wire = List[UInt8]()
            for i in range(len(alpn)):
                var p = alpn[i]
                if p.byte_length() == 0 or p.byte_length() > 255:
                    raise Error(
                        "HttpServer.bind_tls: each ALPN id must be 1..255 bytes"
                    )
                wire.append(UInt8(p.byte_length()))
                for b in p.as_bytes():
                    wire.append(b)
            ctx.set_alpn(wire)
        var srv = HttpServer(listener^, config^)
        srv._tls_ctx = Optional[ServerCtx](ctx^)
        srv._tls_certs.append(TlsSniCert("", cert_file, key_file))
        return srv^

    @staticmethod
    def bind_tls(
        addr: SocketAddr,
        var tls: TlsServerConfig,
        var config: ServerConfig = ServerConfig(),
    ) raises -> HttpServer:
        """Bind an HTTPS server from a full :class:`TlsServerConfig`.

        The context is built by :class:`TlsAcceptor`, so everything the
        config carries applies to the reactor's handshakes: ALPN, client
        certificate verification (mTLS), the minimum protocol version and
        the session-ticket policy (off unless enabled). The cert/key form
        of :meth:`bind_tls` reached none of these. A misconfiguration
        raises here, at bind time.
        """
        var listener = TcpListener.bind(addr)
        var certs = tls.sni_certs.copy()
        certs.append(TlsSniCert("", tls.cert_file, tls.key_file))
        var ctx = TlsAcceptor(tls^).into_ctx()
        var srv = HttpServer(listener^, config^)
        srv._tls_ctx = Optional[ServerCtx](ctx^)
        srv._tls_certs = certs^
        return srv^

    def reload_tls(self) raises:
        """Re-read every certificate and key file the server was bound
        with and serve them to new handshakes. Safe to call from another
        thread while :meth:`serve` runs; connections already up keep
        their certificate. A pair that fails to load raises, and that
        pair stays as it was."""
        if not self._tls_ctx:
            raise Error("HttpServer.reload_tls: not a TLS server")
        for i in range(len(self._tls_certs)):
            ref c = self._tls_certs[i]
            self._tls_ctx.value().set_cert(c.host, c.cert_file, c.key_file)

    def advertised_alpn_protocols(self) -> List[String]:
        """Return the ALPN identifier list this server advertises on its
        TLS handshakes, highest preference first, as
        :func:`dodo.http.alpn_dispatch.negotiate_alpn` consumes it.
        """
        var out = List[String]()
        out.append(ALPN_HTTP_2)
        out.append(ALPN_HTTP_1_1)
        return out^

    def route_alpn(self, alpn: String) raises -> Int:
        """Map a negotiated ALPN identifier to a
        :class:`dodo.http.alpn_dispatch.WireProtocol` codepoint.

        Args:
            alpn: The ALPN identifier returned by the TLS
                handshake (empty string == "no ALPN advertised").

        Returns:
            One of :class:`WireProtocol`.

        Raises:
            Error: If the identifier is one dodo doesn't serve.
        """
        return dispatch_alpn(alpn)

    def serve(
        mut self,
        handler: def(Request) raises thin -> Response,
        num_workers: Int = 1,
        pin_cores: Bool = True,
    ) raises:
        """Run the reactor loop, calling ``handler`` per request.

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
          ``EPOLLEXCLUSIVE`` (Linux >= 4.5), which trades
          7-22 % req/s (handler vs static fast path) for a
          uniformly tighter p99.99 σ under sustained load; see
          ``docs/benchmark.md``. The exclusive wakeup goes to one
          waiting worker per event, so connections are not spread
          evenly: a lightly loaded server may keep landing them on the
          same worker (see ``Reactor.register_exclusive``).

        For Router / middleware / stateful-struct handlers, use the
        Handler-typed overload ``serve[H: Handler & Copyable]``.

        Args:
            handler: Called once per parsed request.
            num_workers: Worker count. ``<= 0`` is coerced to 1.
                Values > 256 are rejected (see ``Scheduler.start``).
            pin_cores: On Linux, pin worker N to core ``N % num_cpus``.
                Ignored when ``num_workers == 1``. No-op on macOS.

        Raises:
            NetworkError: On fatal listener errors; per-connection errors
                close the offending connection silently.
            Error: If a worker fails to spawn when
                ``num_workers >= 2``.
        """
        from .handler import FnHandler

        var h = FnHandler(handler)
        if num_workers <= 1:
            self._serve_one(h)
        else:
            self._serve_multicore[FnHandler](h^, num_workers, pin_cores)

    def serve[H: Handler](mut self, var handler: H) raises:
        """Run the single-worker reactor loop with any ``Handler``.

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

        Args:
            handler: The request handler (ownership transferred).

        Raises:
            NetworkError: On fatal listener errors; per-connection
                errors close the offending connection silently.
        """
        self._serve_one(handler)

    def _resolve_max_connections(mut self, workers: Int):
        """Turn ``max_connections == 0`` (automatic) into a per-worker cap
        that keeps the process below its open-file limit."""
        from dodo.net._libc import raise_open_file_limit

        if self.config.max_connections != 0:
            return
        # Listeners, epoll and event fds, files being served, DNS, TLS.
        comptime SPARE_FILES = 128
        var files = raise_open_file_limit()
        var per_worker = (files - SPARE_FILES) // max(workers, 1)
        self.config.max_connections = max(per_worker, 16)

    def _resolve_bufring(mut self):
        """Decide once, at startup, whether the io_uring buffer-ring loop
        serves: when opted into (``DODO_BUFRING_HANDLER=1`` or
        ``use_bufring``) and the config needs nothing that loop lacks."""
        if not self.config.use_bufring:
            self.config.use_bufring = _resolve_bufring_handler_env()
        if not self.config.use_bufring:
            return
        var gap = bufring_gap(self.config)
        if not gap and self._ws_h2_hooks:
            gap = "WebSocket upgrades"
        if gap:
            print(
                "dodo: the io_uring buffer ring does not enforce",
                gap + "; serving with the reactor loop",
                file=stderr,
            )
            self.config.use_bufring = False

    def _serve_one[H: Handler](mut self, ref handler: H) raises:
        """The single-worker reactor: io_uring buffer ring when opted in,
        else the unified h1/h2 loop over every bound listener, with the
        WebSocket-over-h2 sidecar when one is attached."""
        from ._server_reactor_impl import run_uring_bufring_reactor_loop
        from ._unified_reactor_impl import run_unified_reactor_loop
        from dodo.runtime.uring_reactor import use_uring_backend
        from std.sys.info import CompilationTarget

        self._stopping = False
        self._resolve_max_connections(1)
        self._resolve_bufring()
        comptime if CompilationTarget.is_linux():
            if (
                use_uring_backend()
                and self.config.use_bufring
                and len(self._extra_listener_fds) == 0
                and not self._tls_ctx
                and not self._ws_h2_hooks
            ):
                run_uring_bufring_reactor_loop[H](
                    self._listener, self.config, handler, self._stopping
                )
                return
        var hooks = Optional[WsH2Hooks](None)
        if self._ws_h2_hooks:
            hooks = Optional[WsH2Hooks](self._ws_h2_hooks.value().copy())
        try:
            run_unified_reactor_loop(
                self._listener,
                self.config,
                self.config.h2.copy(),
                handler,
                self._stopping,
                hooks,
                self._tls_ctx_addr(),
                self._extra_listener_fds,
            )
        finally:
            self._drop_ws_h2_hooks()

    def _drop_ws_h2_hooks(mut self):
        """Release the boxed WS-over-h2 sidecar, if one was attached.

        Idempotent. Runs in ``serve``'s ``finally`` so the thunk is freed
        whether the reactor returned or raised.
        """
        if self._ws_h2_hooks:
            var h = self._ws_h2_hooks.value().copy()
            h.destroy_thunk(h.addr)
            self._ws_h2_hooks = None

    def _reject_extra_listeners(self, method: String) raises:
        """Raise when :meth:`bind` was given several addresses.

        ``serve_cancellable``, ``serve_view`` and ``serve_static`` run a
        reactor over ``self._listener`` alone; only :meth:`serve` (and
        ``serve_streaming``'s own check) drive the extra listeners. Serving
        just the first address would leave the others bound -- connections
        complete in the kernel backlog -- and never answered, with no error.
        Rejecting is the smaller change than a multi-listener variant of
        each loop, and it is what ``docs/features.md`` promises.
        """
        if len(self._extra_listener_fds) > 0:
            raise Error(
                "HttpServer."
                + method
                + " serves a single listener and cannot serve the extra"
                " addresses given to bind(List[SocketAddr]); bind one"
                " address, or use serve(), which serves every listener"
            )

    def attach_ws_h2[W: WsH2Handler](mut self, var ws_handler: W) raises:
        """Bridge RFC 8441 Extended CONNECT tunnels to ``ws_handler``.

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
            ws_handler: The WS-over-h2 sidecar (ownership transferred).
        """
        from dodo.ws.server_h2 import make_ws_h2_hooks

        if self._ws_h2_hooks:
            raise Error(
                "HttpServer.attach_ws_h2: a sidecar is already attached"
            )
        self.config.h2.enable_connect_protocol = True
        var hooks = make_ws_h2_hooks[W](ws_handler^)
        self._ws_h2_hooks = Optional[WsH2Hooks](hooks.copy())

    def serve_streaming[
        H: StreamHandler
    ](
        mut self,
        var handler: H,
        max_in_flight: Int = 0,
        retry_after_s: Int = 1,
    ) raises:
        """Run the single-threaded streaming reactor loop.

        The typed-streaming counterpart of ``serve``: instead of a
        request/response ``Handler``, it drives a ``StreamHandler``
        through the per-connection lifecycle (``on_open`` /
        ``on_writable`` / ``on_upstream`` / ``on_close``) over the
        reactor, owning the EPOLLOUT-driven outbound drain so the front
        never blocks the event loop. Use this for multiplexing /
        streaming fronts (e.g. a streaming proxy).

        Single-listener, single-worker. Extra ``bind(List[SocketAddr])`` listeners
        and multi-worker mode are not supported here yet.

        Args:
            handler: The streaming front (ownership transferred). One
                instance services every connection.
            max_in_flight: Admission cap; ``0`` (default) = unlimited.
                When the live-connection count is at the cap, a new
                connection is refused with a 503 + ``Retry-After`` instead
                of hanging in the accept backlog.
            retry_after_s: ``Retry-After`` seconds advertised in the 503.

        Raises:
            NetworkError: On fatal listener / reactor errors;
                per-connection errors close the offending connection.
        """
        from ._stream_reactor_impl import run_stream_reactor_loop

        if len(self._extra_listener_fds) > 0:
            raise Error(
                "HttpServer.serve_streaming is single-listener only; bind"
                " with HttpServer.bind(addr), not a list of addresses."
            )
        self._stopping = False
        run_stream_reactor_loop(
            self._listener,
            handler,
            self._stopping,
            max_in_flight=max_in_flight,
            retry_after_s=retry_after_s,
        )

    def serve_streaming[
        H: StreamHandler & Copyable
    ](
        mut self,
        var handler: H,
        num_workers: Int,
        pin_cores: Bool = True,
        max_in_flight: Int = 0,
        retry_after_s: Int = 1,
    ) raises:
        """Multi-worker streaming reactor (N workers over the scheduler).

        The :trait:`StreamHandler` twin of ``serve(handler, num_workers)``:
        each worker runs its own copy of ``handler`` on its own reactor +
        connection table (state is fully per-worker; the ``H: Copyable``
        bound clones the handler once per worker before spawn). Listener
        sharing (per-worker SO_REUSEPORT vs one EPOLLEXCLUSIVE fd) is the
        scheduler's decision via ``DODO_REUSEPORT_WORKERS``.

        ``num_workers <= 1`` falls through to the single-worker loop.
        Single-listener only: extra ``bind(List[SocketAddr])`` listeners are rejected
        (multi-worker uses SO_REUSEPORT, not multi-address).
        """
        if num_workers <= 1:
            self.serve_streaming[H](
                handler^,
                max_in_flight=max_in_flight,
                retry_after_s=retry_after_s,
            )
            return
        if len(self._extra_listener_fds) > 0:
            raise Error(
                "HttpServer.serve_streaming multi-worker is single-listener"
                " only; bind with HttpServer.bind(addr), not a list of"
                " addresses."
            )
        self._serve_streaming_multicore[H](
            handler^, num_workers, pin_cores, max_in_flight, retry_after_s
        )

    def _serve_streaming_multicore[
        H: StreamHandler & Copyable
    ](
        mut self,
        var handler: H,
        num_workers: Int,
        pin_cores: Bool,
        max_in_flight: Int,
        retry_after_s: Int,
    ) raises:
        """Internal: run the multicore streaming path (mirror of
        :meth:`_serve_multicore` with a :class:`StreamFrontend`)."""
        from ..runtime import Scheduler
        from .frontend import StreamFrontend

        var addr = self._listener.local_addr()
        self._listener.close()
        self._stopping = False

        var frontend = StreamFrontend[H](
            handler^,
            max_in_flight=max_in_flight,
            retry_after_s=retry_after_s,
        )
        var scheduler = Scheduler[StreamFrontend[H]].start(
            addr=addr,
            frontend=frontend^,
            num_workers=num_workers,
            pin_cores=pin_cores,
        )
        while not self._stopping and scheduler.is_running():
            _ = libc_nanosleep_ms(50)
        scheduler.shutdown()

    def serve[
        H: Handler & Copyable
    ](
        mut self,
        var handler: H,
        num_workers: Int,
        pin_cores: Bool = True,
    ) raises:
        """Run the multi-worker reactor loop with a ``Copyable Handler``.

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
            handler: The request handler (ownership transferred).
            num_workers: Worker count. ``<= 0`` is coerced to 1.
                Values > 256 are rejected (see ``Scheduler.start``).
            pin_cores: On Linux, pin worker N to core ``N % num_cpus``.
                Ignored when ``num_workers == 1``. No-op on macOS.

        Raises:
            NetworkError: On fatal listener errors; per-connection errors
                close the offending connection silently.
            Error: If a worker fails to spawn when
                ``num_workers >= 2``.
        """
        if num_workers <= 1:
            self._serve_one(handler)
        else:
            self._serve_multicore[H](handler^, num_workers, pin_cores)

    def _serve_multicore[
        H: Handler & Copyable
    ](mut self, var handler: H, num_workers: Int, pin_cores: Bool) raises:
        """Internal: run the multicore (N-worker) path.

        Extracted so both ``serve(def ...)`` and ``serve[H](H ...)``
        dispatch through the same ``Scheduler.start`` call site. Not
        part of the public API; callers should go through ``serve``.
        """
        from ..runtime import Scheduler
        from .frontend import HttpFrontend

        var addr = self._listener.local_addr()
        # N x M: each worker binds its own SO_REUSEPORT listener on
        # every address, so every listener bound by a multi-address bind has to be
        # closed first -- SO_REUSEPORT only composes with other
        # SO_REUSEPORT sockets, and the list-bind originals are plain
        # binds holding the address.
        var extra_addrs = self._extra_local_addrs.copy()
        self._listener.close()
        self._close_extras()

        # Before the config is handed to the worker threads.
        self._resolve_max_connections(num_workers)
        self._resolve_bufring()

        var frontend = HttpFrontend[H](
            handler^,
            self.config.copy(),
            self.config.h2.copy(),
            auto_protocol=True,
            tls_ctx_addr=self._tls_ctx_addr(),
            ws_hooks=self._ws_h2_hooks.copy(),
        )
        var scheduler = Scheduler[HttpFrontend[H]].start(
            addr=addr,
            frontend=frontend^,
            num_workers=num_workers,
            pin_cores=pin_cores,
            extra_addrs=extra_addrs,
        )

        # Block until the caller flips _stopping via close() or until
        # all workers exit (an external close() on each listener via
        # the scheduler's own shutdown path is the normal exit).
        #
        # Routes through ``libc_nanosleep_ms`` (50ms) rather than
        # the inferred-signature ``usleep`` because Mojo mis-passes
        # the c_uint argument and ends up sleeping ~50 seconds
        # instead of 50 ms — the rolled-own FFI in
        # ``dodo.runtime._libc_time`` has explicit Int32 /
        # pointer-to-Int64 signatures.
        while not self._stopping and scheduler.is_running():
            # Coarse wait: the HttpServer loop on the main thread
            # doesn't need to be responsive the way the worker reactor
            # is. Sleep for a short interval, then re-check.
            _ = libc_nanosleep_ms(50)

        scheduler.shutdown()
        self._drop_ws_h2_hooks()

    def serve_cancellable[
        CH: CancelHandler
    ](mut self, var handler: CH,) raises:
        """Run the cancel-aware reactor loop with a ``CancelHandler``.

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

            var r = Router()
            r.get("/", home)
            var stack = Logger(RequestId(r^), prefix="[app]")
            var srv = HttpServer.bind(SocketAddr.localhost(8080))
            srv.serve_cancellable(WithCancel(stack^))

        To run the *same* stack inside a streaming front (one process,
        one logging/auth/routing stack behind both a REST control plane
        and a token-streaming endpoint), call ``stack.serve(req)`` in the
        ``StreamHandler`` and frame the result with
        ``StreamConn.send_response`` (see
        :mod:`dodo.http.streaming_server`).

        Args:
            handler: Cancel-aware request handler (ownership transferred).

        Raises:
            NetworkError: On fatal listener errors.
            Error: If a TLS context is bound, or ``bind`` was given several
                addresses (these loops serve one listener; use ``serve``).
        """
        if self._tls_ctx:
            raise Error(
                "HttpServer.serve_cancellable: TLS is not wired into this loop;"
                " use serve() on a bind_tls server"
            )
        self._reject_extra_listeners("serve_cancellable")
        from ._server_reactor_impl import run_reactor_loop_cancel

        self._stopping = False
        self._resolve_max_connections(1)
        run_reactor_loop_cancel(
            self._listener, self.config, handler, self._stopping
        )

    def serve_view[
        VH: ViewHandler
    ](mut self, var handler: VH,) raises:
        """Run the view-aware reactor loop with a ``ViewHandler``.

        Single-threaded entry point. Per-request the reactor:

        1. Reads bytes into ``ConnHandle.read_buf``.
        2. Parses the request as a ``RequestView`` borrowing into
           ``read_buf`` (no per-header String alloc, no body copy).
        3. Dispatches into ``handler.serve_view(view, cancel)`` —
           ``view.body()`` returns ``Span[UInt8, origin]`` directly.
        4. Serialises the response and resets ``read_buf`` for
           the next pipelined request.

        Use this entry point for handlers that benefit from
        zero-copy reads — multipart upload parsers, large-body
        echos, anything that scans the body without re-encoding
        it. For ``Handler.serve(req: Request)`` plug-in,
        wrap with ``WithViewCancel[H](inner=h)`` (the adapter
        does ``view.into_owned()`` and forwards).

        Args:
            handler: View-aware request handler (ownership
                transferred).

        Raises:
            NetworkError: On fatal listener errors.
            Error: If a TLS context is bound, or ``bind`` was given several
                addresses (these loops serve one listener; use ``serve``).
        """
        if self._tls_ctx:
            raise Error(
                "HttpServer.serve_view: TLS is not wired into this loop; use"
                " serve() on a bind_tls server"
            )
        self._reject_extra_listeners("serve_view")
        from ._server_reactor_impl import run_reactor_loop_view

        self._stopping = False
        self._resolve_max_connections(1)
        run_reactor_loop_view(
            self._listener, self.config, handler, self._stopping
        )

    def serve_static(
        mut self,
        resp: StaticResponse,
        num_workers: Int = 1,
        pin_cores: Bool = True,
    ) raises:
        """Run the reactor loop in static-response mode.

        Every parsed request — regardless of path, method, or body — is
        answered with the pre-encoded ``resp`` bytes. The reactor:

        1. Reads until the end of the headers (``\\r\\n\\r\\n``).
        2. Consumes the declared ``Content-Length`` bytes and discards
           them (no ``Request`` struct, no handler call).
        3. Writes ``resp.keepalive_bytes`` or ``resp.close_bytes`` into
           the write queue in a single ``memcpy``, then returns the
           socket to readable-interest for the next pipelined request.

        Intended for health-check endpoints, TFB plaintext benchmarks,
        and any workload where the response body is genuinely static.
        For heterogeneous routes that happen to share static bodies,
        combine ``serve_static`` under a reverse-proxy router upstream
        of the dodo process.

        Args:
            resp: Pre-encoded static response from
                ``precompute_response(...)``.
            num_workers: Reactor workers. Above 1 the response is served by
                ``num_workers`` threads, each with its own listener.
            pin_cores: Pin worker N to core N % num_cpus (Linux only).

        Raises:
            NetworkError: On fatal listener errors; per-connection
                errors close the offending connection silently.
            Error: If a TLS context is bound, or ``bind`` was given several
                addresses (these loops serve one listener; use ``serve``).
        """
        if self._tls_ctx:
            raise Error(
                "HttpServer.serve_static: TLS is not wired into this loop; use"
                " serve() on a bind_tls server"
            )
        self._reject_extra_listeners("serve_static")
        self._resolve_max_connections(num_workers)
        if num_workers > 1:
            self._serve_static_multicore(resp.copy(), num_workers, pin_cores)
            return
        from ._server_reactor_impl import (
            run_reactor_loop_static,
            run_uring_reactor_loop_static,
        )
        from dodo.runtime.uring_reactor import use_uring_backend
        from std.sys.info import CompilationTarget

        self._stopping = False
        # Route the static-response path through
        # the io_uring reactor when the kernel exposes io_uring AND
        # the contributor hasn't set ``DODO_DISABLE_IO_URING=1`` for
        # an A/B comparison run. The two loops are functional twins:
        # same on_readable_static / on_writable per-conn state
        # machine, same StaticResponse memcpy, same keep-alive
        # framing — only the readiness notifier differs (epoll_wait
        # / kqueue vs IORING_OP_POLL_ADD multishot). See the long
        # comment above ``run_uring_reactor_loop_static`` for the
        # design tradeoffs.
        comptime if CompilationTarget.is_linux():
            if use_uring_backend():
                run_uring_reactor_loop_static(
                    self._listener, self.config, resp, self._stopping
                )
                return
        run_reactor_loop_static(
            self._listener, self.config, resp, self._stopping
        )

    def _serve_static_multicore(
        mut self,
        var resp: StaticResponse,
        num_workers: Int,
        pin_cores: Bool = True,
    ) raises:
        """Multi-worker twin of :meth:`serve_static`.

        Spawns ``num_workers`` workers via
        :class:`dodo.runtime.Scheduler` parameterized over
        :class:`dodo.http.StaticHttpFrontend`, each running
        ``run_reactor_loop_static_shared``. Per-request work in
        each worker collapses to ``recv -> _scan_content_length ->
        unsafe_memcpy(resp.bytes) -> send`` -- no parser, no handler, no
        Response struct allocation, no header lookups, no body
        re-serialisation. This is the fastest path dodo exposes for
        the gate-defining TFB plaintext bench; it scales near-linearly
        across cores because each worker owns its own conns dict +
        write buffers (no cross-thread state).

        The HttpServer's bound listener is closed before spawning;
        the Scheduler then binds its own listener(s) at the
        same address. By default each worker pre-binds its own
        ``SO_REUSEPORT`` listener (highest throughput; matches
        actix_web's listener strategy). Export
        ``DODO_REUSEPORT_WORKERS=0`` before launch to switch
        back to a single shared listener with
        ``EPOLLEXCLUSIVE`` -- trades 7-22 % req/s (handler vs
        static fast path) for a uniformly tighter p99.99 σ
        under sustained load; see ``docs/benchmark.md``.

        Caller is expected to hold the scheduler reference
        returned via ``self._stopping`` indirectly -- in practice,
        callers run this until SIGINT and let the process exit.

        Args:
            resp: Pre-encoded response bytes (copied per worker).
            num_workers: Number of worker threads. ``1..=256``.
            pin_cores: Pin worker N to core ``N % num_cpus``. No-op
                on macOS.

        Raises:
            NetworkError: On fatal listener errors.
            Error: If a worker fails to spawn (rare); partially-
                started workers are best-effort joined before raise.
        """
        from ..runtime import Scheduler
        from ..runtime._libc_time import libc_nanosleep_ms
        from .frontend import StaticHttpFrontend

        var addr = self._listener.local_addr()
        self._listener.close()

        var frontend = StaticHttpFrontend(self.config.copy(), resp^)
        var scheduler = Scheduler[StaticHttpFrontend].start(
            addr=addr,
            frontend=frontend^,
            num_workers=num_workers,
            pin_cores=pin_cores,
        )

        # Block until self._stopping flips. Same 50 ms sleep loop the
        # generic _serve_multicore uses (see the long comment there
        # for why libc_nanosleep_ms beats the inferred-signature
        # usleep).
        while not self._stopping and scheduler.is_running():
            _ = libc_nanosleep_ms(50)

        scheduler.shutdown()

    def local_addr(self) -> SocketAddr:
        """Return the local address the server is bound to."""
        return self._listener.local_addr()

    def close(mut self):
        """Stop accepting new connections and break the reactor loop.

        **Hard stop.** In-flight handlers may be cut mid-write — there
        is no wait. Use ``drain(timeout_ms)`` for a graceful tear-down.

        Idempotent. The loop finishes processing in-flight events before
        returning; a concurrent caller from another thread can use this to
        request graceful shutdown (the reactor's wakeup fd will be notified
        automatically next iteration).
        """
        self._stopping = True
        self._listener.close()

    def drain(mut self, timeout_ms: Int) raises -> ShutdownReport:
        """Graceful shutdown.

        Closes the listening socket so no new connections are accepted,
        keeps the reactor running for ``timeout_ms`` milliseconds so
        in-flight requests and responses can finish, then breaks the
        reactor loop. When the loop stops it flips ``Cancel.SHUTDOWN``
        on whatever is still live and closes it.

        Wires ``ServerConfig.shutdown_timeout_ms`` into a real
        wait-for-drain loop.

        Args:
            timeout_ms: Milliseconds to keep serving in-flight
                connections. ``0`` is a hard stop (equivalent to
                ``close()``). Negative values are clamped to ``0``.

        Returns:
            A ``ShutdownReport``. On this single-threaded path the
            counts are all zero: ``serve()`` owns the serving thread,
            so ``drain`` has no vantage point from which to observe
            per-connection progress. ``Scheduler.drain`` (multi-worker)
            joins its workers and reports measured counts per worker.

        Raises:
            NetworkError: If the listener cannot be closed.

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
        """
        # Close the listener so new accepts fail.
        self._listener.close()

        # Hold the reactor open for the grace window. The wait
        # is bounded by the monotonic clock, with 1 ms sleeps, so a
        # misbehaving sleep can only make it poll more often, never
        # overshoot the deadline by a multiple.
        var wait_ms = timeout_ms
        if wait_ms < 0:
            wait_ms = 0
        # The clock is truncated to whole milliseconds, so a deadline taken
        # mid-millisecond arrives up to 1 ms early; one extra millisecond
        # keeps "at least timeout_ms" true.
        var deadline = monotonic_now_ms() + wait_ms + (1 if wait_ms > 0 else 0)
        while monotonic_now_ms() < deadline:
            _ = libc_nanosleep_ms(1)

        # Signal the reactor loop to stop on its next poll iteration,
        # where it flips Cancel.SHUTDOWN on every live connection before
        # closing it.
        self._stopping = True
        return ShutdownReport(
            drained=0, timed_out=0, in_flight_at_deadline=0, crashed=0
        )


# ── Re-exported helpers (moved to dodo.http._server.*) ───────────────────────
# The request parser, response constructors, and response serializer
# used to trail ``HttpServer`` in this file; they now live in the
# ``dodo.http._server`` sub-package (kept under the size budget so the
# reactor-size lint can guard them). Re-export every symbol here under
# its original name so all existing ``from dodo.http.server import ...``
# call sites across dodo/http, dodo/http2, the reactor, the public
# ``dodo`` surface, the tests and the fuzzers keep resolving.
from ._server.parse import (
    _parse_http_request,
    _parse_http_request_bytes,
    _parse_http_request_bytes_minimal,
)
from ._server.parse_util import (
    _ascii_safe,
    _ascii_strip_slice,
    _ascii_unchecked_string,
    _find_crlfcrlf,
    _is_field_value_char,
    _is_token_char,
    _parse_int_str,
    _read_line_buf,
    _read_line_buf_lenient,
    _scan_content_length,
)
from ._server.responses import (
    _string_to_bytes,
    bad_request,
    forbidden,
    internal_error,
    not_found,
    ok,
    ok_json,
    ok_json_value,
    ok_json_of,
    redirect,
    unauthorized,
)
from ._server.write import (
    _append_int,
    _append_str,
    _ascii_lower,
    _status_reason,
    _write_response,
    _write_response_buffered,
)
