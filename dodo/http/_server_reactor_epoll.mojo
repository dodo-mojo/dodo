"""epoll/kqueue server reactor loops.

The ``Reactor``-backed (epoll on Linux, kqueue on macOS) HTTP/1.1 loops:
the dynamic-handler loop and the cancel-aware loop. The
connection-lifecycle helpers they build on (alloc/free/lookup of a
``ConnHandle``, ``_apply_step``, ``_cleanup_conn``, the accept drainers)
live in ``dodo.http._reactor.lifecycle`` and are re-exported here.
"""

from std.collections import Dict
from std.ffi import c_int
from std.memory import Pointer, alloc

from dodo.http.cancel import Cancel, CancelCell, CancelReason
from dodo.http.handler import Handler, CancelHandler
from dodo.http.server import ServerConfig

# Per-connection state-machine constants, ``StepResult``, ``ConnHandle``,
# the h2c-upgrade detector, and the byte-fast-path / keep-alive helpers
# live in ``dodo.http._reactor`` (split across ``conn_handle``,
# ``keepalive_scan``, and ``write_path`` modules). The sub-package's
# ``__init__`` aggregates them; we re-export every existing public
# symbol here for back-compat with imports across ``dodo.http``,
# ``dodo.http2``, ``dodo.runtime``, ``tests/``, ``fuzz/``.
from ._reactor import (
    STATE_READING,
    STATE_WRITING,
    STATE_CLOSING,
    StepResult,
    ConnHandle,
    _detect_h2c_upgrade_inline,
    _monotonic_ms,
    _is_content_length,
    _is_date,
    _is_connection,
    _connection_is_keepalive,
    _connection_is_close,
    _compact_read_buf_drop_prefix,
    _compute_close_after,
    _wants_close,
)

from dodo.tcp import TcpListener
from dodo.runtime import (
    Reactor,
    Event,
    TimerWheel,
    INTEREST_READ,
    LISTENER_TOKEN,
)
from dodo.runtime.scheduler import (
    load_stop_flag,
    store_worker_stat,
    WORKER_STAT_INFLIGHT,
    WORKER_STAT_STATUS,
    WORKER_STATUS_CLEAN,
    WORKER_STATUS_CRASHED,
)


from dodo.http._offload_pool import (
    offload_outstanding,
    offload_port_open,
    offload_port_open_cancel,
)
from ._reactor.offload_loop import (
    begin_offload_settle_h1,
    close_offload_port,
    deliver_offloads_h1,
    offload_settled_h1,
    offload_timeout_h1,
)
from ._reactor.lifecycle import (
    _poll_timeout_ms,
    _collect_fired_timers,
    _expired_idle_conns,
    _conn_alloc_addr,
    _conn_free_addr,
    _conn_ptr_from_int,
    _apply_step,
    _cleanup_conn,
    _accept_errno_is_retry,
    _arm_accept_timer,
    _accept_loop,
    _accept_loop_fd,
    _adopt_handed_off_h1,
    ListenerGate,
)


def _handler_conn_event[
    H: Handler
](
    fd: Int,
    readable: Bool,
    writable: Bool,
    ref handler: H,
    config: ServerConfig,
    mut conns: Dict[Int, Int],
    mut reactor: Reactor,
    mut wheel: TimerWheel,
    mut timers: Dict[Int, UInt64],
):
    """Drive one connection of the HTTP/1.1 handler loop through a
    readable or writable event, closing it when it is done."""
    var addr = conns.get(fd)
    if not addr:
        return
    var ch_ptr = _conn_ptr_from_int(addr.value())
    var step_done = False
    try:
        var last_step = StepResult()
        if readable:
            last_step = ch_ptr[].on_readable(handler, config)
            step_done = last_step.done
            # Fast path: while the state machine is cycling (readable ->
            # writable on request, writable -> readable on keep-alive),
            # drive the next step inline rather than bouncing through the
            # reactor. Capped at 3 cycles so pipelining can't starve
            # other fds.
            var cycles = 0
            while (not step_done) and cycles < 3:
                cycles += 1
                if (
                    last_step.want_write
                    and len(ch_ptr[].write_buf) > ch_ptr[].write_pos
                ):
                    last_step = ch_ptr[].on_writable(config)
                    step_done = last_step.done
                elif (
                    last_step.want_read
                    and len(ch_ptr[].read_buf) > 0
                    and ch_ptr[].state == STATE_READING
                ):
                    last_step = ch_ptr[].on_readable(handler, config)
                    step_done = last_step.done
                else:
                    break
        elif writable:
            last_step = ch_ptr[].on_writable(config)
            step_done = last_step.done
            # A response just finished flushing; any pipelined request
            # behind it is already in read_buf and will raise no readable
            # event of its own.
            if not step_done and ch_ptr[].has_buffered_request():
                last_step = ch_ptr[].on_readable(handler, config)
                step_done = last_step.done
        if (
            not step_done
            and last_step.want_read
            and ch_ptr[].has_buffered_request()
        ):
            # The cycle cap stopped us with a whole request still
            # buffered: ask for a writable edge, which a level-triggered
            # socket raises at once, so the branch above serves it on the
            # next poll.
            last_step.want_write = True
        if not step_done:
            _apply_step(fd, last_step, reactor, wheel, timers, ch_ptr)
    except:
        step_done = True
    if step_done:
        _cleanup_conn(fd, conns, timers, reactor, wheel)


def _run_handler_loop_impl[
    H: Handler, is_shared: Bool
](
    listener_fd: Int,
    config: ServerConfig,
    ref handler: H,
    ref stopping: Bool,
    stats_addr: Int = 0,
) raises:
    """Shared epoll/kqueue event-loop body for the HTTP/1.1 handler path.

    Drives the multi-worker shared-listener entry point
    (``run_reactor_loop_shared``); that public surface is a thin wrapper
    that fans into this body.

    On Linux >= 4.5 ``register_exclusive`` sets ``EPOLLEXCLUSIVE`` so
    the kernel wakes only one worker per accept event; on macOS the
    flag is unavailable and the call falls back to plain ``register``
    (the wakeup pattern degrades to "wake-all, one-wins" but
    practical behaviour is similar because non-blocking ``accept``
    returns ``EAGAIN`` on the losers).

    A handler that may block gets a port to the offload pool, as on the
    unified loop: an offloaded request parks its connection until the
    pool answers, and a stop waits up to ``shutdown_timeout_ms`` for
    such requests.

    Args:
        listener_fd: Listener fd. The dedicated path obtains it from
            its owned ``TcpListener``; the shared path borrows it
            from the multi-worker scheduler. Either way this body
            never closes the fd.
        config: Per-worker / per-server ``ServerConfig``.
        handler: Per-request callback (borrowed for the lifetime of
            the loop).
        stopping: Heap-allocated stop flag; re-read every iteration
            via a fresh externally-mutated pointer so the optimiser
            cannot LICM-hoist the load. The owning ``Scheduler`` (or
            the dedicated-path caller) flips it on shutdown.
        stats_addr: Address of this worker's stats block, or ``0`` for
            none. Inflight and exit-status counters are published to it.
    """
    var reactor = Reactor()
    var wheel = TimerWheel(now_ms=UInt64(_monotonic_ms()))
    var conns = Dict[Int, Int]()
    var timers = Dict[Int, UInt64]()

    comptime if is_shared:
        reactor.register_exclusive(
            c_int(listener_fd), LISTENER_TOKEN, INTEREST_READ
        )
    else:
        reactor.register(c_int(listener_fd), LISTENER_TOKEN, INTEREST_READ)

    var gate = ListenerGate(exclusive=is_shared)
    gate.add(Int(listener_fd), LISTENER_TOKEN)
    var events = List[Event]()
    var exit_status = WORKER_STATUS_CLEAN
    var stopping_addr = Int(Pointer[Bool, _](to=stopping))
    var offload_port = 0
    if handler.may_block():
        offload_port = offload_port_open(
            handler,
            reactor.wake_fd(),
            config.offload_threads,
            config.offload_queue_depth,
        )
    # Non-zero once the stop flag is seen with offloaded requests out:
    # the loop keeps serving their connections until this deadline.
    var settle_deadline = 0
    while True:
        if settle_deadline == 0 and load_stop_flag(stopping_addr):
            if offload_outstanding(offload_port) == 0:
                break
            settle_deadline = _monotonic_ms() + max(
                config.shutdown_timeout_ms, 0
            )
            begin_offload_settle_h1(
                offload_port, listener_fd, conns, reactor, wheel, timers
            )
        if settle_deadline != 0:
            if offload_settled_h1(conns) or _monotonic_ms() >= settle_deadline:
                break
        store_worker_stat(stats_addr, WORKER_STAT_INFLIGHT, len(conns))
        events.clear()
        try:
            _ = reactor.poll(_poll_timeout_ms(wheel), events)
        except:
            exit_status = WORKER_STATUS_CRASHED
            break

        var now_ms = UInt64(_monotonic_ms())
        var fired_fds = List[Int]()
        var fired_ids = List[UInt64]()
        _collect_fired_timers(now_ms, wheel, timers, fired_fds, fired_ids)

        for i in range(len(events)):
            var evt = events[i]
            if evt.is_wakeup():
                continue
            if evt.token == LISTENER_TOKEN:
                if settle_deadline == 0:
                    _accept_loop_fd(
                        listener_fd,
                        reactor,
                        conns,
                        wheel,
                        timers,
                        config.idle_timeout_ms,
                        config.max_connections,
                        offload_port=offload_port,
                    )
                continue
            _handler_conn_event(
                Int(evt.token),
                evt.is_readable(),
                evt.is_writable(),
                handler,
                config,
                conns,
                reactor,
                wheel,
                timers,
            )

        if offload_outstanding(offload_port) > 0:
            var ready = deliver_offloads_h1(
                offload_port, conns, reactor, wheel, timers
            )
            for i in range(len(ready)):
                # Flush now rather than wait a poll for the writable edge.
                _handler_conn_event(
                    ready[i],
                    False,
                    True,
                    handler,
                    config,
                    conns,
                    reactor,
                    wheel,
                    timers,
                )

        # Deadlines that passed while this poll's events were pending are
        # enforced only now: a connection that had a request waiting was
        # served above and re-armed its timer, so it is spared.
        var expired = _expired_idle_conns(fired_fds, fired_ids, conns, timers)
        for i in range(len(expired)):
            var fd = expired[i]
            if offload_port != 0 and offload_timeout_h1(
                fd, conns, reactor, wheel, timers
            ):
                _handler_conn_event(
                    fd,
                    False,
                    True,
                    handler,
                    config,
                    conns,
                    reactor,
                    wheel,
                    timers,
                )
                continue
            _cleanup_conn(fd, conns, timers, reactor, wheel)
        if settle_deadline == 0:
            gate.sync(reactor, len(conns), config.max_connections)

    store_worker_stat(stats_addr, WORKER_STAT_STATUS, exit_status)

    # Graceful shutdown: close every per-conn fd. The listener fd
    # is owned by the caller in both modes (Scheduler in the shared
    # case; the wrapper's ``mut TcpListener`` in the dedicated case)
    # and is never closed here.
    var leftover = List[Int]()
    for kv in conns.items():
        leftover.append(kv.key)
    for i in range(len(leftover)):
        _cleanup_conn(leftover[i], conns, timers, reactor, wheel)
    close_offload_port(offload_port)


def run_reactor_loop_shared[
    H: Handler
](
    listener_fd: Int,
    config: ServerConfig,
    ref handler: H,
    ref stopping: Bool,
    stats_addr: Int = 0,
) raises:
    """Worker reactor loop sharing a single listener fd across workers.

    Multi-worker entry point. Delegates to :func:`_run_handler_loop_impl`
    with ``is_shared=True`` so the listener registers with
    ``EPOLLEXCLUSIVE`` (Linux >= 4.5; falls back to plain register on
    macOS) and the kernel wakes only one worker per accept event.

    The fairness improvement vs ``bind_reuseport`` is in the
    accept-time distribution: instead of the kernel hashing each new
    4-tuple to one of N listeners (variance: a 256-conn storm can
    land 80+ on one worker, 30 on another), every new accept is
    offered to the worker that's currently waiting in ``epoll_wait``.
    Idle workers absorb spikes; busy workers aren't burdened with
    extra conns.

    Args:
        listener_fd: Listener fd, owned by the ``Scheduler``. Must be
            in non-blocking mode before calling (the ``Scheduler``
            configures this once at bind time). This worker never
            closes ``listener_fd``.
        config: Per-worker copy of ``ServerConfig``.
        handler: Per-worker copy of ``H``.
        stopping: Heap-allocated stop flag mutated by the
            ``Scheduler`` from another thread on shutdown.
        stats_addr: Address of this worker's stats block, or ``0`` for
            none. Inflight and exit-status counters are published to it.
    """
    _run_handler_loop_impl[H, is_shared=True](
        listener_fd, config, handler, stopping, stats_addr
    )


def _cancel_conn_event[
    CH: CancelHandler
](
    fd: Int,
    readable: Bool,
    writable: Bool,
    ref handler: CH,
    config: ServerConfig,
    mut conns: Dict[Int, Int],
    mut reactor: Reactor,
    mut wheel: TimerWheel,
    mut timers: Dict[Int, UInt64],
):
    """Drive one connection of the cancel-aware loop through a readable
    or writable event, closing it when it is done."""
    var addr = conns.get(fd)
    if not addr:
        return
    var ch_ptr = _conn_ptr_from_int(addr.value())
    var step_done = False
    try:
        var last_step = StepResult()
        if readable:
            last_step = ch_ptr[].on_readable_cancel(handler, config)
            step_done = last_step.done
            var cycles = 0
            while (not step_done) and cycles < 3:
                cycles += 1
                if (
                    last_step.want_write
                    and len(ch_ptr[].write_buf) > ch_ptr[].write_pos
                ):
                    last_step = ch_ptr[].on_writable(config)
                    step_done = last_step.done
                elif (
                    last_step.want_read
                    and len(ch_ptr[].read_buf) > 0
                    and ch_ptr[].state == STATE_READING
                ):
                    last_step = ch_ptr[].on_readable_cancel(handler, config)
                    step_done = last_step.done
                else:
                    break
        elif writable:
            last_step = ch_ptr[].on_writable(config)
            step_done = last_step.done
            # A response just finished flushing; any pipelined request
            # behind it is already in read_buf and will raise no readable
            # event of its own.
            if not step_done and ch_ptr[].has_buffered_request():
                last_step = ch_ptr[].on_readable_cancel(handler, config)
                step_done = last_step.done
        if (
            not step_done
            and last_step.want_read
            and ch_ptr[].has_buffered_request()
        ):
            # The cycle cap stopped us with a whole request still
            # buffered: ask for a writable edge, which a level-triggered
            # socket raises at once, so the branch above serves it on the
            # next poll.
            last_step.want_write = True
        if not step_done:
            _apply_step(fd, last_step, reactor, wheel, timers, ch_ptr)
    except:
        step_done = True
    if step_done:
        _cleanup_conn(fd, conns, timers, reactor, wheel)


def run_reactor_loop_cancel[
    CH: CancelHandler
](
    mut listener: TcpListener,
    config: ServerConfig,
    ref handler: CH,
    ref stopping: Bool,
    stats_addr: Int = 0,
) raises:
    """Cancel-aware HTTP/1.1 loop behind ``serve_cancellable``.

    Drives each connection through ``ConnHandle.on_readable_cancel``, so
    the handler receives a ``Cancel`` token bound to the connection's
    per-request ``CancelCell``. The reactor flips that cell on:

    - ``CancelReason.PEER_CLOSED``: peer FIN observed before the
      response was queued.
    - ``CancelReason.TIMEOUT``: an offloaded request outlived
      ``handler_timeout_ms``.
    - ``CancelReason.SHUTDOWN``: the loop is stopping.

    A handler that may block gets a port to the offload pool: a request
    it marks ``blocking`` runs on a pool thread while the connection is
    parked, as on the unified loop. A stop with such requests out keeps
    serving their connections until they are answered or
    ``shutdown_timeout_ms`` passes.

    Args:
        listener: Bound and listening ``TcpListener`` (caller-owned;
            borrowed for accept / fd access).
        config: Server configuration.
        handler: Per-request cancel-aware callback.
        stopping: Checked each iteration; flipping it stops the loop
            and closes in-flight connections.
        stats_addr: Address of this worker's stats block, or ``0`` for
            none. Inflight and exit-status counters are published to it.
    """
    listener._socket.set_nonblocking(True)
    var listener_fd = listener._socket.fd

    var reactor = Reactor()
    var wheel = TimerWheel(now_ms=UInt64(_monotonic_ms()))
    var conns = Dict[Int, Int]()
    var timers = Dict[Int, UInt64]()

    reactor.register(listener_fd, LISTENER_TOKEN, INTEREST_READ)

    var gate = ListenerGate()
    gate.add(Int(listener_fd), LISTENER_TOKEN)
    var events = List[Event]()
    var exit_status = WORKER_STATUS_CLEAN
    var stopping_addr = Int(Pointer[Bool, _](to=stopping))
    var offload_port = 0
    if handler.may_block():
        offload_port = offload_port_open_cancel(
            handler,
            reactor.wake_fd(),
            config.offload_threads,
            config.offload_queue_depth,
        )
    # Non-zero once the stop flag is seen with offloaded requests out:
    # the loop keeps serving their connections until this deadline.
    var settle_deadline = 0
    while True:
        if settle_deadline == 0 and load_stop_flag(stopping_addr):
            if offload_outstanding(offload_port) == 0:
                break
            settle_deadline = _monotonic_ms() + max(
                config.shutdown_timeout_ms, 0
            )
            begin_offload_settle_h1(
                offload_port, Int(listener_fd), conns, reactor, wheel, timers
            )
        if settle_deadline != 0:
            if offload_settled_h1(conns) or _monotonic_ms() >= settle_deadline:
                break
        store_worker_stat(stats_addr, WORKER_STAT_INFLIGHT, len(conns))
        events.clear()
        try:
            _ = reactor.poll(_poll_timeout_ms(wheel), events)
        except:
            exit_status = WORKER_STATUS_CRASHED
            break

        var now_ms = UInt64(_monotonic_ms())
        var fired_fds = List[Int]()
        var fired_ids = List[UInt64]()
        _collect_fired_timers(now_ms, wheel, timers, fired_fds, fired_ids)

        for i in range(len(events)):
            var evt = events[i]
            if evt.is_wakeup():
                continue
            if evt.token == LISTENER_TOKEN:
                if settle_deadline == 0:
                    _accept_loop(
                        listener,
                        reactor,
                        conns,
                        wheel,
                        timers,
                        config.idle_timeout_ms,
                        config.max_connections,
                        offload_port,
                    )
                continue
            _cancel_conn_event(
                Int(evt.token),
                evt.is_readable(),
                evt.is_writable(),
                handler,
                config,
                conns,
                reactor,
                wheel,
                timers,
            )

        if offload_outstanding(offload_port) > 0:
            var ready = deliver_offloads_h1(
                offload_port, conns, reactor, wheel, timers
            )
            for i in range(len(ready)):
                # Flush now rather than wait a poll for the writable edge.
                _cancel_conn_event(
                    ready[i],
                    False,
                    True,
                    handler,
                    config,
                    conns,
                    reactor,
                    wheel,
                    timers,
                )

        # Deadlines that passed while this poll's events were pending are
        # enforced only now: a connection that had a request waiting was
        # served above and re-armed its timer, so it is spared.
        var expired = _expired_idle_conns(fired_fds, fired_ids, conns, timers)
        for i in range(len(expired)):
            var fd = expired[i]
            if offload_port != 0 and offload_timeout_h1(
                fd, conns, reactor, wheel, timers
            ):
                _cancel_conn_event(
                    fd,
                    False,
                    True,
                    handler,
                    config,
                    conns,
                    reactor,
                    wheel,
                    timers,
                )
                continue
            _cleanup_conn(fd, conns, timers, reactor, wheel)
        if settle_deadline == 0:
            gate.sync(reactor, len(conns), config.max_connections)

    store_worker_stat(stats_addr, WORKER_STAT_STATUS, exit_status)

    # Flip every live connection's cell to SHUTDOWN before closing it, so
    # a cancel-aware handler still running on the pool sees the stop.
    var leftover = List[Int]()
    for kv in conns.items():
        leftover.append(kv.key)
    for i in range(len(leftover)):
        var ch_ptr = _conn_ptr_from_int(conns[leftover[i]])
        ch_ptr[].cancel_cell.flip(CancelReason.SHUTDOWN)
        ch_ptr[].offload_abandon(CancelReason.SHUTDOWN)
        _cleanup_conn(leftover[i], conns, timers, reactor, wheel)
    close_offload_port(offload_port)
