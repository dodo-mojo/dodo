"""Offload pool glue for the HTTP/1.1-only epoll/kqueue loops (ADR-0004).

The cancel-aware loop (``serve_cancellable``) keeps plain
``ConnHandle`` addresses in its connection table, so it uses these
helpers instead of the unified loop's tagged ones: hand finished jobs
back to their connections, answer a handler deadline, start and check a
graceful stop, and close the worker's port.
"""

from std.collections import Dict, List
from std.ffi import c_int

from dodo.http.cancel import CancelReason
from dodo.http._offload_pool import (
    offload_cancel_all,
    offload_free,
    offload_job,
    offload_outstanding,
    offload_port_borrows_handler,
    offload_port_close,
    offload_take_done,
)
from dodo.runtime import Event, Reactor, TimerWheel

from .keepalive_scan import STATE_PARKED, STATE_WRITING
from .lifecycle import _apply_step, _cleanup_conn, _conn_ptr_from_int


def deliver_offloads_h1(
    port: Int,
    mut conns: Dict[Int, Int],
    mut reactor: Reactor,
    mut wheel: TimerWheel,
    mut timers: Dict[Int, UInt64],
) raises -> List[Int]:
    """Hand each finished job back to its connection and queue the
    response. A job whose connection stopped waiting (timeout, client
    gone, fd reused) is dropped. Every job is freed.

    Returns the connections that now have a response to send; the
    caller runs a writable step on each so it goes out without waiting
    a poll for the writable edge.
    """
    var ready = List[Int]()
    var jobs = offload_take_done(port)
    for i in range(len(jobs)):
        var job = jobs[i]
        var fd = offload_job(job)[].fd
        var finished = False
        if fd in conns:
            var ch = _conn_ptr_from_int(conns[fd])
            try:
                var step = ch[].offload_done(job)
                if step:
                    _apply_step(fd, step.value(), reactor, wheel, timers, ch)
                    ready.append(fd)
            except:
                finished = True
        offload_free(job)
        if finished:
            _cleanup_conn(fd, conns, timers, reactor, wheel)
    return ready^


def offload_timeout_h1(
    fd: Int,
    mut conns: Dict[Int, Int],
    mut reactor: Reactor,
    mut wheel: TimerWheel,
    mut timers: Dict[Int, UInt64],
) raises -> Bool:
    """A fired timer on a parked connection is its handler deadline:
    cancel the job with ``TIMEOUT`` and queue 503. False when ``fd`` is
    not parked, so the caller treats the timer as an idle timeout."""
    if fd not in conns:
        return False
    var ch = _conn_ptr_from_int(conns[fd])
    if ch[].state != STATE_PARKED:
        return False
    var step = ch[].offload_timeout()
    _apply_step(fd, step, reactor, wheel, timers, ch)
    return True


def begin_offload_settle_h1(
    port: Int,
    listener_fd: Int,
    mut conns: Dict[Int, Int],
    mut reactor: Reactor,
    mut wheel: TimerWheel,
    mut timers: Dict[Int, UInt64],
):
    """Start a graceful stop that waits for offloaded requests.

    Stops accepting, flips ``SHUTDOWN`` on every job still out (queued
    ones are then answered 503 without running), and closes every
    connection that has nothing parked. A parked one closes after its
    response.
    """
    try:
        reactor.unregister(c_int(listener_fd))
    except:
        pass
    offload_cancel_all(port, CancelReason.SHUTDOWN)
    var fds = List[Int]()
    for kv in conns.items():
        fds.append(kv.key)
    for i in range(len(fds)):
        var fd = fds[i]
        try:
            var ch = _conn_ptr_from_int(conns[fd])
            if ch[].state == STATE_PARKED:
                ch[].offload_close = True
                continue
            ch[].cancel_cell.flip(CancelReason.SHUTDOWN)
        except:
            pass
        _cleanup_conn(fd, conns, timers, reactor, wheel)


def offload_settled_h1(conns: Dict[Int, Int]) raises -> Bool:
    """No connection is parked or still writing a response."""
    for kv in conns.items():
        var state = _conn_ptr_from_int(kv.value)[].state
        if state == STATE_PARKED or state == STATE_WRITING:
            return False
    return True


def close_offload_port(port: Int, mut reactor: Reactor):
    """Cancel every job this worker still has out and close its port.

    Queued jobs are skipped once cancelled. A running one finishes on
    the port's own copy of the handler and is freed by the pool, so the
    worker returns at once. Only a handler that is not ``Copyable`` is
    borrowed by its jobs, and then the worker waits for them.
    """
    if port == 0:
        return
    offload_cancel_all(port, CancelReason.SHUTDOWN)
    if offload_port_borrows_handler(port):
        var events = List[Event]()
        while offload_outstanding(port) > 0:
            events.clear()
            try:
                _ = reactor.poll(10, events)
            except:
                pass
            var jobs = offload_take_done(port)
            for i in range(len(jobs)):
                offload_free(jobs[i])
    offload_port_close(port)
