# `std.collections.optional`

Defines Optional, a type modeling a value which may or may not be present.

Optional values can be thought of as a type-safe nullable pattern.
Your value can take on a value or `None`, and you need to check
and explicitly extract the value to get it out.

Examples:

```mojo
var a = Optional(1)
var b = Optional[Int](None)
if case .Some(value) = a:
    print(value)  # prints 1
if case .Some(value) = b:  # b is empty, so no print
    print(value)
var c = a.or_else(2)
var d = b.or_else(2)
print(c)  # prints 1
print(d)  # prints 2
```

## Structs

### `EmptyOptionalError`

```mojo
struct EmptyOptionalError[T: AnyType]
```

An error type for when an empty `Optional` is accessed.

Parameters:

- `T`: The type of the value that was accessed in the `Optional`.

Implemented traits: `AnyType`, `Copyable`, `Deinitable`, `ImplicitlyCopyable`, `Movable`, `RegisterPassable`, `Writable`

#### `EmptyOptionalError.write_to`

```mojo
def write_to(self, mut writer: T)
```

Write the error to a `Writer`.

Args:

- `writer`: The `Writer` to write to.

#### `EmptyOptionalError.write_repr_to`

```mojo
def write_repr_to(self, mut writer: T)
```

Write the error to a `Writer`.

Args:

- `writer`: The `Writer` to write to.

### `Optional`

```mojo
struct Optional[T: AnyType]
```

A type modeling a value which may or may not be present.

Optional values can be thought of as a type-safe nullable pattern.
Your value can take on a value or `None`, and you need to check
and explicitly extract the value to get it out.

## Layout

The layout of `Optional` is not guaranteed and may change at any time.
The implementation may apply niche optimizations (for example, storing the
`None` sentinel inside spare bits of `T`) that alter the resulting layout.
Do not rely on `size_of[Optional[T]]()` or `align_of[Optional[T]]()` being
stable across compiler versions. The only guarantee is that the size and
alignment will be at least as large as those of `T` itself.

If you need to inspect the current size or alignment, use `size_of` and
`align_of`, but treat the results as non-stable implementation details.

Examples:

```mojo
var a = Optional(1)
var b = Optional[Int](None)
if case .Some(value) = a:
    print(value)  # prints 1
if case .Some(value) = b:  # b is empty, so no print
    print(value)
var c = a.or_else(2)
var d = b.or_else(2)
print(c)  # prints 1
print(d)  # prints 2
```

Parameters:

- `T`: The type of value stored in the `Optional`.

Implemented traits: `AnyType`, `Boolable`, `Copyable`, `Defaultable`, `Deinitable`, `DevicePassable`, `EnumLike`, `Equatable`, `Hashable`, `ImplicitlyCopyable`, `Iterable`, `IterableOwned`, `Movable`, `RegisterPassable`, `Writable`

Aliases:

- `IteratorType = _OptionalIter[T(Deinitable & Movable)]`: The iterator type for this optional.
- `IteratorOwnedType = _OptionalIter[T(Deinitable & Movable)]`: The owned iterator type for this optional.
- `Element = T`: The element type of this optional.
- `device_type = Optional[T(DevicePassable).device_type if conforms_to(T, DevicePassable) else T]`: The device-side type for this optional.

#### `Optional.__init__`

```mojo
def __init__(out self)
```

Construct an empty `Optional`.

Examples:

```mojo
var instance = Optional[String]()
print(instance) # Output: None
```

```mojo
def __init__(out self, var value: T) where conforms_to(T, Movable)
```

Construct an `Optional` containing a value.

Examples:

```mojo
var instance = Optional[String]("Hello")
print(instance) # Output: 'Hello'
```

Args:

- `value`: The value to store in the `Optional`.

```mojo
def __init__[F: def() -> T](out self, *, init_with: F)
```

Construct an `Optional` holding a value produced in place by `call`.

The value returned by `call` is constructed directly into the
`Optional`'s storage without being moved, so this is the only way to
populate an `Optional` whose element type is not `Movable`. For a
`Movable` element type, prefer the value constructor.

The `init_with` keyword is required to disambiguate from the value
constructor: a closure is itself a storable value, so a positional
`Optional(f)` would store `f` rather than call it.

Examples:

```mojo
@fieldwise_init
struct Pinned(not Movable):
    var value: Int

def make() -> Pinned:
    return Pinned(7)

var opt = Optional[Pinned](init_with=make)
print(opt.value().value)  # Output: 7
```

Parameters:

- `F`: The type of the initializer closure.

Args:

- `init_with`: A closure returning the value to store. Called exactly once.

```mojo
def __init__(out self, value: NoneType)
```

Construct an empty `Optional`.

Examples:

```mojo
var instance = Optional[String](None)
print(instance) # Output: None
```

Args:

- `value`: Must be exactly `None`.

#### `Optional.__bool__`

```mojo
def __bool__(self) -> Bool
```

Return true if the Optional has a value.

Returns: True if the `Optional` has a value and False otherwise.

#### `Optional.__getitem__`

```mojo
def __getitem__(ref self) raises -> ref[self_is_mut._value] T
```

Retrieve a reference to the value inside the `Optional`.

Returns: A reference to the value inside the `Optional`.

Raises: On empty `Optional`.

#### `Optional.__invert__`

```mojo
def __invert__(self) -> Bool
```

Return False if the `Optional` has a value.

Returns: False if the `Optional` has a value and True otherwise.

#### `Optional.__eq__`

```mojo
def __eq__(self, rhs: None) -> Bool
```

Return `True` if a value is not present.

Args:

- `rhs`: The `None` value to compare to.

Returns: `True` if a value is not present, `False` otherwise.

```mojo
def __eq__(self, rhs: Self) -> Bool where conforms_to(T, Equatable)
```

Return `True` if this is the same as another `Optional` value, meaning both are absent, or both are present and have the same underlying value.

Args:

- `rhs`: The value to compare to.

Returns: True if the values are the same.

#### `Optional.__ne__`

```mojo
def __ne__(self, rhs: None) -> Bool
```

Return `True` if a value is present.

Args:

- `rhs`: The `None` value to compare to.

Returns: `False` if a value is not present, `True` otherwise.

#### `Optional.__is__`

```mojo
def __is__(self, other: NoneType) -> Bool
```

Return `True` if the Optional has no value.

Notes:
It allows you to use the following syntax:
`if my_optional is None:`.

Args:

- `other`: The value to compare to (None).

Returns: True if the Optional has no value and False otherwise.

#### `Optional.__isnot__`

```mojo
def __isnot__(self, other: NoneType) -> Bool
```

Return `True` if the Optional has a value.

Notes:
It allows you to use the following syntax:
`if my_optional is not None:`.

Args:

- `other`: The value to compare to (None).

Returns: True if the Optional has a value and False otherwise.

#### `Optional.__iter__`

```mojo
def __iter__(ref self) -> _OptionalIter[T(Deinitable & Movable)]
```

Iterate over the Optional's possibly contained value.

Optionals act as a collection of size 0 or 1.

Examples:

```mojo
var instance = Optional("Hello")
for value in instance:
    print(value) # Output: Hello
instance = None
for value in instance:
    print(value) # Does not reach line
```

Returns: An iterator over the Optional's value (if present).

```mojo
def __iter__(var self) -> _OptionalIter[T(Deinitable & Movable)] where conforms_to(T, Deinitable & Movable)
```

Consume the Optional and return an iterator over its value.

Optionals act as a collection of size 0 or 1.

Returns: An iterator that owns the Optional's value (if present).

#### `Optional.bounds`

```mojo
def bounds(self) -> Tuple[Int, Optional[Int]]
```

Return the bounds of the `Optional`, which is 0 or 1.

Examples:

```mojo
def bounds():
    var empty_instance = Optional[Int]()
    var populated_instance = Optional[Int](50)

    # Bounds returns a tuple: (`bounds`, `Optional` version of `bounds`)
    # with the length of the `Optional`.
    print(empty_instance.bounds()[0])     # 0
    print(populated_instance.bounds()[0]) # 1
    print(empty_instance.bounds()[1])     # 0
    print(populated_instance.bounds()[1]) # 1
```

Returns: A tuple containing the length (0 or 1) and an `Optional` containing the length.

#### `Optional.write_to`

```mojo
def write_to(self, mut writer: T) where conforms_to(T, Writable)
```

Write this `Optional` to a `Writer`.

Args:

- `writer`: The object to write to.

#### `Optional.write_repr_to`

```mojo
def write_repr_to(self, mut writer: T) where conforms_to(T, Writable)
```

Write this `Optional`'s representation to a `Writer`.

Args:

- `writer`: The object to write to.

#### `Optional.__hash__`

```mojo
def __hash__[H: Hasher](self, mut hasher: H) where conforms_to(T, Hashable)
```

Updates hasher with the hash of the contained value, if present.

A `None` optional hashes differently from any present value.

Parameters:

- `H`: The hasher type.

Args:

- `hasher`: The hasher instance.

#### `Optional.get_type_name`

```mojo
def get_type_name() -> String where conforms_to(T, DevicePassable & Copyable)
```

Get the human-readable type name for this `Optional` type.

Returns: A string representation of the type, e.g. `Optional[Int]`.

#### `Optional.value`

```mojo
def value(ref self) -> ref[self_is_mut._value] T
```

Retrieve a reference to the value of the `Optional`.

Notes:
This will abort on empty `Optional`.

Examples:

```mojo
var instance = Optional("Hello")
var x = instance.value()
print(x) # Hello
# instance = Optional[String]() # Uncomment both lines to crash
# print(instance.value())       # Attempts to take value from `None`
```

Returns: A reference to the contained data of the `Optional` as a reference.

#### `Optional.unsafe_value`

```mojo
def unsafe_value(ref self) -> ref[self_is_mut._value] T
```

Unsafely retrieve a reference to the value of the `Optional`.

Notes:
This will **not** abort on empty `Optional`.

Examples:

```mojo
var instance = Optional("Hello")
var x = instance.unsafe_value()
print(x) # Hello
instance = Optional[String](None)

# Best practice:
if instance:
    var y = instance.unsafe_value() # Will not reach this line
    print(y)

# In debug builds, this will deterministically abort:
y = instance.unsafe_value()
print(y)
```

Returns: A reference to the contained data of the `Optional` as a reference.

#### `Optional.take`

```mojo
def take(mut self) -> T where conforms_to(T, Movable)
```

Move the value out of the `Optional`.

Notes:
This will abort on empty `Optional`.

Examples:

```mojo
var instance = Optional("Hello")
print(instance.bounds()[0])  # Output: 1
var x = instance.take() # Moves value from `instance` to `x`
print(x)  # Output: Hello

# `instance` is now `Optional(None)`
print(instance.bounds()[0])  # Output: 0
print(instance)  # Output: None

# Best practice
if instance:
    var y = instance.take()  # Won't reach this line
    print(y)

# Used directly
# y = instance.take()         # ABORT: `Optional.take()` called on empty `Optional` (via runtime `abort`)
# print(y)                    # Does not reach this line
```

Returns: The contained data of the `Optional` as an owned T value.

#### `Optional.unsafe_take`

```mojo
def unsafe_take(mut self) -> T where conforms_to(T, Movable)
```

Unsafely move the value out of the `Optional`.

Notes:
This will **not** abort on empty `Optional`.

Examples:

```mojo
var instance = Optional("Hello")
print(instance.bounds()[0])     # Output: 1
var x = instance.unsafe_take()  # Moves value from `instance` to `x`
print(x)                        # Output: Hello

# `instance` is now `Optional(None)`
print(instance.bounds()[0])     # Output: 0
print(instance)                 # Output: None

# Best practice:
if instance:
    var y = instance.unsafe_take() # Won't reach this line
    print(y)

# In debug builds, this will deterministically abort:
y = instance.unsafe_take()      # ABORT: `Optional.take()` called on empty `Optional` (via `debug_assert`)
print(y)                        # Does not reach this line
```

Returns: The contained data of the `Optional` as an owned T value.

#### `Optional.deinit_with`

```mojo
def deinit_with[F: def(var T) -> None](deinit self, deinit_func: F, /)
```

Destroy the value contained in this `Optional` in-place using a caller-provided deinitializer function.

This method can be used to destroy `Optional` values whose element
type is not `Deinitable`. The `__deinit__` on `Optional`
requires `T: Deinitable`, so explicit-deinit users must
destroy an `Optional[T]` through this API instead.

If `self` is empty, `deinit_func` is not called. Otherwise
`deinit_func` is called exactly once on the contained value.

Examples:

```mojo
@fieldwise_init
struct ExplicitDeinit(Movable, not Deinitable):
    var data: Int

    def explicit_deinit(deinit self):
        pass

var opt = Optional(ExplicitDeinit(5))
opt^.deinit_with(ExplicitDeinit.explicit_deinit)
```

Parameters:

- `F`: The type of the caller-provided deinitializer function.

Args:

- `deinit_func`: Caller-provided deinitializer function for destroying an instance of `Self.T`. Not called when `self` is empty.

#### `Optional.deinit_assert_empty`

```mojo
def deinit_assert_empty(deinit self)
```

Destroys an empty `Optional`, asserting that it holds no value.

Use this on an `Optional[T]` whose element type is not
`Deinitable` when the value is known to be empty. Unlike
`deinit_with`, it takes no deinitializer function (there is no live
value to destroy). In safe-assert builds it aborts if the `Optional`
is non-empty.

Examples:

```mojo
var opt: Optional[ExplicitDeinit] = None
opt^.deinit_assert_empty()
```

#### `Optional.or_else`

```mojo
def or_else(deinit self, var default: T) -> T where conforms_to(T, Deinitable & Movable)
```

Return the underlying value contained in the `Optional` or a default value if the `Optional`'s underlying value is not present.

Examples:

```mojo
var instance = Optional("Hello")
print(instance)                  # Output: 'Hello'
print(instance.or_else("Bye"))   # Output: Hello
instance = None
print(instance)                  # Output: None
print(instance.or_else("Bye"))   # Output: Bye
```

Args:

- `default`: The new value to use if no value was present.

Returns: The underlying value contained in the `Optional` or a default value.

#### `Optional.copied`

```mojo
def copied[mut: Bool, origin: Origin[mut=mut], //, _T: Copyable](self: Optional[Pointer[_T, origin]]) -> Optional[_T]
```

Converts an `Optional` containing a Pointer to an `Optional` of an owned value by copying.

Examples:

Copy the value of an `Optional[Pointer[_]]`

```mojo
var data = "foo"
var opt = Optional(Pointer(to=data))
var opt_owned: Optional[String] = opt.copied()
```

Notes:
If `self` is an empty `Optional`, the returned `Optional` will be
empty as well.

Parameters:

- `mut`: Mutability of the pointee origin.
- `origin`: Origin of the contained `Pointer`.
- `_T`: Type of the owned result value.

Returns: An `Optional` containing an owned copy of the pointee value.

#### `Optional.map`

```mojo
def map[To: Movable, //, Mapper: def(var T) -> To](deinit self, mapper: Mapper) -> Optional[To] where conforms_to(T, Movable)
```

Applies a function to the contained value (if any), returning an `Optional` containing the result.

Transforms `Optional[T]` into `Optional[To]` by applying `mapper` to
the contained value. If `self` is empty, returns an empty `Optional[To]`
without calling `mapper`.

Examples:

Map the value inside an `Optional` to a different type:

```mojo
var opt = Optional("hello")
var length = opt.map(String.byte_length)
print(length.value())  # Output: 5
```

If the `Optional` is empty, the mapper is not called:

```mojo
var opt = Optional[String](None)
var length = opt.map(String.byte_length)
print(length.or_else(-1))  # Output: -1
```

Parameters:

- `To`: The result type of the mapping closure.
- `Mapper`: The type of the mapping closure.

Args:

- `mapper`: The closure to apply to the contained value.

Returns: An `Optional[To]` containing the mapped value, or `None` if `self` was empty.

#### `Optional.and_then`

```mojo
def and_then[To: Movable, //, Mapper: def(var T) -> Optional[To]](deinit self, mapper: Mapper) -> Optional[To] where conforms_to(T, Movable)
```

Calls `mapper` on the contained value (if any), returning the result.

Unlike `map()`, the mapper function itself returns an `Optional`. This
allows chaining operations that may each independently fail. Sometimes
called "flat map" in other languages.

Examples:

Chain operations that may each return `None`:

```mojo
def try_parse_int(s: String) -> Optional[Int]:
    try:
        return Int(s)
    except:
        return None

def main():
    var opt = Optional("42")
    var parsed = opt.and_then(try_parse_int)
    print(parsed.value())  # Output: 42
```

If the `Optional` is empty, the mapper is not called:

```mojo
def main():
    var opt = Optional[String](None)
    var parsed = opt.and_then(try_parse_int)
    print(parsed.or_else(-1))  # Output: -1
```

Parameters:

- `To`: The value type of the `Optional` returned by the mapper.
- `Mapper`: The type of the mapping function.

Args:

- `mapper`: The function to apply to the contained value. Must return an `Optional[To]`.

Returns: The `Optional[To]` returned by `mapper`, or `None` if `self` was empty.

### `OptionalReg`

```mojo
struct OptionalReg[T: TrivialRegisterPassable]
```

A register-passable optional type.

This struct optionally contains a value. It only works with trivial register
passable types at the moment.

Parameters:

- `T`: The type of value stored in the Optional.

Implemented traits: `AnyType`, `Boolable`, `Copyable`, `Defaultable`, `Deinitable`, `DevicePassable`, `EnumLike`, `ImplicitlyCopyable`, `Movable`, `RegisterPassable`, `TrivialRegisterPassable`

Aliases:

- `device_type = OptionalReg[T(DevicePassable & TrivialRegisterPassable).device_type(TrivialRegisterPassable) if conforms_to(T, DevicePassable) else T]`: The device-side type for this optional register.

#### `OptionalReg.__init__`

```mojo
def __init__() -> Self
```

Create an optional with a value of None.

```mojo
def __init__(value: T) -> Self
```

Create an optional with a value.

Args:

- `value`: The value.

```mojo
def __init__(value: NoneType) -> Self
```

Create an optional without a value from a None literal.

Args:

- `value`: The None value.

```mojo
def __init__(optional: Optional[T]) -> Self
```

Implicitly convert an `Optional[T]` to an `OptionalReg[T]`.

Args:

- `optional`: The `Optional` to convert from.

#### `OptionalReg.__bool__`

```mojo
def __bool__(self) -> Bool
```

Return true if the optional has a value.

Returns: True if the optional has a value and False otherwise.

#### `OptionalReg.__is__`

```mojo
def __is__(self, other: NoneType) -> Bool
```

Return `True` if the Optional has no value.

It allows you to use the following syntax: `if my_optional is None:`

Args:

- `other`: The value to compare to (None).

Returns: True if the Optional has no value and False otherwise.

#### `OptionalReg.__isnot__`

```mojo
def __isnot__(self, other: NoneType) -> Bool
```

Return `True` if the Optional has a value.

It allows you to use the following syntax: `if my_optional is not None:`

Args:

- `other`: The value to compare to (None).

Returns: True if the Optional has a value and False otherwise.

#### `OptionalReg.get_type_name`

```mojo
def get_type_name() -> String
```

Get the human-readable type name for this `OptionalReg` type.

Returns: A string representation of the type, e.g. `OptionalReg[Int]`.

#### `OptionalReg.value`

```mojo
def value(self) -> T
```

Get the optional value.

Returns: The contained value.

#### `OptionalReg.unsafe_value`

```mojo
def unsafe_value(self) -> T
```

Get the optional value.

Returns: The contained value.

#### `OptionalReg.or_else`

```mojo
def or_else(var self, var default: T) -> T
```

Return the underlying value contained in the Optional or a default value if the Optional's underlying value is not present.

Args:

- `default`: The new value to use if no value was present.

Returns: The underlying value contained in the Optional or a default value.
