"""Idle client-connection pool, one LIFO deque per origin.

Used by the HTTP/2 client (:class:`dodo.http._client.h2_send.H2Link`).

* Keyed on ``host:port``; the warmest connection is reused first.
* Per-host idle cap, plus idle-timeout eviction on :meth:`acquire`.
* A ``Copyable`` handle over one heap-allocated ``_PoolState``, so the
  owning ``HttpClient`` can acquire and release from a ``read self``
  method. The owner frees the state in ``__deinit__``; copies must not.

Connections are ``Movable`` values, so each idle one lives in its own
heap cell (:class:`dodo.runtime.pool.Pool`) and the deque holds the
cell addresses.
"""

from std.collections import Dict, List, Optional
from std.memory import Layout, Pointer, alloc

from dodo.runtime.pool import Pool, PoolableConn
from dodo.runtime._libc_time import monotonic_now_ms


@fieldwise_init
struct _PoolState(Movable):
    """Mutable state behind an :class:`IdleConnPool` handle."""

    var entries: Dict[String, List[Int]]
    """``host:port -> [cell_addr, ...]``, newest last."""

    var ts_ms: Dict[Int, Int]
    """``cell_addr -> insertion monotonic-ms``, for idle-timeout
    eviction. Drained alongside ``entries``."""

    var max_idle_per_host: Int
    """Per-origin idle cap. Releases above this close the connection."""

    var idle_timeout_ms: Int
    """Max age before an idle connection is evicted on the next
    :meth:`acquire`. ``0`` disables timeout eviction."""


struct IdleConnPool[T: PoolableConn](Copyable):
    """Idle client-connection pool handle (pointer-backed)."""

    var _addr: Int
    """Heap address of the ``_PoolState``; ``0`` means pooling is off."""

    @staticmethod
    def disabled() -> Self:
        """The no-op handle: every acquire misses, every release drops
        the connection."""
        return Self(0)

    @staticmethod
    def new(
        max_idle_per_host: Int = 8,
        idle_timeout_ms: Int = 90_000,
    ) -> Self:
        """Allocate an enabled pool. Doesn't raise, so it can initialize
        an ``HttpClient`` field eagerly."""
        var p = alloc(Layout[_PoolState](count=1)).unsafe_leak()
        p.unsafe_write(
            _PoolState(
                Dict[String, List[Int]](),
                Dict[Int, Int](),
                max_idle_per_host,
                idle_timeout_ms,
            )
        )
        return Self(Int(p))

    @always_inline
    def __init__(out self, addr: Int):
        self._addr = addr

    @always_inline
    def enabled(imm self) -> Bool:
        return self._addr != 0

    def _state(
        imm self,
    ) -> Pointer[_PoolState, MutUntrackedOrigin]:
        return Pointer[UInt8, MutUntrackedOrigin](
            unsafe_from_address=self._addr
        ).unsafe_bitcast[_PoolState]()

    @staticmethod
    def build_key(host: String, port: Int) -> String:
        """``host:port``, with the port always explicit so a ``:443``
        connection never lands in a ``:8443`` bucket."""
        return host + ":" + String(port)

    def acquire(imm self, key: String) raises -> Optional[Self.T]:
        """Move out the most recently released idle connection for
        ``key``, evicting any past the idle timeout first. Returns
        ``None`` on a miss."""
        if not self.enabled():
            return None
        var sp = self._state()
        if key not in sp[].entries:
            return None
        var now_ms = monotonic_now_ms()
        var deque = sp[].entries[key].copy()
        while len(deque) > 0:
            var addr = deque[len(deque) - 1]
            deque.resize(len(deque) - 1, 0)
            var inserted = sp[].ts_ms.pop(addr)
            var timeout = sp[].idle_timeout_ms
            if timeout > 0 and (now_ms - inserted) > timeout:
                Pool[Self.T].get_ptr(addr)[].retire()
                Pool[Self.T].free(addr)
                continue
            var cell = Pool[Self.T].get_ptr(addr)
            var conn = cell.unsafe_take_pointee()
            cell.unsafe_free()
            sp[].entries[key] = deque^
            return Optional(conn^)
        _ = sp[].entries.pop(key)
        return None

    def release(imm self, key: String, var conn: Self.T) raises:
        """Hand ``conn`` back for reuse, or retire it when pooling is
        off or the per-host cap is reached."""
        if not self.enabled():
            conn.retire()
            return
        var sp = self._state()
        if sp[].max_idle_per_host <= 0:
            conn.retire()
            return
        var deque: List[Int]
        if key in sp[].entries:
            deque = sp[].entries[key].copy()
        else:
            deque = List[Int]()
        if len(deque) >= sp[].max_idle_per_host:
            conn.retire()
            sp[].entries[key] = deque^
            return
        var addr = Pool[Self.T].alloc_move(conn^)
        deque.append(addr)
        sp[].entries[key] = deque^
        sp[].ts_ms[addr] = monotonic_now_ms()

    def idle_count(imm self) -> Int:
        """Total idle connections across all origins."""
        if not self.enabled():
            return 0
        var sp = self._state()
        var total = 0
        for entry in sp[].entries.items():
            total += len(entry.value)
        return total

    def free(mut self) raises -> None:
        """Retire every idle connection and free the state. Safe to call
        on a disabled or moved-from handle."""
        if self._addr == 0:
            return
        var sp = self._state()
        for entry in sp[].entries.items():
            for i in range(len(entry.value)):
                var addr = entry.value[i]
                Pool[Self.T].get_ptr(addr)[].retire()
                Pool[Self.T].free(addr)
        sp.unsafe_deinit_pointee()
        sp.unsafe_free()
        self._addr = 0
