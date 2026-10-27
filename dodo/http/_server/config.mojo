"""``dodo.http._server.config`` -- HTTP server configuration carrier.

The :class:`ServerConfig` value type (read/buffer sizing, timeouts,
keep-alive policy, leniency + bufring toggles) plus the startup
``DODO_BUFRING_HANDLER`` env read. Extracted from ``dodo.http.server`` to
keep the reactor module within the file-size budget;
``dodo.http.server`` re-exports every name so existing
``from dodo.http.server import ServerConfig`` call sites keep
resolving unchanged.
"""

from std.os import getenv
from std.collections import Optional

from ..proto.h1_leniency import H1LeniencyConfig
from ..proto.h2_config import Http2Config

# WebSocket upgrade seam. ``WsConnection`` is named here so
# :attr:`WsUpgrade.handler` can carry the per-connection callback.
# No import cycle: ``dodo.ws.server`` reaches into ``dodo.http`` only
# for ``dodo.http.response`` (a leaf) -- never for the server or this
# package.
from ...ws.server import DEFAULT_MAX_OFFLOADED_WS, WsConnection
from ...ws.server_reactor import (
    WsReactorHandler,
    WsReactorHooks,
    make_ws_reactor_hooks,
)

comptime MIN_BODY_RATE_GRACE_MS: Int = 5_000
"""How long a request body may arrive at any speed before
``ServerConfig.min_body_rate`` applies, so a slow start (TCP slow start,
a client that waits for ``100 Continue``) is not punished."""

comptime WsHandlerFn = def(mut WsConnection) raises thin -> None
"""The opt-in WebSocket handler signature. Identical to
``WsServer.serve``'s callback, so a handler written for a standalone
``WsServer`` plugs into ``ServerConfig.ws = WsUpgrade(...)`` unchanged."""


@fieldwise_init
struct WsUpgrade(Copyable, Defaultable):
    """Opt-in WebSocket upgrade handling on the same port as HTTP.

    Set ``handler`` and any request arriving with a valid RFC 6455
    upgrade is routed to it, while everything else goes to the ordinary
    ``Handler``. ``offload`` moves each upgraded socket onto its own
    detached thread, which suits long-lived connections that would
    otherwise hold a reactor slot for their whole lifetime.
    """

    var handler: Optional[WsHandlerFn]
    """The upgrade handler, or ``None`` to serve HTTP only."""

    var offload: Bool
    """Run each upgraded socket on its own detached thread."""

    var max_offloaded: Int
    """Detached threads the process runs at once. An upgrade past it is
    answered 503, so clients cannot open threads without bound."""

    var reactor: Optional[WsReactorHooks]
    """Event-driven handler run on the reactor, set by :meth:`on_reactor`.
    Takes precedence over ``handler``."""

    def __init__(out self):
        """No WebSocket handling."""
        self.handler = None
        self.offload = False
        self.max_offloaded = DEFAULT_MAX_OFFLOADED_WS
        self.reactor = None

    @staticmethod
    def on_reactor[
        W: WsReactorHandler
    ](
        var handler: W,
        max_message: Int = 16 * 1024 * 1024,
        max_outbox: Int = 4 * 1024 * 1024,
        idle_timeout_ms: Int = 60_000,
    ) raises -> WsUpgrade:
        """Handle upgrades with an event-driven ``handler`` on the reactor
        worker: no thread per connection, the RFC 6455 rules enforced for
        the handler, a client that stops reading closed with 1008 once
        ``max_outbox`` bytes wait for it, and a connection idle for
        ``idle_timeout_ms`` dropped.

        Each connection gets its own copy of ``handler``.
        """
        var out = WsUpgrade()
        out.reactor = make_ws_reactor_hooks(
            handler^, max_message, max_outbox, idle_timeout_ms
        )
        return out^

    def __init__(
        out self,
        handler: WsHandlerFn,
        offload: Bool = True,
        max_offloaded: Int = DEFAULT_MAX_OFFLOADED_WS,
    ):
        """Handle WebSocket upgrades with ``handler``.

        Args:
            handler: Called once per upgraded connection.
            offload: Give each socket its own detached thread (the
                default). With ``False`` the handler runs on
                the reactor thread for the socket's whole lifetime, so
                one WebSocket client stalls every other connection on
                that worker.
            max_offloaded: Detached threads the process runs at once;
                an upgrade past it gets 503.
        """
        self.handler = Optional[WsHandlerFn](handler)
        self.offload = offload
        self.max_offloaded = max_offloaded
        self.reactor = None


struct ServerConfig(Copyable):
    """Configuration for the HTTP server.

    Fields:
        read_buffer_size: Socket read chunk size in bytes (default 8192).
        max_header_size: Maximum total bytes for request headers (default 8192).
        max_body_size: Maximum bytes for the request body (default 10MB).
        max_uri_length: Maximum bytes for the request URI (default 8192).
        keep_alive: Enable HTTP/1.1 keep-alive (default True).
        max_keepalive_requests: Max requests per connection before forcing close (default 1000).
        idle_timeout_ms: Max ms a connection may stay idle before the
            reactor closes it (default 500), including a connection
            that has not sent its first byte yet. 0 disables.
        write_timeout_ms: Max ms allowed for a partial write to complete
            (default 5000). 0 disables.
        shutdown_timeout_ms: Max ms graceful shutdown waits for in-flight
            connections to drain before force-closing (default 5000).
        expose_error_messages: When ``True``, 400 / 5xx response bodies
            include the raised ``Error`` message verbatim — useful for
            local development. **Default ``False``** so production
            servers send a fixed status reason and log the message
            (with any user-controlled bytes) to stderr instead of
            echoing it back.
        read_body_timeout_ms: Max ms allowed between headers-end and the
            last body byte (default 30_000). 0 disables. Guards the
            slow-body-upload variant of the slow-client DoS surface.
            Mirrors nginx's ``client_body_timeout``.
        handler_timeout_ms: Max ms an ``Offload`` handler may run
            (default 30_000). When it runs out the client gets 503,
            ``req.cancel`` flips to ``TIMEOUT`` and the late result is
            dropped. 0 disables. Inline handlers run on the worker
            thread and can't be interrupted, so it does not bound them.
            Checked against ``request_timeout_ms`` by
            ``ServerConfig.check``.
        offload_threads: Threads in the process-wide offload pool that
            runs ``Offload`` handlers (default 0: one per CPU core). The
            first server to start the pool sizes it.
        offload_queue_depth: Offloaded requests that may wait for a pool
            thread (default 1024). When the queue is full the client gets
            503 with ``Retry-After: 1`` at once.
        request_timeout_ms: Max ms to read one whole request, head and
            body, from its first byte (default 60_000); the reactor
            answers 408 and closes when it runs out. 0 disables. It
            bounds the peer that trickles bytes just inside
            ``idle_timeout_ms``, which re-arms on every read. It does
            not interrupt a running handler. Must be >=
            ``handler_timeout_ms`` and >= ``read_body_timeout_ms``
            (checked at compile time by ``ServerConfig.check``).
        header_timeout_ms: Max ms to read the request head (request line
            and headers) from its first byte (default 10_000); 408 when
            it runs out. 0 disables. Stops a client that sends its
            headers a byte at a time from holding the connection for
            the whole ``request_timeout_ms``.
        min_body_rate: Minimum average upload speed for a request body,
            in bytes per second (default 240), checked once the body has
            been arriving for ``MIN_BODY_RATE_GRACE_MS``. A slower body
            gets 408. 0 disables. Large uploads on slow links still
            work; a client trickling bytes to hold the connection does
            not.
        use_bufring: Opt into the io_uring buffer-ring single-worker
            reactor (HTTP/1.1-only, single-listener-only) on Linux
            ``>= 6.0``. When ``False`` (default), every entry point
            consults the ``DODO_BUFRING_HANDLER=1`` env var **once
            at startup** and OR-equals the result into this field;
            subsequent dispatch decisions read this field directly.
            That guarantees a runtime flip of the env var mid-flight
            cannot reroute live connections.
        h1_leniency: HTTP/1.1 parser leniency configuration. Strict
            by default (every flag off); each named flag relaxes a
            specific RFC 9112 grammar branch. See
            :class:`dodo.http.proto.H1LeniencyConfig` for the per-
            flag contract. The strict default is the production-safe
            pick; flip individual flags only when a trusted upstream
            cannot avoid the corresponding relaxation.
    """

    var read_buffer_size: Int
    var max_header_size: Int
    var max_body_size: Int
    var max_uri_length: Int
    var keep_alive: Bool
    var max_keepalive_requests: Int
    var idle_timeout_ms: Int
    var write_timeout_ms: Int
    var shutdown_timeout_ms: Int
    var expose_error_messages: Bool
    var read_body_timeout_ms: Int
    var handler_timeout_ms: Int
    var offload_threads: Int
    var offload_queue_depth: Int
    var request_timeout_ms: Int
    var header_timeout_ms: Int
    var min_body_rate: Int
    var skip_header_decode_for_short_requests: Bool
    """When True, the parser skips the per-request ``HeaderMap``
    build for requests whose handler doesn't read headers.
    Header bytes are still scanned (RAW) for ``Content-Length``
    (so body framing stays correct) and for ``Connection: close``
    (so keep-alive policy stays correct), but per-header
    ``String`` allocations + the ``HeaderMap`` itself are elided.
    ``Request.headers`` is an empty ``HeaderMap`` -- handlers
    that read headers will see an empty map and silently break,
    so this opt-in is appropriate ONLY for handlers known to
    ignore headers (TFB plaintext, fixed health-checks,
    low-latency micro-services).

    The fast path also skips header *validation*: field names, field
    values and the request target are not checked, and
    ``h1_leniency`` has no effect. Framing (``Content-Length`` and
    ``Transfer-Encoding``) is still decided strictly. Do not enable
    it behind a proxy that forwards whatever it is sent.

    Default ``False`` -- the standard full-parse behaviour.
    Set ``True`` on production servers whose handler shape
    doesn't depend on headers."""
    var use_bufring: Bool
    """Opt into the io_uring buffer-ring single-worker reactor.

    Defaults to ``False``. ``HttpServer.serve`` and
    ``Scheduler.start`` consult ``DODO_BUFRING_HANDLER=1``
    once at startup and ``or``-equal the result into this
    field; downstream dispatch reads this field directly so
    a mid-flight env-var flip cannot reroute live connections.
    Linux-only, HTTP/1.1-only, single-listener-only -- the
    field is silently ignored on macOS / for HTTP/2 / for
    a multi-address ``HttpServer.bind(List[SocketAddr])``.
    That loop has no offload pool, so a handler whose
    ``may_block()`` is True is served by the reactor loop."""
    var h1_leniency: H1LeniencyConfig
    """HTTP/1.1 parser leniency configuration. Strict by default
    (every flag off); each named flag relaxes a specific RFC 9112
    grammar branch. See :class:`dodo.http.proto.H1LeniencyConfig`
    for the per-flag contract."""
    var max_connections: Int
    """Accept-path admission cap: the maximum number of concurrent
    connections a single reactor worker will hold. When the live count
    reaches the cap the worker stops accepting (new clients wait in the
    listen backlog) and resumes as connections close.

    ``0`` (default) means automatic: at startup the server raises its
    open-file limit to the hard limit and splits it between the
    workers, keeping some files spare. Without a cap below the file
    limit, ``accept`` fails with ``EMFILE`` while the listener stays
    readable, and the worker spins. A negative value means unlimited."""
    var ws: WsUpgrade
    """WebSocket-on-the-same-port configuration. Default: HTTP only."""

    var h2: Http2Config
    """HTTP/2 SETTINGS and per-stream limits, applied when a connection
    negotiates h2 by ALPN or upgrades via h2c."""

    def __init__(
        out self,
        read_buffer_size: Int = 8192,
        max_header_size: Int = 8192,
        max_body_size: Int = 10 * 1024 * 1024,
        max_uri_length: Int = 8192,
        keep_alive: Bool = True,
        max_keepalive_requests: Int = 1000,
        idle_timeout_ms: Int = 500,
        write_timeout_ms: Int = 5000,
        shutdown_timeout_ms: Int = 5000,
        expose_error_messages: Bool = False,
        read_body_timeout_ms: Int = 30_000,
        handler_timeout_ms: Int = 30_000,
        offload_threads: Int = 0,
        offload_queue_depth: Int = 1024,
        request_timeout_ms: Int = 60_000,
        header_timeout_ms: Int = 10_000,
        min_body_rate: Int = 240,
        skip_header_decode_for_short_requests: Bool = False,
        use_bufring: Bool = False,
        var h1_leniency: H1LeniencyConfig = H1LeniencyConfig(),
        max_connections: Int = 0,
        var ws: WsUpgrade = WsUpgrade(),
        var h2: Http2Config = Http2Config(),
    ):
        self.read_buffer_size = read_buffer_size
        self.max_header_size = max_header_size
        self.max_body_size = max_body_size
        self.max_uri_length = max_uri_length
        self.keep_alive = keep_alive
        self.max_keepalive_requests = max_keepalive_requests
        self.idle_timeout_ms = idle_timeout_ms
        self.write_timeout_ms = write_timeout_ms
        self.shutdown_timeout_ms = shutdown_timeout_ms
        self.expose_error_messages = expose_error_messages
        self.read_body_timeout_ms = read_body_timeout_ms
        self.handler_timeout_ms = handler_timeout_ms
        self.offload_threads = offload_threads
        self.offload_queue_depth = offload_queue_depth
        self.request_timeout_ms = request_timeout_ms
        self.header_timeout_ms = header_timeout_ms
        self.min_body_rate = min_body_rate
        self.skip_header_decode_for_short_requests = (
            skip_header_decode_for_short_requests
        )
        self.use_bufring = use_bufring
        self.h1_leniency = h1_leniency^
        self.max_connections = max_connections
        self.ws = ws^
        self.h2 = h2^

    @staticmethod
    def check[cfg: ServerConfig]() -> None:
        """Validate a comptime ``ServerConfig`` at compile time.

        Every invariant is a ``comptime assert``, so a configuration
        that violates one fails the build with the message below rather
        than misbehaving at run time. The deadline ordering is the one
        worth stating out loud: when ``request_timeout_ms`` is enabled it
        must bound both ``handler_timeout_ms`` and
        ``read_body_timeout_ms``, or the handler could keep working past
        the request deadline -- the bug these checks exist to prevent.

        Parameters:
            cfg: The configuration to validate.

        Example:
            ```mojo
            comptime CFG = ServerConfig(max_body_size=1 << 20)
            ServerConfig.check[CFG]()
            ```
        """
        comptime assert (
            cfg.read_buffer_size > 0
        ), "ServerConfig.read_buffer_size must be > 0"
        comptime assert (
            cfg.max_header_size > 0
        ), "ServerConfig.max_header_size must be > 0"
        comptime assert (
            cfg.max_uri_length > 0
        ), "ServerConfig.max_uri_length must be > 0"
        comptime assert (
            cfg.max_body_size >= cfg.max_header_size
        ), "ServerConfig.max_body_size must be >= ServerConfig.max_header_size"
        comptime assert (
            cfg.max_keepalive_requests >= 1
        ), "ServerConfig.max_keepalive_requests must be >= 1"
        comptime assert (
            cfg.idle_timeout_ms >= 0
        ), "ServerConfig.idle_timeout_ms must be >= 0"
        comptime assert (
            cfg.write_timeout_ms >= 0
        ), "ServerConfig.write_timeout_ms must be >= 0"
        comptime assert (
            cfg.read_body_timeout_ms >= 0
        ), "ServerConfig.read_body_timeout_ms must be >= 0 (0 disables)"
        comptime assert (
            cfg.handler_timeout_ms >= 0
        ), "ServerConfig.handler_timeout_ms must be >= 0 (0 disables)"
        comptime assert (
            cfg.offload_threads >= 0
        ), "ServerConfig.offload_threads must be >= 0 (0 = one per CPU core)"
        comptime assert (
            cfg.offload_queue_depth >= 1
        ), "ServerConfig.offload_queue_depth must be >= 1"
        comptime assert (
            cfg.request_timeout_ms >= 0
        ), "ServerConfig.request_timeout_ms must be >= 0 (0 disables)"
        comptime assert (
            cfg.header_timeout_ms >= 0
        ), "ServerConfig.header_timeout_ms must be >= 0 (0 disables)"
        comptime assert (
            cfg.min_body_rate >= 0
        ), "ServerConfig.min_body_rate must be >= 0 (0 disables)"
        # When request_timeout_ms is non-zero (enabled), it must
        # bound the per-handler and per-body deadlines so the
        # outer-most reactor deadline is the last to fire. A
        # request_timeout_ms shorter than handler_timeout_ms would
        # let the handler keep working past the request deadline,
        # which is the bug we're trying to prevent.
        comptime assert (
            cfg.request_timeout_ms == 0
            or cfg.handler_timeout_ms == 0
            or cfg.request_timeout_ms >= cfg.handler_timeout_ms
        ), (
            "ServerConfig.request_timeout_ms must be >="
            " ServerConfig.handler_timeout_ms (or one must be 0 to"
            " disable)"
        )
        comptime assert (
            cfg.request_timeout_ms == 0
            or cfg.read_body_timeout_ms == 0
            or cfg.request_timeout_ms >= cfg.read_body_timeout_ms
        ), (
            "ServerConfig.request_timeout_ms must be >="
            " ServerConfig.read_body_timeout_ms (or one must be 0 to"
            " disable)"
        )


def bufring_gap(cfg: ServerConfig) -> String:
    """What ``cfg`` needs that the io_uring buffer-ring loop does not do,
    or ``""`` when that loop can serve it.

    The loop serves plain HTTP/1.1 and arms no timers and no connection
    cap, so a config that relies on any of them is served by the reactor
    loop instead: running it there would drop the limit silently.
    """
    if cfg.ws.handler or cfg.ws.reactor:
        return "WebSocket upgrades"
    if (
        cfg.idle_timeout_ms > 0
        or cfg.write_timeout_ms > 0
        or cfg.read_body_timeout_ms > 0
        or cfg.request_timeout_ms > 0
        or cfg.header_timeout_ms > 0
        or cfg.min_body_rate > 0
    ):
        return "timeouts"
    if cfg.max_connections > 0:
        return "max_connections"
    return ""


def _resolve_bufring_handler_env() -> Bool:
    """Read ``DODO_BUFRING_HANDLER`` once at startup.

    The env-var read lives at the entry point of every reactor
    loop overload; consumers (the reactor loops, the scheduler
    workers) then read ``ServerConfig.use_bufring`` directly so
    a mid-flight ``setenv`` cannot reroute live connections.
    """
    return getenv("DODO_BUFRING_HANDLER") == "1"
