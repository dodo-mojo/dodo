"""The offload pool behind :class:`dodo.http.Offload` (ADR-0004).

A worker that reaches an offloaded handler does not run it. It wraps the
request in a job, puts the job on the process-wide queue and goes on
serving its other connections. A pool thread takes the job, runs the
handler, puts the finished job on the worker's completion list and wakes
the worker's reactor, which writes the response.

Pieces:

- ``OffloadJob``: one request on its way through the pool. It owns the
  request, the request's cancel cell and, once the handler returns, the
  response.
- ``OffloadPort``: one per worker. A copy of the worker's handler and
  its serve thunk, the completion list, and the wake fd.
- The pool itself: a bounded job queue and a fixed set of OS threads
  (``ThreadHandle.spawn_os``), started by the first worker that needs it
  and shared by every worker in the process.

Ownership: the worker allocates a job and frees it once it comes back
on the completion list, whether it was delivered or dropped. A
connection that gives up on a job (timeout, client gone) only flips its
cancel cell and forgets it; the job stays alive until the pool hands it
back, so a job's address is never reused while a pool thread can still
touch it. A worker that stops with jobs still running closes its port
without waiting: those jobs are freed by the pool thread that finishes
them, and the last one frees the port.

Closures can't cross threads in Mojo, so a job runs the handler through
an address and a thunk monomorphised for the handler type. The port
keeps its own copy of the handler, so a job can outlive the worker.
"""

from std.atomic import Atomic, Ordering
from std.collections import List, Optional
from std.ffi import _get_global, c_int, c_size_t, external_call
from std.iter import downcast
from std.memory import Layout, OptionalPointer, Pointer, alloc, stack_allocation
from std.sys.info import CompilationTarget

from dodo.errors import log_handler_error, map_handler_error
from dodo.runtime._thread import ThreadHandle, _OpaquePtr, _null_ptr, num_cpus
from dodo.runtime.pool import Pool

from .cancel import CancelCell, CancelReason
from .handler import CancelHandler, Handler
from .request import Request
from .response import Response


# ── pthread mutex and condition variable ──────────────────────────────────


comptime _SYNC_BYTES: Int = 64
"""Room for a ``pthread_mutex_t`` or ``pthread_cond_t`` on glibc, musl
and macOS (40 to 64 bytes)."""


def _sync_alloc() -> Pointer[UInt8, MutUntrackedOrigin]:
    var p = alloc(Layout[UInt8](count=_SYNC_BYTES)).unsafe_leak()
    for i in range(_SYNC_BYTES):
        p[unsafe_offset=i] = UInt8(0)
    return p


def _mutex_new() -> Pointer[UInt8, MutUntrackedOrigin]:
    var mu = _sync_alloc()
    _ = external_call["pthread_mutex_init", Int32](
        mu.unsafe_bitcast[Int8](), Int(0)
    )
    return mu


def _cond_new() -> Pointer[UInt8, MutUntrackedOrigin]:
    var cv = _sync_alloc()
    _ = external_call["pthread_cond_init", Int32](
        cv.unsafe_bitcast[Int8](), Int(0)
    )
    return cv


def _lock(mu: Pointer[UInt8, MutUntrackedOrigin]):
    _ = external_call["pthread_mutex_lock", Int32](mu.unsafe_bitcast[Int8]())


def _unlock(mu: Pointer[UInt8, MutUntrackedOrigin]):
    _ = external_call["pthread_mutex_unlock", Int32](mu.unsafe_bitcast[Int8]())


def _wait(
    cv: Pointer[UInt8, MutUntrackedOrigin],
    mu: Pointer[UInt8, MutUntrackedOrigin],
):
    _ = external_call["pthread_cond_wait", Int32](
        cv.unsafe_bitcast[Int8](), mu.unsafe_bitcast[Int8]()
    )


def _signal(cv: Pointer[UInt8, MutUntrackedOrigin]):
    _ = external_call["pthread_cond_signal", Int32](cv.unsafe_bitcast[Int8]())


def _wake(fd: Int):
    """Make the worker's sleeping ``Reactor.poll`` return. The wake fd is
    an eventfd on Linux (8 bytes) and a pipe on macOS (1 byte); ``poll``
    drains either."""
    var buf = stack_allocation[8, UInt8]()
    buf[0] = UInt8(1)
    for i in range(1, 8):
        buf[i] = UInt8(0)
    var n = 1
    comptime if CompilationTarget.is_linux():
        n = 8
    _ = external_call["write", Int](c_int(fd), buf, c_size_t(n))


def _getpid() -> Int:
    return Int(external_call["getpid", Int32]())


struct _Ring(Movable):
    """A fixed-size FIFO of ``Int`` shared between threads; the caller
    holds the lock that guards it.

    Head, count and slots live in one heap block and every access is an
    atomic load or store. Plain fields were read once and kept in a
    register across ``pthread_cond_wait``, so a sleeping thread never
    saw the job pushed while it slept.
    """

    var addr: Int
    """Heap block: ``[head, count, slot 0, slot 1, ...]``."""
    var cap: Int

    def __init__(out self, cap: Int):
        self.cap = cap
        var p = alloc(Layout[Int64](count=cap + 2)).unsafe_leak()
        for i in range(cap + 2):
            p[unsafe_offset=i] = Int64(0)
        self.addr = Int(p)

    def _cell(self, i: Int) -> Pointer[Scalar[DType.int64], MutUntrackedOrigin]:
        return Pointer[Scalar[DType.int64], MutUntrackedOrigin](
            unsafe_from_address=self.addr + i * 8
        )

    def _get(self, i: Int) -> Int:
        return Int(Atomic[Int64].load[ordering=Ordering.ACQUIRE](self._cell(i)))

    def _set(self, i: Int, v: Int):
        Atomic[Int64].store[ordering=Ordering.RELEASE](self._cell(i), Int64(v))

    def count(self) -> Int:
        return self._get(1)

    def push(self, v: Int) -> Bool:
        """Append ``v``; False when full."""
        var head = self._get(0)
        var count = self._get(1)
        if count >= self.cap:
            return False
        self._set(2 + (head + count) % self.cap, v)
        self._set(1, count + 1)
        return True

    def pop(self) -> Int:
        """Remove and return the oldest value; 0 when empty."""
        var count = self._get(1)
        if count == 0:
            return 0
        var head = self._get(0)
        var v = self._get(2 + head)
        self._set(0, (head + 1) % self.cap)
        self._set(1, count - 1)
        return v

    def free(self):
        Pointer[Int64, MutUntrackedOrigin](
            unsafe_from_address=self.addr
        ).unsafe_free()


struct _Counter(Movable):
    """One ``Int`` shared between threads, in its own heap cell so every
    read goes to memory; the caller holds the lock that guards it."""

    var addr: Int

    def __init__(out self):
        var p = alloc(Layout[Int64](count=1)).unsafe_leak()
        p[] = Int64(0)
        self.addr = Int(p)

    def _cell(self) -> Pointer[Scalar[DType.int64], MutUntrackedOrigin]:
        return Pointer[Scalar[DType.int64], MutUntrackedOrigin](
            unsafe_from_address=self.addr
        )

    def get(self) -> Int:
        return Int(Atomic[Int64].load[ordering=Ordering.ACQUIRE](self._cell()))

    def set(self, v: Int):
        Atomic[Int64].store[ordering=Ordering.RELEASE](self._cell(), Int64(v))

    def free(self):
        self._cell().unsafe_free()


# ── Job ───────────────────────────────────────────────────────────────────


struct OffloadJob(Movable):
    """One offloaded request, from the worker to a pool thread and back."""

    var req: Request
    """The request. ``req.cancel`` points at :attr:`cell`."""

    var cell: CancelCell
    """The request's cancel cell. The worker flips it on timeout, client
    close or shutdown; the handler can poll it through ``req.cancel``."""

    var handler_addr: Int
    """Address of the worker's top-level handler."""

    var serve: def(Int, Request) raises thin -> Response
    """Runs the handler at ``handler_addr``."""

    var drop_handler: def(Int) thin -> None
    """Frees the handler at ``handler_addr`` with the job: a copy the job
    owns (:func:`offload_submit_owned`), else nothing."""

    var port: Int
    """Address of the worker's ``OffloadPort``."""

    var fd: Int
    """The connection the request came in on."""

    var sid: Int
    """The HTTP/2 stream id, or 0 on HTTP/1.1."""

    var resp: Optional[Response]
    """The handler's response, once it returned one."""

    var err_status: Int
    """Status for a handler that raised (0 when it did not)."""

    var err_reason: String
    """Reason phrase for ``err_status``."""

    def __init__(
        out self,
        var req: Request,
        handler_addr: Int,
        serve: def(Int, Request) raises thin -> Response,
        drop_handler: def(Int) thin -> None,
        port: Int,
        fd: Int,
        sid: Int,
    ) raises:
        var cell = CancelCell()
        req.cancel = cell.handle()
        self.req = req^
        self.cell = cell^
        self.handler_addr = handler_addr
        self.serve = serve
        self.drop_handler = drop_handler
        self.port = port
        self.fd = fd
        self.sid = sid
        self.resp = Optional[Response]()
        self.err_status = 0
        self.err_reason = String("")

    def run(mut self):
        """Run the handler, unless the job was cancelled while queued.

        A handler error is logged and mapped here, as the inline path
        does, so the worker gets a status and reason back."""
        if self.req.cancel.cancelled():
            return
        var request_id = self.req.headers.get("x-request-id")
        try:
            self.resp = self.serve(self.handler_addr, self.req)
        except e:
            log_handler_error(request_id, String(e))
            var mapped = map_handler_error(String(e), self.req.expose_errors)
            self.err_status = mapped.status
            self.err_reason = mapped.reason


def offload_job(addr: Int) -> Pointer[OffloadJob, MutUntrackedOrigin]:
    """The job at ``addr``."""
    return Pool[OffloadJob].get_ptr(addr)


def offload_cancel(addr: Int, reason: Int):
    """Flip job ``addr``'s cancel cell. The worker then forgets the job;
    its result is dropped when it comes back."""
    offload_job(addr)[].cell.flip(reason)


def unavailable_response() -> Response:
    """``503 Service Unavailable`` with ``Retry-After: 1``: the answer
    to a full queue, a timeout and a job skipped at shutdown."""
    var resp = Response(status=503, reason="Service Unavailable")
    try:
        resp.headers.set("Retry-After", "1")
    except:
        pass
    return resp^


# ── Pool ──────────────────────────────────────────────────────────────────


struct _OffloadPool(Movable):
    """The process-wide job queue: a ring of job addresses."""

    var mu: Pointer[UInt8, MutUntrackedOrigin]
    var cv: Pointer[UInt8, MutUntrackedOrigin]
    var queue: _Ring
    var threads: Int
    """Pool threads, resolved from ``offload_threads``."""
    var pid: Int
    """The process that started the pool. A forked child inherits the
    pointer but none of the threads, so it starts its own."""

    def __init__(out self, depth: Int, threads: Int):
        self.mu = _mutex_new()
        self.cv = _cond_new()
        self.queue = _Ring(depth)
        self.threads = threads
        self.pid = _getpid()

    def push(self, job: Int) -> Bool:
        """Queue ``job``; False when the queue is full."""
        _lock(self.mu)
        var queued = self.queue.push(job)
        if queued:
            _signal(self.cv)
        _unlock(self.mu)
        return queued

    def pop(self) -> Int:
        """Take the oldest job, sleeping while the queue is empty."""
        _lock(self.mu)
        while self.queue.count() == 0:
            _wait(self.cv, self.mu)
        var job = self.queue.pop()
        _unlock(self.mu)
        return job


def _pool_cell_init() -> OptionalPointer[NoneType, UntrackedOrigin[mut=True]]:
    var raw = alloc(Layout[Int64](count=1)).unsafe_leak()
    raw.unsafe_write(Int64(0))
    return Pointer[NoneType, UntrackedOrigin[mut=True]](
        unsafe_from_address=Int(raw)
    )


def _pool_cell_keep(p: OptionalPointer[NoneType, UntrackedOrigin[mut=True]]):
    pass


def _pool_slot() -> Pointer[Scalar[DType.int64], MutUntrackedOrigin]:
    """The process-wide cell holding the pool's address (0 before the
    first start)."""
    var p = _get_global["dodo_offload_pool", _pool_cell_init, _pool_cell_keep]()
    return Pointer[Scalar[DType.int64], MutUntrackedOrigin](
        unsafe_from_address=Int(p.value())
    )


def _pool_thread(arg: _OpaquePtr) -> _OpaquePtr:
    """A pool thread: run jobs forever."""
    var pool = Pool[_OffloadPool].get_ptr(Int(arg))
    while True:
        var job = pool[].pop()
        var jp = offload_job(job)
        jp[].run()
        _port_complete(jp[].port, job)
    return _null_ptr()


def _pool_start(threads: Int, depth: Int) raises -> Int:
    """The pool's address, starting it on first use in this process.

    ``threads`` (0 = one per CPU core) and ``depth`` come from whichever
    server starts it first; later servers in the process share it.
    """
    var slot = _pool_slot()
    var current = Atomic[Int64].load[ordering=Ordering.ACQUIRE](slot)
    if current != 0:
        if Pool[_OffloadPool].get_ptr(Int(current))[].pid == _getpid():
            return Int(current)
    var n = threads
    if n <= 0:
        n = num_cpus()
    n = max(n, 1)
    var fresh = Pool[_OffloadPool].alloc_move(_OffloadPool(max(depth, 1), n))
    var expected = current
    if not Atomic[Int64].compare_exchange(slot, expected, Int64(fresh)):
        # Another worker started it first.
        Pool[_OffloadPool].free(fresh)
        return Int(Atomic[Int64].load[ordering=Ordering.ACQUIRE](slot))
    for _ in range(n):
        var arg = _OpaquePtr(unsafe_from_address=fresh)
        var t = ThreadHandle.spawn_os[_pool_thread](arg)
        t.detach()
    return fresh


# ── Per-worker port ───────────────────────────────────────────────────────


struct OffloadPort(Movable):
    """One worker's link to the pool.

    Pool threads touch only ``mu``, ``done``, ``abandoned`` and
    ``wake_fd``; everything else belongs to the worker thread until the
    worker closes the port.
    """

    var mu: Pointer[UInt8, MutUntrackedOrigin]
    var done: _Ring
    """Finished jobs not yet taken by the worker. Never full: it holds
    at most :attr:`cap` jobs, and the worker submits no more than that."""
    var cap: Int
    """Jobs this worker may have out at once: everything the pool can
    hold (queue plus threads)."""
    var abandoned: _Counter
    """One cell: how many jobs were still out when the worker closed the
    port, counted down as they come back (0 while the worker owns it).
    The pool thread that brings back the last one frees the port."""
    var wake_fd: Int
    var pool: Int
    var handler_addr: Int
    """The handler jobs run: the port's own copy, or the worker's
    handler when its type is not ``Copyable``."""
    var serve: def(Int, Request) raises thin -> Response
    var drop_handler: def(Int) thin -> None
    """Frees the handler at ``handler_addr`` with the port."""
    var owns_handler: Bool
    """False when jobs borrow the worker's handler, so the worker must
    wait for every job before it returns."""
    var live: List[Int]
    """Jobs submitted and not yet taken back (worker only)."""

    def __init__(
        out self,
        pool: Int,
        handler_addr: Int,
        serve: def(Int, Request) raises thin -> Response,
        drop_handler: def(Int) thin -> None,
        owns_handler: Bool,
        wake_fd: Int,
    ):
        var p = Pool[_OffloadPool].get_ptr(pool)
        self.cap = p[].queue.cap + p[].threads
        self.mu = _mutex_new()
        self.done = _Ring(self.cap)
        self.abandoned = _Counter()
        self.wake_fd = wake_fd
        self.pool = pool
        self.handler_addr = handler_addr
        self.serve = serve
        self.drop_handler = drop_handler
        self.owns_handler = owns_handler
        self.live = List[Int]()


def _port_free(port_addr: Int):
    """Free a port, its handler copy and its locks."""
    var port = Pool[OffloadPort].get_ptr(port_addr)
    port[].drop_handler(port[].handler_addr)
    port[].done.free()
    port[].abandoned.free()
    _ = external_call["pthread_mutex_destroy", Int32](
        port[].mu.unsafe_bitcast[Int8]()
    )
    port[].mu.unsafe_free()
    Pool[OffloadPort].free(port_addr)


def _port_complete(port_addr: Int, job: Int):
    """Hand ``job`` back to its worker (pool thread side).

    Writes the wake fd only when the list was empty: the worker takes
    the whole list on each wake, so one write per take is enough. The
    write happens under the lock, so it never lands after the worker
    closed the port and its wake fd.

    On a port the worker already closed nobody waits for the job: it is
    freed here, and the last one back frees the port.
    """
    var port = Pool[OffloadPort].get_ptr(port_addr)
    _lock(port[].mu)
    var left = port[].abandoned.get()
    if left > 0:
        port[].abandoned.set(left - 1)
        _unlock(port[].mu)
        offload_free(job)
        if left == 1:
            _port_free(port_addr)
        return
    var was_empty = port[].done.count() == 0
    _ = port[].done.push(job)
    if was_empty:
        _wake(port[].wake_fd)
    _unlock(port[].mu)


def _offload_serve_thunk[
    H: Handler
](addr: Int, req: Request) raises -> Response:
    return Pool[H].get_ptr(addr)[].serve(req).lower()


def _drop_handler_copy[H: Handler](addr: Int):
    Pool[H].free(addr)


def _drop_cancel_handler_copy[CH: CancelHandler](addr: Int):
    Pool[CH].free(addr)


def _keep_handler(addr: Int):
    """The worker owns the handler; the port leaves it alone."""
    pass


def _offload_cancel_serve_thunk[
    CH: CancelHandler
](addr: Int, req: Request) raises -> Response:
    return Pool[CH].get_ptr(addr)[].serve(req, req.cancel)


def _open_port(
    handler_addr: Int,
    serve: def(Int, Request) raises thin -> Response,
    drop_handler: def(Int) thin -> None,
    owns_handler: Bool,
    wake_fd: Int,
    threads: Int,
    depth: Int,
) raises -> Int:
    var pool = _pool_start(threads, depth)
    return Pool[OffloadPort].alloc_move(
        OffloadPort(
            pool, handler_addr, serve, drop_handler, owns_handler, wake_fd
        )
    )


def offload_port_open[
    H: Handler
](ref handler: H, wake_fd: Int, threads: Int, depth: Int) raises -> Int:
    """Open a port for a worker serving ``handler``, starting the pool if
    this is its first user. Returns the port's address.

    A ``Copyable`` handler is copied into the port, so a job still
    running when the worker stops keeps a live handler after the worker
    returns. Any other handler is borrowed, and the worker waits for its
    jobs before it returns."""
    comptime if conforms_to(H, Copyable):
        comptime C = downcast[H, Copyable & Handler]
        var copy = rebind[C](handler).copy()
        return _open_port(
            Pool[C].alloc_move(copy^),
            _offload_serve_thunk[C],
            _drop_handler_copy[C],
            True,
            wake_fd,
            threads,
            depth,
        )
    else:
        return _open_port(
            Int(Pointer[H, _](to=handler)),
            _offload_serve_thunk[H],
            _keep_handler,
            False,
            wake_fd,
            threads,
            depth,
        )


def _no_serve(addr: Int, req: Request) raises -> Response:
    raise Error("offload: this port has no handler of its own")


def offload_port_open_bare(
    wake_fd: Int, threads: Int, depth: Int
) raises -> Int:
    """Open a port whose jobs each bring their own handler copy
    (:func:`offload_submit_call`), for the streaming loop."""
    return _open_port(
        0, _no_serve, _keep_handler, True, wake_fd, threads, depth
    )


def offload_port_open_cancel[
    CH: CancelHandler
](ref handler: CH, wake_fd: Int, threads: Int, depth: Int) raises -> Int:
    """:func:`offload_port_open` for a ``CancelHandler``. Jobs call
    ``serve(req, req.cancel)``, so the handler sees the job's cancel
    cell."""
    comptime if conforms_to(CH, Copyable):
        comptime C = downcast[CH, Copyable & CancelHandler]
        var copy = rebind[C](handler).copy()
        return _open_port(
            Pool[C].alloc_move(copy^),
            _offload_cancel_serve_thunk[C],
            _drop_cancel_handler_copy[C],
            True,
            wake_fd,
            threads,
            depth,
        )
    else:
        return _open_port(
            Int(Pointer[CH, _](to=handler)),
            _offload_cancel_serve_thunk[CH],
            _keep_handler,
            False,
            wake_fd,
            threads,
            depth,
        )


def offload_submit(
    port_addr: Int, var req: Request, fd: Int, sid: Int
) raises -> Int:
    """Queue ``req`` for the pool, to run on the port's handler. Returns
    the job's address, or 0 when the queue is full (the caller answers
    with :func:`unavailable_response`)."""
    var port = Pool[OffloadPort].get_ptr(port_addr)
    return _submit(
        port_addr,
        OffloadJob(
            req^,
            port[].handler_addr,
            port[].serve,
            _keep_handler,
            port_addr,
            fd,
            sid,
        ),
    )


struct OffloadCall(Movable):
    """A request and its own copy of the handler to run it on, not yet
    queued. A streaming front builds one with ``StreamConn.offload``; the
    loop queues it with :func:`offload_submit_call`, or runs it in place
    where there is no pool. Dropping it frees the handler copy."""

    var req: Request
    var handler_addr: Int
    var serve: def(Int, Request) raises thin -> Response
    var drop_handler: def(Int) thin -> None

    def __init__[
        H: Handler & Copyable
    ](out self, handler: H, var req: Request) raises:
        var copy = handler.copy()
        self.handler_addr = Pool[H].alloc_move(copy^)
        self.serve = _offload_serve_thunk[H]
        self.drop_handler = _drop_handler_copy[H]
        self.req = req^

    def __deinit__(deinit self):
        self.drop_handler(self.handler_addr)

    def into_job(deinit self, port_addr: Int, fd: Int) raises -> OffloadJob:
        """The job that runs this call; it owns the handler copy."""
        return OffloadJob(
            self.req^,
            self.handler_addr,
            self.serve,
            self.drop_handler,
            port_addr,
            fd,
            0,
        )

    def run_here(mut self) -> Response:
        """Run the handler on this thread. A handler error becomes its
        mapped status, as on the pool."""
        var request_id = self.req.headers.get("x-request-id")
        try:
            return self.serve(self.handler_addr, self.req)
        except e:
            log_handler_error(request_id, String(e))
            var mapped = map_handler_error(String(e), self.req.expose_errors)
            return Response(status=mapped.status, reason=mapped.reason)


def offload_submit_call(
    port_addr: Int, var call: OffloadCall, fd: Int
) raises -> Int:
    """Queue ``call`` for the pool; the job takes over its handler copy.
    Returns the job's address, or 0 when the queue is full (the copy is
    then freed here)."""
    var addr = call.handler_addr
    var drop = call.drop_handler
    var job = _submit(port_addr, call^.into_job(port_addr, fd))
    if job == 0:
        drop(addr)
    return job


def offload_job_response(job: Int) -> Response:
    """The response job ``job`` came back with: the handler's, its error
    status, or 503 when it never ran."""
    var jp = offload_job(job)
    if jp[].resp:
        return jp[].resp.take()
    if jp[].err_status != 0:
        return Response(status=jp[].err_status, reason=jp[].err_reason)
    return unavailable_response()


def _submit(port_addr: Int, var job: OffloadJob) raises -> Int:
    """Queue ``job``; 0 (and nothing queued) when this worker or the
    pool is full. A job refused here does not free its handler."""
    var port = Pool[OffloadPort].get_ptr(port_addr)
    if len(port[].live) >= port[].cap:
        return 0
    var addr = Pool[OffloadJob].alloc_move(job^)
    if not Pool[_OffloadPool].get_ptr(port[].pool)[].push(addr):
        Pool[OffloadJob].free(addr)
        return 0
    port[].live.append(addr)
    return addr


def offload_take_done(port_addr: Int) -> List[Int]:
    """Take every finished job (worker side). The caller delivers or
    drops each one, then frees it with :func:`offload_free`."""
    var port = Pool[OffloadPort].get_ptr(port_addr)
    var out = List[Int]()
    _lock(port[].mu)
    while port[].done.count() > 0:
        out.append(port[].done.pop())
    _unlock(port[].mu)
    for i in range(len(out)):
        _forget(port[].live, out[i])
    return out^


def _forget(mut live: List[Int], job: Int):
    for i in range(len(live)):
        if live[i] == job:
            live[i] = live[len(live) - 1]
            _ = live.pop()
            return


def offload_free(job: Int):
    """Free a job the worker took back, and the handler copy it owns."""
    var jp = offload_job(job)
    jp[].drop_handler(jp[].handler_addr)
    Pool[OffloadJob].free(job)


def offload_outstanding(port_addr: Int) -> Int:
    """Jobs this worker submitted that have not come back yet."""
    if port_addr == 0:
        return 0
    return len(Pool[OffloadPort].get_ptr(port_addr)[].live)


def offload_cancel_all(port_addr: Int, reason: Int):
    """Flip the cancel cell of every job still out. Queued ones are then
    skipped; running ones see the reason through ``req.cancel``."""
    var port = Pool[OffloadPort].get_ptr(port_addr)
    for i in range(len(port[].live)):
        offload_cancel(port[].live[i], reason)


def offload_port_borrows_handler(port_addr: Int) -> Bool:
    """Whether jobs on this port run the worker's own handler, so the
    worker has to wait for them before it returns."""
    if port_addr == 0:
        return False
    return not Pool[OffloadPort].get_ptr(port_addr)[].owns_handler


def offload_port_close(port_addr: Int):
    """Close a worker's port. Jobs already back are freed; jobs still on
    the pool are left to it, and the last one back frees the port. The
    worker flips their cancel cells first (:func:`offload_cancel_all`)
    and must not touch the port afterwards."""
    if port_addr == 0:
        return
    var port = Pool[OffloadPort].get_ptr(port_addr)
    _lock(port[].mu)
    var back = List[Int]()
    while port[].done.count() > 0:
        back.append(port[].done.pop())
    var out = len(port[].live) - len(back)
    if out > 0:
        port[].abandoned.set(out)
    _unlock(port[].mu)
    for i in range(len(back)):
        offload_free(back[i])
    if out == 0:
        _port_free(port_addr)
