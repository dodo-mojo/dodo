# `dodo.runtime.scheduler_stats`

Cross-thread stop flag and per-worker stats cell.

Shared by ``scheduler.mojo`` (which allocates and reads them) and
``_worker.mojo`` (which writes them), so they live here rather than in
either -- importing one from the other would be a cycle.

``scheduler.mojo`` re-exports every name below, so the existing
``from dodo.runtime.scheduler import load_stop_flag`` call sites in
the reactor loops keep working unchanged.

## Aliases

### `WORKER_STAT_INFLIGHT`

```mojo
comptime WORKER_STAT_INFLIGHT = Int(0)
```

Slot index: connections still registered on this worker.

### `WORKER_STAT_STATUS`

```mojo
comptime WORKER_STAT_STATUS = Int(1)
```

Slot index: worker exit status (see ``WORKER_STATUS_*``).

### `WORKER_STAT_DONE`

```mojo
comptime WORKER_STAT_DONE = Int(2)
```

Slot index: 1 once the worker's thread has returned from ``run_worker``, whatever the frontend reported. ``Scheduler.drain`` waits on it with a deadline instead of blocking in ``pthread_join``.

### `WORKER_STAT_GROUP`

```mojo
comptime WORKER_STAT_GROUP = Int(3)
```

Slot index: address of the scheduler's accept-balancing group block (``dodo.runtime._balance``), or 0 when balancing is off.

### `WORKER_STAT_INDEX`

```mojo
comptime WORKER_STAT_INDEX = Int(4)
```

Slot index: this worker's index inside the balancing group.

### `WORKER_STAT_SLOTS`

```mojo
comptime WORKER_STAT_SLOTS = Int(5)
```

Number of Int64 slots per worker cell.

### `WORKER_STATUS_RUNNING`

```mojo
comptime WORKER_STATUS_RUNNING = Int(0)
```

Worker has not exited its serve loop yet.

### `WORKER_STATUS_CLEAN`

```mojo
comptime WORKER_STATUS_CLEAN = Int(1)
```

Worker exited because it observed the stop flag (normal shutdown).

### `WORKER_STATUS_CRASHED`

```mojo
comptime WORKER_STATUS_CRASHED = Int(2)
```

Worker exited because its reactor poll failed (unexpected).

## Functions

### `store_stop_flag`

```mojo
def store_stop_flag(addr: Int, value: Bool)
```

Release-store ``value`` into the heap stop-flag byte at ``addr``.

### `load_stop_flag`

```mojo
def load_stop_flag(addr: Int) -> Bool
```

Acquire-load the heap stop-flag byte at ``addr``.

### `store_worker_stat`

```mojo
def store_worker_stat(base_addr: Int, slot: Int, value: Int)
```

Release-store ``value`` into ``slot`` of the worker stats cell.

### `load_worker_stat`

```mojo
def load_worker_stat(base_addr: Int, slot: Int) -> Int
```

Acquire-load ``slot`` of the worker stats cell (0 when disabled).
