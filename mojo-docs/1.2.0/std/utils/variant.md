# `std.utils.variant`

Defines a Variant type.

## Structs

### `Variant`

```mojo
struct Variant[*Ts: AnyType]
```

A union that can hold a runtime-variant value from a set of predefined types.

`Variant` is a discriminated union type, similar to `std::variant` in C++
or `enum` in Rust. It can store exactly one value that can be any of the
specified types, determined at runtime.

The key feature is that the actual type stored in a `Variant` is determined
at runtime, not compile time. This allows you to change what type a variant
holds during program execution. Memory-wise, a variant only uses the space
needed for the largest possible type plus a small discriminant field to
track which type is currently active.

Tips:

- use `isa[T]()` to check what type a variant is
- use `unsafe_unwrap[T]()` to take a value from the variant
- use `[T]` to get a value out of a variant
    - This currently does an extra copy/move until we have origins
    - It also temporarily requires the value to be mutable
- use `set[T](var new_value: T)` to reset the variant to a new value
- use `is_type_supported[T]` to check if the variant permits the type `T`

**Note**: Currently, variant operations require the variant to be
mutable (`mut`), even for read operations.

Example:

```mojo
from std.utils import Variant
import std.random as random

comptime IntOrString = Variant[Int, String]

def to_string(mut x: IntOrString) -> String:
    if x.isa[String]():
        return x[String]
    return String(x[Int])

var an_int = IntOrString(4)
var a_string = IntOrString("I'm a string!")
var who_knows = IntOrString(0)
# Randomly change who_knows to a string
random.seed()
if random.random_ui64(0, 1):
    who_knows.set[String]("I'm also a string!")

print(a_string[String])      # => I'm a string!
print(an_int[Int])           # => 4
print(to_string(who_knows))  # Either 0 or "I'm also a string!"

if who_knows.isa[String]():
    print("It's a String!")
```

Example usage for error handling:

```mojo
comptime Result = Variant[String, Error]

def process_data(data: String) -> Result:
    if data.byte_length() == 0:
        return Result(Error("Empty data"))
    return Result(String("Processed: ", data))

var result = process_data("Hello")
if result.isa[String]():
    print("Success:", result[String])
else:
    print("Error:", result[Error])
```

Example usage in a `List` to create a heterogeneous list:

```mojo
comptime MixedType = Variant[Int, Float64, String, Bool]

var mixed_list = List[MixedType]()
mixed_list.append(MixedType(42))
mixed_list.append(MixedType(3.14))
mixed_list.append(MixedType("hello"))
mixed_list.append(MixedType(True))

for item in mixed_list:
    if item.isa[String]():
        print("String:", item[String])
    elif item.isa[Int]():
        print("Integer:", item[Int])
    elif item.isa[Float64]():
        print("Float:", item[Float64])
    elif item.isa[Bool]():
        print("Boolean:", item[Bool])
```

## Layout

The layout of `Variant` is not guaranteed and may change at any time. The
implementation may apply niche optimizations (for example, encoding the
discriminant inside spare bits of one of the types in `Ts`) that alter the
resulting layout. Do not rely on `size_of[Variant[...]]()` or
`align_of[Variant[...]]()` being stable across language versions. The only
guarantee is that the size and alignment will be at least as large as those
of the largest type among `Ts`.

If you need to inspect the current size or alignment, use `size_of` and
`align_of`, but treat the results as non-stable implementation details.

Parameters:

- `*Ts`: The possible types that this variant can hold. Types that implement `Copyable` enable copy semantics for the variant.

Implemented traits: `AnyType`, `Copyable`, `Deinitable`, `Equatable`, `Hashable`, `ImplicitlyCopyable`, `Movable`, `RegisterPassable`, `Writable`

#### `Variant.__init__`

```mojo
def __init__[T: Movable](out self, var value: T)
```

Create a variant with one of the types.

Parameters:

- `T`: The type to initialize the variant to. Generally this should be able to be inferred from the call type, eg. `Variant[Int, String](4)`.

Args:

- `value`: The value to initialize the variant with.

```mojo
def __init__[T: AnyType, //, F: def() -> T](out self, *, init_with: F)
```

Create a variant holding a `T` produced in place by a closure.

The value returned by `init_with` is constructed directly into the
variant's storage without being moved, so this is the only way to
store a value whose type is not `Movable`.

The `init_with` keyword is required to disambiguate from the value
constructor: a closure is itself a storable value, so a positional
`Variant(f)` stores `f`, whereas `Variant(init_with=f)` calls `f` and
stores its result.

Examples:

```mojo
from std.utils import Variant

@fieldwise_init
struct Pinned(not Movable):
    var value: Int

def make() -> Pinned:
    return Pinned(7)

var v = Variant[Pinned, Int](init_with=make)
print(v[Pinned].value)  # => 7
```

Parameters:

- `T`: The type to initialize the variant to. Must be one of the variant's type arguments.
- `F`: The type of the initializer closure.

Args:

- `init_with`: A closure returning the value to store. Called exactly once.

#### `Variant.__deinit__`

```mojo
def __deinit__(deinit self) where TypeList.all_conforms_to[Deinitable]()
```

Destroy the variant, running the destructor of the currently held value.

Constraints: All types in `Ts` must conform to `Deinitable`.

#### `Variant.__eq__`

```mojo
def __eq__(self, other: Self) -> Bool where TypeList.all_conforms_to[Equatable]()
```

Compares two variants for equality.

Two variants are equal if they hold the same type and the held
values are equal.

Args:

- `other`: The other variant to compare against.

Returns: True if the variants hold the same type and equal values.

#### `Variant.__ne__`

```mojo
def __ne__(self, other: Self) -> Bool where TypeList.all_conforms_to[Equatable]()
```

Compares two variants for inequality.

Args:

- `other`: The other variant to compare against.

Returns: True if the variants hold different types or unequal values.

#### `Variant.__getitem_param__`

```mojo
def __getitem_param__[T: AnyType](ref self) -> ref[T["value"]] T
```

Get the value out of the variant as a type-checked type.

This explicitly check that your value is of that type!
If you haven't verified the type correctness at runtime, the program
will abort!

For now this has the limitations that it
    - requires the variant value to be mutable

Parameters:

- `T`: The type of the value to get out.

Returns: A reference to the internal data.

#### `Variant.__hash__`

```mojo
def __hash__(self, mut hasher: T) where TypeList.all_conforms_to[Hashable]()
```

Hashes the variant using the given hasher.

The hash incorporates both the type discriminant and the held
value's hash, so variants holding different types are unlikely to
collide.

Args:

- `hasher`: The hasher instance.

#### `Variant.write_to`

```mojo
def write_to(self, mut writer: T) where TypeList.all_conforms_to[Writable]()
```

Writes the currently held variant value to the provided Writer.

Args:

- `writer`: The object to write to.

#### `Variant.write_repr_to`

```mojo
def write_repr_to(self, mut writer: T) where TypeList.all_conforms_to[Writable]()
```

Write the string representation of the Variant.

Args:

- `writer`: The object to write to.

#### `Variant.unwrap`

```mojo
def unwrap[T: Movable](deinit self) -> T
```

Take the current value of the variant with the provided type.

The caller takes ownership of the underlying value.

This explicitly check that your value is of that type!
If you haven't verified the type correctness at runtime, the program
will abort!

Parameters:

- `T`: The type to take out.

Returns: The underlying data to be taken out as an owned value.

#### `Variant.unsafe_unwrap`

```mojo
def unsafe_unwrap[T: Movable](deinit self) -> T
```

Unsafely take the current value of the variant with the provided type.

The caller takes ownership of the underlying value.

This doesn't explicitly check that your value is of that type!
If you haven't verified the type correctness at runtime, you'll get
a type that _looks_ like your type, but has potentially unsafe
and garbage member data.

Parameters:

- `T`: The type to take out.

Returns: The underlying data to be taken out as an owned value.

#### `Variant.replace`

```mojo
def replace[Tin: Deinitable & Movable, Tout: Movable](mut self, var value: Tin) -> Tout
```

Replace the current value of the variant with the provided type.

The caller takes ownership of the underlying value.

This explicitly check that your value is of that type!
If you haven't verified the type correctness at runtime, the program
will abort!

Parameters:

- `Tin`: The type to put in.
- `Tout`: The type to take out.

Args:

- `value`: The value to put in.

Returns: The underlying data to be taken out as an owned value.

#### `Variant.unsafe_replace`

```mojo
def unsafe_replace[Tin: Movable, Tout: Movable](mut self, var value: Tin) -> Tout
```

Unsafely replace the current value of the variant with the provided type.

The caller takes ownership of the underlying value.

This doesn't explicitly check that your value is of that type!
If you haven't verified the type correctness at runtime, you'll get
a type that _looks_ like your type, but has potentially unsafe
and garbage member data.

Parameters:

- `Tin`: The type to put in.
- `Tout`: The type to take out.

Args:

- `value`: The value to put in.

Returns: The underlying data to be taken out as an owned value.

#### `Variant.set`

```mojo
def set[T: Movable](mut self, var value: T) where TypeList.all_conforms_to[Deinitable]()
```

Set the variant value.

This will call the destructor on the old value, and update the variant's
internal type and data to the new value.

Parameters:

- `T`: The new variant type. Must be one of the Variant's type arguments.

Args:

- `value`: The new value to set the variant to.

```mojo
def set[T: AnyType, //, F: def() -> T](mut self, *, init_with: F)
```

Replace the variant's value with a `T` produced in place by a closure.

Destroys the currently held value, then constructs the closure's return
value directly into the variant's storage without moving it. This is the
only way to replace the contents with a value whose type is not
`Movable`.

The `init_with` keyword is required to disambiguate from the value-taking
`set`: a closure is itself a storable value, so a positional
`set(f)` stores `f`, whereas `set(init_with=f)` calls `f` and stores its
result.

Examples:

```mojo
from std.utils import Variant

@fieldwise_init
struct Pinned(not Movable):
    var value: Int

def make() -> Pinned:
    return Pinned(7)

var v = Variant[Pinned, Int](0)
v.set(init_with=make)
print(v[Pinned].value)  # => 7
```

Constraints: All types in `Ts` must conform to `Deinitable`, since the
outgoing value is destroyed in place.

Parameters:

- `T`: The new variant type. Must be one of the variant's type arguments.
- `F`: The type of the initializer closure.

Args:

- `init_with`: A closure returning the replacement value. Called exactly once.

#### `Variant.isa`

```mojo
def isa[T: AnyType](self) -> Bool
```

Check if the variant contains the required type.

Parameters:

- `T`: The type to check.

Returns: True if the variant contains the requested type.

#### `Variant.unsafe_get`

```mojo
def unsafe_get[T: AnyType](ref self) -> ref[T] T
```

Get the value out of the variant as a type-checked type.

This doesn't explicitly check that your value is of that type!
If you haven't verified the type correctness at runtime, you'll get
a type that _looks_ like your type, but has potentially unsafe
and garbage member data.

For now this has the limitations that it
    - requires the variant value to be mutable

Parameters:

- `T`: The type of the value to get out.

Returns: The internal data represented as a `Pointer[T]`.

#### `Variant.is_type_supported`

```mojo
def is_type_supported[T: Movable]() -> Bool
```

Check if a type can be used by the `Variant`.

Example:

```mojo
from std.utils import Variant

def takes_variant(mut arg: Variant) raises:
    if arg.is_type_supported[Float64]():
        arg = Float64(1.5)

def main() raises:
    var x = Variant[Int, Float64](1)
    takes_variant(x)
    if x.isa[Float64]():
        print(x[Float64]) # 1.5
```

For example, the `Variant[Int, Bool]` permits `Int` and `Bool`.

Parameters:

- `T`: The type of the value to check support for.

Returns: `True` if type `T` is supported by the `Variant`.

#### `Variant.deinit_with`

```mojo
def deinit_with[T: AnyType, F: def(var T) -> None](deinit self, deinit_func: F, /)
```

Deinitialize a value contained in this Variant in-place using a caller provided destructor function.

This method can be used to deinitialize types that do not conform to
`Deinitable` in a `Variant` in-place.

This method will abort if this variant does not current contain an
element of the specified type `T`.

Parameters:

- `T`: The element type the variant is expected to currently contain, and which will be deinitialized by `deinit_func`.
- `F`: The type of the caller-provided deinitializer function.

Args:

- `deinit_func`: Caller-provided function for deinitializing an instance of `T`.
