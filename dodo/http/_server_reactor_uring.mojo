"""io_uring buffer-ring server loop (Linux only).

The handler loop ``run_uring_bufring_reactor_loop`` / ``_shared`` on a
kernel-managed ``IORING_REGISTER_PBUF_RING``, with generation-stamped
conn ids, the setup-flag probe and the submit-send drivers. Each
Linux-only path guards itself with ``comptime if not is_linux(): raise``.
"""

from std.collections import Dict
from std.ffi import c_int
from std.os import getenv
from std.memory import Layout, Pointer, alloc, stack_allocation
from std.sys.info import CompilationTarget

from dodo.http.cancel import CancelReason
from dodo.http.handler import Handler
from dodo.http._offload_pool import (
    offload_cancel_all,
    offload_free,
    offload_job,
    offload_outstanding,
    offload_port_open,
    offload_take_done,
)
from dodo.http.server import ServerConfig
from dodo.net import SocketAddr
from dodo.net._libc import _close
from dodo.tcp import TcpStream, TcpListener
from dodo.runtime import Pool
from dodo.runtime.scheduler import (
    load_stop_flag,
    store_worker_stat,
    WORKER_STAT_INFLIGHT,
    WORKER_STAT_STATUS,
    WORKER_STATUS_CLEAN,
    WORKER_STATUS_CRASHED,
)
from dodo.runtime.uring_reactor import (
    UringReactor,
    _pbuf_ring_add,
    _pbuf_ring_get_tail,
    _pbuf_ring_set_tail,
)
from ._bufring_ledger import RECV_CLOSE, RECV_STAGE, classify_recv
from ._reactor import (
    ConnHandle,
    STATE_PARKED,
    STATE_READING,
    STATE_WRITING,
)
from ._reactor.offload_loop import close_offload_port
from ._server_uring_setup import _probe_bufring_setup_flags

# Shared connection-lifecycle helpers live in ``_server_reactor_epoll``
# (the epoll loops own them); imported here for the io_uring teardown path.
from ._server_reactor_epoll import _conn_free_addr, _conn_ptr_from_int
from dodo.runtime._libc_time import monotonic_now_ms

comptime URING_STOP_POLL_MS: Int = 100
"""Longest an io_uring worker blocks before it re-reads the stop flag (the
rings have no wakeup channel; same cap as the epoll/kqueue loops)."""


def _alloc_conn_from_accepted_fd(fd: Int) raises -> Int:
    """Wrap an already-accepted client fd in a ConnHandle and
    return its address.

    Mirrors ``_conn_alloc_addr`` but takes a raw integer fd
    (the kernel returns the accepted fd directly in the
    ``IORING_OP_ACCEPT`` CQE's ``res`` field; we don't get to
    call ``accept(2)`` ourselves on the io_uring multishot
    accept path).

    Sets ``TCP_NODELAY`` + non-blocking on the fd to match the
    contract of :func:`dodo.tcp.listener.accept_fd`. The peer
    address is left as a loopback placeholder, so ``Request.peer``
    is wrong on this loop (see ``TODO.md``).
    """
    from std.ffi import c_int
    from dodo.net.socket import RawSocket
    from dodo.net._libc import AF_INET, SOCK_STREAM

    var raw = RawSocket(c_int(fd), AF_INET, SOCK_STREAM, True)
    raw.set_tcp_nodelay(True)
    raw.set_nonblocking(True)
    var stream = TcpStream(raw^, SocketAddr.localhost(0))
    return Pool[ConnHandle].alloc_move(ConnHandle(stream^))


# ── io_uring buffer-ring dispatch (handler path) ────────────────────────────
#
# Production handler-path io_uring loop using the kernel-managed buffer
# ring substrate: ``IORING_OP_RECV`` + ``IORING_RECV_MULTISHOT`` +
# ``IOSQE_BUFFER_SELECT`` against a registered buffer group (set up via
# ``IORING_REGISTER_PBUF_RING`` on kernels >= 5.19, or
# ``IORING_OP_PROVIDE_BUFFERS`` on older).
#
# How it works
# ------------
#
# This is the same pattern every Rust io_uring HTTP server (tokio-uring,
# monoio, glommio) uses:
#
#   1. At reactor startup, allocate a per-worker buffer pool of
#      N × 8 KiB and register it as a buffer group via
#      ``register_pbuf_ring(bgid, ring_entries)``. The kernel takes
#      ownership of the buffer ring; we keep the backing allocation
#      alive (free at reactor shutdown).
#   2. On each accept CQE, arm one IORING_OP_RECV +
#      IORING_RECV_MULTISHOT + IOSQE_BUFFER_SELECT SQE with
#      buf_group=bgid. The kernel auto-rotates buffers from the
#      pool for every recv on this fd; one SQE per connection
#      drives an unbounded stream of recv CQEs.
#   3. On each recv CQE, the buffer id is in the CQE's flags
#      high 16 bits (IORING_CQE_F_BUFFER set). We compute the
#      buffer's address as ``pool + bid * BUF_SIZE``, feed the
#      bytes into ConnHandle.on_readable_from_buf[H], and recycle
#      the buffer back into the pool via a shared-memory tail bump
#      (PBUF_RING) or a one-shot PROVIDE_BUFFERS SQE (older
#      kernels).
#   4. On step_done, just free the conn (close fd; kernel cancels
#      any pending recv multishot SQE). No per-conn buffer to free
#      -- the buffer was already returned to the pool in step 3
#      (or will be returned by the kernel on the next CQE).
#
# Why MULTISHOT recv requires the buffer ring: without
# ``IOSQE_BUFFER_SELECT``, IORING_RECV_MULTISHOT either errors out,
# fires once and stops, or unsafely reuses the user's single buffer
# across overlapping CQEs. ``IORING_OP_POLL_ADD``'s multishot mode is
# also unsuitable because its edge-triggered semantics race against
# the recv-EAGAIN drain pattern under back-to-back keep-alive.
#
# This eliminates per-conn buffer pinning AND drops the recv
# syscall per request (the kernel hands us bytes via the buffer
# ring), which is the principal io_uring performance unlock for
# the recv-side.
#
# Send path is synchronous ``on_writable`` using non-blocking
# ``_send``. ``UringReactor.submit_send`` is exposed as substrate
# for callers that want to land kernel-async sends on top of
# this dispatch.


comptime _URING_BR_BUF_SIZE: Int = 8192
comptime _URING_BR_NBUFS: Int = 256
comptime _URING_BR_BGID: UInt16 = 1

# Generation-stamped conn_id encoding -- the fix for the
# 9cf97d0 SIGSEGV under concurrent connections.
#
# When connection A on fd=8 closes, the kernel may have a
# trailing recv CQE in flight (the final-no-more-events CQE
# from the cancelled multishot recv) tagged with conn_id=8.
# If a new connection B is accepted on the *same* fd=8 before
# we see that stale CQE, our naive ``conn_id = fd`` scheme
# routes the stale CQE to B's freshly-armed recv state -- which
# either double-arms recv (kernel SIGSEGV territory) or feeds
# stale buffer-id data into B's parser. Generation-stamped
# conn_ids fix this: each accept bumps a per-worker monotonic
# generation counter, packs ``(gen << 24) | fd`` into the
# 56-bit conn_id space, and stores the conn under that full
# packed id. Stale CQEs from connection A carry the OLD gen
# bits and miss the ``if conn_id not in conns`` lookup --
# they're dropped cleanly, never touching connection B's
# state.
#
# 24-bit fd / 32-bit gen split: fd values fit in 24 bits even
# at the kernel's per-process limit (typically 2^20 on a
# default ulimit); 32-bit generation gives 4 billion connections
# per worker before wrap-around (effectively infinite for any
# bench window).

comptime _URING_BR_FD_BITS: Int = 24
comptime _URING_BR_FD_MASK: UInt64 = (
    UInt64(1) << UInt64(_URING_BR_FD_BITS)
) - UInt64(1)


@always_inline
def _br_pack_conn_id(fd: Int, gen: UInt64) -> UInt64:
    """Pack ``(gen, fd)`` into the 56-bit conn_id slot used by
    the buffer-ring dispatch."""
    return (gen << UInt64(_URING_BR_FD_BITS)) | (UInt64(fd) & _URING_BR_FD_MASK)


@always_inline
def _br_unpack_fd(conn_id: UInt64) -> Int:
    """Extract the fd portion of a packed buffer-ring conn_id."""
    return Int(conn_id & _URING_BR_FD_MASK)


def _alloc_recv_buffer_pool() raises -> Int:
    """Allocate the worker-local recv buffer pool: ``_URING_BR_NBUFS``
    contiguous buffers of ``_URING_BR_BUF_SIZE`` bytes.

    Caller owns the lifetime; the kernel retains pointers via the
    PROVIDE_BUFFERS SQE but the userspace allocation must outlive
    the reactor (released on graceful shutdown via
    ``_free_recv_buffer_pool``).
    """
    var size = _URING_BR_NBUFS * _URING_BR_BUF_SIZE
    var raw = alloc(Layout[UInt8](count=size)).unsafe_leak()
    # Zero-init defensively; kernel will overwrite the prefix of
    # each buffer on every recv, but a stale read of an unused
    # slot (e.g. dump-on-error) shouldn't trip on uninitialised
    # memory.
    for i in range(size):
        raw.unsafe_offset(i).unsafe_write(UInt8(0))
    return Int(raw)


def _free_recv_buffer_pool(addr: Int):
    """Release the pool previously returned by ``_alloc_recv_buffer_pool``."""
    if addr == 0:
        return
    var p = Pointer[UInt8, MutUntrackedOrigin](unsafe_from_address=addr)
    p.unsafe_free()


def _br_return_buf(ring_addr: Int, pool_addr: Int, bid: Int):
    """Give provided buffer ``bid`` back to the ring (shared-memory tail
    bump, PBUF_RING). Call exactly once for every receive completion that
    carries ``IORING_CQE_F_BUFFER``, including ones the loop drops."""
    var cur_tail = _pbuf_ring_get_tail(ring_addr)
    _pbuf_ring_add(
        ring_addr,
        _URING_BR_NBUFS,
        UInt64(pool_addr + bid * _URING_BR_BUF_SIZE),
        UInt32(_URING_BR_BUF_SIZE),
        UInt16(bid),
        0,
        cur_tail,
    )
    _pbuf_ring_set_tail(ring_addr, cur_tail + UInt16(1))


def _cleanup_conn_uring_br(
    conn_id: UInt64,
    mut conns: Dict[UInt64, Int],
    mut ureactor: UringReactor,
):
    """``_cleanup_conn`` for the buffer-ring path.

    Cleanup ordering matters because there's a kernel-level race
    between conn-close and reaccept-on-the-same-fd: if we close
    the fd while the kernel still has an armed multishot recv on
    it, the kernel's implicit cancel of that recv races against
    a potential new accept on the reused fd. Empirically this
    SIGSEGV's our process under sustained conn-churn (sequential
    8 short-lived conns reproduces; sleep(50ms) between conns
    masks it; ASAN's slowdown also masks it).

    The fix: explicitly cancel the multishot recv BEFORE freeing
    the ConnHandle, so the kernel processes the cancel cleanly
    while the fd is still open and the io_uring ring resources
    for that recv are still valid. The cancel CQE arrives a few
    iterations later and is silently dropped (no op tag handler
    for URING_OP_CANCEL); the recv's terminal CQE is dropped via
    the ``conn_id not in conns`` gen-stamp miss.
    """
    if conn_id in conns:
        # Issue the cancel BEFORE freeing the ConnHandle (which
        # closes the fd). cancel_conn uses URING_OP_ASYNC_CANCEL
        # targeting the recv SQE tagged with this conn_id.
        try:
            ureactor.cancel_conn(conn_id)
        except:
            # SQ pressure -- fall back to implicit cancel via fd
            # close. Higher race risk but the only alternative is
            # to drop the cleanup which would leak the conn.
            pass
        try:
            var addr = conns.pop(conn_id)
            _conn_free_addr(addr)
        except:
            pass


def _drive_handler_with_submit_send[
    H: Handler,
](
    fd: Int,
    conn_id: UInt64,
    bytes: Span[UInt8, _],
    config: ServerConfig,
    ref handler: H,
    ch_ptr: Pointer[ConnHandle, MutUntrackedOrigin],
    mut ureactor: UringReactor,
) raises -> Bool:
    """Drive one request via parse → handler → submit_send.

    After ``on_readable_from_buf`` parses the request and queues
    the response in ``write_buf``, this helper submits an
    ``IORING_OP_SEND`` SQE pointing at the write_buf bytes
    (instead of the synchronous ``_send`` syscall used in
    ``_drive_handler_after_buf_recv``). The conn is marked
    ``send_in_flight=True``; subsequent recv CQEs for this conn
    just buffer bytes into read_buf without parsing (the next
    request can't be processed until the kernel releases the
    write_buf via the matching send CQE).

    Returns True iff the conn should be cleaned up (handler
    raised, response framing failed, etc.).
    """
    var step_done: Bool
    try:
        var last_step = ch_ptr[].on_readable_from_buf(bytes, handler, config)
        step_done = last_step.done
        # Pipelined-request inline cycle: drain everything in
        # read_buf BEFORE submitting the send (so we batch
        # multiple responses if the client pipelined). Each
        # cycle iter writes to write_buf; the LAST one's bytes
        # are what we submit_send.
        while not step_done:
            if last_step.want_read and ch_ptr[].has_buffered_request():
                # Only drive again for a *whole* buffered request: a
                # partial one consumes nothing, so looping on it would spin
                # here and starve every other connection.
                #
                # NOTE: we DON'T call on_writable here -- we let
                # write_buf accumulate, then submit_send the
                # whole thing once.
                var empty_buf = stack_allocation[1, UInt8]()
                last_step = ch_ptr[].on_readable_from_buf(
                    Span[UInt8, _](unsafe_ptr=empty_buf, length=0),
                    handler,
                    config,
                )
                step_done = last_step.done
            else:
                break
        # If we're now in STATE_WRITING with bytes to send, fire
        # off the submit_send + mark in-flight. The send CQE will
        # land later; the dispatch handler will reset state +
        # process any deferred read_buf bytes then.
        var sending = (
            ch_ptr[].state == STATE_WRITING or ch_ptr[].state == STATE_PARKED
        )
        if (
            (not step_done)
            and sending
            and len(ch_ptr[].write_buf) > ch_ptr[].write_pos
        ):
            var write_ptr = (
                ch_ptr[]
                .write_buf.unsafe_ptr()
                .unsafe_offset(ch_ptr[].write_pos)
            )
            var write_len = len(ch_ptr[].write_buf) - ch_ptr[].write_pos
            try:
                ureactor.submit_send(fd, write_ptr, write_len, conn_id)
                ch_ptr[].send_in_flight = True
            except:
                # SQ full -- can't kick off the send. Drop the
                # conn rather than leaving the response stranded.
                step_done = True
    except:
        step_done = True
    return step_done


def _on_send_cqe_complete[
    H: Handler,
](
    fd: Int,
    conn_id: UInt64,
    res: Int,
    config: ServerConfig,
    ref handler: H,
    ch_ptr: Pointer[ConnHandle, MutUntrackedOrigin],
    mut ureactor: UringReactor,
) raises -> Bool:
    """Handle a ``URING_OP_SEND`` CQE that sent ``res`` bytes (or failed
    with ``-errno``): send the rest of the response if the kernel took
    only part of it; once all of it is out, clear the send-in-flight
    state and start a new request cycle if bytes are buffered.

    Returns True iff the conn should be cleaned up: the send failed, or
    ``should_close`` was set on the response just sent.
    """
    if res <= 0:
        return True
    ch_ptr[].write_pos += res
    var rest = len(ch_ptr[].write_buf) - ch_ptr[].write_pos
    if rest > 0:
        try:
            ureactor.submit_send(
                fd,
                ch_ptr[]
                .write_buf.unsafe_ptr()
                .unsafe_offset(ch_ptr[].write_pos),
                rest,
                conn_id,
            )
        except:
            return True
        return False
    ch_ptr[].send_in_flight = False
    # Reset the write buffer so the next request's response
    # serializes from a clean state.
    ch_ptr[].write_buf.clear()
    ch_ptr[].write_pos = 0
    if ch_ptr[].state == STATE_PARKED:
        # Earlier pipelined responses are out; the offloaded one is
        # still on the pool.
        return False
    # Was this the close-after-send response? If so, the conn is
    # done.
    if ch_ptr[].should_close:
        return True
    # Transition back to reading; drain any pipelined bytes that
    # arrived while send was in flight.
    ch_ptr[].state = STATE_READING
    if len(ch_ptr[].read_buf) > 0:
        var empty_buf = stack_allocation[1, UInt8]()
        return _drive_handler_with_submit_send[H](
            fd,
            conn_id,
            Span[UInt8, _](unsafe_ptr=empty_buf, length=0),
            config,
            handler,
            ch_ptr,
            ureactor,
        )
    return False


def _drive_handler_after_buf_recv[
    H: Handler,
](
    fd: Int,
    conn_id: UInt64,
    bytes: Span[UInt8, _],
    config: ServerConfig,
    ref handler: H,
    ch_ptr: Pointer[ConnHandle, MutUntrackedOrigin],
    mut ureactor: UringReactor,
) raises -> Bool:
    """Sync-send variant of ``_drive_handler_with_submit_send``: the
    response is written with ``send(2)`` straight away, and whatever the
    socket does not take is handed to a ``submit_send`` whose completion
    (``_on_send_cqe_complete``) finishes it.
    """
    var step_done: Bool
    try:
        var last_step = ch_ptr[].on_readable_from_buf(bytes, handler, config)
        step_done = last_step.done
        while not step_done:
            if (
                last_step.want_write
                and len(ch_ptr[].write_buf) > ch_ptr[].write_pos
            ):
                last_step = ch_ptr[].on_writable(config)
                step_done = last_step.done
                if (not step_done) and last_step.want_write:
                    if ch_ptr[].body_src:
                        # A streamed body needs the reactor loop.
                        step_done = True
                        break
                    ureactor.submit_send(
                        fd,
                        ch_ptr[]
                        .write_buf.unsafe_ptr()
                        .unsafe_offset(ch_ptr[].write_pos),
                        len(ch_ptr[].write_buf) - ch_ptr[].write_pos,
                        conn_id,
                    )
                    ch_ptr[].send_in_flight = True
                    break
            elif last_step.want_read and ch_ptr[].has_buffered_request():
                # Whole pipelined request already in read_buf -- drive the
                # parser without appending more bytes (a partial one would
                # consume nothing and spin this loop). Use stack-
                # allocated empty span (Span over a temp List would
                # be a use-after-free).
                var empty_buf = stack_allocation[1, UInt8]()
                last_step = ch_ptr[].on_readable_from_buf(
                    Span[UInt8, _](unsafe_ptr=empty_buf, length=0),
                    handler,
                    config,
                )
                step_done = last_step.done
            else:
                break
    except:
        step_done = True
    return step_done


# ── Offload pool (ADR-0004) ────────────────────────────────────────────────
#
# This loop has no timer wheel, so it tracks its parked connections itself:
# which connection waits on the pool, and until when (``handler_timeout_ms``).
# The pool wakes the ring through its eventfd.


struct _BrParked(Movable):
    """Connections of the io_uring loop parked on the offload pool."""

    var ids: Dict[Int, UInt64]
    """fd -> conn_id of the connection parked on it."""
    var deadlines: Dict[Int, Int]
    """fd -> monotonic ms its handler deadline runs out (only with
    ``handler_timeout_ms``)."""
    var held: List[Int]
    """Finished jobs whose connection still has a send in the kernel:
    its write buffer can't change until that send completes."""

    def __init__(out self):
        self.ids = Dict[Int, UInt64]()
        self.deadlines = Dict[Int, Int]()
        self.held = List[Int]()

    def note(
        mut self,
        fd: Int,
        conn_id: UInt64,
        ch_ptr: Pointer[ConnHandle, MutUntrackedOrigin],
        config: ServerConfig,
    ):
        """Start tracking ``fd`` if its connection just parked."""
        if ch_ptr[].state != STATE_PARKED:
            return
        var known = self.ids.get(fd)
        if known and known.value() == conn_id:
            return
        self.ids[fd] = conn_id
        if config.handler_timeout_ms > 0:
            self.deadlines[fd] = monotonic_now_ms() + config.handler_timeout_ms
        else:
            _ = self.deadlines.pop(fd, 0)

    def forget(mut self, fd: Int):
        _ = self.ids.pop(fd, UInt64(0))
        _ = self.deadlines.pop(fd, 0)

    def poll_timeout_ms(self) -> Int:
        """How long the ring may block: until the earliest deadline, at
        most ``URING_STOP_POLL_MS``."""
        var wait = URING_STOP_POLL_MS
        var now = monotonic_now_ms()
        for kv in self.deadlines.items():
            var left = kv.value - now
            if left < wait:
                wait = left
        return max(wait, 0)


def _br_drive[
    H: Handler
](
    conn_id: UInt64,
    config: ServerConfig,
    ref handler: H,
    ch_ptr: Pointer[ConnHandle, MutUntrackedOrigin],
    mut ureactor: UringReactor,
    submit_send: Bool,
) raises -> Bool:
    """Run the connection on what it already holds: serve buffered
    requests and send what is queued. True when it is done."""
    var fd = _br_unpack_fd(conn_id)
    var empty_buf = stack_allocation[1, UInt8]()
    var empty_span = Span[UInt8, _](unsafe_ptr=empty_buf, length=0)
    if ch_ptr[].send_in_flight:
        return False
    if submit_send:
        return _drive_handler_with_submit_send[H](
            fd, conn_id, empty_span, config, handler, ch_ptr, ureactor
        )
    return _drive_handler_after_buf_recv[H](
        fd, conn_id, empty_span, config, handler, ch_ptr, ureactor
    )


def _br_deliver_offloads[
    H: Handler
](
    port: Int,
    config: ServerConfig,
    ref handler: H,
    mut conns: Dict[UInt64, Int],
    mut parked: _BrParked,
    mut ureactor: UringReactor,
    submit_send: Bool,
) raises:
    """Hand each finished job back to its connection and send the
    response. A job whose connection stopped waiting is dropped; one
    whose connection is mid-send waits in ``parked.held``."""
    var jobs = parked.held.copy()
    parked.held.clear()
    var fresh = offload_take_done(port)
    for i in range(len(fresh)):
        jobs.append(fresh[i])
    for i in range(len(jobs)):
        var job = jobs[i]
        var fd = offload_job(job)[].fd
        var conn_id = parked.ids.get(fd)
        if not conn_id or conn_id.value() not in conns:
            offload_free(job)
            continue
        var id = conn_id.value()
        var ch_ptr = _conn_ptr_from_int(conns[id])
        if ch_ptr[].send_in_flight:
            parked.held.append(job)
            continue
        var done = False
        try:
            var step = ch_ptr[].offload_done(job)
            if step:
                parked.forget(fd)
                done = _br_drive[H](
                    id, config, handler, ch_ptr, ureactor, submit_send
                )
                parked.note(fd, id, ch_ptr, config)
        except:
            done = True
        offload_free(job)
        if done:
            parked.forget(fd)
            _cleanup_conn_uring_br(id, conns, ureactor)


def _br_expire_offloads[
    H: Handler
](
    config: ServerConfig,
    ref handler: H,
    mut conns: Dict[UInt64, Int],
    mut parked: _BrParked,
    mut ureactor: UringReactor,
    submit_send: Bool,
) raises:
    """Answer 503 on every parked connection whose handler deadline ran
    out, cancelling its job with ``TIMEOUT``. One mid-send is answered
    once its send completes."""
    var now = monotonic_now_ms()
    var expired = List[Int]()
    for kv in parked.deadlines.items():
        if kv.value <= now:
            expired.append(kv.key)
    for i in range(len(expired)):
        var fd = expired[i]
        var conn_id = parked.ids.get(fd)
        if not conn_id or conn_id.value() not in conns:
            parked.forget(fd)
            continue
        var id = conn_id.value()
        var ch_ptr = _conn_ptr_from_int(conns[id])
        if ch_ptr[].state != STATE_PARKED:
            parked.forget(fd)
            continue
        if ch_ptr[].send_in_flight:
            continue
        parked.forget(fd)
        var done = False
        try:
            _ = ch_ptr[].offload_timeout()
            done = _br_drive[H](
                id, config, handler, ch_ptr, ureactor, submit_send
            )
            parked.note(fd, id, ch_ptr, config)
        except:
            done = True
        if done:
            parked.forget(fd)
            _cleanup_conn_uring_br(id, conns, ureactor)


def _br_begin_settle(
    port: Int,
    mut conns: Dict[UInt64, Int],
    mut ureactor: UringReactor,
):
    """Start a graceful stop that waits for offloaded requests: flip
    ``SHUTDOWN`` on every job still out and close every connection with
    nothing parked or being sent. A parked one closes after its
    response. New connections are closed as they arrive."""
    offload_cancel_all(port, CancelReason.SHUTDOWN)
    var ids = List[UInt64]()
    for kv in conns.items():
        ids.append(kv.key)
    for i in range(len(ids)):
        var ch_ptr = _conn_ptr_from_int(conns.get(ids[i]).value())
        if ch_ptr[].state == STATE_PARKED:
            ch_ptr[].offload_close = True
            continue
        if ch_ptr[].send_in_flight:
            ch_ptr[].should_close = True
            continue
        ch_ptr[].cancel_cell.flip(CancelReason.SHUTDOWN)
        _cleanup_conn_uring_br(ids[i], conns, ureactor)


def _br_settled(conns: Dict[UInt64, Int]) -> Bool:
    """No connection is parked or still sending a response."""
    for kv in conns.items():
        var ch_ptr = _conn_ptr_from_int(kv.value)
        if ch_ptr[].state == STATE_PARKED or ch_ptr[].send_in_flight:
            return False
    return True


def run_uring_bufring_reactor_loop[
    H: Handler,
](
    mut listener: TcpListener,
    config: ServerConfig,
    ref handler: H,
    ref stopping: Bool,
) raises:
    """Single-worker io_uring buffer-ring reactor loop.

    Production handler-path io_uring loop. See the module-level
    "io_uring buffer-ring dispatch" comment block above for the
    design rationale and the *Why this finally works* note.
    Linux-only.

    Functionally equivalent to :func:`run_uring_bufring_reactor_loop_shared`
    once the listener fd is extracted -- io_uring's multishot accept
    is already kernel-side fan-out, so there's no
    ``EPOLLEXCLUSIVE``-style register-mode distinction the way the
    epoll/kqueue path needs. This entry sets the listener
    non-blocking, hands off the fd, and delegates to the shared body.
    """
    listener._socket.set_nonblocking(True)
    run_uring_bufring_reactor_loop_shared[H](
        Int(listener._socket.fd), config, handler, stopping
    )


def run_uring_bufring_reactor_loop_shared[
    H: Handler,
](
    listener_fd: Int,
    config: ServerConfig,
    ref handler: H,
    ref stopping: Bool,
    stats_addr: Int = 0,
) raises:
    """Multi-worker io_uring buffer-ring reactor loop.

    Sharing-listener twin of :func:`run_uring_bufring_reactor_loop`.
    Each pthread worker owns its own UringReactor + per-worker
    buffer pool (no cross-worker sharing -- the buffer ring is
    per-ring, and rings are per-worker). Multishot accept on the
    shared listener fd from each worker; kernel hands each new
    connection to exactly one worker. Linux-only.

    A handler that may block gets a port to the offload pool, and the
    ring keeps its wakeup eventfd so the pool can wake it. An offloaded
    request parks its connection; ``handler_timeout_ms`` answers 503
    and a stop waits up to ``shutdown_timeout_ms`` for it.
    """
    comptime if not CompilationTarget.is_linux():
        raise Error(
            "run_uring_bufring_reactor_loop_shared: io_uring path is Linux-only"
        )
    from dodo.runtime.uring_reactor import (
        URING_OP_ACCEPT,
        URING_OP_PROVIDE_BUFFERS,
        URING_OP_RECV,
        URING_OP_SEND,
        UringCompletion,
        UringReactor,
    )
    from dodo.runtime.io_uring_sqe import IORING_CQE_F_BUFFER

    # Same setup-flag probe as the single-worker variant;
    # per-worker rings independently negotiate. Each worker is
    # single-issuer (one pthread owns its ring), so the wakeup eventfd
    # is kept only for the offload pool, the one other thread that
    # needs to wake it.
    var may_block = handler.may_block()
    var ureactor = UringReactor(
        4096,
        setup_flags=_probe_bufring_setup_flags(),
        enable_wakeup=may_block,
    )
    var conns = Dict[UInt64, Int]()
    var next_gen: UInt64 = 1
    var submit_send = getenv("DODO_SUBMIT_SEND") == "1"

    var pool_addr = _alloc_recv_buffer_pool()
    var ring_addr = ureactor.register_pbuf_ring(_URING_BR_BGID, _URING_BR_NBUFS)
    for i in range(_URING_BR_NBUFS):
        _pbuf_ring_add(
            ring_addr,
            _URING_BR_NBUFS,
            UInt64(pool_addr + i * _URING_BR_BUF_SIZE),
            UInt32(_URING_BR_BUF_SIZE),
            UInt16(i),
            i,
            UInt16(0),
        )
    _pbuf_ring_set_tail(ring_addr, UInt16(_URING_BR_NBUFS))

    ureactor.arm_listener_multishot(listener_fd, UInt64(0))

    var offload_port = 0
    if may_block:
        offload_port = offload_port_open(
            handler,
            ureactor.wake_fd(),
            config.offload_threads,
            config.offload_queue_depth,
        )
    var parked = _BrParked()

    var completions = List[UringCompletion]()
    var exit_status = WORKER_STATUS_CLEAN
    var stopping_addr = Int(Pointer[Bool, _](to=stopping))
    # Non-zero once the stop flag is seen with offloaded requests out:
    # the loop keeps serving their connections until this deadline.
    var settle_deadline = 0
    while True:
        if settle_deadline == 0 and load_stop_flag(stopping_addr):
            if offload_outstanding(offload_port) == 0:
                break
            settle_deadline = monotonic_now_ms() + max(
                config.shutdown_timeout_ms, 0
            )
            _br_begin_settle(offload_port, conns, ureactor)
        if settle_deadline != 0:
            if _br_settled(conns) or monotonic_now_ms() >= settle_deadline:
                break
        store_worker_stat(stats_addr, WORKER_STAT_INFLIGHT, len(conns))
        completions.clear()
        try:
            _ = ureactor.poll(1, completions, 64, parked.poll_timeout_ms())
        except:
            exit_status = WORKER_STATUS_CRASHED
            break

        for i in range(len(completions)):
            var comp = completions[i]
            if comp.op == URING_OP_ACCEPT:
                if comp.is_error():
                    continue
                var client_fd = Int(comp.res)
                if settle_deadline != 0:
                    _ = _close(c_int(client_fd))
                    continue
                var conn_addr: Int
                try:
                    conn_addr = _alloc_conn_from_accepted_fd(client_fd)
                except:
                    var c = c_int(client_fd)
                    _ = _close(c)
                    continue
                var conn_id = _br_pack_conn_id(client_fd, next_gen)
                next_gen += 1
                _conn_ptr_from_int(conn_addr)[].offload_port = offload_port
                conns[conn_id] = conn_addr
                try:
                    ureactor.arm_recv_buffer_select(
                        client_fd,
                        _URING_BR_BGID,
                        conn_id,
                        True,
                    )
                except:
                    _cleanup_conn_uring_br(conn_id, conns, ureactor)
                continue

            if comp.op == URING_OP_PROVIDE_BUFFERS:
                continue

            if comp.op == URING_OP_SEND:
                var send_conn_id = comp.conn_id
                if send_conn_id not in conns:
                    continue
                var send_fd = _br_unpack_fd(send_conn_id)
                var send_ch_ptr = _conn_ptr_from_int(conns[send_conn_id])
                var send_done = _on_send_cqe_complete[H](
                    send_fd,
                    send_conn_id,
                    Int(comp.res),
                    config,
                    handler,
                    send_ch_ptr,
                    ureactor,
                )
                if send_done:
                    parked.forget(send_fd)
                    _cleanup_conn_uring_br(send_conn_id, conns, ureactor)
                else:
                    parked.note(send_fd, send_conn_id, send_ch_ptr, config)
                continue

            if comp.op != URING_OP_RECV:
                continue

            var conn_id = comp.conn_id
            var has_buf = (comp.flags & IORING_CQE_F_BUFFER) != UInt32(0)
            var bid = Int(comp.flags >> UInt32(16))
            # A completion carrying IORING_CQE_F_BUFFER has already taken
            # buffer ``bid`` out of the ring, whatever happens to it next.
            # Every path must follow ``decision.return_buf`` or the pool
            # shrinks for good (issue #37; proved in Kernels/BufLedger).
            var decision = classify_recv(conn_id in conns, comp.res, has_buf)
            if decision.action != RECV_STAGE:
                if decision.return_buf:
                    _br_return_buf(ring_addr, pool_addr, bid)
                if decision.action == RECV_CLOSE:
                    if conn_id in conns:
                        parked.forget(_br_unpack_fd(conn_id))
                    _cleanup_conn_uring_br(conn_id, conns, ureactor)
                continue

            var fd = _br_unpack_fd(conn_id)
            var n = Int(comp.res)
            var pool_ptr = Pointer[UInt8, MutUntrackedOrigin](
                unsafe_from_address=pool_addr
            )
            var buf = pool_ptr.unsafe_offset((bid * _URING_BR_BUF_SIZE))
            var ch_ptr = _conn_ptr_from_int(conns[conn_id])

            # Stage the kernel bytes into the conn's ``read_buf``
            # before the handler runs (Span-origin narrowing -- see
            # the matching block in the single-worker variant for
            # the full rationale).
            ch_ptr[].read_buf.extend(Span[UInt8, _](unsafe_ptr=buf, length=n))

            if decision.return_buf:
                _br_return_buf(ring_addr, pool_addr, bid)

            var step_done = False
            var empty_buf = stack_allocation[1, UInt8]()
            var empty_span = Span[UInt8, _](unsafe_ptr=empty_buf, length=0)
            if submit_send:
                if not ch_ptr[].send_in_flight:
                    step_done = _drive_handler_with_submit_send[H](
                        fd,
                        conn_id,
                        empty_span,
                        config,
                        handler,
                        ch_ptr,
                        ureactor,
                    )
            elif not ch_ptr[].send_in_flight:
                step_done = _drive_handler_after_buf_recv[H](
                    fd,
                    conn_id,
                    empty_span,
                    config,
                    handler,
                    ch_ptr,
                    ureactor,
                )

            if not step_done:
                parked.note(fd, conn_id, ch_ptr, config)

            if (not step_done) and (not comp.has_more):
                try:
                    ureactor.arm_recv_buffer_select(
                        fd,
                        _URING_BR_BGID,
                        conn_id,
                        True,
                    )
                except:
                    step_done = True

            if step_done:
                parked.forget(fd)
                _cleanup_conn_uring_br(conn_id, conns, ureactor)

        if offload_port != 0:
            if offload_outstanding(offload_port) > 0 or len(parked.held) > 0:
                _br_deliver_offloads[H](
                    offload_port,
                    config,
                    handler,
                    conns,
                    parked,
                    ureactor,
                    submit_send,
                )
            if len(parked.deadlines) > 0:
                _br_expire_offloads[H](
                    config, handler, conns, parked, ureactor, submit_send
                )

    store_worker_stat(stats_addr, WORKER_STAT_STATUS, exit_status)

    # Worker shutdown: close all per-conn fds + free pool +
    # unregister the kernel ring. Shared listener fd stays open
    # -- Scheduler.shutdown closes it.
    var leftover = List[UInt64]()
    for kv in conns.items():
        leftover.append(kv.key)
    for i in range(len(leftover)):
        _cleanup_conn_uring_br(leftover[i], conns, ureactor)
    for i in range(len(parked.held)):
        offload_free(parked.held[i])
    close_offload_port(offload_port)
    try:
        ureactor.unregister_pbuf_ring(
            _URING_BR_BGID, ring_addr, _URING_BR_NBUFS
        )
    except:
        pass
    _free_recv_buffer_pool(pool_addr)
