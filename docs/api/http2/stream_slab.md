# `dodo.http2.stream_slab`

HTTP/2 per-connection stream slab.

The per-connection :class:`dodo.http2.state.Connection` keeps a
table of every open / half-closed / recently-closed stream so the
state machine can resolve incoming frames against the right stream
in O(1). Stream IDs are dense small integers per RFC 9113 §5.1.1
(client streams 1, 3, 5, ..., server streams 2, 4, 6, ...) and
``SETTINGS_MAX_CONCURRENT_STREAMS`` is typically a few hundred --
the working set of "open" stream IDs at any instant is small.

An earlier implementation stored streams in a generic
``Dict[StreamId, Stream]``. The hash + Robin-Hood eviction is
overhead the dense-small-int key shape doesn't need, which is
why this slab replaces it.

## Design

``StreamSlab`` is a two-tier container parametric over the stream
value type ``S``. The slab is defined in this leaf module so the
state machine module can depend on the slab without forcing the
slab to know the concrete ``Stream`` shape (which would create a
``state <-> stream_slab`` cycle).

For stream IDs in the hot range ``[0, FAST_CAPACITY)`` (256 by
default; covers every typical browser-driven h2 connection because
the default ``SETTINGS_MAX_CONCURRENT_STREAMS`` is 100, and IDs
are recycled as streams close) the slab routes accesses through
a flat ``List[Optional[S]]`` indexed by the stream ID directly.
No hashing, no probing, no eviction -- just an array lookup and
an ``Optional`` discriminator. The fast path is the entire body
of every method when the ID fits, which matches the plaintext
fast path's "do the cheapest thing if you can" principle.

When a stream ID exceeds ``FAST_CAPACITY`` (long-running h2
connections that have churned through enough streams to overflow
the dense range, or peers that send unusually high client-chosen
IDs) the slab falls through to a chained ``Dict[Int, S]`` with
the same semantics as the fast path. The overflow
Dict only allocates on first use, so connections that never
exceed the fast range pay zero extra cost over the prior code.

## API

Drop-in replacement for ``Dict[Int, S]`` at every call site in
:mod:`dodo.http2.state` and the surrounding ``server`` /
``client`` modules. Specifically:

- ``slab[sid]`` -- copy out the value at ``sid``. Raises if
  absent (matches ``Dict.__getitem__``).
- ``slab[sid] = value`` -- insert or overwrite.
- ``sid in slab`` -- O(1) membership check.
- ``slab.get(sid)`` -> ``Optional[S]`` -- non-raising read.
- ``len(slab)`` -- total count across both tiers.
- ``slab.items()`` -- eager copy out a list of ``(sid, value)``
  tuples for callers that need to scan the table
  (``Http2Connection.take_completed_streams`` is the only caller).

Nothing about the API is hidden inside the Dict-or-slab choice:
both tiers see the same operations, and the slab boundary is the
type whose internals can swap in future perf-gated commits without
touching call sites.

## Aliases

### `FAST_CAPACITY`

```mojo
comptime FAST_CAPACITY = Int(256)
```

## Structs

### `StreamSlab`

```mojo
struct StreamSlab[S: SlabEntry & Copyable & Deinitable]
```

Dense small-int stream table parametric over the value type ``S``.

Owns every per-stream ``S`` value the HTTP/2 connection has
open. See module docstring for the design rationale.

Fields:

- `fast` (`List[Optional[S]]`): ``FAST_CAPACITY`` slots indexed by stream ID. ``None`` for empty slots, ``Some(value)`` for occupied ones. Allocated once at construction; never resized.
- `fast_count` (`Int`): Number of occupied slots in :attr:`fast`. Maintained on every ``__setitem__`` so :meth:`__len__` is O(1).
- `overflow` (`Dict[Int, S]`): Spillover for stream IDs >= ``FAST_CAPACITY``. Lazily populated; empty on most connections.
- `overflow_count` (`Int`): Count of entries in :attr:`overflow`. Avoids a ``len(self.overflow)`` walk on every ``__len__`` call.
- `active` (`Int`): Entries whose ``slab_active()`` holds, kept exact by every write.
- `ready` (`List[Int]`): Ids whose ``slab_ready()`` holds, ascending.

Implemented traits: `AnyType`, `Copyable`, `Defaultable`, `Deinitable`, `Movable`, `Sized`

#### `StreamSlab.__init__`

```mojo
def __init__(out self)
```

#### `StreamSlab.__getitem__`

```mojo
def __getitem__(self, sid: Int) raises -> ref[self] S
```

Read-only view of the value at ``sid``.

Raises if ``sid`` is not present, matching
``Dict.__getitem__`` semantics so existing call sites
that gate on a prior ``sid in slab`` check don't change.
Writes go through ``__setitem__`` / ``pop`` so the tracked
count and ready list stay exact.

#### `StreamSlab.__setitem__`

```mojo
def __setitem__(mut self, sid: Int, var value: S)
```

#### `StreamSlab.__contains__`

```mojo
def __contains__(self, sid: Int) -> Bool
```

#### `StreamSlab.pop`

```mojo
def pop(mut self, sid: Int) raises -> S
```

Remove and return the value at ``sid``.

Raises if absent, matching ``Dict.pop`` semantics. The
slot is cleared so a subsequent ``__setitem__`` at the
same ``sid`` overwrites without leaking the prior value.

#### `StreamSlab.get`

```mojo
def get(self, sid: Int) -> Optional[S]
```

Non-raising read.

Returns ``None`` if absent. The caller does its own
copy; we return ``Optional[Self.S]`` so the slab keeps
ownership of the slot.

#### `StreamSlab.__len__`

```mojo
def __len__(self) -> Int
```

#### `StreamSlab.active_count`

```mojo
def active_count(self) -> Int
```

Entries whose ``slab_active()`` holds.

#### `StreamSlab.ready_ids`

```mojo
def ready_ids(self) -> List[Int]
```

Ids whose ``slab_ready()`` holds, ascending.

#### `StreamSlab.ids`

```mojo
def ids(self) -> List[Int]
```

Every id present, fast tier ascending, then the overflow tier.

#### `StreamSlab.items`

```mojo
def items(self) -> List[Tuple[Int, S]]
```

Eager copy of every ``(sid, value)`` pair.

Used by :meth:`dodo.http2.server.Http2Connection.take_completed_streams`
to scan the table for streams whose request is fully
buffered. The call already copies every entry, so the
eager-copy semantics here add no real cost over the prior
Dict iteration. Future bench-gated commit may expand this
to a true iterator if a hot-path use materializes.

## Traits

### `SlabEntry`

```mojo
trait SlabEntry
```

What the slab tracks about each entry without scanning the table.

Inherits from: `AnyType`

#### `SlabEntry.slab_active`

```mojo
def slab_active(self) -> Bool
```

Whether the entry counts toward the active total.

#### `SlabEntry.slab_ready`

```mojo
def slab_ready(self) -> Bool
```

Whether the entry belongs in the ready list.
