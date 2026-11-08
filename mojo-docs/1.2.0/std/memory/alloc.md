# `std.memory.alloc`

Implements layout-aware memory allocation and deallocation.

This module provides the `alloc` and `dealloc` functions together with a
`Layout` descriptor that expresses the size and alignment of an allocation at
the call site, keeping ownership and layout information explicit and
co-located. A `Layout` holds the element count at runtime and carries the
alignment as a compile-time parameter, which every allocation handle carries
alongside it.

Allocations are represented by two explicitly destroyed
owning handles, so the compiler forces every allocation to be released on all
paths — either by passing it to `dealloc` or by taking the raw pointer with
`unsafe_leak()`:

- `Allocation[T, alignment=_]`: the handle returned by `alloc`. It bundles the
  owning pointer with the `Layout` it was allocated with, so the element count
  needed to free the storage travels with the pointer.
- `ThinAllocation[T]`: a bare owning handle that carries only the pointer,
  with neither a count nor an alignment. It makes a good storage field for a
  container that already tracks its own capacity (such as `List`); pair it back
  with a `Layout` via `unsafe_with_layout` to deallocate.

For automatic cleanup, an `Allocation` can be converted into a
`ManagedAllocation[T, alignment=_]` with `into_managed()`. Unlike the two
explicitly destroyed handles, a `ManagedAllocation` implements `Deinitable`: it
deallocates its storage in its destructor, which Mojo runs automatically after
the value's last use (ASAP destruction), so no explicit `dealloc` is needed.
Like `dealloc`, this frees the storage without running the destructors of any
elements written into it. Because of that, `into_managed()` requires `T` to be
`IsTriviallyDeinitable`: for any other `T`, the skipped destructor call could
silently leak resources owned by elements left in the storage.

Examples:

Allocate, use, and free storage through the `Allocation` returned by `alloc`:

```mojo
from std.memory.alloc import alloc, dealloc, Layout
from std.memory import unsafe_destroy_n

var allocation = alloc(Layout[String](count=4))
var ptr = allocation.unsafe_ptr()

# initialize the memory
for i in range(allocation.layout().count()):
    ptr.unsafe_offset(i).unsafe_write("🔥")

# print the values
for string in allocation.unsafe_span():
    print(string) # prints "🔥"

# deinitialize the values
unsafe_destroy_n(allocation.unsafe_ptr(), allocation.layout().count())

# deallocate the memory
dealloc(allocation^)
```

Drop the `Layout` with `into_thin` to keep only the bare `ThinAllocation` handle,
then re-attach a `Layout` with `unsafe_with_layout` to deallocate:

```mojo
from std.memory.alloc import alloc, dealloc, Layout

var layout = Layout[Int64].single()
var thin = alloc(layout).into_thin()
dealloc(thin^.unsafe_with_layout(layout))
```

Memory safety:

Because `Allocation` and `ThinAllocation` are non-`Deinitable types,
the compiler catches the three classic allocation bugs at compile time, instead
of leaving them as runtime hazards.

An accidental leak is rejected: the compiler requires every `Allocation` to be
destroyed on every path, including error paths. If an intervening operation can
raise, skipping the `dealloc`, that is an error (whose message includes the
guidance from `@explicit_destroy(..)`):

```mojo
from std.memory import alloc, dealloc, Layout

def process() raises:
    var allocation = alloc(Layout[Int].single())
    might_raise()  # ERROR: 'allocation' abandoned without being explicitly destroyed: ...
    dealloc(allocation^)
```

A double-free is rejected: `dealloc` consumes the handle, so a second `dealloc`
is a use of an uninitialized value:

```mojo
from std.memory import alloc, dealloc, Layout

def main():
    var allocation = alloc(Layout[Int].single())
    dealloc(allocation^)
    dealloc(allocation^)  # ERROR: use of uninitialized value 'allocation'
```

A use-after-free is rejected: a pointer obtained from an `Allocation` borrows
from it, so it cannot be accessed once the handle has been consumed:

```mojo
from std.memory import alloc, dealloc, Layout

def main():
    var allocation = alloc(Layout[Int].single())
    var ptr = allocation.unsafe_ptr()
    dealloc(allocation^)
    print(ptr[])  # ERROR: potential indirect access to uninitialized value 'allocation'
```

## Structs

### `Alignment`

```mojo
struct Alignment
```

The byte alignment of a memory allocation.

Implemented traits: `AnyType`, `Copyable`, `Deinitable`, `ImplicitlyCopyable`, `Movable`, `RegisterPassable`, `TrivialRegisterPassable`, `Writable`

#### `Alignment.of`

```mojo
def of[T: AnyType, /]() -> Self
```

Returns the natural alignment of `T`.

Parameters:

- `T`: The type whose `align_of` to use.

Returns: An `Alignment` of `align_of[T]()` bytes.

#### `Alignment.of_bytes`

```mojo
def of_bytes[n: Int, /]() -> Self
```

Returns an alignment of exactly `n` bytes.

Constraints: `n` must be a power of two.

Parameters:

- `n`: The byte alignment.

Returns: An `Alignment` of `n` bytes.

#### `Alignment.bytes`

```mojo
def bytes(self) -> Int
```

Returns the byte alignment.

Returns: The byte alignment.

#### `Alignment.write_to`

```mojo
def write_to(self, mut writer: T)
```

Writes a human-readable representation of this alignment to `writer`.

Args:

- `writer`: The writer to write to.

### `Allocation`

```mojo
struct Allocation[T: AnyType, *, alignment: Alignment = Alignment.of[T]()]
```

An owning handle to a heap allocation of `T` together with its `Layout`.

An `Allocation` pairs a `ThinAllocation` (the raw owning pointer) with the
`Layout` that produced it, so the element count needed to deallocate the
storage travels with the pointer. It is the value returned by `alloc`.

`Allocation` is an explicitly destroyed type: it is
never deallocated automatically, and the compiler requires every value to be
destroyed manually on all paths. This prevents accidental leaks and
double-frees. Destroy one by either:

- passing it to `dealloc` to deallocate the storage,
- calling `unsafe_leak()` to take ownership of the raw pointer (the caller
  then becomes responsible for manually deallocating it), or
- calling `into_thin()` to drop the `Layout` and keep the owning
  `ThinAllocation`.

Example:

```mojo
from std.memory.alloc import alloc, dealloc, Layout

var allocation = alloc(Layout[Int32](count=4))
# use the allocation...
dealloc(allocation^)
```

Parameters:

- `T`: The type of the elements stored in the allocation.
- `alignment`: Byte alignment of the storage, matching the `Layout` it was allocated with.

Implemented traits: `AnyType`, `Movable`, `RegisterPassable`, `Sized`, `Writable`

#### `Allocation.__init__`

```mojo
def __init__(var managed: ManagedAllocation[T, alignment=alignment]) -> Self
```

Implicitly convert a `ManagedAllocation` into an `Allocation`.

Args:

- `managed`: The `ManagedAllocation` to convert.

```mojo
def __init__(*, unsafe_owned_ptr: Pointer[T, MutUntrackedOrigin], layout: Layout[T, alignment=alignment]) -> Self
```

Initializes a `Allocation` that takes ownership of a raw pointer.

Safety:

- The pointer must own storage that was previously created though
`alloc`, and no other value may own it.
- The provided `layout` must also exactly match the layout initially
passed to `alloc` which created this `Allocation`.

Args:

- `unsafe_owned_ptr`: The raw pointer to take ownership of. The new `Allocation` assumes responsibility for deallocating this storage.
- `layout`: The associated layout.

#### `Allocation.unsafe_leak`

```mojo
def unsafe_leak(deinit self) -> Pointer[T, MutUntrackedOrigin]
```

Consumes the `Allocation` and returns its raw owning pointer.

`Allocation` is an explicitly destroyed type: it is never deallocated
automatically, and the compiler requires every value to be destroyed
manually. This method is one such destructor — it consumes the handle
and returns the raw pointer, which the compiler no longer tracks. The
caller then owns the storage and must deallocate it manually by wrapping
the pointer in a `ThinAllocation`, pairing it with its `Layout`, and
passing the result to `dealloc`.

Safety:

Leaking hands manual responsibility for the storage to the caller.
Because the compiler no longer tracks the returned pointer, forgetting
to deallocate it leaks the memory.

Returns: The raw pointer to the allocated storage.

#### `Allocation.unsafe_ptr`

```mojo
def unsafe_ptr(ref self) -> Pointer[T, origin_of(self._alloc)]
```

Returns a pointer to the allocated storage without consuming `self`.

The returned pointer borrows from `self`, so the `Allocation` retains
ownership of the storage and remains responsible for deallocating it.

Safety:

`alloc` returns uninitialized storage, so the returned pointer may point
to uninitialized memory. Initialize an element (for example with
`unsafe_write`) before reading it.

Returns: A pointer to the allocated storage.

#### `Allocation.unsafe_span`

```mojo
def unsafe_span(ref self) -> Span[T, origin_of(self._alloc)]
```

Returns a span over the allocated storage without consuming `self`.

The returned span borrows from `self`, so the `Allocation` retains
ownership of the storage. The span covers `layout.count()` elements.

Safety:

`alloc` returns uninitialized storage, so the returned span may cover
uninitialized memory. Initialize the elements before reading them.

Returns: A span over the allocated storage.

#### `Allocation.layout`

```mojo
def layout(self) -> Layout[T, alignment=alignment]
```

Returns the `Layout` the storage was allocated with.

The returned `Layout` carries the element count used to allocate the
storage — the same information needed to deallocate it.

Returns: The `Layout` this allocation was created with.

#### `Allocation.__len__`

```mojo
def __len__(self) -> Int
```

Returns the number of elements the storage was allocated for.

Returns: `layout().count()`, the element count this allocation was created with.

#### `Allocation.storage`

```mojo
def storage(ref self) -> Span[MaybeUninit[T], origin_of(self._alloc)]
```

Returns a span over the allocated storage as possibly uninitialized elements.

Returns: A span of `MaybeUninit[T]` over the allocated storage.

#### `Allocation.into_thin`

```mojo
def into_thin(deinit self) -> ThinAllocation[T]
```

Consumes the `Allocation` and returns its associated `ThinAllocation`.

This drops the `Layout` and keeps only the owning handle. The returned
`ThinAllocation` must be consumed in turn.

Returns: The `ThinAllocation` that owns the storage.

#### `Allocation.into_managed`

```mojo
def into_managed(deinit self) -> ManagedAllocation[T, alignment=alignment] where conforms_to(T, TrivialRegisterPassable) or T.__del__is_trivial if conforms_to(T, Deinitable) else conforms_to(T, Deinitable)
```

Consumes the `Allocation` and wraps it in a `ManagedAllocation`.

This converts the explicitly destroyed handle into a self-freeing
one. The returned `ManagedAllocation` deallocates the storage in
its destructor, which Mojo runs automatically after the value's last use
(ASAP destruction), so — unlike `Allocation` — it does not need to be
passed to `dealloc`. Use this when you want automatic deallocation
instead of explicit destruction.

Converting to a `ManagedAllocation` does not destroy any values
you have initialized in the storage: no element destructors are run,
either by this conversion or when the `ManagedAllocation` is later
destroyed. If the elements need their destructors run, destroy them
yourself (for example with `unsafe_destroy_n`) before the
`ManagedAllocation` is destroyed.

Example:

```mojo
from std.memory.alloc import alloc, Layout

var managed = alloc(Layout[String](count=4)).into_managed()
managed.unsafe_ptr().unsafe_write("hello")

# Even though the allocation is automatically cleaned up, destructors
# must still be manually run!
std.memory.unsafe_destroy_n(managed.unsafe_ptr(), 1)

# No `dealloc` needed: `managed` frees its storage when destroyed.
```

Constraints: `T` must be `IsTriviallyDeinitable`. Because a `ManagedAllocation`
never runs `T`'s `__deinit__`, allowing a non-trivial `T` here would
let its deinitializer be silently skipped, potentially leaking
resources.

Returns: A `ManagedAllocation` owning this storage.

#### `Allocation.write_to`

```mojo
def write_to(self, mut writer: T)
```

Writes a human-readable representation of this allocation to `writer`.

Args:

- `writer`: The writer to write to.

#### `Allocation.write_repr_to`

```mojo
def write_repr_to(self, mut writer: T)
```

Writes a debug representation of this allocation to `writer`.

Args:

- `writer`: The writer to write to.

### `ManagedAllocation`

```mojo
struct ManagedAllocation[T: AnyType, *, alignment: Alignment = Alignment.of[T]()]
```

An owning handle to a heap allocation of `T` that frees itself.

A `ManagedAllocation` wraps an `Allocation` and deallocates the storage in
its destructor. It is the self-freeing counterpart to `Allocation`: where
`Allocation` is non-`Deinitable` and must be passed to `dealloc` on
every path, a `ManagedAllocation` deallocates its storage automatically.
Mojo runs the destructor after the value's last use, following its "as soon
as possible" (ASAP) destruction policy — including on error paths, where the
destructor runs as the stack unwinds.

This trades the compile-time leak-proofing of `Allocation` for ergonomics:
there is no need to thread an explicit `dealloc` through every control-flow
path. Create one from an `Allocation` with `into_managed()` (or by passing
the `Allocation` to the constructor), and recover the underlying
`Allocation` — taking back manual responsibility for deallocation — with
`into_allocation()`.

Like `dealloc`, the destructor frees the storage but does not run the
destructors of any elements written into it. If the elements need their
destructors run, destroy them yourself (for example with
`unsafe_destroy_n`) before the `ManagedAllocation` is destroyed. Because of
that, constructing a `ManagedAllocation` requires `T` to be
`IsTriviallyDeinitable`: for any other `T`, the skipped destructor call
could silently leak resources owned by elements left in the storage.

Example:

```mojo
from std.memory.alloc import alloc, Layout

var managed = alloc(Layout[Int32](count=4)).into_managed()
var ptr = managed.unsafe_ptr()
for i in range(4):
    ptr.unsafe_offset(i).write(i)
# `managed` frees its storage when it is destroyed (after its last use).
```

Parameters:

- `T`: The type of the elements stored in the allocation.
- `alignment`: Byte alignment of the storage, matching the `Layout` it was allocated with.

Implemented traits: `AnyType`, `Deinitable`, `Movable`, `RegisterPassable`, `Writable`

#### `ManagedAllocation.__init__`

```mojo
def __init__(var allocation: Allocation[T, alignment=alignment], /) -> Self where conforms_to(T, TrivialRegisterPassable) or T.__del__is_trivial if conforms_to(T, Deinitable) else conforms_to(T, Deinitable)
```

Initializes a `ManagedAllocation` that owns `allocation`.

This is the constructor form of `Allocation.into_managed()`. The new
`ManagedAllocation` assumes responsibility for deallocating the
storage and frees it automatically when it is destroyed, after its last
use.

Constraints: `T` must be `IsTriviallyDeinitable`. Because a `ManagedAllocation`
never runs `T`'s deinitializer, allowing a non-trivial `T` here would
let its deinitializer be silently skipped, leaking any resources
(heap memory, file handles, and so on) `T`'s elements own.

Args:

- `allocation`: The `Allocation` to take ownership of. It is consumed by this call.

#### `ManagedAllocation.__deinit__`

```mojo
def __deinit__(deinit self)
```

Deallocates the owned storage.

Releases the storage owned by the wrapped `Allocation` by passing it to
`dealloc`. Like `dealloc`, this frees the storage but does not run the
destructors of any elements written into it; destroy them yourself (for
example with `unsafe_destroy_n`) beforehand if they need it.

#### `ManagedAllocation.unsafe_ptr`

```mojo
def unsafe_ptr(ref self) -> Pointer[T, origin_of(self)]
```

Returns a pointer to the allocated storage without consuming `self`.

The returned pointer borrows from `self`, so the `ManagedAllocation`
retains ownership of the storage and frees it automatically when it is
destroyed.

Safety:

`alloc` returns uninitialized storage, so the returned pointer may point
to uninitialized memory. Initialize an element (for example with
`unsafe_write`) before reading it.

Returns: A pointer to the allocated storage.

#### `ManagedAllocation.unsafe_span`

```mojo
def unsafe_span(ref self) -> Span[T, origin_of(self._alloc._alloc)]
```

Returns a span over the allocated storage without consuming `self`.

The returned span borrows from `self`, so the `ManagedAllocation`
retains ownership of the storage. The span covers `layout.count()`
elements.

Safety:

`alloc` returns uninitialized storage, so the returned span may cover
uninitialized memory. Initialize the elements before reading them.

Returns: A span over the allocated storage.

#### `ManagedAllocation.layout`

```mojo
def layout(self) -> Layout[T, alignment=alignment]
```

Returns the `Layout` the storage was allocated with.

The returned `Layout` carries the element count used to allocate the
storage — the same information needed to deallocate it.

Returns: The `Layout` this allocation was created with.

### `ThinAllocation`

```mojo
struct ThinAllocation[T: AnyType]
```

An owning handle to a heap allocation of `T`, without its `Layout`.

A `ThinAllocation` is the minimal owning handle to allocated storage: just
the pointer, with no record of the element count or alignment. Because it
does not carry a `Layout`, the layout must be supplied again to deallocate
the storage. This makes `ThinAllocation` a good storage field for a
container that already tracks its own capacity, such as `List`.

`ThinAllocation` is an explicitly destroyed (`@explicit_destroy`) type: it
is never deallocated automatically, and the compiler requires every value to
be destroyed manually on all paths. Destroy one by either:

- wrapping it in an `Allocation` with its `Layout` and passing that to
  `dealloc` (`dealloc(allocation^.unsafe_with_layout(layout))`), or
- calling `unsafe_leak()` to take ownership of the raw pointer (the caller
  then becomes responsible for deallocating it).

Parameters:

- `T`: The type of the elements stored in the allocation.

Implemented traits: `AnyType`, `Movable`, `RegisterPassable`, `Writable`

#### `ThinAllocation.__init__`

```mojo
def __init__(*, unsafe_owned_ptr: Pointer[T, MutUntrackedOrigin]) -> Self
```

Initializes a `ThinAllocation` that takes ownership of a raw pointer.

Safety:

The pointer must own storage that can be released through `dealloc`
(typically obtained from `alloc`), and no other value may own it.
Otherwise, destroying the `ThinAllocation` causes a double-free.

Args:

- `unsafe_owned_ptr`: The raw pointer to take ownership of. The new `ThinAllocation` assumes responsibility for deallocating this storage.

#### `ThinAllocation.unsafe_with_layout`

```mojo
def unsafe_with_layout[alignment: Alignment, //](var self, layout: Layout[T, alignment=alignment]) -> Allocation[T, alignment=alignment]
```

Pairs this `ThinAllocation` with a `Layout` to form an `Allocation`.

Consumes `self` and bundles it with `layout`, producing an `Allocation`
that can be passed to `dealloc`.

Safety:

The `layout` must exactly match the `Layout` that was passed to `alloc`
when this storage was originally allocated — both its element count and
its alignment. A `ThinAllocation` records neither, so nothing checks
this for you: `dealloc` releases the storage according to the `Layout`
you supply here, and a mismatch frees the wrong number of bytes and can
corrupt the allocator.

Parameters:

- `alignment`: Byte alignment of the storage, taken from `layout`.

Args:

- `layout`: The `Layout` the storage was allocated with.

Returns: An `Allocation` owning this storage together with `layout`.

#### `ThinAllocation.unsafe_leak`

```mojo
def unsafe_leak(deinit self) -> Pointer[T, MutUntrackedOrigin]
```

Consumes the `ThinAllocation` and returns its raw owning pointer.

`ThinAllocation` is an explicitly destroyed type: it is never
deallocated automatically, and the compiler requires every value to be
destroyed manually. This method is one such destructor — it consumes the
handle and returns the raw pointer, which the compiler no longer tracks.
The caller then owns the storage and must deallocate it manually by
wrapping the pointer in a `ThinAllocation` with its `Layout` and passing
that to `dealloc`. Nothing enforces this once the pointer is leaked,
so failing to do so leaks memory.

Returns: The raw pointer to the allocated storage.

#### `ThinAllocation.unsafe_ptr`

```mojo
def unsafe_ptr[origin: Origin[mut=origin.mut], address_space: AddressSpace, //](ref[origin.mut, origin] self) -> Pointer[T, origin, address_space=address_space]
```

Returns a pointer to the allocated storage without consuming `self`.

The returned pointer borrows from `self` with the same origin and
address space, so the `ThinAllocation` retains ownership of the storage.

Parameters:

- `origin`: The origin of `self`, propagated to the returned pointer.
- `address_space`: The address space of `self`, propagated to the returned pointer.

Returns: A pointer to the allocated storage in the given origin and address space.

#### `ThinAllocation.write_to`

```mojo
def write_to(self, mut writer: T)
```

Writes a human-readable representation of this allocation to `writer`.

Args:

- `writer`: The writer to write to.

#### `ThinAllocation.write_repr_to`

```mojo
def write_repr_to(self, mut writer: T)
```

Writes a debug representation of this allocation to `writer`.

Args:

- `writer`: The writer to write to.

### `Layout`

```mojo
struct Layout[T: AnyType, *, alignment: Alignment = Alignment.of[T]()]
```

Describes the shape of a memory allocation for elements of type `T`.

A `Layout` pairs the *count* of elements, held at runtime, with the
*alignment* of the allocation, carried as a compile-time parameter. Passing
a `Layout` to `alloc` and `dealloc` keeps the size and alignment
requirements explicit and co-located at every call site, preventing
mismatches between allocation and deallocation.

Example:

```mojo
from std.memory.alloc import alloc, dealloc, Layout

# Allocate room for 8 Int32 values with `Int32`'s natural alignment.
var layout = Layout[Int32](count=8)
var allocation = alloc(layout)
# ... use allocation ...
dealloc(allocation^)

# Over-align the same storage to a 64-byte boundary.
var over_aligned = alloc(
    Layout[Int32, alignment = .of_bytes[64]()](count=8)
)
dealloc(over_aligned^)
```

Parameters:

- `T`: The element type the layout describes.
- `alignment`: Byte alignment of the allocation.

Implemented traits: `AnyType`, `Copyable`, `Deinitable`, `ImplicitlyCopyable`, `Movable`, `RegisterPassable`, `TrivialRegisterPassable`, `Writable`

#### `Layout.__init__`

```mojo
def __init__(*, count: Int) -> Self
```

Initializes a `Layout` describing `count` elements of type `T`.

Constraints: `alignment` must be no smaller than `align_of[T]()`. `Alignment`
itself enforces the power-of-two requirement.

Args:

- `count`: Number of elements of type `T` to describe.

#### `Layout.single`

```mojo
def single() -> Self
```

Creates a `Layout` for exactly one element of type `T`.

Example:

```mojo
from std.memory.alloc import alloc, dealloc, Layout

var layout = Layout[Int64].single()
var allocation = alloc(layout)
allocation.unsafe_ptr().write(0)
dealloc(allocation^)
```

Returns: A `Layout` with `count` equal to 1.

#### `Layout.as_byte_layout`

```mojo
def as_byte_layout(self) -> Layout[UInt8, alignment=alignment]
```

Converts this layout to an equivalent byte-level layout.

Multiplies the element count by `size_of[T]()` to express the same
allocation in terms of raw bytes, preserving the alignment.

Returns: A `Layout[Byte, alignment=_]` whose `count` is `self.count() * size_of[T]()`.

#### `Layout.count`

```mojo
def count(self) -> Int
```

Returns the number of elements described by this layout.

Returns: The element count passed at construction time.

#### `Layout.write_to`

```mojo
def write_to(self, mut writer: T)
```

Writes a human-readable representation of this layout to `writer`.

Args:

- `writer`: The writer to write to.

#### `Layout.write_repr_to`

```mojo
def write_repr_to(self, mut writer: T)
```

Writes a debug representation of this layout to `writer`.

Args:

- `writer`: The writer to write to.

## Functions

### `alloc`

```mojo
def alloc[type: AnyType, /](count: Int, *, alignment: Int = Int((get_alignof type, _current_target()))) -> Pointer[type, MutUntrackedOrigin]
```

**Deprecated:** `alloc` without a `Layout` is deprecated, use the `Layout`-based `alloc` instead; as a temporary migration step, use `unsafe_alloc`

Allocates contiguous storage for `count` elements of `type` with alignment `alignment`.

Parameters:

- `type`: The type of the elements to allocate storage for.

Args:

- `count`: Number of elements to allocate.
- `alignment`: The alignment of the allocation.

Returns: A pointer to the newly allocated uninitialized array.

```mojo
def alloc[T: AnyType, /, *, alignment: Alignment = Alignment.of[T]()](layout: Layout[T, alignment=alignment], /) -> Allocation[T, alignment=alignment]
```

Allocates owned storage for `layout.count()` elements of `T`.

Returns an `Allocation`, an explicitly destroyed handle that bundles the
newly allocated storage with its `Layout`. The compiler then enforces that
the `Allocation` is destroyed on every path — by passing it to `dealloc`,
or by explicitly leaking it with `unsafe_leak()`.

When `size_of[T]() == 0`, this function returns a sentinel value.

Example:

```mojo
from std.memory.alloc import alloc, dealloc, Layout

var allocation = alloc(Layout[Int32](count=4))
var ptr = allocation.unsafe_ptr()
for i in range(4):
    ptr.unsafe_offset(i).write(i)
dealloc(allocation^)
```

Constraints: `layout.count()` must be `>= 0`.

Parameters:

- `T`: The type of the elements to allocate storage for.
- `alignment`: Byte alignment of the allocation, taken from `layout`.

Args:

- `layout`: Describes the number of elements in the allocation.

Returns: An `Allocation` owning the newly allocated, uninitialized storage.

### `unsafe_alloc`

```mojo
def unsafe_alloc[type: AnyType, /](count: Int, *, alignment: Int = Int((get_alignof type, _current_target()))) -> Pointer[type, MutUntrackedOrigin]
```

Allocates contiguous storage for `count` elements of `type` with alignment `alignment`.

Safety:

- The returned memory is uninitialized; reading before writing is undefined.
- The returned pointer has an empty mutable origin; you must call `free()`
  to release it.

Example:

```mojo
var ptr = unsafe_alloc[Int32](4)
ptr.store(0, Int32(42))
ptr.store(1, Int32(7))
ptr.store(2, Int32(9))
var a = ptr.load(0)
print(a[0], ptr.load(1)[0], ptr.load(2)[0])
ptr.unsafe_free()
```

Constraints: `count` must be positive and `size_of[type]()` must be > 0.

Parameters:

- `type`: The type of the elements to allocate storage for.

Args:

- `count`: Number of elements to allocate.
- `alignment`: The alignment of the allocation.

Returns: A pointer to the newly allocated uninitialized array.

### `dealloc`

```mojo
def dealloc[T: AnyType, /](var allocation: Allocation[T, alignment=allocation.alignment], /)
```

Deallocates the storage owned by an `Allocation`.

Consumes `allocation` and releases its memory. This is the primary way to
dispose of an `Allocation` produced by `alloc`. To deallocate a bare
`ThinAllocation`, wrap it in an `Allocation` with its original `Layout`
first: `dealloc(thin^.unsafe_with_layout(layout))`.

Example:

```mojo
from std.memory.alloc import alloc, dealloc, Layout

var allocation = alloc(Layout[Int64].single())
dealloc(allocation^)
```

Parameters:

- `T`: The type of the elements in the allocation.

Args:

- `allocation`: The `Allocation` to deallocate. It is consumed by this call.
