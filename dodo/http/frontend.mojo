"""HTTP frontends for the multicore :class:`dodo.runtime.Scheduler`.

A :trait:`dodo.runtime.Frontend` impl is the *only* coupling
point between the runtime's multicore lifecycle and a serving
protocol's accept-and-serve loop. This module ships every HTTP-
flavoured frontend dodo needs:

- :class:`HttpFrontend[H]` — the dynamic-handler frontend. Wraps
  a user :trait:`Handler` plus a :class:`ServerConfig` and an
  optional :class:`dodo.http2.Http2Config`. Selects between the
  HTTP/1.1-only loop, the unified HTTP/1.1 + HTTP/2 preface-peek
  loop, and the io_uring buffer-ring loop based on its config
  flags + the runtime backend probe.
- :class:`StreamFrontend[H]`: the :trait:`StreamHandler` frontend
  behind multi-worker ``serve_streaming``.

The runtime imports nothing from :mod:`dodo.http`; the frontends
here import the reactor entry points and serve as the inversion
boundary. See :mod:`dodo.runtime.frontend` for the
trait contract.
"""

from std.os import getenv
from std.sys.info import CompilationTarget

from dodo.http.handler import Handler
from dodo.http.server import ServerConfig
from dodo.http._server_reactor_impl import (
    run_reactor_loop_shared,
    run_uring_bufring_reactor_loop_shared,
)
from dodo.http._stream_reactor_impl import run_stream_reactor_loop_shared
from dodo.http._unified_reactor_impl import run_unified_reactor_loop_shared
from dodo.http.streaming_server import StreamHandler
from dodo.http2.server import Http2Config
from dodo.runtime.frontend import Frontend
from dodo.runtime.uring_reactor import use_uring_backend
from dodo.ws.server_h2 import WsH2Hooks


struct HttpFrontend[H: Handler & Copyable](Copyable, Frontend):
    """Dynamic-handler HTTP frontend for the multicore scheduler.

    Carries the per-worker HTTP state (handler, request config,
    HTTP/2 settings, auto-protocol toggle) and dispatches into
    one of three reactor entry points per accepted connection:

    1. **io_uring buffer-ring path** (Linux + ``use_bufring``):
       :func:`run_uring_bufring_reactor_loop_shared`. Signalled
       to the scheduler via :meth:`requires_per_worker_listener`
       so each worker gets its own SO_REUSEPORT listener.
    2. **Unified HTTP/1.1 + HTTP/2** (``auto_protocol``):
       :func:`run_unified_reactor_loop_shared`. Per-connection
       preface peek selects the protocol.
    3. **HTTP/1.1 only** (default):
       :func:`run_reactor_loop_shared`. A handler whose
       ``may_block()`` is True always takes path 2, the one loop
       with the offload pool.

    The frontend is :class:`Copyable` so the scheduler can clone
    it once per worker before pthread spawn; expensive shared
    state inside the user handler should be wrapped behind an
    :class:`Pointer` so per-worker copies stay cheap.
    """

    var handler: Self.H
    var config: ServerConfig
    var h2_config: Http2Config
    var auto_protocol: Bool
    var tls_ctx_addr: Int
    """Address of the server's shared ``SSL_CTX``, or 0 for cleartext.

    Carried as an address rather than a value because ``ServerCtx`` is
    move-only and OpenSSL intends ``SSL_CTX*`` to be shared read-only
    across threads (each connection makes its own ``SSL`` via
    ``SSL_new``). Every worker borrows the one the server owns, so
    cloning the frontend per worker stays cheap and there is a single
    context to reload certificates into."""
    var ws_hooks: Optional[WsH2Hooks]
    """The server's WebSocket-over-h2 sidecar; each worker serves a copy
    of it (:meth:`WsH2Hooks.clone`)."""

    def __init__(
        out self,
        var handler: Self.H,
        var config: ServerConfig,
        var h2_config: Http2Config = Http2Config(),
        auto_protocol: Bool = False,
        tls_ctx_addr: Int = 0,
        ws_hooks: Optional[WsH2Hooks] = None,
    ):
        """Build a frontend with the given handler + config combo.

        Args:
            handler: User request handler; cloned per worker.
            config: Server configuration; cloned per worker.
            h2_config: HTTP/2 SETTINGS used by the unified path.
                Ignored when ``auto_protocol`` is ``False``.
            auto_protocol: When ``True``, every accepted
                connection auto-dispatches to the right per-conn
                state machine via the RFC 9113 §3.4 preface peek.
                When ``False`` (default), the worker speaks
                HTTP/1.1 exclusively.
            tls_ctx_addr: Address of the shared server ``SSL_CTX``;
                0 (default) serves cleartext. When set, each accepted
                connection starts as a TLS handshake and its protocol
                is chosen by ALPN.
            ws_hooks: Optional WS-over-h2 sidecar handler (RFC 8441).
                ``None`` disables the WS carrier path.
        """
        self.handler = handler^
        self.config = config^
        self.h2_config = h2_config^
        self.auto_protocol = auto_protocol
        self.tls_ctx_addr = tls_ctx_addr
        self.ws_hooks = ws_hooks.copy()

    def requires_per_worker_listener(self) -> Bool:
        """The io_uring buffer-ring path needs per-worker listeners.

        See the trait docstring for the full rationale: the
        kernel-side accept fan-out happens at multishot accept
        arming time, and a shared listener with EPOLLEXCLUSIVE
        would funnel every accept event through one entry. For
        every other backend the scheduler is free to pick its
        listener strategy from the ``DODO_REUSEPORT_WORKERS``
        env knob (which still applies to the epoll handler /
        unified paths).
        """
        comptime if CompilationTarget.is_linux():
            if (
                use_uring_backend()
                and self.config.use_bufring
                and self.tls_ctx_addr == 0
                and not self.handler.may_block()
            ):
                return True
        return False

    def run_worker(
        mut self,
        listener_fd: Int,
        mut stopping: Bool,
        stats_addr: Int,
        extra_fds: List[Int] = List[Int](),
    ):
        """Pick the reactor entry point and run it until ``stopping`` flips."""
        try:
            comptime if CompilationTarget.is_linux():
                if (
                    use_uring_backend()
                    and self.config.use_bufring
                    and self.tls_ctx_addr == 0
                    and len(extra_fds) == 0
                    and not self.handler.may_block()
                ):
                    # The buffer-ring loop registers exactly one
                    # listener, so it is not eligible once this worker
                    # owns listeners on several addresses; fall through
                    # to the unified loop, which is.
                    run_uring_bufring_reactor_loop_shared[Self.H](
                        listener_fd,
                        self.config,
                        self.handler,
                        stopping,
                        stats_addr,
                    )
                    return
            # Only the unified loop runs offloaded handlers on the pool.
            var unified = self.auto_protocol or self.tls_ctx_addr != 0
            if extra_fds or self.handler.may_block():
                unified = True
            if unified:
                var ws = Optional[WsH2Hooks](None)
                if self.ws_hooks:
                    ws = self.ws_hooks.value().clone()
                try:
                    run_unified_reactor_loop_shared[Self.H](
                        listener_fd,
                        self.config,
                        self.h2_config.copy(),
                        self.handler,
                        stopping,
                        stats_addr,
                        self.tls_ctx_addr,
                        extra_fds,
                        ws,
                    )
                finally:
                    if ws:
                        ws.value().destroy_thunk(ws.value().addr)
            else:
                run_reactor_loop_shared[Self.H](
                    listener_fd,
                    self.config,
                    self.handler,
                    stopping,
                    stats_addr,
                )
        except:
            pass


struct StreamFrontend[H: StreamHandler & Copyable](Copyable, Frontend):
    """Typed-streaming frontend for the multicore scheduler.

    The :trait:`StreamHandler` twin of :class:`HttpFrontend`: carries a
    per-worker streaming handler + admission-control knobs and drives
    :func:`run_stream_reactor_loop_shared` on each worker's listener fd.
    Copied once per worker before pthread spawn (the ``H: Copyable``
    bound); expensive shared state should sit behind an
    :class:`Pointer` so the per-worker copy stays cheap.
    """

    var handler: Self.H
    var max_in_flight: Int
    var retry_after_s: Int

    def __init__(
        out self,
        var handler: Self.H,
        max_in_flight: Int = 0,
        retry_after_s: Int = 1,
    ):
        self.handler = handler^
        self.max_in_flight = max_in_flight
        self.retry_after_s = retry_after_s

    def requires_per_worker_listener(self) -> Bool:
        """Streaming is fine with either listener strategy (honours the
        ``DODO_REUSEPORT_WORKERS`` knob via the scheduler)."""
        return False

    def run_worker(
        mut self,
        listener_fd: Int,
        mut stopping: Bool,
        stats_addr: Int,
        extra_fds: List[Int] = List[Int](),
    ):
        """Drive the shared streaming reactor loop.

        ``extra_fds`` is refused rather than ignored: the streaming
        reactor registers a single listener, so accepting the list
        silently would leave an address the caller bound with nothing
        listening on it. ``HttpServer.serve_streaming`` refuses
        multi-address binds up front for the same reason.
        """
        if extra_fds:
            return
        try:
            run_stream_reactor_loop_shared[Self.H](
                listener_fd,
                self.handler,
                stopping,
                stats_addr=stats_addr,
                max_in_flight=self.max_in_flight,
                retry_after_s=self.retry_after_s,
            )
        except:
            pass
