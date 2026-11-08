"""Graceful stop for the reactor loops.

When the stop flag flips, a loop stops accepting and keeps serving the
connections it already has, so a request that reached the server is
answered instead of reset:

- A connection reading or answering a request finishes it, and closes
  after the response (which says `Connection: close`).
- A keep-alive connection between requests is closed at once.
- A connection that has not sent its first request yet gets
  `FIRST_REQUEST_GRACE_MS` to send it. A client sends its request right
  after connecting, so this covers one that connected just before the
  stop without holding the stop for clients that never send.
- A request on the offload pool is waited for, as before.

The loop ends once no connection is left, or at `shutdown_timeout_ms`.
Connections waiting in the listener's queue are never accepted: when the
listener outlives this process (`dodo dev` holds it), the next server
answers them.

These helpers serve the HTTP/1.1-only loops, whose connection table holds
plain `ConnHandle` addresses. The unified loop has tagged versions.
"""

from std.collections import Dict, List
from std.ffi import c_int

from dodo.http.cancel import CancelReason
from dodo.http._offload_pool import offload_cancel_all
from dodo.runtime import Reactor, TimerWheel

from .lifecycle import _cleanup_conn, _conn_ptr_from_int


comptime FIRST_REQUEST_GRACE_MS = 500
"""How long a stopping server waits for the first request of a
connection that has sent nothing yet."""

comptime DRAIN_POLL_MS = 10
"""Poll cap while draining, so the loop ends soon after its last
connection closes."""


struct DrainClock(ImplicitlyCopyable, Movable):
    """When a stopping loop gives up: on silent connections, and on all."""

    var first_request_deadline_ms: Int
    var deadline_ms: Int

    def __init__(out self, now_ms: Int, shutdown_timeout_ms: Int):
        var timeout = shutdown_timeout_ms
        if timeout < 0:
            timeout = 0
        self.deadline_ms = now_ms + timeout
        self.first_request_deadline_ms = now_ms + FIRST_REQUEST_GRACE_MS
        if self.first_request_deadline_ms > self.deadline_ms:
            self.first_request_deadline_ms = self.deadline_ms


def stop_accepting(listener_fds: List[Int], mut reactor: Reactor):
    """Unregister every listener, so no new connection is accepted."""
    for fd in listener_fds:
        try:
            reactor.unregister(c_int(fd))
        except:
            # Already unregistered by the accept gate.
            pass


def begin_drain_h1(
    offload_port: Int,
    listener_fds: List[Int],
    mut conns: Dict[Int, Int],
    mut reactor: Reactor,
) raises:
    """Start a graceful stop: stop accepting, and mark every connection
    to close after its current response.

    Jobs still queued on the offload pool are cancelled (and answered
    503 without running); running ones finish.
    """
    stop_accepting(listener_fds, reactor)
    if offload_port != 0:
        offload_cancel_all(offload_port, CancelReason.SHUTDOWN)
    for entry in conns.items():
        _conn_ptr_from_int(entry.value)[].start_draining()


def close_idle_h1(
    now_ms: Int,
    clock: DrainClock,
    mut conns: Dict[Int, Int],
    mut reactor: Reactor,
    mut wheel: TimerWheel,
    mut timers: Dict[Int, UInt64],
) raises:
    """Close each connection that waits for a request it will not get:
    a keep-alive one at once, a new one after the first-request grace.
    Called once per loop pass while draining, after the pass's events."""
    var grace_over = now_ms >= clock.first_request_deadline_ms
    var idle = List[Int]()
    for entry in conns.items():
        var ch = _conn_ptr_from_int(entry.value)
        # Again on each pass: a request parked on the offload pool since
        # the last one set its own close flag.
        ch[].start_draining()
        if not ch[].waits_for_request():
            continue
        var served_before = ch[].keepalive_count > 0
        if served_before or grace_over:
            idle.append(entry.key)
    for fd in idle:
        _conn_ptr_from_int(conns[fd])[].cancel_cell.flip(CancelReason.SHUTDOWN)
        _cleanup_conn(fd, conns, timers, reactor, wheel)


def drain_done(now_ms: Int, clock: DrainClock, open_conns: Int) -> Bool:
    """Whether a draining loop can end: nothing left, or out of time."""
    if open_conns == 0:
        return True
    return now_ms >= clock.deadline_ms
