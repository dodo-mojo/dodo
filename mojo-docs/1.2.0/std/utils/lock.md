# `std.utils.lock`

Implements thread synchronization primitives including spin locks.

This module provides low-level locking mechanisms for thread synchronization,
including spin locks with blocking behavior and scoped lock guards for
automatic lock management. These primitives enable safe concurrent access to
shared resources in multi-threaded code.

## Structs

### `SpinWaiter`

```mojo
struct SpinWaiter
```

A proxy for the C++ runtime's SpinWaiter type.

Fields:

- `storage` (`Pointer[NoneType, MutUntrackedOrigin]`): Pointer to the underlying SpinWaiter instance.

Implemented traits: `AnyType`, `Defaultable`, `Deinitable`, `Movable`

#### `SpinWaiter.__init__`

```mojo
def __init__(out self)
```

Initializes a SpinWaiter instance.

#### `SpinWaiter.__deinit__`

```mojo
def __deinit__(deinit self)
```

Destroys the SpinWaiter instance.

#### `SpinWaiter.wait`

```mojo
def wait(self)
```

Blocks the current task for a duration determined by the underlying policy.

### `BlockingSpinLock`

```mojo
struct BlockingSpinLock
```

A basic locking implementation that uses an integer to represent the owner of the lock.

Fields:

- `counter` (`Atomic[Int64]`): The atomic counter implementing the spin lock.

Implemented traits: `AnyType`, `Defaultable`, `Deinitable`, `Movable`

Aliases:

- `UNLOCKED = Int64(-1)`: Non-zero means locked, -1 means unlocked.

#### `BlockingSpinLock.__init__`

```mojo
def __init__(out self)
```

Default constructor.

#### `BlockingSpinLock.lock`

```mojo
def lock(mut self, owner: Int)
```

Acquires the lock.

Args:

- `owner`: The lock's owner (usually an address).

#### `BlockingSpinLock.unlock`

```mojo
def unlock(mut self, owner: Int) -> Bool
```

Releases the lock.

Args:

- `owner`: The lock's owner (usually an address).

Returns: The successful release of the lock.

### `BlockingScopedLock`

```mojo
struct BlockingScopedLock[origin: MutOrigin, //]
```

A scope adapter for BlockingSpinLock.

Fields:

- `lock` (`Pointer[BlockingSpinLock, origin]`): The underlying lock instance.

Implemented traits: `AnyType`, `Deinitable`, `Movable`

Aliases:

- `LockType = BlockingSpinLock`: The type of the lock.

#### `BlockingScopedLock.__init__`

```mojo
def __init__(out self, lock: Pointer[BlockingSpinLock, origin])
```

Primary constructor.

Args:

- `lock`: A pointer to the underlying lock.

```mojo
def __init__(out self, ref[origin] lock: BlockingSpinLock)
```

Secondary constructor.

Args:

- `lock`: A mutable reference to the underlying lock.

#### `BlockingScopedLock.__enter__`

```mojo
def __enter__(mut self)
```

Acquire the lock on entry. This is done by setting the owner of the lock to own address.

#### `BlockingScopedLock.__exit__`

```mojo
def __exit__(mut self)
```

Release the lock on exit. Reset the address on the underlying lock.
