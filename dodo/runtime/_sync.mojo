"""pthread mutexes and condition variables, as heap cells.

Shared by the offload pool (`dodo.http._offload_pool`) and the database
connection pool (`dodo.db.pool`). Each lock lives in its own heap cell so
its address never moves, which pthread requires.
"""

from std.ffi import c_int, external_call
from std.memory import Layout, Pointer, alloc


comptime SYNC_BYTES: Int = 64
"""Room for a ``pthread_mutex_t`` or ``pthread_cond_t`` on glibc, musl
and macOS (40 to 64 bytes)."""

comptime _CLOCK_REALTIME: c_int = 0
"""The clock ``pthread_cond_timedwait`` measures against by default, on
Linux and macOS."""


def sync_alloc() -> Pointer[UInt8, MutUntrackedOrigin]:
    var p = alloc(Layout[UInt8](count=SYNC_BYTES)).unsafe_leak()
    for i in range(SYNC_BYTES):
        p[unsafe_offset=i] = UInt8(0)
    return p


def mutex_new() -> Pointer[UInt8, MutUntrackedOrigin]:
    var mu = sync_alloc()
    _ = external_call["pthread_mutex_init", Int32](
        mu.unsafe_bitcast[Int8](), Int(0)
    )
    return mu


def mutex_free(mu: Pointer[UInt8, MutUntrackedOrigin]):
    _ = external_call["pthread_mutex_destroy", Int32](mu.unsafe_bitcast[Int8]())
    mu.unsafe_free()


def cond_new() -> Pointer[UInt8, MutUntrackedOrigin]:
    var cv = sync_alloc()
    _ = external_call["pthread_cond_init", Int32](
        cv.unsafe_bitcast[Int8](), Int(0)
    )
    return cv


def cond_free(cv: Pointer[UInt8, MutUntrackedOrigin]):
    _ = external_call["pthread_cond_destroy", Int32](cv.unsafe_bitcast[Int8]())
    cv.unsafe_free()


def lock(mu: Pointer[UInt8, MutUntrackedOrigin]):
    _ = external_call["pthread_mutex_lock", Int32](mu.unsafe_bitcast[Int8]())


def unlock(mu: Pointer[UInt8, MutUntrackedOrigin]):
    _ = external_call["pthread_mutex_unlock", Int32](mu.unsafe_bitcast[Int8]())


def wait(
    cv: Pointer[UInt8, MutUntrackedOrigin],
    mu: Pointer[UInt8, MutUntrackedOrigin],
):
    _ = external_call["pthread_cond_wait", Int32](
        cv.unsafe_bitcast[Int8](), mu.unsafe_bitcast[Int8]()
    )


def wait_ms(
    cv: Pointer[UInt8, MutUntrackedOrigin],
    mu: Pointer[UInt8, MutUntrackedOrigin],
    timeout_ms: Int,
):
    """Wait on `cv` for at most about `timeout_ms`, or until signalled.

    pthread measures the deadline on the wall clock, which can jump, so a
    caller with a real deadline checks the monotonic clock itself and
    waits again in short slices.
    """
    # timespec { tv_sec, tv_nsec }: two machine words, in a heap cell
    # because C writes it.
    var now = List[Int](length=2, fill=0)
    _ = external_call["clock_gettime", c_int](_CLOCK_REALTIME, now.unsafe_ptr())
    var nanoseconds = now[1] + (timeout_ms % 1000) * 1_000_000
    var deadline = List[Int](length=2, fill=0)
    deadline[0] = now[0] + timeout_ms // 1000 + nanoseconds // 1_000_000_000
    deadline[1] = nanoseconds % 1_000_000_000
    _ = external_call["pthread_cond_timedwait", Int32](
        cv.unsafe_bitcast[Int8](),
        mu.unsafe_bitcast[Int8](),
        deadline.unsafe_ptr(),
    )
    _ = deadline^


def signal(cv: Pointer[UInt8, MutUntrackedOrigin]):
    _ = external_call["pthread_cond_signal", Int32](cv.unsafe_bitcast[Int8]())


def broadcast(cv: Pointer[UInt8, MutUntrackedOrigin]):
    _ = external_call["pthread_cond_broadcast", Int32](
        cv.unsafe_bitcast[Int8]()
    )
