# `std.builtin.tuple`

Implements the Tuple type.

These are Mojo built-ins, so you don't need to import them.

## Structs

### `Tuple`

```mojo
struct Tuple[*Ts: Movable]
```

The type of a literal tuple expression.

A tuple consists of zero or more values, separated by commas.

Parameters:

- `*Ts`: The elements type.

Implemented traits: `AnyType`, `Comparable`, `Copyable`, `Defaultable`, `Deinitable`, `Equatable`, `Hashable`, `ImplicitlyCopyable`, `Movable`, `RegisterPassable`, `Sized`, `Writable`

Aliases:

- `element_types = Ts`: The elements type. Deprecated alias for `Ts`.

#### `Tuple.__init__`

```mojo
def __init__(out self) where TypeList.all_conforms_to[Defaultable]()
```

Construct a tuple with default-initialized elements.

Constraints: All `Ts` must conform to `Defaultable`. The constraint
is enforced via a per-element `comptime assert` in the body
instead of an explicit `where` clause so that callers whose
element types come from a comptime reducer (which the solver
can't reduce through when checking
`all_conforms_to[Defaultable]()`) can
still default-construct.

```mojo
def __init__(out self, var *args: *Ts.values)
```

Construct the tuple.

Args:

- `*args`: Initial values.

```mojo
def __init__(out self, *, copy: Self) where TypeList.all_conforms_to[Copyable]()
```

Copy construct the tuple.

Args:

- `copy`: The value to copy from.

```mojo
def __init__(out self, *, deinit move: Self)
```

Move construct the tuple.

Args:

- `move`: The value to move from.

#### `Tuple.__deinit__`

```mojo
def __deinit__(deinit self) where TypeList.all_conforms_to[Deinitable]()
```

Destructor that destroys all of the elements.

Constraints: All `Ts` must be `Deinitable`. When any element
is not, the tuple has no implicit destructor and must be torn down
with `deinit_with()`.

#### `Tuple.__lt__`

```mojo
def __lt__(self, other: Self, /) -> Bool where TypeList.all_conforms_to[Comparable]()
```

Compare this tuple to another tuple using less than comparison.

Args:

- `other`: The other tuple to compare against.

Returns: True if this tuple is less than the other tuple, False otherwise.

#### `Tuple.__le__`

```mojo
def __le__(self, other: Self, /) -> Bool where TypeList.all_conforms_to[Comparable]()
```

Compare this tuple to another tuple using less than or equal to comparison.

Args:

- `other`: The other tuple to compare against.

Returns: True if this tuple is less than or equal to the other tuple, False otherwise.

#### `Tuple.__eq__`

```mojo
def __eq__(self, other: Self) -> Bool where TypeList.all_conforms_to[Equatable]()
```

Compare this tuple to another tuple using equality comparison.

Args:

- `other`: The other tuple to compare against.

Returns: True if this tuple is equal to the other tuple, False otherwise.

#### `Tuple.__gt__`

```mojo
def __gt__(self, other: Self, /) -> Bool where TypeList.all_conforms_to[Comparable]()
```

Compare this tuple to another tuple using greater than comparison.

Args:

- `other`: The other tuple to compare against.

Returns: True if this tuple is greater than the other tuple, False otherwise.

#### `Tuple.__ge__`

```mojo
def __ge__(self, other: Self, /) -> Bool where TypeList.all_conforms_to[Comparable]()
```

Compare this tuple to another tuple using greater than or equal to comparison.

Args:

- `other`: The other tuple to compare against.

Returns: True if this tuple is greater than or equal to the other tuple, False otherwise.

#### `Tuple.__contains__`

```mojo
def __contains__[T: Equatable](self, value: T) -> Bool where TypeList.contains[T]()
```

Return whether the tuple contains the specified value.

For example:

```mojo
var t = Tuple(True, 1, 2.5)
if 1 in t:
    print("t contains 1")
```

Constraints: `T` must be one of the tuple's element types. A value of any
other type is never compared against the elements, so the
result would always be False.

Parameters:

- `T`: The type of the value.

Args:

- `value`: The value to search for.

Returns: True if the value is in the tuple, False otherwise.

#### `Tuple.deinit_with`

```mojo
def deinit_with[F: def[idx: Int](var elt: Ts.values[idx]) -> None](deinit self, deinit_func: F, /)
```

Consume the tuple, deinitializing each element with a closure.

Use this to tear down a `Tuple` whose elements are not
`Deinitable`. Elements are visited in index order.

Parameters:

- `F`: The type of the deinitializing closure.

Args:

- `deinit_func`: A closure called once per element, receiving ownership of the element at that index so it can destroy it.

#### `Tuple.__len__`

```mojo
def __len__() -> Int
```

Return the number of elements in the tuple.

Returns: The tuple length.

```mojo
def __len__(self) -> Int
```

Get the number of elements in the tuple.

Returns: The tuple length.

#### `Tuple.__getitem_param__`

```mojo
def __getitem_param__[idx: Int](ref self) -> ref[idx] Ts.values[SIMDLength(idx)]
```

Get a reference to an element in the tuple.

Parameters:

- `idx`: The element to return.

Returns: A reference to the specified element.

#### `Tuple.first_of`

```mojo
def first_of[T: Movable](ref self) -> ref[T] T
```

Get a reference to the first element whose type is `T`.

The lookup is resolved at compile time, and it is a compile-time error
if the tuple has no element of type `T`. For example:

```mojo
var t = (String("one"), 2, String("three"))
t.first_of[String]() += "!"
print(t.first_of[String]())  # one!
```

Parameters:

- `T`: The element type to look up.

Returns: A reference to the first element of type `T`, propagating the mutability of `self`.

#### `Tuple.__hash__`

```mojo
def __hash__[H: Hasher](self, mut hasher: H) where TypeList.all_conforms_to[Hashable]()
```

Hashes the tuple using the given hasher.

Parameters:

- `H`: The hasher type.

Args:

- `hasher`: The hasher instance.

#### `Tuple.write_to`

```mojo
def write_to(self, mut writer: T) where TypeList.all_conforms_to[Writable]()
```

Write this tuple's text representation to a writer.

Elements are formatted using their `write_to()` representation.
Single-element tuples include a trailing comma: `(1,)`.

Args:

- `writer`: The writer to write to.

#### `Tuple.write_repr_to`

```mojo
def write_repr_to(self, mut writer: T) where TypeList.all_conforms_to[Writable]()
```

Write this tuple's debug representation to a writer.

Outputs the type name and parameters followed by elements formatted
using their `write_repr_to()` representation. For example,
`Tuple[Int, String](Int(0), 'hello')`.

Args:

- `writer`: The writer to write to.

#### `Tuple.reverse`

```mojo
def reverse(deinit self, out result: Tuple[*#kgen.param_list.tabulate(len(Ts.values), [idx: __mlir_type.index] Ts.values[(add (mul idx, -1), len(Ts.values), -1)])])
```

Return a new tuple with the elements in reverse order.

Usage:

```mojo
image_coords = Tuple[Int, Int](100, 200) # row-major indexing
screen_coords = image_coords.reverse() # (col, row) for x,y display
print(screen_coords[0], screen_coords[1]) # output: 200, 100
```

Returns: A new tuple with the elements in reverse order.

#### `Tuple.concat`

```mojo
def concat[*OtherTs: Movable](deinit self, deinit other: Tuple[OtherTs], out result: Tuple[*#kgen.param_list.concat(Ts.values, OtherTs.values)])
```

Return a new tuple that concatenates this tuple with another.

Usage:

```mojo
var rgb = Tuple[Int, Int, Int](0xFF, 0xF0, 0x0)
var rgba = rgb.concat(Tuple[Int](0xFF)) # Adds alpha channel
print(rgba[0], rgba[1], rgba[2], rgba[3]) # 255 240 0 255
```

Parameters:

- `*OtherTs`: The types of the elements contained in the other Tuple.

Args:

- `other`: The other tuple to concatenate.

Returns: A new tuple with the concatenated elements.

#### `Tuple.consume_elements`

```mojo
def consume_elements[F: def[idx: Int](var elt: Ts.values[idx]) -> None](deinit self, elt_handler: F, /)
```

Consume the tuple by transferring ownership of each element into the provided closure one at a time.

Destructuring assignment such as `a, b = t^` desugars to
reference-returning subscripts, so it copies each element and cannot
extract elements whose type is `Movable` but not `ImplicitlyCopyable`.
`consume_elements` hands each element to `elt_handler` by value instead,
so a tuple of move-only elements can still be taken apart. Elements are
visited in index order.

Example:

`List` is `Movable` but not `ImplicitlyCopyable`, so its elements can
be moved out of a tuple but not copied out:

```mojo
# Each `List` is moved out of the tuple, one at a time.
var t = ([1, 2, 3], [4, 5, 6])

def handler[idx: Int](var elt: t.Ts[idx]):
    print(len(elt))  # prints 3, then 3

t^.consume_elements(handler)
```

Parameters:

- `F`: The type of the element handler closure.

Args:

- `elt_handler`: A function called once for each element of the tuple, receiving ownership of the element at that index.
