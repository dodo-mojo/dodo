# `dodo.runtime.pool`

Typed heap-allocator wrapper.

``Pool[T]`` confines ``Pointer.alloc`` / ``free`` /
``unsafe_write`` / ``unsafe_deinit_pointee`` plumbing to one place
so the rest of ``dodo/http`` and ``dodo/runtime`` can stay
pointer-free at the source level. This keeps raw pointers out
of the hot path by giving callers a typed API that owns the
pointer arithmetic.

Today's callers go through ``Pointer[T].alloc(1)`` directly:

```mojo
var p = unsafe_alloc[ConnHandle](1)
if Int(p) == 0:
    raise Error("alloc failed")
p.unsafe_write(ConnHandle(stream^))
var addr = Int(p)
...
var ptr = Pointer[UInt8, MutUntrackedOrigin](
    unsafe_from_address=addr
).unsafe_bitcast[ConnHandle]()
ptr.unsafe_deinit_pointee()
ptr.free()
```

With ``Pool[T]``, the same flow reads:

```mojo
var addr = Pool[ConnHandle].alloc_move(ConnHandle(stream^))
...
Pool[ConnHandle].free(addr)
```

Same machine code (``Pool`` is a zero-size dispatcher with
``@staticmethod`` methods); narrower public surface; one place to
audit if ownership semantics ever change.

The "Pool" name leaves room for a future implementation that
batches allocations or hands out from a per-connection slab; the
current implementation is one heap allocation per call. The
public API doesn't need to change for that upgrade.

Why is this in ``dodo/runtime/`` rather than each call site?

- Per the criticism: "no ``Pointer`` reaches outside
  ``dodo/runtime/``." Concentrating the unsafe primitives here
  means the rest of the library can stay safe code.
- ``Pool[T]`` is generic enough to serve other modules
  (``Request._params``, future ``StreamingBody`` chunk pools).

## Structs

### `Pool`

```mojo
struct Pool[T: Deinitable & Movable]
```

Typed heap allocator over ``Pointer[T].alloc(1)``.

Stateless — every method is ``@staticmethod``. The struct
exists only to pin the type parameter; instantiating it is
not required.

``alloc_move(value)`` returns the heap address as an ``Int``
so callers can store it in a Mojo-managed structure
(``Dict[Int, Int]``, ``List[Int]``, struct field) without a
typed pointer escaping into user code. ``free(addr)`` runs
``T``'s destructor and releases the memory.

ZST handling: when ``size_of[T]() == 0``, ``alloc[T](1)`` is
rejected by Mojo's stdlib ("size must be greater than zero").
Pool transparently allocates a single placeholder byte via
``alloc[UInt8](1)`` and bitcasts to ``Pointer[T]`` for
the move-in / dereference pattern (which is a no-op for a
zero-byte type). Callers see the same API regardless of
whether ``T`` is ZST.

Threading: each ``Pool[T]`` operation is independent (no
shared state between calls). Multiple threads can call
``alloc_move`` and ``free`` concurrently as long as each
address is owned by exactly one thread at a time.

Implemented traits: `AnyType`, `Deinitable`, `Movable`

#### `Pool.alloc_move`

```mojo
def alloc_move(var value: T) raises -> Int
```

Heap-allocate one ``T``, move ``value`` into it, return the address.

Args:

- `value`: Owned ``T`` to move into the heap cell.

Returns: The cell's address as an ``Int``. Zero is never returned — alloc failure raises.

Raises: Error: When the underlying allocation returns null.

#### `Pool.free`

```mojo
def free(addr: Int)
```

Run ``T``'s destructor at ``addr`` and release the memory.

Idempotent on ``addr == 0`` (no-op). Calling ``free``
twice on the same non-zero ``addr`` is undefined
behaviour — the caller must own the address exactly
once, just as with raw ``Pointer``.

Args:

- `addr`: Address returned by ``Pool[T].alloc_move``, or 0 (no-op).

#### `Pool.get_ptr`

```mojo
def get_ptr(addr: Int) -> Pointer[T, MutUntrackedOrigin]
```

Re-materialise a typed pointer from an address.

For callers that need to dereference the cell (e.g. read /
write a field) without allocating their own
``Pointer`` arithmetic. Returned pointer carries
``MutUntrackedOrigin`` so the Mojo optimiser cannot hoist
loads through it.

Caller is responsible for ensuring ``addr`` is a valid
live pool allocation.

## Traits

### `PoolableConn`

```mojo
trait PoolableConn
```

A client connection an idle-connection pool can hold: the pool calls :meth:`retire` on one it drops (cap reached, idle timeout, pool freed), so the peer is told it is going away.

Inherits from: `AnyType`, `Deinitable`, `Movable`

#### `PoolableConn.retire`

```mojo
def retire(mut self)
```

Close gracefully (GOAWAY / CONNECTION_CLOSE), best effort.
