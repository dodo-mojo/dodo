# `std.ffi.unsafe_union`

Defines an untagged union type for C FFI interoperability.

This module provides a C-style union type that allows storing different types
in the same memory location without runtime type tracking. Unlike `Variant`,
`UnsafeUnion` does not maintain a discriminant field, making it suitable for:

- Interfacing with C libraries that use union types
- Low-level memory manipulation and type punning
- Situations where memory layout must exactly match C unions

Warning: Using `UnsafeUnion` is inherently unsafe. Reading a value as the wrong
type results in undefined behavior, just like in C. Prefer `Variant` for safe,
type-checked sum types.

## Structs

### `UnsafeUnion`

```mojo
struct UnsafeUnion[*Ts: AnyType]
```

An untagged union that can store any one of its element types.

`UnsafeUnion` is an untagged (non-discriminated) union, similar to `union`
in C. It provides a way to store different types in the same memory
location, where only one value is active at a time. The size of an
`UnsafeUnion` is the size of its largest element type, and its alignment
is the strictest alignment requirement among its elements.

**Important**: Unlike `Variant`, `UnsafeUnion` does NOT track which type is
currently stored. Reading a value as the wrong type is undefined behavior.
This type is primarily intended for C FFI interoperability.

**Type requirements**: All element types must have trivial copy, move, and
destroy operations. This ensures safe bitwise operations and matches the
semantics of C unions which don't have constructors or destructors.

Example:

```mojo
from std.ffi import UnsafeUnion

# Define a union that can hold Int32 or Float32
comptime IntOrFloat = UnsafeUnion[Int32, Float32]

# Create with an integer
var u = IntOrFloat(Int32(42))
print(u.unsafe_get[Int32]())  # => 42

# Type punning (reinterpreting bits)
var u2 = IntOrFloat(Float32(1.0))
print(u2.unsafe_get[Int32]())  # => 1065353216 (IEEE 754 bits of 1.0f)
```

Example for C FFI:

```mojo
from std.ffi import UnsafeUnion

# Matches C: union { int32_t i; float f; }
comptime CUnion = UnsafeUnion[Int32, Float32]

def call_c_function(u: CUnion):
    # Pass to C code expecting union type
    ...
```

Parameters:

- `*Ts`: The possible types that this union can hold. Must have at least one type, and all types must be unique.

Implemented traits: `AnyType`, `Copyable`, `Deinitable`, `ImplicitlyCopyable`, `Movable`, `Writable`

#### `UnsafeUnion.__init__`

```mojo
def __init__(out self, *, unsafe_uninitialized: Tuple)
```

Unsafely create an uninitialized `UnsafeUnion`.

The storage contains garbage data. You must call `unsafe_set` before
reading any value.

Args:

- `unsafe_uninitialized`: Marker argument indicating this initializer is unsafe.

```mojo
def __init__[T: Movable](out self, var value: T)
```

Create a union initialized with the given value.

Example:

```mojo
from std.ffi import UnsafeUnion

var u = UnsafeUnion[Int32, Float32](Int32(42))
```

Parameters:

- `T`: The type of the value. Must be one of the union's element types.

Args:

- `value`: The value to initialize the union with.

```mojo
def __init__(out self, *, copy: Self)
```

Creates a bitwise copy of the union.

Args:

- `copy`: The union to copy from.

```mojo
def __init__(out self, *, deinit move: Self)
```

Move initializer for the union.

Args:

- `move`: The union to move from.

#### `UnsafeUnion.unsafe_get`

```mojo
def unsafe_get[origin: Origin[mut=origin.mut], address_space: AddressSpace, //, T: AnyType](ref[Ts, origin_of(origin)] self) -> ref[Ts, origin_of(origin)] T
```

Get a reference to the stored value as type T.

Safety:
Reading as the wrong type is undefined behavior.

Example:

```mojo
from std.ffi import UnsafeUnion

var u = UnsafeUnion[Int32, Float32](Int32(42))
ref val = u.unsafe_get[Int32]()
print(val)  # => 42
```

Parameters:

- `T`: The type to interpret the stored value as. Must be one of the union's element types.

Returns: A reference to the storage interpreted as type T.

#### `UnsafeUnion.write_to`

```mojo
def write_to(self, mut writer: T)
```

Writes a representation of the union to the writer.

Since `UnsafeUnion` is untagged and doesn't track the stored type,
this writes the union's type signature and size/alignment info rather
than the stored value.

Example:

```mojo
from std.ffi import UnsafeUnion

var u = UnsafeUnion[Int32, Float32](Int32(42))
print(u)  # => UnsafeUnion[Int32, Float32](size=4, align=4)
```

Args:

- `writer`: The object to write to.

#### `UnsafeUnion.write_repr_to`

```mojo
def write_repr_to(self, mut writer: T)
```

Writes the repr representation of the union to the writer.

Args:

- `writer`: The object to write to.

#### `UnsafeUnion.unsafe_take`

```mojo
def unsafe_take[T: Movable](mut self) -> T
```

Move the stored value out of the union.

This takes ownership of the stored value, leaving the union in an
uninitialized state. The caller is responsible for ensuring that
`T` matches the type that was actually stored.

Safety:
Taking as the wrong type is undefined behavior. After calling this,
the union is uninitialized and you must call `unsafe_set` before
reading again.

Example:

```mojo
from std.ffi import UnsafeUnion

var u = UnsafeUnion[Int32, Float32](Int32(42))
var val = u.unsafe_take[Int32]()  # val = 42, u is now uninitialized
```

Parameters:

- `T`: The type to take out. Must be one of the union's element types and must be `Movable`.

Returns: The stored value, moved out of the union.

#### `UnsafeUnion.unsafe_set`

```mojo
def unsafe_set[T: Movable](mut self, var value: T)
```

Set the union to hold the given value.

This overwrites whatever was previously stored. Since all union element
types must be trivial, no destructor needs to be called on the old
value.

Example:

```mojo
from std.ffi import UnsafeUnion

var u = UnsafeUnion[Int32, Float32](Int32(0))
u.unsafe_set(Float32(3.14))
```

Parameters:

- `T`: The type of the value. Must be one of the union's element types.

Args:

- `value`: The value to store.

#### `UnsafeUnion.unsafe_ptr`

```mojo
def unsafe_ptr[origin: Origin[mut=origin.mut], address_space: AddressSpace, //, T: AnyType](ref[Ts, origin_of(origin)] self) -> Pointer[T, origin, address_space=address_space]
```

Get a pointer to the storage interpreted as type T.

This allows direct manipulation of the union's storage. Useful for
C FFI where you need to pass a pointer to union members.

Safety:
Interpreting as the wrong type is undefined behavior.

Example:

```mojo
from std.ffi import UnsafeUnion

var u = UnsafeUnion[Int32, Float32](Int32(0))
var ptr = u.unsafe_ptr[Int32]()
ptr[] = 42
```

Parameters:

- `T`: The type to interpret the storage as. Must be one of the union's element types.

Returns: A pointer to the storage as type T.
