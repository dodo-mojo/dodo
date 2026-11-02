"""A thread-safe, bounded connection pool shared by every driver.

A pool opens connections lazily, up to `max_size`, and hands one out at a
time. The handle (`Pool`) is cheap to copy and every copy shares the same
connections, so a pool can sit in the app state and be used from every
worker and offload thread.

A checked-out connection comes back when its `Pooled` guard is destroyed.
One that failed mid-call (`broken()`) or outlived `max_lifetime_ms` is
closed instead. A connection that sat idle longer than `idle_ping_ms` is
pinged before it is handed out, and replaced if the ping fails.
"""

from std.memory import ArcPointer, Pointer

from ..runtime._libc_time import monotonic_now_ms
from ..runtime._sync import (
    broadcast,
    cond_free,
    cond_new,
    lock,
    mutex_free,
    mutex_new,
    unlock,
    wait_ms,
)
from .error import DbError


trait Connection(Deinitable, Movable):
    """What a driver's connection gives the pool."""

    comptime Config: Copyable & Deinitable

    @staticmethod
    def open(config: Self.Config) raises DbError -> Self:
        """Connect and authenticate."""
        ...

    def ping(mut self) -> Bool:
        """A cheap round trip; False when the connection is unusable."""
        ...

    def broken(self) -> Bool:
        """Whether an earlier call left the connection unusable."""
        ...

    def reset(mut self) -> Bool:
        """Undo session state before reuse (an open transaction, a selected
        database). False when that failed and the connection should close.
        """
        ...

    def close(mut self):
        """Say goodbye to the server, best effort. Never raises."""
        ...


@fieldwise_init
struct PoolOptions(Copyable, Writable):
    """How a pool sizes and checks its connections."""

    var max_size: Int
    """Connections open at once, idle or in use."""
    var acquire_timeout_ms: Int
    """How long a caller waits for a free connection before an error."""
    var idle_ping_ms: Int
    """Ping a connection idle longer than this before handing it out."""
    var max_lifetime_ms: Int
    """Close a connection older than this when it comes back. 0: never."""

    def __init__(out self):
        self.max_size = 10
        self.acquire_timeout_ms = 5_000
        self.idle_ping_ms = 30_000
        self.max_lifetime_ms = 30 * 60_000

    def write_to[W: Writer](self, mut writer: W):
        writer.write(
            "max_size=",
            self.max_size,
            " acquire_timeout_ms=",
            self.acquire_timeout_ms,
        )


struct _Idle[C: Connection](Movable):
    var conn: Self.C
    var since_ms: Int
    var born_ms: Int

    def __init__(out self, var conn: Self.C, since_ms: Int, born_ms: Int):
        self.conn = conn^
        self.since_ms = since_ms
        self.born_ms = born_ms

    def into_conn(deinit self) -> Self.C:
        return self.conn^


struct _PoolState[C: Connection](Movable):
    var mu: Pointer[UInt8, MutUntrackedOrigin]
    var cv: Pointer[UInt8, MutUntrackedOrigin]
    var idle: List[_Idle[Self.C]]
    var open_count: Int
    var config: Self.C.Config
    var options: PoolOptions

    def __init__(out self, config: Self.C.Config, options: PoolOptions):
        self.mu = mutex_new()
        self.cv = cond_new()
        self.idle = List[_Idle[Self.C]]()
        self.open_count = 0
        self.config = config.copy()
        self.options = options.copy()

    def __deinit__(deinit self):
        while len(self.idle) > 0:
            var entry = self.idle.pop()
            entry.conn.close()
        mutex_free(self.mu)
        cond_free(self.cv)


struct Pool[C: Connection](Copyable):
    """Connections to one database, shared by every copy of the handle."""

    var _state: ArcPointer[_PoolState[Self.C]]

    def __init__(
        out self, config: Self.C.Config, options: PoolOptions = PoolOptions()
    ):
        self._state = ArcPointer(_PoolState[Self.C](config, options))

    def _shared(self) -> Pointer[_PoolState[Self.C], MutUntrackedOrigin]:
        # Every field is guarded by the state's mutex, so callers holding a
        # read-only handle may change it.
        return Pointer[_PoolState[Self.C], MutUntrackedOrigin](
            unsafe_from_address=Int(Pointer(to=self._state[]))
        )

    def acquire(self) raises DbError -> Pooled[Self.C]:
        """A connection for the caller alone, until the guard is destroyed."""
        var state = self._shared()
        var deadline = monotonic_now_ms() + state[].options.acquire_timeout_ms
        lock(state[].mu)
        while True:
            if len(state[].idle) > 0:
                var entry = state[].idle.pop()
                unlock(state[].mu)
                var now = monotonic_now_ms()
                var usable = True
                if self._too_old(entry.born_ms, now):
                    usable = False
                elif now - entry.since_ms > state[].options.idle_ping_ms:
                    usable = entry.conn.ping()
                if usable:
                    var born_ms = entry.born_ms
                    return Pooled[Self.C](
                        self._state, entry^.into_conn(), born_ms
                    )
                entry.conn.close()
                _ = entry^
                lock(state[].mu)
                state[].open_count -= 1
                continue
            if state[].open_count < state[].options.max_size:
                state[].open_count += 1
                unlock(state[].mu)
                return self._open_new()
            var remaining = deadline - monotonic_now_ms()
            if remaining <= 0:
                var in_use = state[].open_count
                unlock(state[].mu)
                raise DbError(
                    DbError.POOL_TIMEOUT,
                    String(),
                    String(
                        "no connection came free within ",
                        state[].options.acquire_timeout_ms,
                        " ms (",
                        in_use,
                        " in use)",
                    ),
                    String(),
                )
            # Short slices: the wall clock pthread waits on can jump.
            wait_ms(state[].cv, state[].mu, min(remaining, 50))

    def _open_new(self) raises DbError -> Pooled[Self.C]:
        var state = self._shared()
        try:
            var conn = Self.C.open(state[].config)
            return Pooled[Self.C](self._state, conn^, monotonic_now_ms())
        except e:
            lock(state[].mu)
            state[].open_count -= 1
            broadcast(state[].cv)
            unlock(state[].mu)
            raise e^

    def _too_old(self, born_ms: Int, now: Int) -> Bool:
        var limit = self._shared()[].options.max_lifetime_ms
        return limit > 0 and now - born_ms > limit

    def open_count(self) -> Int:
        """Connections open now, idle or in use."""
        var state = self._shared()
        lock(state[].mu)
        var count = state[].open_count
        unlock(state[].mu)
        return count

    def idle_count(self) -> Int:
        """Connections open and waiting in the pool."""
        var state = self._shared()
        lock(state[].mu)
        var count = len(state[].idle)
        unlock(state[].mu)
        return count


struct Pooled[C: Connection](Movable):
    """A checked-out connection. Destroying it gives the connection back."""

    var _state: ArcPointer[_PoolState[Self.C]]
    var _conn: Self.C
    var _born_ms: Int

    def __init__(
        out self,
        state: ArcPointer[_PoolState[Self.C]],
        var conn: Self.C,
        born_ms: Int,
    ):
        self._state = state
        self._conn = conn^
        self._born_ms = born_ms

    def conn(ref self) -> ref[self._conn] Self.C:
        """The connection itself."""
        return self._conn

    def __deinit__(deinit self):
        var state = Pointer[_PoolState[Self.C], MutUntrackedOrigin](
            unsafe_from_address=Int(Pointer(to=self._state[]))
        )
        var now = monotonic_now_ms()
        var limit = state[].options.max_lifetime_ms
        var expired = limit > 0 and now - self._born_ms > limit
        var reusable = not self._conn.broken() and not expired
        if reusable:
            reusable = self._conn.reset()
        if not reusable:
            self._conn.close()
            lock(state[].mu)
            state[].open_count -= 1
            broadcast(state[].cv)
            unlock(state[].mu)
            return
        lock(state[].mu)
        state[].idle.append(_Idle[Self.C](self._conn^, now, self._born_ms))
        broadcast(state[].cv)
        unlock(state[].mu)
