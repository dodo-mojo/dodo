# `std.builtin.variadics`

Implements the VariadicList, ParameterList and VariadicPack types.

These are Mojo built-ins, so you don't need to import them.

## Structs

### `TypeList`

```mojo
struct TypeList[Trait: AnyTrait[AnyType], //, values: KGENParamList[Trait]]
```

A compile-time list of types conforming to a common trait.

`TypeList` provides type-level operations on variadic sequences of types,
such as reversing, slicing, mapping, and membership testing.

Examples:

```mojo
from std.builtin.variadics import TypeList
from std.testing import assert_equal

# Create a type list
comptime tl = TypeList.of[Trait=AnyType, Int, String, Float64]()

def main() raises:
    # Query length
    assert_equal(tl.length, 3)

    # Check membership
    comptime assert tl.contains[Int]()
    comptime assert not tl.contains[Bool]()

    # Index into the list
    comptime assert tl[0] == Int
```

Parameters:

- `Trait`: The trait that all types in the list must conform to.
- `values`: The types in the list.

Implemented traits: `AnyType`, `Copyable`, `Deinitable`, `ImplicitlyCopyable`, `Movable`, `RegisterPassable`, `Sized`, `TrivialRegisterPassable`

Aliases:

- `length = SIMD(mlir_value=len(values))`: The number of types in the list.
- `__getitem_param__ = values[idx]`: Gets a type at the given index.
- `of = TypeList[values]`: Form a compile-time list of types with some elements, uninstantiated.
- `tabulate = TypeList[#kgen.param_list.tabulate(count, [idx: __mlir_type.index] Mapper[Int(idx)])]`: Builds a type list by applying an index-to-type mapper `count` times.
- `splat = comptime[ToT: Trait, //] TypeList[#kgen.param_list.tabulate(count, [idx: __mlir_type.index] type)]`: Splats a type a given number of times.
- `reduce = #kgen.param_list.reduce(values, base=BaseVal, reducer=[PrevV: FromAndTo, VA: KGENParamList[Trait], idx: __mlir_type.index] Reducer[PrevV, VA[idx]])`: Folds this type list to a single value using an associative step function.
- `reduce_idx = #kgen.param_list.reduce(values, base=BaseVal, reducer=[PrevV: FromAndTo, VA: KGENParamList[Trait], idx: __mlir_type.index] Reducer[PrevV, VA[idx], Int(idx)])`: Folds this type list to a single value using a step function of position.
- `map = comptime[ToT: ToTrait, //] TypeList[#kgen.param_list.tabulate(len(values), [idx: __mlir_type.index] Mapper[values[SIMDLength(Int(idx))]])]`: Maps types to new types using a mapper.
- `filter_idx = TypeList[#kgen.param_list.concat(#kgen.param_list.tabulate(len(values), [idx: __mlir_type.index] values[idx] if Predicate[values[SIMDLength(Int(idx))], Int(idx)] else ))]`: Returns a new `TypeList` containing only elements selected by a predicate.
- `map_to_values = ParameterList[#kgen.param_list.tabulate(len(values), [idx: __mlir_type.index] Mapper[values[SIMDLength(Int(idx))]])]`: Convert each type in this list to a value, forming a ParameterList.
- `reverse = TypeList[#kgen.param_list.tabulate(len(values), [idx: __mlir_type.index] values[SIMDLength((Int((add len(values), -1)) - Int(idx)))])]`: Returns this type list in reverse order.
- `slice = comptime[ToT: Trait, //] TypeList[#kgen.param_list.tabulate(max((end - start), Int(0)), [idx: __mlir_type.index] values[SIMDLength((start + Int(idx)))])]`: Extracts a contiguous subsequence from the type list.

#### `TypeList.__init__`

```mojo
def __init__(existing: TypeList) -> TypeList[existing.values] where #kgen.is_refined_type<!kgen.param<:meta<!lit.trait<@std::@traits::@anytype::@AnyType>> *"existing.Trait`2x">, !kgen.param<:meta<!lit.trait<@std::@traits::@anytype::@AnyType>> Trait>>
```

Upcasts a TypeList to a base trait.

Constraints: The existing.Trait is more refined than Self.Trait.

Args:

- `existing`: The TypeList to upcast from.

```mojo
def __init__() -> Self
```

Constructs a TypeList.

#### `TypeList.any`

```mojo
def any[predicate: __generator_type[Type: Trait] Bool]() -> Bool
```

Returns true if `predicate` holds for at least one type in this list.

Parameters:

- `predicate`: A compile-time generator `[T: Self.Trait] -> Bool`.

Returns: True if `predicate` holds for at least one type in this list, False otherwise.

#### `TypeList.all_conforms_to`

```mojo
def all_conforms_to[_trait: AnyTrait[AnyType]]() -> Bool
```

Returns true if all types in this list conform to `Trait`.

Parameters:

- `_trait`: The trait to check for conformance to.

Returns: True if all types in this list conform to `Trait`, False otherwise.

#### `TypeList.all`

```mojo
def all[predicate: __generator_type[Type: Trait] Bool]() -> Bool
```

Returns true if `predicate` holds for every type in this list.

For an empty list, returns true.

Parameters:

- `predicate`: A compile-time generator `[T: Self.Trait] -> Bool`.

Returns: True if `predicate` holds for every type in this list, False otherwise.

#### `TypeList.contains`

```mojo
def contains[type: AnyType]() -> Bool
```

Checks if a type is contained in this type list.

Parameters:

- `type`: The type to check for.

Returns: True if the type is contained in this type list, False otherwise.

#### `TypeList.__len__`

```mojo
def __len__(self) -> Int
```

Gets the number of elements in the TypeList.

Returns: The number of elements on the TypeList.

### `ParameterList`

```mojo
struct ParameterList[type: AnyType, //, values: KGENParamList[type]]
```

A utility class to access homogeneous variadic parameters.

`ParameterList` is used by homogenous variadic parameter lists. Unlike
`VariadicPack` (which is heterogeneous), `ParameterList` requires all
elements to have the same type.

`ParameterList` is only used for parameter lists, `VariadicList` is
used for function arguments.

For example, in the following function signature, `*args: Int` creates a
`ParameterList` because it uses a single type `Int` instead of a variadic type
parameter. The `*` before `args` indicates that `args` is a variadic argument,
which means that the function can accept any number of arguments, but all
arguments must have the same type `Int`.

```mojo
def sum_values[*args: Int]():

    # Iterate over elements at compile time
    comptime for i in range(args.size):  # can also use len() at comptime

        # print() below is a run-time call, so placing args[i] directly inside
        # it will invoke run-time access and not compile-time access; both share
        # the same syntax. For illustration, we place comptime access in a separate
        # step here.
        comptime arg = args[i]
        print(arg, end=" ")

    print()

    # Iterate over elements at run-time
    var total = 0
    for i in range(len(args)): # can also use the comptime args.size
        total += args[i]

    print(total)

def main():
    sum_values[1, 2, 3, 4, 5]()

    # Output:
    #  1 2 3 4 5
    #  15
```

Parameters:

- `type`: The type of the elements in the list.
- `values`: The values in the list.

Implemented traits: `AnyType`, `Copyable`, `Deinitable`, `ImplicitlyCopyable`, `Movable`, `RegisterPassable`, `Sized`, `TrivialRegisterPassable`, `Writable`

Aliases:

- `size = SIMD(mlir_value=len(values))`: The number of elements in the list.
- `__getitem_param__ = values[idx]`: Gets a single element on the variadic list.
- `empty_of = ParameterList[]`: Form an empty compile-time list of values some element type.
- `of = ParameterList[values]`: Form a compile-time list of values with some elements, uninstantiated.
- `tabulate = ParameterList[#kgen.param_list.tabulate(count, [idx: __mlir_type.index] Mapper[Int(idx)])]`: Builds a parameter list by applying an index-to-value mapper `count` times.
- `splat = ParameterList[#kgen.param_list.tabulate(count, [idx: __mlir_type.index] value)]`: Builds a homogeneous parameter list by repeating `value` `count` times.
- `reduce = #kgen.param_list.reduce(values, base=BaseVal, reducer=[PrevV: FromAndTo, VA: KGENParamList[type], idx: __mlir_type.index] Reducer[PrevV, values[idx]])`: Form a value by applying a function that merges each element into a starting value, then return the result.
- `map_to_type = comptime[ToT: Trait, //] TypeList[#kgen.param_list.tabulate(len(values), [idx: __mlir_type.index] Mapper[values[SIMDLength(Int(idx))]])]`: Convert each element of this list into a type, forming a TypeList with the result.

#### `ParameterList.__init__`

```mojo
def __init__() -> Self
```

Constructs a ParameterList.

#### `ParameterList.__getitem__`

```mojo
def __getitem__(self, idx: Int) -> ref[ImmStaticOrigin] type
```

Gets a single element on the variadic list.

Args:

- `idx`: The index of the element to access on the list.

Returns: The element on the list corresponding to the given index.

#### `ParameterList.__len__`

```mojo
def __len__(self) -> Int
```

Gets the size of the list.

Returns: The number of elements on the variadic list.

#### `ParameterList.get_span`

```mojo
def get_span() -> Span[type, ImmStaticOrigin]
```

Gets a span of the elements on the variadic list.

Returns: A span of the elements on the variadic list.

#### `ParameterList.any`

```mojo
def any[predicate: __generator_type[Elt: type] Bool]() -> Bool
```

'any' applies a function to each element and returns true if the function returns True for any element.

Parameters:

- `predicate`: A `[elt: Self.Type] -> Bool` comptime expression to apply.

Returns: True if the predicate returns True for any element, False otherwise.

#### `ParameterList.all`

```mojo
def all[predicate: __generator_type[Elt: type] Bool]() -> Bool
```

'all' applies a function to each element and returns true if the function returns True for all elements.

Parameters:

- `predicate`: A `[elt: Self.Type] -> Bool` comptime expression to apply.

Returns: True if the predicate returns True for all elements, False otherwise.

#### `ParameterList.contains`

```mojo
def contains[value: type]() -> Bool where conforms_to(type, Equatable)
```

Check if a value is contained in a variadic sequence of values.

Parameters:

- `value`: The value to search for.

Returns: True if the value is contained in the list, False otherwise.

#### `ParameterList.write_to`

```mojo
def write_to(self, mut writer: T) where conforms_to(type, Writable)
```

Writes the elements of this variadic list to a writer.

Constraints: `type` must conform to `Writable`.

Args:

- `writer`: The object to write to.

#### `ParameterList.write_repr_to`

```mojo
def write_repr_to(self, mut writer: T) where conforms_to(type, Writable)
```

Writes the repr of this variadic list to a writer.

Constraints: `type` must conform to `Writable`.

Args:

- `writer`: The object to write to.

#### `ParameterList.__iter__`

```mojo
def __iter__(ref self) -> _ParameterListIter[ParameterList()] where conforms_to(type, Copyable)
```

Iterate over the list.

Returns: An iterator to the start of the list.

### `VariadicList`

```mojo
struct VariadicList[elt_is_mutable: Bool, origin: Origin[mut=elt_is_mutable], //, element_type: AnyType, is_owned: Bool]
```

A utility class to access variadic function arguments of memory-only types that may have ownership. It exposes references to the elements in a way that can be enumerated.  Each element may be accessed with `elt[]`.

Parameters:

- `elt_is_mutable`: True if the elements of the list are mutable for an mut or owned argument.
- `origin`: The origin of the underlying elements.
- `element_type`: The type of the elements in the list.
- `is_owned`: Whether the elements are owned by the list because they are passed as an 'var' argument.

Implemented traits: `AnyType`, `Deinitable`, `Movable`, `RegisterPassable`, `Sized`, `Writable`

#### `VariadicList.__deinit__`

```mojo
def __deinit__(deinit self)
```

Destructor that releases elements if owned.

#### `VariadicList.__getitem__`

```mojo
def __getitem__[self_origin: ImmOrigin](ref[elt_is_mutable] self, idx: Int) -> ref[origin, elt_is_mutable] element_type
```

Gets a single element on the variadic list.

Parameters:

- `self_origin`: The origin of the list.

Args:

- `idx`: The index of the element to access on the list.

Returns: A low-level pointer to the element on the list corresponding to the given index.

#### `VariadicList.consume_elements`

```mojo
def consume_elements(deinit self, elt_handler: T) where is_owned
```

Consume the variadic list by transferring ownership of each element into the provided closure one at a time.  This is only valid on 'owned' variadic lists.

Args:

- `elt_handler`: A function that will be called for each element of the list.

#### `VariadicList.__len__`

```mojo
def __len__(self) -> Int
```

Gets the size of the list.

Returns: The number of elements on the variadic list.

#### `VariadicList.write_to`

```mojo
def write_to(self, mut writer: T) where conforms_to(element_type, Writable)
```

Writes the elements of this variadic list to a writer.

Constraints: `element_type` must conform to `Writable`.

Args:

- `writer`: The object to write to.

#### `VariadicList.write_repr_to`

```mojo
def write_repr_to(self, mut writer: T) where conforms_to(element_type, Writable)
```

Writes the repr of this variadic list to a writer.

Constraints: `element_type` must conform to `Writable`.

Args:

- `writer`: The object to write to.

#### `VariadicList.__iter__`

```mojo
def __iter__[self_origin: ImmOrigin](ref[elt_is_mutable] self) -> _VariadicListIter[element_type, origin, self_origin, is_owned]
```

Iterate over the list.

Parameters:

- `self_origin`: The origin of the list.

Returns: An iterator to the start of the list.

### `VariadicPack`

```mojo
struct VariadicPack[elt_is_mutable: Bool, origin: Origin[mut=elt_is_mutable], element_trait: AnyTrait[AnyType], //, is_owned: Bool, *Ts: element_trait]
```

A utility class to access heterogeneous variadic function arguments.

`VariadicPack` is used when you need to accept variadic arguments where each
argument can have a different type, but all types conform to a common trait.
Unlike `ParameterList` (which is homogeneous), `VariadicPack` allows each
element to have a different concrete type.

`VariadicPack` is essentially a heterogeneous tuple that gets lowered to a
struct at runtime. Because `VariadicPack` is a heterogeneous tuple (not an
array), each element can have a different size and memory layout, which
means the compiler needs to know the exact type of each element at compile
time to generate the correct memory layout and access code.

Therefore, indexing into `VariadicPack` requires compile-time indices using
`comptime for` loops, whereas indexing into `ParameterList` uses runtime
indices.

For example, in the following function signature, `*args: *ArgTypes` creates a
`VariadicPack` because it uses a variadic type parameter `*ArgTypes` instead
of a single type. The `*` before `ArgTypes` indicates that `ArgTypes` is a
variadic type parameter, which means that the function can accept any number
of arguments, and each argument can have a different type. This allows each
argument to have a different type while all types must conform to the
`Intable` trait.

```mojo
def count_many_things[*ArgTypes: Intable](*args: *ArgTypes) -> Int:
    var total = 0

    # Must use comptime for loop because args is a VariadicPack
    comptime for i in range(args.__len__()):
        # Each args[i] has a different concrete type from *ArgTypes
        # The compiler generates specific code for each iteration
        total += Int(args[i])

    return total

def main():
    print(count_many_things(Int8(5), UInt32(11), Int(12)))  # Prints: 28
```

Parameters:

- `elt_is_mutable`: True if the elements of the list are mutable for an mut or owned argument pack.
- `origin`: The origin of the underlying elements.
- `element_trait`: The trait that each element of the pack conforms to.
- `is_owned`: Whether the elements are owned by the pack. If so, the pack will release the elements when it is destroyed.
- `*Ts`: The list of types held by the argument pack.

Implemented traits: `AnyType`, `Copyable`, `Deinitable`, `Movable`, `RegisterPassable`, `Sized`

Aliases:

- `element_types = Ts`: The list of types held by the argument pack. Deprecated alias for `Ts`.

#### `VariadicPack.__init__`

```mojo
def __init__(*, copy: Self) -> Self where not is_owned
```

Copy construct the variadic pack.

Constraints: The variadic pack must not be owned.

Args:

- `copy`: The pack to copy from.

#### `VariadicPack.__deinit__`

```mojo
def __deinit__(deinit self)
```

Destructor that releases elements if owned.

#### `VariadicPack.consume_elements`

```mojo
def consume_elements[F: def[idx: Int](var elt: Ts.values[idx]) -> None](deinit self, elt_handler: F, /) where is_owned
```

Consume the variadic pack by transferring ownership of each element into the provided closure one at a time.  This is only valid on 'owned' variadic packs.

Parameters:

- `F`: The type of the element handler closure.

Args:

- `elt_handler`: A function that will be called for each element of the pack.

#### `VariadicPack.__len__`

```mojo
def __len__() -> Int
```

Return the VariadicPack length.

Returns: The number of elements in the variadic pack.

```mojo
def __len__(self) -> Int
```

Return the VariadicPack length.

Returns: The number of elements in the variadic pack.

#### `VariadicPack.__getitem_param__`

```mojo
def __getitem_param__[index: Int](self) -> ref[origin] Ts.values[SIMDLength(index)]
```

Return a reference to an element of the pack.

Parameters:

- `index`: The element of the pack to return.

Returns: A reference to the element. The Pointer's mutability follows the mutability of the pack argument convention.

#### `VariadicPack.write_to`

```mojo
def write_to(self, mut writer: T) where TypeList.all_conforms_to[Writable]()
```

Writes the elements of this pack to a writer.

Args:

- `writer`: The object to write to.

#### `VariadicPack.write_repr_to`

```mojo
def write_repr_to(self, mut writer: T) where TypeList.all_conforms_to[Writable]()
```

Writes the repr of the elements of this pack to a writer.

Args:

- `writer`: The object to write to.
