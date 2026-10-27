"""libc time FFI.

An older Mojo passed the argument of an inferred-signature
``external_call["usleep"]`` wrongly: a 1 ms sleep took ~1.5 s and a
50 ms one ~56 s. These bindings use explicit signatures from that
time. Mojo 1.2.0 sleeps accurately either way, on its own or with
thousands of threads in the process, and
``tests/runtime/test_libc_time.mojo`` checks the wall-clock semantics
(a many-threads case included) so a regression shows up there first.

POSIX semantics:

- ``usleep(useconds_t usec)`` — suspends the calling thread for
  at least ``usec`` microseconds. ``useconds_t`` is uint32 on
  Linux + macOS. Values >= 1_000_000 are explicitly undefined;
  callers wanting >= 1 second should use ``nanosleep`` instead.
  Returns 0 on success, -1 on signal interruption.

- ``nanosleep(const struct timespec *req, struct timespec *rem)``
  — suspends for ``req->tv_sec`` seconds + ``req->tv_nsec``
  nanoseconds. No upper limit. Returns 0 on success, -1 on
  signal interruption (with ``rem`` populated with the remaining
  time).
"""

from std.ffi import external_call
from std.time import monotonic, sleep


@always_inline
def monotonic_now_ms() -> Int:
    """The steady clock in milliseconds, for deadlines and elapsed time.

    The clock never jumps backwards, so ``monotonic_now_ms() - start``
    is a sound elapsed measure. It wraps the stdlib clock, which reads
    ``CLOCK_MONOTONIC`` without allocating.

    Returns:
        Milliseconds since an unspecified but fixed epoch.
    """
    var nanoseconds = Int(monotonic())
    return nanoseconds // 1_000_000


@always_inline
def libc_usleep(microseconds: Int) -> Int:
    """Sleep for at least ``microseconds`` microseconds.

    Args:
        microseconds: Number of microseconds to sleep. Negative
            values are treated as 0. Values >= 1_000_000 are
            allowed but POSIX-undefined; for sleeps that long
            prefer ``libc_nanosleep_ms``.

    Returns:
        0 on success; -1 on signal interruption (the actual
        wall-clock sleep may be shorter than requested).
    """
    if microseconds <= 0:
        return 0
    var rc = external_call["usleep", Int32, Int32](Int32(microseconds))
    return Int(rc)


@always_inline
def libc_nanosleep_ms(ms: Int) -> Int:
    """Sleep for at least ``ms`` milliseconds.

    More flexible than ``usleep``: no 1-second ceiling and
    nanosecond-resolution semantics. Interrupt remainders are
    discarded; callers needing interrupt-aware sleeps go through
    ``nanosleep`` directly.

    Args:
        ms: Number of milliseconds to sleep. Negative values are
            treated as 0.

    Returns:
        Always 0. Kept as ``Int`` so the signature matches
        :func:`libc_usleep` and existing ``_ =`` call sites.
    """
    if ms <= 0:
        return 0
    # ``std.time.sleep``, not our own ``nanosleep`` extern. The stdlib
    # already declares ``nanosleep`` with a different signature, and Mojo
    # declares one extern per signature, so any binary that reaches both
    # refuses to lower with "existing function with conflicting
    # signature". Nothing in dodo imports ``std.time.sleep`` today, so
    # dodo alone never hit it -- but anything linked alongside dodo that
    # does, directly or through a dependency, could not build at all.
    #
    # The remainder was already being discarded here and the stdlib's
    # sleep is the same ``nanosleep`` underneath, so only the linkage
    # changes.
    sleep(Float64(ms) / 1000.0)
    return 0
