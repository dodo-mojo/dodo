"""``Scheduler.start`` rolls back completely when a worker fails to spawn.

The default listener mode pre-binds one ``SO_REUSEPORT`` listener per
worker before any worker starts. When a later spawn failed, the rollback
freed the worker array, the contexts, the stats cells, the shared listener
and the stop flag, but never the per-worker listeners: the port stayed held
and the kernel kept hashing connections to sockets nobody accepted on.

A worker runs as a pool task while a serving lease is free and on its own
OS thread otherwise, and only the OS-thread path can fail. So the test
first holds every lease itself, then fills this process's thread table
(``kern.num_taskthreads`` on macOS) with parked threads and frees exactly
one slot: worker 0 spawns and worker 1 fails. The parked threads block in
``read(2)`` on a pipe, so closing the pipe releases all of them at once.

On Linux the same fill hits the system or cgroup thread limit and would
starve other processes, so the test returns early there.

Standalone: it owns the whole thread table for a while, so it cannot share
a process with other tests.
"""

from std.ffi import c_int, external_call
from std.memory import Pointer
from std.sys.info import CompilationTarget
from std.testing import assert_equal, assert_true, TestSuite

from dodo.net import SocketAddr
from dodo.runtime import Frontend, Scheduler
from dodo.runtime._asyncrt import asyncrt_release_lease, asyncrt_try_lease
from dodo.runtime._libc_time import libc_nanosleep_ms
from dodo.runtime._thread import ThreadHandle, _OpaquePtr
from dodo.runtime.scheduler import load_stop_flag

comptime MAX_PARKED = 20000
"""Upper bound on parked threads, well above macOS's 8192 per process."""


struct _Pipe:
    var read_fd: c_int
    var write_fd: c_int

    def __init__(out self) raises:
        var fds = List[c_int](length=2, fill=0)
        if external_call["pipe", c_int](fds.unsafe_ptr()) != 0:
            raise Error("pipe() failed")
        self.read_fd = fds[0]
        self.write_fd = fds[1]

    def close_write_end(mut self):
        """Every thread parked on the read end wakes up with EOF."""
        if self.write_fd >= 0:
            _ = external_call["close", c_int](self.write_fd)
            self.write_fd = -1


def _park_on_pipe(arg: _OpaquePtr) -> _OpaquePtr:
    """Block in ``read`` until the pipe's write end is closed."""
    var fd = c_int(Int(arg))
    var byte = UInt8(0)
    _ = external_call["read", Int](fd, Pointer(to=byte), 1)
    return arg


def _park(pipe: _Pipe) raises -> ThreadHandle:
    return ThreadHandle.spawn_os[_park_on_pipe](
        _OpaquePtr(unsafe_from_address=Int(pipe.read_fd))
    )


def _open_fds() -> Int:
    var n = 0
    for fd in range(4096):
        # F_GETFD is 1 on Linux and macOS; it fails with EBADF on a closed fd.
        if external_call["fcntl", c_int](c_int(fd), c_int(1), c_int(0)) >= 0:
            n += 1
    return n


@fieldwise_init
struct _Idle(Copyable, Frontend):
    def requires_per_worker_listener(self) -> Bool:
        return False

    def run_worker(
        mut self,
        listener_fd: Int,
        mut stopping: Bool,
        stats_addr: Int,
        extra_fds: List[Int] = List[Int](),
    ):
        var stop_addr = Int(Pointer[Bool, _](to=stopping))
        while not load_stop_flag(stop_addr):
            _ = libc_nanosleep_ms(1)


def _hold_every_lease() -> Int:
    var held = 0
    while asyncrt_try_lease():
        held += 1
    return held


def _release_leases(count: Int):
    for _ in range(count):
        asyncrt_release_lease()


def _fill_thread_table(pipe: _Pipe, mut parked: List[ThreadHandle]) -> Bool:
    """Park threads until ``pthread_create`` fails. True if it did."""
    for _ in range(MAX_PARKED):
        try:
            parked.append(_park(pipe))
        except:
            return True
    return False


def _join_all(mut parked: List[ThreadHandle]):
    """Wait for every parked thread. The process crashes on exit if
    thousands of them are still winding down."""
    for i in range(len(parked)):
        try:
            parked[i].join()
        except:
            pass


def _start_two_workers() -> Bool:
    """Try a two-worker start. True if it raised."""
    try:
        var s = Scheduler[_Idle].start(
            addr=SocketAddr.localhost(0),
            frontend=_Idle(),
            num_workers=2,
            pin_cores=False,
        )
        s.shutdown()
    except:
        return True
    return False


def test_failed_start_releases_the_per_worker_listeners() raises:
    comptime if CompilationTarget.is_linux():
        return
    var leases = _hold_every_lease()
    var everyone = _Pipe()
    var last_slot = _Pipe()
    # Parked first so that closing its pipe frees exactly one slot.
    var one = _park(last_slot)

    var parked = List[ThreadHandle]()
    var exhausted = _fill_thread_table(everyone, parked)
    last_slot.close_write_end()
    one.join()

    var before = _open_fds()
    var raised = False
    if exhausted:
        raised = _start_two_workers()
    var after = _open_fds()

    everyone.close_write_end()
    _join_all(parked)
    _release_leases(leases)

    assert_true(exhausted, "the thread table did not fill up")
    assert_true(raised, "the worker spawn did not fail inside start")
    assert_equal(after, before, "the failed start left listener fds open")


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
