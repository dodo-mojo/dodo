"""Single-threaded reactor loop for the typed streaming surface.

``run_stream_reactor_loop`` is the multi-connection driver behind
``HttpServer.serve_streaming``. It owns the reactor and the connection
table; it dispatches the four ``StreamHandler`` lifecycle callbacks on
the right edges and owns the outbound drain (EPOLLOUT re-arm) so a
front never blocks the event loop.

Connection state lives in a ``Dict[Int, StreamConn]`` keyed by client
fd, accessed by mutable ``ref`` -- no heap-address-as-``Int`` smuggling
(``StreamConn`` is non-copyable and stays put in the dict). A connection
may also attach one upstream fd (``StreamConn.attach_upstream``); the
reactor registers it for read, routes its readiness through
``up_to_client`` to fire ``on_upstream`` on the owning connection, and
unregisters it on teardown. The reactor token for a connection is its
client fd; an attached upstream fd is its own token; the listener fd is
its own token. A token routes by membership: listener, then
``up_to_client`` (upstream), then ``conns`` (client).

Scope: the outbound streaming path -- accept, ``on_open``,
``on_writable``-driven chunking with backpressure-correct draining, and
upstream pumping via ``on_upstream`` -- plus peer-FIN / error teardown
via ``on_close``. The front owns the upstream fd's lifetime (open in
``on_open``, close in ``on_close``); the reactor only watches it.
Inbound request-body consumption is opt-in via ``StreamConn.enable_inbound``.

Backpressure: a connection's attached upstream fd is read only
while its client relay buffer is below the high watermark. ``_reconcile_after``
calls ``StreamConn.apply_backpressure`` (hi/lo hysteresis) and toggles the
upstream's ``INTEREST_READ`` accordingly, so a slow client throttles the
upstream instead of forcing unbounded token buffering. The buffer is
bounded by the high watermark plus at most one upstream read; a relay
front should also check ``conn.write_buffer_full()`` in its drain loop to
avoid overshooting within a single readable edge.

While a connection is open and not closing, ``INTEREST_WRITE``
stays armed, so a front *without an upstream* that stalls without
producing or closing still busy-spins on level-triggered writable edges.
The upstream-relay shape (the streaming-proxy case) is fully gated by the
pending-fd park + watermark backpressure; the residual spin is the
no-upstream stalled front, expected to produce on every writable edge
until ``request_close``.
"""

from std.collections import Dict
from std.ffi import c_int

from dodo.runtime import Reactor, Event, INTEREST_READ, INTEREST_WRITE
from dodo.runtime.scheduler import load_stop_flag
from dodo.tcp import TcpListener, TcpStream, accept_fd

from .cancel import CancelReason
from .response import Response
from .streaming_server import StreamConn, StreamHandler, _OffloadSlot
from ._offload_pool import (
    offload_cancel,
    offload_cancel_all,
    offload_free,
    offload_job,
    offload_job_response,
    offload_outstanding,
    offload_port_open_bare,
    offload_submit_call,
    offload_take_done,
    unavailable_response,
)
from ._reactor.offload_loop import close_offload_port
from ._server.config import ServerConfig
from dodo.runtime._libc_time import monotonic_now_ms


def _shed_503_bytes(retry_after_s: Int) -> List[UInt8]:
    """Canned ``503 Service Unavailable`` with ``Retry-After`` and
    ``Connection: close`` -- the graceful overload signal sent to a
    connection refused by the admission cap. Fixed/sanitized: no
    request-derived bytes, so it is safe to emit before ``on_open``."""
    var ra = retry_after_s if retry_after_s >= 0 else 0
    var s = String("HTTP/1.1 503 Service Unavailable\r\n")
    s += "Retry-After: " + String(ra) + "\r\n"
    s += "Content-Length: 0\r\n"
    s += "Connection: close\r\n\r\n"
    var bytes = s.as_bytes()
    var out = List[UInt8](capacity=len(bytes))
    for i in range(len(bytes)):
        out.append(bytes[i])
    return out^


@always_inline
def _desired_interest(conn: StreamConn) -> Int:
    """Interest bits for an open connection: always READ (to see peer
    FIN); WRITE while there is pending output or the stream is still
    live (producing). A connection waiting on the offload pool produces
    nothing until the response is back."""
    var interest = INTEREST_READ
    if conn.has_pending_out():
        interest |= INTEREST_WRITE
    elif not conn.is_closing() and not conn.offload_pending():
        interest |= INTEREST_WRITE
    return interest


# ── Offload pool (ADR-0004) ──────────────────────────────────────────────


struct _StreamOffload(Movable):
    """The loop's link to the offload pool. The port opens on the first
    ``StreamConn.offload``, so a front that never offloads starts no
    pool. This loop has no timer wheel, so handler deadlines are kept
    here, per job."""

    var port: Int
    var wake_fd: Int
    var threads: Int
    var depth: Int
    var timeout_ms: Int
    var deadlines: Dict[Int, Int]
    """Job address to its handler deadline, until the job comes back."""

    def __init__(out self, wake_fd: Int, config: ServerConfig):
        self.port = 0
        self.wake_fd = wake_fd
        self.threads = config.offload_threads
        self.depth = config.offload_queue_depth
        self.timeout_ms = config.handler_timeout_ms
        self.deadlines = Dict[Int, Int]()

    def outstanding(self) -> Int:
        return offload_outstanding(self.port)

    def submit[
        H: StreamHandler
    ](mut self, mut handler: H, mut conn: StreamConn, fd: Int) raises:
        """Queue what the last callback passed to ``conn.offload``, then
        hand the front every answer that is ready, oldest first. A full
        queue answers 503 in that request's turn."""
        while True:
            self._queue(conn, fd)
            if not conn._offload_next_ready():
                return
            handler.on_offload_done(conn, conn._offload_take_next())

    def _queue(mut self, mut conn: StreamConn, fd: Int) raises:
        while len(conn._offload_calls) > 0:
            var call = conn._offload_calls.pop(0)
            if self.port == 0:
                self.port = offload_port_open_bare(
                    self.wake_fd, self.threads, self.depth
                )
            var job = offload_submit_call(self.port, call^, fd)
            if job == 0:
                conn._offload_slots.append(
                    _OffloadSlot(unavailable_response())
                )
                continue
            conn._offload_slots.append(_OffloadSlot(job))
            if self.timeout_ms > 0:
                self.deadlines[job] = monotonic_now_ms() + self.timeout_ms

    def poll_timeout_ms(self, cap_ms: Int) -> Int:
        """How long to block: until the earliest handler deadline, at
        most ``cap_ms``."""
        var wait = cap_ms
        var now = monotonic_now_ms()
        for kv in self.deadlines.items():
            var left = kv.value - now
            if left < wait:
                wait = left
        return max(wait, 0)

    def expired(mut self) -> List[Int]:
        """Jobs whose handler deadline ran out; forgotten here."""
        var now = monotonic_now_ms()
        var out = List[Int]()
        for kv in self.deadlines.items():
            if kv.value <= now:
                out.append(kv.key)
        for i in range(len(out)):
            _ = self.deadlines.pop(out[i], 0)
        return out^


def _give_offload_response[
    H: StreamHandler
](
    mut conns: Dict[Int, StreamConn],
    fd: Int,
    job: Int,
    var resp: Response,
    mut handler: H,
    mut off: _StreamOffload,
) raises -> Bool:
    """Record ``resp`` as the answer to ``job``, hand the front what is
    ready and send what it queued. True when the connection is done and
    can be dropped."""
    ref c = conns[fd]
    c._offload_answer(job, resp^)
    off.submit(handler, c, fd)
    _ = c.drain_nonblocking()
    return c.is_closing() and not c.has_pending_out()


def _waits_on(conns: Dict[Int, StreamConn], fd: Int, job: Int) -> Bool:
    """Whether the connection on ``fd`` still waits for ``job``. False
    when the connection is gone or the fd now belongs to another one."""
    if fd not in conns:
        return False
    try:
        return conns[fd]._offload_waits_on(job)
    except:
        return False


def _answer_offload[
    H: StreamHandler
](
    mut reactor: Reactor,
    mut conns: Dict[Int, StreamConn],
    mut interests: Dict[Int, Int],
    mut up_to_client: Dict[Int, Int],
    fd: Int,
    job: Int,
    var resp: Response,
    mut handler: H,
    mut off: _StreamOffload,
):
    """Give the front the response to its offloaded request, then send
    what it queued and close the connection if it is done."""
    var drop_it = False
    try:
        drop_it = _give_offload_response(conns, fd, job, resp^, handler, off)
    except:
        drop_it = True
    if drop_it:
        _close_conn(reactor, conns, interests, up_to_client, fd, handler)
        return
    try:
        _reconcile_after(reactor, conns, interests, up_to_client, fd)
    except:
        pass


def _deliver_offloads[
    H: StreamHandler
](
    mut reactor: Reactor,
    mut conns: Dict[Int, StreamConn],
    mut interests: Dict[Int, Int],
    mut up_to_client: Dict[Int, Int],
    mut handler: H,
    mut off: _StreamOffload,
):
    """Hand each finished job's response to its connection. A job whose
    connection stopped waiting (timeout, client gone) is dropped."""
    var jobs = offload_take_done(off.port)
    for i in range(len(jobs)):
        var job = jobs[i]
        var fd = offload_job(job)[].fd
        _ = off.deadlines.pop(job, 0)
        if _waits_on(conns, fd, job):
            _answer_offload(
                reactor,
                conns,
                interests,
                up_to_client,
                fd,
                job,
                offload_job_response(job),
                handler,
                off,
            )
        offload_free(job)


def _expire_offloads[
    H: StreamHandler
](
    mut reactor: Reactor,
    mut conns: Dict[Int, StreamConn],
    mut interests: Dict[Int, Int],
    mut up_to_client: Dict[Int, Int],
    mut handler: H,
    mut off: _StreamOffload,
):
    """``handler_timeout_ms`` ran out: cancel the job with ``TIMEOUT``
    and answer 503."""
    var jobs = off.expired()
    for i in range(len(jobs)):
        var job = jobs[i]
        # The job stays alive until the pool hands it back, so its fd
        # can still be read.
        var fd = offload_job(job)[].fd
        if not _waits_on(conns, fd, job):
            continue
        offload_cancel(job, CancelReason.TIMEOUT)
        _answer_offload(
            reactor,
            conns,
            interests,
            up_to_client,
            fd,
            job,
            unavailable_response(),
            handler,
            off,
        )


def _client_fds(interests: Dict[Int, Int]) -> List[Int]:
    """Every open client fd. ``interests`` has the same keys as
    ``conns``, which can't be walked because ``StreamConn`` is not
    ``Copyable``."""
    var fds = List[Int]()
    for fd in interests.keys():
        fds.append(fd)
    return fds^


def _offload_settled(
    conns: Dict[Int, StreamConn], interests: Dict[Int, Int]
) raises -> Bool:
    """No connection waits on the pool or still has a response going
    out."""
    for fd in _client_fds(interests):
        ref c = conns[fd]
        if c.offload_pending() or c.has_pending_out():
            return False
    return True


def _close_conn[
    H: StreamHandler
](
    mut reactor: Reactor,
    mut conns: Dict[Int, StreamConn],
    mut interests: Dict[Int, Int],
    mut up_to_client: Dict[Int, Int],
    fd: Int,
    mut handler: H,
):
    """Tear one connection down: unregister the client fd (and any
    attached upstream fd), fire ``on_close``, drop (which closes the
    client socket). Never raises -- teardown is best-effort.
    """
    if fd not in conns:
        return
    try:
        var conn = conns.pop(fd)
        if fd in interests:
            _ = interests.pop(fd)
        var ufd = conn.reg_upstream_fd()
        if ufd != -1:
            try:
                reactor.unregister(c_int(ufd))
            except:
                pass
            if ufd in up_to_client:
                _ = up_to_client.pop(ufd)
        try:
            reactor.unregister(c_int(fd))
        except:
            pass
        # If the connection was cancelled (peer FIN / deadline / drain)
        # and owns its upstream source, tell the backend to stop
        # producing before we drop it. No-op for a front managing its
        # own raw-fd upstream.
        conn._maybe_cancel_upstream()
        # Requests still on the offload pool have no one to answer.
        conn._offload_cancel_all(CancelReason.PEER_CLOSED)
        try:
            handler.on_close(conn)
        except:
            pass
        # ``conn`` drops here -> client socket closed (and the
        # framework-owned upstream source, if any). A raw-fd upstream is
        # the front's to close (it owns the upstream stream).
    except:
        pass


def _reconcile_after(
    mut reactor: Reactor,
    mut conns: Dict[Int, StreamConn],
    mut interests: Dict[Int, Int],
    mut up_to_client: Dict[Int, Int],
    fd: Int,
) raises:
    """After a lifecycle callback, reconcile the connection's upstream
    registration (the front may have called ``attach_upstream`` /
    ``detach_upstream``) and re-arm its client write interest.

    Diffs desired (``upstream_fd``) against registered
    (``reg_upstream_fd``) so a no-op call costs only two lookups.
    """
    ref c = conns[fd]
    # Upstream reconcile (fd attach/detach) + backpressure gating: the
    # upstream read interest is armed only while the client relay buffer
    # is below the high watermark, so a slow client throttles the upstream
    # instead of forcing unbounded token buffering.
    var want = c.upstream_fd()
    var have = c.reg_upstream_fd()
    if want != have:
        if have != -1:
            try:
                reactor.unregister(c_int(have))
            except:
                pass
            if have in up_to_client:
                _ = up_to_client.pop(have)
        if want != -1:
            var up_int = INTEREST_READ if c.apply_backpressure() else 0
            try:
                reactor.register(c_int(want), UInt64(want), up_int)
                up_to_client[want] = fd
            except:
                pass
            c._set_reg_upstream_interest(up_int)
        else:
            c._set_reg_upstream_interest(-1)
        c._set_reg_upstream_fd(want)
    elif want != -1:
        # Same upstream fd: toggle its read interest across watermarks.
        var up_int = INTEREST_READ if c.apply_backpressure() else 0
        if up_int != c.reg_upstream_interest():
            try:
                reactor.modify(c_int(want), up_int)
                c._set_reg_upstream_interest(up_int)
            except:
                pass
    # Client write-interest reconcile.
    var desired = _desired_interest(c)
    if interests[fd] != desired:
        try:
            reactor.modify(c_int(fd), desired)
            interests[fd] = desired
        except:
            pass


def run_stream_reactor_loop[
    H: StreamHandler
](
    mut listener: TcpListener,
    mut handler: H,
    ref stopping: Bool,
    poll_timeout_ms: Int = 100,
    max_in_flight: Int = 0,
    retry_after_s: Int = 1,
    config: ServerConfig = ServerConfig(),
) raises:
    """Run the streaming reactor loop until ``stopping`` flips.

    Args:
        listener: Bound, listening ``TcpListener``. Borrowed for accept;
            the caller retains ownership.
        handler: The streaming front (typed shared state). One instance
            services every connection via ``mut self``.
        stopping: External stop flag, checked each iteration.
        poll_timeout_ms: Reactor poll timeout; bounds how often
            ``stopping`` is re-checked when idle.
        max_in_flight: Admission cap. ``0`` = unlimited. When the
            live-connection count is at the cap, a newly accepted
            connection is refused with a canned 503 + ``Retry-After``
            (``on_open`` is never called for it) instead of leaning on the
            accept backlog -- a deliberate overload policy with a graceful
            client signal. Unlike the synchronous request/response path
            (where ``serve`` runs one at a time so in-flight is always 1),
            the streaming reactor holds many connections concurrently, so
            this cap is meaningful and enforced at the accept edge.
        retry_after_s: ``Retry-After`` seconds advertised in the 503.
        config: Offload pool settings for ``StreamConn.offload``:
            ``offload_threads``, ``offload_queue_depth``,
            ``handler_timeout_ms`` and ``shutdown_timeout_ms`` (how long
            a stop waits for offloaded requests).
    """
    listener._socket.set_nonblocking(True)
    _run_stream_loop_impl[H, is_shared=False](
        Int(listener._socket.fd),
        handler,
        stopping,
        poll_timeout_ms,
        max_in_flight,
        retry_after_s,
        config,
    )


def run_stream_reactor_loop_shared[
    H: StreamHandler
](
    listener_fd: Int,
    mut handler: H,
    ref stopping: Bool,
    stats_addr: Int = 0,
    poll_timeout_ms: Int = 100,
    max_in_flight: Int = 0,
    retry_after_s: Int = 1,
    config: ServerConfig = ServerConfig(),
) raises:
    """Multi-worker streaming reactor loop sharing a borrowed listener fd.

    The scheduler-driven twin of :func:`run_stream_reactor_loop`: each
    worker calls this with the same (or a per-worker SO_REUSEPORT)
    ``listener_fd`` and its own ``handler`` copy + heap ``stopping``
    flag, mirroring :func:`run_reactor_loop_shared` on the Handler path.
    The listener is registered with ``EPOLLEXCLUSIVE`` so a shared fd
    wakes one worker per accept event; per-worker SO_REUSEPORT fds also
    work (the exclusive flag is a harmless no-op there).

    ``stats_addr`` is accepted for :trait:`dodo.runtime.Frontend`
    signature parity; the streaming loop does not publish per-worker
    stats yet (documented ceiling).
    """
    _run_stream_loop_impl[H, is_shared=True](
        listener_fd,
        handler,
        stopping,
        poll_timeout_ms,
        max_in_flight,
        retry_after_s,
        config,
    )


def _run_stream_loop_impl[
    H: StreamHandler, *, is_shared: Bool
](
    listen_fd: Int,
    mut handler: H,
    ref stopping: Bool,
    poll_timeout_ms: Int,
    max_in_flight: Int,
    retry_after_s: Int,
    config: ServerConfig,
) raises:
    """Shared body for the streaming reactor loop (single- and
    multi-worker). ``is_shared`` picks ``register_exclusive`` (shared
    listener) vs plain ``register`` for the listener fd.

    A stop with offloaded requests out stops accepting, closes every
    other connection and keeps serving those until they are answered or
    ``shutdown_timeout_ms`` passes."""
    var reactor = Reactor()

    comptime if is_shared:
        reactor.register_exclusive(
            c_int(listen_fd), UInt64(listen_fd), INTEREST_READ
        )
    else:
        reactor.register(c_int(listen_fd), UInt64(listen_fd), INTEREST_READ)

    var conns = Dict[Int, StreamConn]()
    var interests = Dict[Int, Int]()
    # Maps an attached upstream fd -> its owning client fd, so an
    # upstream readiness event routes to the right connection.
    var up_to_client = Dict[Int, Int]()
    var next_id = 1
    var events = List[Event]()
    var off = _StreamOffload(reactor.wake_fd(), config)
    # Non-zero once the stop flag is seen with offloaded requests out:
    # the loop keeps serving their connections until this deadline.
    var settle_deadline = 0
    # Another thread sets the flag, so it is read atomically: a plain
    # read may be hoisted out of the loop.
    var stopping_addr = Int(Pointer[Bool, _](to=stopping))

    while True:
        if settle_deadline == 0 and load_stop_flag(stopping_addr):
            if off.outstanding() == 0:
                break
            settle_deadline = monotonic_now_ms() + max(
                config.shutdown_timeout_ms, 0
            )
            try:
                reactor.unregister(c_int(listen_fd))
            except:
                pass
            offload_cancel_all(off.port, CancelReason.SHUTDOWN)
            var idle = List[Int]()
            for fd in _client_fds(interests):
                if not conns[fd].offload_pending():
                    idle.append(fd)
            for i in range(len(idle)):
                conns[idle[i]].flip_cancel(CancelReason.SHUTDOWN)
                _close_conn(
                    reactor, conns, interests, up_to_client, idle[i], handler
                )
        if settle_deadline != 0:
            if (
                _offload_settled(conns, interests)
                or monotonic_now_ms() >= settle_deadline
            ):
                break
        var n = reactor.poll(off.poll_timeout_ms(poll_timeout_ms), events)
        for i in range(n):
            var ev = events[i]
            if ev.is_wakeup():
                continue
            var tok = Int(ev.token)

            # ── Listener: drain the accept queue ───────────────────
            if tok == listen_fd:
                while True:
                    var client: TcpStream
                    try:
                        client = accept_fd(c_int(listen_fd))
                    except:
                        break  # EAGAIN / no more pending this round
                    # Admission cap: refuse over-capacity connections
                    # with a 503 + Retry-After on the still-blocking socket
                    # before any on_open work, then drop (close). Counted
                    # for observability.
                    if max_in_flight > 0 and len(conns) >= max_in_flight:
                        try:
                            client.write_all(
                                Span[UInt8, _](_shed_503_bytes(retry_after_s))
                            )
                        except:
                            pass
                        continue  # client drops here -> socket closed
                    try:
                        client._socket.set_nonblocking(True)
                    except:
                        pass
                    var cfd = Int(client._socket.fd)
                    var id = next_id
                    next_id += 1
                    var conn = StreamConn(client^, id)
                    var open_ok = True
                    try:
                        handler.on_open(conn)
                        off.submit(handler, conn, cfd)
                        _ = conn.drain_nonblocking()
                    except:
                        open_ok = False
                    if not open_ok or (
                        conn.is_closing() and not conn.has_pending_out()
                    ):
                        try:
                            handler.on_close(conn)
                        except:
                            pass
                        continue  # conn drops -> socket closed
                    var interest = _desired_interest(conn)
                    try:
                        reactor.register(c_int(cfd), UInt64(cfd), interest)
                    except:
                        try:
                            handler.on_close(conn)
                        except:
                            pass
                        continue
                    interests[cfd] = interest
                    conns[cfd] = conn^
                    # Pick up any upstream the front attached in on_open.
                    _reconcile_after(
                        reactor, conns, interests, up_to_client, cfd
                    )
                continue

            # ── Upstream readiness: pump via on_upstream ───────────
            if tok in up_to_client:
                var client_fd = up_to_client[tok]
                if client_fd not in conns:
                    try:
                        reactor.unregister(c_int(tok))
                    except:
                        pass
                    _ = up_to_client.pop(tok)
                    continue
                var up_drop = False
                ref uc = conns[client_fd]
                try:
                    handler.on_upstream(uc)
                    off.submit(handler, uc, client_fd)
                    _ = uc.drain_nonblocking()
                except:
                    up_drop = True
                if not up_drop:
                    if (
                        conns[client_fd].is_closing()
                        and not conns[client_fd].has_pending_out()
                    ):
                        up_drop = True
                if up_drop:
                    _close_conn(
                        reactor,
                        conns,
                        interests,
                        up_to_client,
                        client_fd,
                        handler,
                    )
                else:
                    _reconcile_after(
                        reactor, conns, interests, up_to_client, client_fd
                    )
                continue

            if tok not in conns:
                continue

            # ── Peer error / hangup: tear down ─────────────────────
            # For an inbound-owning front a peer *half-close*
            # (EPOLLRDHUP, which folds into EVENT_HUP) is the normal
            # end-of-body signal, not a teardown: fall through so the
            # handler reads ``read_body`` -> eof and replies on the still-
            # open write side. A genuine full hangup then makes the
            # writable drain raise, which closes the connection below.
            if ev.is_error() or ev.is_hup():
                if not conns[tok].inbound_enabled():
                    conns[tok].flip_cancel(CancelReason.PEER_CLOSED)
                    _close_conn(
                        reactor, conns, interests, up_to_client, tok, handler
                    )
                    continue

            var drop_it = False

            # ── Readable: detect peer FIN, or hand inbound body to the
            # front. When the front owns the inbound body
            # (``enable_inbound``), the reactor must NOT drain-and-discard
            # client bytes here -- that would steal the body. The front
            # reads it via ``read_body`` (and learns EOF there); the
            # reactor still tears down on a hard error / hangup above.
            if ev.is_readable() and not conns[tok].inbound_enabled():
                var got: Int
                ref c = conns[tok]
                try:
                    var scratch = List[UInt8]()
                    got = c.recv(scratch, 4096)
                except:
                    got = 0
                if got == 0:
                    conns[tok].flip_cancel(CancelReason.PEER_CLOSED)
                    drop_it = True

            # ── Writable: pump next chunk, drain, decide teardown ──
            if not drop_it and ev.is_writable():
                ref c = conns[tok]
                try:
                    # A connection waiting on the pool only sends what it
                    # already queued.
                    if not c.offload_pending():
                        handler.on_writable(c)
                        off.submit(handler, c, tok)
                    _ = c.drain_nonblocking()
                except:
                    drop_it = True
                if not drop_it:
                    if (
                        conns[tok].is_closing()
                        and not conns[tok].has_pending_out()
                    ):
                        drop_it = True

            if drop_it:
                _close_conn(
                    reactor, conns, interests, up_to_client, tok, handler
                )
                continue

            # Reconcile upstream registration + re-arm write interest.
            _reconcile_after(reactor, conns, interests, up_to_client, tok)

        if off.outstanding() > 0:
            _deliver_offloads(
                reactor, conns, interests, up_to_client, handler, off
            )
        if len(off.deadlines) > 0:
            _expire_offloads(
                reactor, conns, interests, up_to_client, handler, off
            )

    # Drain remaining connections on shutdown. ``conns`` keys are the
    # client fds; the upstream entries in ``up_to_client`` are cleaned up
    # by ``_close_conn`` as each owning connection is torn down.
    for fd_key in _client_fds(interests):
        _close_conn(reactor, conns, interests, up_to_client, fd_key, handler)
    close_offload_port(off.port)
