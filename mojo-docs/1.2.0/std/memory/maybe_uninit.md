# `std.memory.maybe_uninit`

Implements `MaybeUninit`, a wrapper for memory that may or may not be initialized.

## Structs

### `MaybeUninit`

```mojo
struct MaybeUninit[T: AnyType]
```

Holds memory that may or may not contain an initialized `T`.

`MaybeUninit[T]` helps enable low level code deal with uninitialized data.

```mojo
# The compiler knows `uninit` may contain uninitialized data, so it
# makes no assumptions.
var uninit = MaybeUninit[Int]()
uninit.unsafe_write(42)

# SAFETY: `uninit` now contains an initialized `Int`.
print(uninit.unsafe_assume_init()) # 42
```

However, improper usage of this type can lead to undefined behavior:

```mojo
var uninit = MaybeUninit[Int]()
# Undefined Behavior: reading uninitialized memory 👻
print(uninit.unsafe_assume_init())
```

## Examples

### Out-arguments across C-FFI

A C function that fills an out-argument writes into memory the caller
provides. Without `MaybeUninit[T]`, you'd need a placeholder value to point
at, even though the call is about to overwrite it entirely. Because
`MaybeUninit[T]` has the same layout as `T`, you can pass it directly as the
out-pointer and skip constructing a placeholder.

```mojo
from std.ffi import external_call, c_long, c_int
from std.memory import MaybeUninit

struct CTimeSpec(ImplicitlyCopyable, Writable):
    var tv_sec: c_long
    var tv_nsec: c_long

def main():
    # Create an uninitialized `CTimeSpec`
    var spec = MaybeUninit[CTimeSpec]()

    # int clock_gettime(clockid_t clockid, struct timespec *res)
    var result = external_call["clock_gettime", c_int](
        c_int(1), # CLOCK_MONOTONIC on linux
        Pointer(to=spec), # out-pointer: clock_gettime() fills this in
    )

    if result == 0:
        # SAFETY: `clock_gettime` succeeded, so `spec` is now initialized.
        print(spec.unsafe_assume_init()) # CTimeSpec(tv_sec=.., tv_nsec=..)

    # On failure, `spec` is left uninitialized and unread.
```

### Uninitialized fields

Wrap a field in `MaybeUninit[T]` to leave it uninitialized rather than
filling it with a placeholder or default value. Track whether it
actually holds a value separately, as this minimal reimplementation of
`Optional` does.

```mojo
from std.memory import MaybeUninit

struct Optional[T: Movable & Deinitable]:
    var storage: MaybeUninit[Self.T]
    var initialized: Bool

    def __init__(out self):
        # No value yet, leave `storage` uninitialized.
        self.storage = {}
        self.initialized = False

    def __init__(out self, var value: Self.T):
        self.storage = {value^}
        self.initialized = True

    def __init__(out self, *, deinit move: Self):
        self.storage = {}
        self.initialized = move.initialized

        # If `move` was initialized, write its contents into our storage.
        if move.initialized:
            self.storage.unsafe_write(move.storage^.unsafe_assume_init())
        else:
            move.storage^.unsafe_forget()

    def __deinit__(deinit self):
        # If we're initialized, call the `__deinit__` on the held value,
        # otherwise we can just forget the storage.
        if self.initialized:
            self.storage^.unsafe_deinit()
        else:
            self.storage^.unsafe_forget()
```

## Deinitialization, moving, and copying

Unlike `T`, a `MaybeUninit[T]` does not automatically perform `T`'s
lifecycle operations. Its lifecycle trait conformances depend on whether
those operations can be performed trivially:

- `MaybeUninit[T]` is `Movable` when `T` is trivially movable.
- `MaybeUninit[T]` is `ImplicitlyCopyable` when `T` is trivially copyable.
- `MaybeUninit[T]` is `Deinitable` when `T` is trivially deinitializable.

This matters most for types with non-trivial implicit deinitializers. To
prevent accidental resource leaks, if `T` is not trivially deinitializable,
`MaybeUninit[T]` is an explicitly destroyed type and must be consumed.

`String` is not trivially deinitializable, so `MaybeUninit[String]` is not
`Deinitable`.

```mojo
var uninit = MaybeUninit[String]()
# error: `uninit` abandoned without being explicitly destroyed
```

Use `unsafe_deinit()` when the storage contains a live `T` whose
deinitializer must run.

```mojo
var uninit = MaybeUninit[String]()
uninit.unsafe_write("hello")
# SAFETY: `uninit` contains a live `String`.
uninit^.unsafe_deinit()
```

Use `unsafe_forget()` when the storage does not contain a live `T`:

```mojo
var uninit = MaybeUninit[String]()
# SAFETY: Nothing was ever written into the storage, so there is no `String`
# to destroy.
uninit^.unsafe_forget()
```

`String` also demonstrates why these lifecycle operations are independent.
A `String` is trivially movable, so `MaybeUninit[String]` can itself be
moved:

```mojo
var uninit = MaybeUninit[String]()
uninit.unsafe_write("hello")
var moved = uninit^ # OK: `String` is trivially movable.
```

However, `String` is not trivially copyable so `MaybeUninit[String]` is not
`ImplicitlyCopyable`. Copying it implicitly is a compile-time error.

```mojo
var uninit = MaybeUninit[String]()
var copy = uninit # error: `MaybeUninit[String]` is not `ImplicitlyCopyable`
```

For types such as `Int` that are trivially movable, copyable, and
deinitializable, all of these conditions are satisfied and
`MaybeUninit[Int]` behaves like an ordinary trivial value.

```mojo
var uninit = MaybeUninit[Int]()
var copy = uninit # OK: Int is trivially copyable
var moved = uninit^ # OK: Int is trivially movable
# OK: No need to explicitly consume `MaybeUninit[Int]` since `Int` is
# trivially deinitializable.
```

## Layout

`MaybeUninit[T]` has the same size and alignment as `T`:
- `size_of[MaybeUninit[T]]() == size_of[T]()`
- `align_of[MaybeUninit[T]]() == align_of[T]()`

Parameters:

- `T`: The held element type of the wrapper.

Implemented traits: `AnyType`, `Copyable`, `Defaultable`, `Deinitable`, `ImplicitlyCopyable`, `Movable`, `RegisterPassable`

#### `MaybeUninit.__init__`

```mojo
def __init__(out self)
```

Construct a `MaybeUninit` in an uninitialized state.

```mojo
def __init__(out self, var value: T, /) where conforms_to(T, Movable)
```

Construct a `MaybeUninit` in an initialized state.

Args:

- `value`: The value to initialize the memory with.

#### `MaybeUninit.zeroed`

```mojo
def zeroed(out result)
```

Construct a `MaybeUninit` in an uninitialized state, with the memory set to all 0 bytes.

It depends on `T` whether zeroed memory makes for proper initialization.
For example, `MaybeUninit[Int].zeroed()` is initialized,
but `MaybeUninit[String].zeroed()` is not.

Returns: A `MaybeUninit` with the memory set to all 0 bytes.

#### `MaybeUninit.write`

```mojo
def write(mut self, var value: T, /) where conforms_to(T, Movable) and conforms_to(T, TrivialRegisterPassable) if conforms_to(T, TrivialRegisterPassable) else T.__del__is_trivial if conforms_to(T, Deinitable) else conforms_to(T, Deinitable)
```

Initialize this memory with the given `value`.

This overwrites any previous value in the memory. Unlike
`unsafe_write()`, this is safe to call even when the memory is
already initialized: `T` is constrained to be trivially
deinitializable, so there's no destructor to skip and overwriting
a previous value can't leak a resource.

Args:

- `value`: The value to store in memory.

#### `MaybeUninit.unsafe_write`

```mojo
def unsafe_write(mut self, var value: T, /) where conforms_to(T, Movable)
```

Initialize this memory with the given `value`.

This overwrites any previous value without destroying it.
This means, if a previous `T` existed in the memory, that old instance
will not be destroyed, potentially leading to memory leaks.

If `T` is trivially deinitializable (for example, `Int`), prefer
`write()` instead: it overwrites safely, since there's no
destructor that a previous value could leak.

Safety:

- If the memory is already initialized, calling this leaks the
  previous value: its destructor never runs. Call `unsafe_deinit()`
  first if the previous value needs to be destroyed.

Args:

- `value`: The value to store in memory.

```mojo
def unsafe_write(mut self, *, var init_with: T)
```

Initialize this memory with the value returned by `init_with`.

The value returned by `init_with` is constructed directly into this
memory rather than being constructed elsewhere and then moved, so `T`
does not need to be `Movable`.

```mojo
from std.memory import MaybeUninit

@fieldwise_init
struct Pinned(not Movable):
    var value: Int

var uninit = MaybeUninit[Pinned]()
ref value = uninit.unsafe_write(init_with=lambda () -> Pinned: Pinned(7))
print(value)  # => 7
```

Safety:

- If the memory is already initialized, calling this leaks the
  previous value: its destructor never runs. Call `unsafe_deinit()`
  first if the previous value needs to be destroyed.

Args:

- `init_with`: A function that constructs and returns the value to store in memory.

#### `MaybeUninit.unsafe_assume_init`

```mojo
def unsafe_assume_init(deinit self) -> T where conforms_to(T, Movable)
```

Takes ownership of the contained value.

Calling this method assumes that the memory is initialized. The
value is moved out of the `MaybeUninit` and returned to the
caller. After this call, the memory is considered uninitialized.

Safety:

- The memory must be initialized with a live `T` value. Calling this
  on uninitialized memory reads an invalid bit pattern as `T`, which
  is undefined behavior.

Returns: The initialized value that was stored in this container.

```mojo
def unsafe_assume_init(ref self) -> ref[self_is_mut] T
```

Returns a reference to the internal value.

Calling this method assumes that the memory is initialized.

Safety:

- The memory must be initialized with a live `T` value. Calling this
  on uninitialized memory produces a reference to an invalid bit
  pattern, which is undefined behavior if the reference is read.

Returns: A reference to the internal value.

#### `MaybeUninit.unsafe_deinit`

```mojo
def unsafe_deinit(deinit self) where conforms_to(T, Deinitable)
```

Destroys the contained value.

Calling this method assumes that the memory is initialized. It runs
`T`'s destructor on the contained value. After this call, the memory
is considered uninitialized.

Safety:

- The memory must be initialized with a live `T` value. Calling this
  on uninitialized memory runs `T`'s destructor on an invalid bit
  pattern, which is undefined behavior.

#### `MaybeUninit.unsafe_forget`

```mojo
def unsafe_forget(deinit self)
```

Discards this `MaybeUninit` without destroying its contents.

Unlike `unsafe_deinit()`, this does not run `T`'s destructor. Use
this when the memory is uninitialized, or when the contained value
has already been disposed of some other way.

Safety:

- If the memory is initialized with a value that owns a resource
  (for example, an allocation), calling this leaks that resource:
  its destructor never runs. Call `unsafe_deinit()` instead if the
  value needs to be destroyed.

#### `MaybeUninit.unsafe_ptr`

```mojo
def unsafe_ptr(ref self) -> Pointer[T, origin_of(self)]
```

Get a pointer to the underlying element.

Note that this method does not assumes that the memory is initialized
or not. It can always be called.

Safety:

- The returned pointer may point to uninitialized memory. Reading
  through it before the memory is initialized is undefined behavior.

Returns: A pointer to the underlying element.
