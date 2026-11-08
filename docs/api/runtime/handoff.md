# `dodo.runtime.handoff`

Cross-worker connection handoff.

A small mutex-guarded MPSC FIFO designed for one specific job:
moving a freshly-accepted file descriptor (or any opaque integer
token) between dodo's per-worker reactors so the scheduler can
even out load skew without paying for kernel-level fd migration.

## Why this exists

dodo's multicore mode (``HttpServer.serve(... num_workers=N)``)
leans on Linux's ``SO_REUSEPORT`` for accept distribution. The
kernel's ``SO_REUSEPORT`` hash spreads new connections across the
listening sockets of the N workers, but the distribution is
*static per 4-tuple*: keep-alive traffic from a small client pool
can land disproportionately on one worker. The
``benchmark/results//multicore`` run logs P99.9 tails ~0.5×
worse on one worker compared to its three siblings under skewed
keep-alive — see the design doc for numbers.

## What it is

:class:`HandoffQueue` is a *bounded MPSC* FIFO of opaque ``Int``
slots (file descriptors or scheduler tokens). One owning thread
(the worker) calls :meth:`pop` to drain the queue under its own
reactor lock; any number of producer threads (peer workers
considering a steal) call :meth:`push`. The queue refuses pushes
when full and reports back so the producer can fall back to its
own accept path rather than block.

Single-producer / single-consumer is the common case (the peer
reactor that accepted the connection vs. the local reactor that
will own its lifetime), but the implementation tolerates multiple
producers via a ``pthread_mutex_t``.

## What it isn't

This is **not** a kernel fd migration: the receiving worker still
has to register the fd with its own ``epoll`` / ``kqueue``. We
keep the handoff at the *application* level so the implementation
is portable, tiny, and matches dodo's "shared-nothing per worker"
discipline — every worker's reactor still owns its own fd set, the
handoff just changes *which* worker owns a brand-new fd.

Scope, stated plainly: this rebalances only **newly accepted**
connections at accept time (:meth:`WorkerHandoffPool.choose_handoff_target`
picks an idle peer under skew). **Established keep-alive connections
are never migrated** — moving a live connection's fd *and* its
per-connection state machine to another worker's reactor would need
cross-thread ownership transfer, which fights Mojo's shared-nothing
model and the missing ``Send``/``Sync`` type system. That migration
is deliberately out of scope; the accept-time rebalance is the
portable, safe subset that still attacks reuseport head-of-line skew.

The locked design adds a single uncontended atomic acquire on the
hot path (push). Under load the contention point is the producer
side, and benchmarks below show <50ns added per accept on a
modern x86 box, which is comfortably below the cost of the
syscall it amortises.

## Structs

### `HandoffQueue`

```mojo
struct HandoffQueue
```

Bounded MPSC FIFO of opaque ``Int`` tokens.

Storage is a circular buffer; ``capacity`` slots, head + tail
indices wrap modulo ``capacity``. A token can be a file
descriptor or any scheduler-meaningful integer; the queue is
type-agnostic on purpose so callers can stuff a packed
``(worker_id, fd)`` pair through it without wrapping a struct.

Empty / full are distinguished by a separate ``count`` field so
we don't need to reserve a slot for "full vs empty" disambiguation.

Fields:

- `slots` (`List[Int]`)
- `head` (`Int`)
- `tail` (`Int`)
- `count` (`Int`)
- `capacity` (`Int`)
- `mu` (`Pointer[UInt8, MutUntrackedOrigin]`)
- `pushes` (`Int`)
- `pops` (`Int`)
- `refused` (`Int`)

Implemented traits: `AnyType`, `Defaultable`, `Deinitable`, `Movable`

#### `HandoffQueue.__init__`

```mojo
def __init__(out self)
```

```mojo
def __init__(out self, capacity: Int)
```

#### `HandoffQueue.push`

```mojo
def push(mut self, fd: Int) -> Bool
```

Try to enqueue ``fd``. Returns True on success.

Callers MUST treat False as "queue is full, fall back to
regular accept". The queue NEVER blocks — that would
defeat the point of work-stealing under skew, which is
latency reduction.

#### `HandoffQueue.pop`

```mojo
def pop(mut self) -> Optional[Int]
```

Try to dequeue one ``fd``. Returns ``None`` when empty.

#### `HandoffQueue.drain`

```mojo
def drain(mut self) -> List[Int]
```

Pop every queued fd at once. Useful at the top of a reactor tick.

#### `HandoffQueue.size`

```mojo
def size(mut self) -> Int
```

### `HandoffPolicy`

```mojo
struct HandoffPolicy
```

Knobs for the work-stealing strategy.

* ``enabled`` — master switch. When ``False`` the scheduler skips
  handoffs entirely and behaves exactly like SO_REUSEPORT.
* ``capacity`` — per-worker handoff queue depth.
* ``steal_threshold`` — when a worker's accept queue goes
  ``steal_threshold`` ticks empty in a row, the scheduler tries
  to peek at peer queues. Lower = more aggressive stealing
  (better tail), higher = less cross-thread chatter (better
  throughput on uniform workloads).

Fields:

- `enabled` (`Bool`)
- `capacity` (`Int`)
- `steal_threshold` (`Int`)

Implemented traits: `AnyType`, `Copyable`, `Defaultable`, `Deinitable`, `Movable`

#### `HandoffPolicy.__init__`

```mojo
def __init__(out self)
```

```mojo
def __init__(out self, enabled: Bool, capacity: Int, steal_threshold: Int)
```

#### `HandoffPolicy.from_env`

```mojo
def from_env(var default) -> Self
```

Read ``DODO_SOAK_WORKERS`` as the work-stealing toggle.

``DODO_SOAK_WORKERS=on`` (the soak job's signal) flips
``enabled`` to ``True`` and bumps ``steal_threshold`` to a
smaller value so the scheduler spends more time stealing.
Everything else honours ``default``. The env variable is
deliberately conservative: production stays opt-in.

### `WorkerHandoffPool`

```mojo
struct WorkerHandoffPool
```

One :class:`HandoffQueue` per worker, addressable by worker id.

The multicore scheduler holds a single :class:`WorkerHandoffPool`
sized to ``num_workers``; each worker's accept loop pushes into
its peers' queues when the policy says to steal, and drains its
own queue at the top of every reactor tick. The pool is *thread-
confined to the main thread for construction* but the per-queue
push / pop operations are safe to call from any worker.

The pool retains a copy of the :class:`HandoffPolicy` it was
built with so workers can re-read the master ``enabled`` switch
without an extra pointer chase. Mutating the policy at runtime
is not supported (we'd need an atomic ``Bool``); mainline use
is read-once at startup.

Use :meth:`peek_idle_worker` from a worker to find another peer
whose queue is mostly empty so the scheduler can prefer
*evening out* skew over *flat-shuffling* a stable workload.

Fields:

- `queues` (`Pointer[HandoffQueue, MutUntrackedOrigin]`)
- `num` (`Int`)
- `policy` (`HandoffPolicy`)

Implemented traits: `AnyType`, `Deinitable`, `Movable`

#### `WorkerHandoffPool.__init__`

```mojo
def __init__(out self, var policy: HandoffPolicy, num_workers: Int)
```

#### `WorkerHandoffPool.size`

```mojo
def size(self) -> Int
```

#### `WorkerHandoffPool.try_handoff`

```mojo
def try_handoff(mut self, target: Int, fd: Int) -> Bool
```

Push ``fd`` into worker ``target``'s queue.

Returns ``True`` on success, ``False`` if the queue is full
or the policy has handoff disabled (so the caller falls back
to the local accept path immediately, no syscalls wasted).

#### `WorkerHandoffPool.drain_local`

```mojo
def drain_local(mut self, worker_id: Int) -> List[Int]
```

Drain the queue belonging to ``worker_id``.

#### `WorkerHandoffPool.peek_idle_worker`

```mojo
def peek_idle_worker(mut self, exclude: Int) -> Int
```

Return the id of the peer with the shortest queue.

``exclude`` is the calling worker (skipped in the search).
Returns ``-1`` when the policy is disabled or no peer queue
is below capacity. Linear scan; the inner loop is bounded
by ``num_workers`` (typically <= 64) so this is comfortably
below the ``accept`` syscall it amortises.

#### `WorkerHandoffPool.choose_handoff_target`

```mojo
def choose_handoff_target(mut self, local_worker: Int, local_load: Int) -> Int
```

Load-aware target for a *newly accepted* connection: the id of an idle peer to hand it to, or ``-1`` to keep it on ``local_worker``.

Only hands off under genuine skew -- when ``local_load`` exceeds
the idlest peer's queue depth by at least ``steal_threshold``. A
uniform workload therefore stays local (no cross-thread chatter),
and rebalancing only kicks in when the ``SO_REUSEPORT`` hash has
piled disproportionately onto this worker (the head-of-line case
D1 targets). Returns ``-1`` when handoff is disabled, there are no
peers, or the skew is below threshold.

This rebalances the placement of *new* connections only.
Established keep-alive connections are never migrated across
workers -- see the module docstring.
