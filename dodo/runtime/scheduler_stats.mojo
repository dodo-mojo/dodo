"""Cross-thread stop flag and per-worker stats cell.

Shared by ``scheduler.mojo`` (which allocates and reads them) and
``_worker.mojo`` (which writes them), so they live here rather than in
either -- importing one from the other would be a cycle.

``scheduler.mojo`` re-exports every name below, so the existing
``from dodo.runtime.scheduler import load_stop_flag`` call sites in
the reactor loops keep working unchanged.
"""

from std.atomic import Atomic, Ordering
from std.ffi import c_int, c_size_t, external_call
from std.memory import Pointer, stack_allocation
from std.sys.info import CompilationTarget


# ── Atomic stop-flag helpers ─────────────────────────────────────────────────
# The stopping flag is a heap-allocated byte written by the main
# thread and read by every worker. Release-store / acquire-load pair
# gives the workers a proper happens-before edge on shutdown; lowers
# to a plain ``mov`` on x86-64 (TSO) and to ``stlr`` / ``ldar`` on
# ARM64. Callers pass the raw heap address (the same ``Int`` the
# worker ctx carries) so the flag stays valid across struct moves.


@always_inline
def store_stop_flag(addr: Int, value: Bool):
    """Release-store ``value`` into the heap stop-flag byte at ``addr``."""
    if addr == 0:
        return
    var p = Pointer[UInt8, MutUntrackedOrigin](
        unsafe_from_address=addr
    ).unsafe_bitcast[Scalar[DType.uint8]]()
    Atomic[UInt8].store[ordering=Ordering.RELEASE](
        p, UInt8(1) if value else UInt8(0)
    )


@always_inline
def load_stop_flag(addr: Int) -> Bool:
    """Acquire-load the heap stop-flag byte at ``addr``."""
    if addr == 0:
        return False
    var p = Pointer[UInt8, MutUntrackedOrigin](
        unsafe_from_address=addr
    ).unsafe_bitcast[Scalar[DType.uint8]]()
    return Atomic[UInt8].load[ordering=Ordering.ACQUIRE](p) != UInt8(0)


# ── Per-worker stats cell (D6 drain accounting + D9 crash visibility) ─────────
# Each worker owns a heap cell of ``Int64`` slots the worker writes
# and the scheduler (main thread) reads. Slot 0 is the live-connection
# snapshot (updated each reactor iteration); slot 1 is the exit status;
# slots 3-4 are written once by the scheduler and name the worker's place
# in the accept-balancing group.
# Release-store / acquire-load makes the worker's writes visible to the
# scheduler after it joins the worker. A ``base_addr`` of 0 disables the
# writes (single-worker / non-scheduler paths pay nothing).

comptime WORKER_STAT_INFLIGHT: Int = 0
"""Slot index: connections still registered on this worker."""
comptime WORKER_STAT_STATUS: Int = 1
"""Slot index: worker exit status (see ``WORKER_STATUS_*``)."""
comptime WORKER_STAT_DONE: Int = 2
"""Slot index: 1 once the worker's thread has returned from
``run_worker``, whatever the frontend reported. ``Scheduler.drain``
waits on it with a deadline instead of blocking in ``pthread_join``."""
comptime WORKER_STAT_GROUP: Int = 3
"""Slot index: address of the scheduler's accept-balancing group block
(``dodo.runtime._balance``), or 0 when balancing is off."""
comptime WORKER_STAT_INDEX: Int = 4
"""Slot index: this worker's index inside the balancing group."""
comptime WORKER_STAT_WAKE_FD: Int = 5
"""Slot index: the worker reactor's wake fd plus one, so a zeroed cell
means "none" (see ``advertise_wake_fd``)."""
comptime WORKER_STAT_SLOTS: Int = 6
"""Number of Int64 slots per worker cell."""

comptime WORKER_STATUS_RUNNING: Int = 0
"""Worker has not exited its serve loop yet."""
comptime WORKER_STATUS_CLEAN: Int = 1
"""Worker exited because it observed the stop flag (normal shutdown)."""
comptime WORKER_STATUS_CRASHED: Int = 2
"""Worker exited because its reactor poll failed (unexpected)."""


@always_inline
def store_worker_stat(base_addr: Int, slot: Int, value: Int):
    """Release-store ``value`` into ``slot`` of the worker stats cell."""
    if base_addr == 0:
        return
    var p = Pointer[Int, MutUntrackedOrigin](
        unsafe_from_address=base_addr + slot * 8
    ).unsafe_bitcast[Scalar[DType.int64]]()
    Atomic[Int64].store[ordering=Ordering.RELEASE](p, Int64(value))


@always_inline
def load_worker_stat(base_addr: Int, slot: Int) -> Int:
    """Acquire-load ``slot`` of the worker stats cell (0 when disabled)."""
    if base_addr == 0:
        return 0
    var p = Pointer[Int, MutUntrackedOrigin](
        unsafe_from_address=base_addr + slot * 8
    ).unsafe_bitcast[Scalar[DType.int64]]()
    return Int(Atomic[Int64].load[ordering=Ordering.ACQUIRE](p))


# ── Waking a worker on stop ──────────────────────────────────────────────────
# A worker blocked in ``Reactor.poll`` sees the stop flag only when the
# poll returns. Its reactor advertises its wake fd in the worker's stats
# cell, so ``Scheduler`` can write that fd on stop and the worker sees
# the flag at once instead of on its next poll timeout.
#
# The scheduler must never write an fd the worker already closed: the
# number may belong to something else by then. The slot is a tiny lock.
# It holds the fd plus one, 0 for none, or ``_WAKE_FD_BUSY`` while the
# scheduler writes. The scheduler swaps fd+1 for busy, writes, and puts
# fd+1 back. The reactor, before it closes the fd, waits out a busy slot
# and swaps fd+1 for 0, so no write can start after that.

comptime _WAKE_FD_NONE: Int64 = 0
comptime _WAKE_FD_BUSY: Int64 = -1


def write_wake(fd: Int):
    """Make the reactor whose wake fd is ``fd`` return from ``poll``.

    The wake fd is an eventfd on Linux (8 bytes) and a pipe on macOS
    (1 byte); ``poll`` drains either. A full pipe already wakes the
    reactor, so a failed write needs nothing more.
    """
    var buf = stack_allocation[8, UInt8]()
    buf[unsafe_offset=0] = UInt8(1)
    for i in range(1, 8):
        buf[unsafe_offset=i] = UInt8(0)
    var size = 1
    comptime if CompilationTarget.is_linux():
        size = 8
    _ = external_call["write", Int](c_int(fd), buf, c_size_t(size))


def _wake_slot(stats_addr: Int) -> Pointer[Scalar[DType.int64], MutUntrackedOrigin]:
    return Pointer[Int, MutUntrackedOrigin](
        unsafe_from_address=stats_addr + WORKER_STAT_WAKE_FD * 8
    ).unsafe_bitcast[Scalar[DType.int64]]()


def advertise_wake_fd(stats_addr: Int, fd: Int):
    """Publish ``fd`` so ``wake_worker`` can reach this worker's reactor.
    Does nothing when ``stats_addr`` is 0."""
    if stats_addr == 0:
        return
    Atomic[Int64].store[ordering=Ordering.RELEASE](
        _wake_slot(stats_addr), Int64(fd + 1)
    )


def withdraw_wake_fd(stats_addr: Int):
    """Take the advertised fd back. Once this returns, no ``wake_worker``
    writes to it, so the reactor may close it. Waits while a wake is
    being written, which is one ``write`` call."""
    if stats_addr == 0:
        return
    var slot = _wake_slot(stats_addr)
    while True:
        var current = Atomic[Int64].load[ordering=Ordering.ACQUIRE](slot)
        if current == _WAKE_FD_NONE:
            return
        if current == _WAKE_FD_BUSY:
            _ = external_call["sched_yield", c_int]()
            continue
        var expected = current
        if Atomic[Int64].compare_exchange(slot, expected, _WAKE_FD_NONE):
            return


def wake_worker(stats_addr: Int):
    """Wake the worker whose stats cell is ``stats_addr``, if its reactor
    still advertises a wake fd. Safe from any thread."""
    if stats_addr == 0:
        return
    var slot = _wake_slot(stats_addr)
    var current = Atomic[Int64].load[ordering=Ordering.ACQUIRE](slot)
    if current <= _WAKE_FD_NONE:
        return
    var expected = current
    if not Atomic[Int64].compare_exchange(slot, expected, _WAKE_FD_BUSY):
        # The reactor withdrew it meanwhile: it is closing anyway.
        return
    write_wake(Int(current) - 1)
    Atomic[Int64].store[ordering=Ordering.RELEASE](slot, current)
