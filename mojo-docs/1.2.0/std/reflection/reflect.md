# `std.reflection.reflect`

Provides the unified `reflect[T]` / `Reflected[T]` reflection API.

`reflect[T]` is a `comptime` alias for the `Reflected[T]` handle type, which
exposes type introspection through static methods. The handle has no runtime
state — `T` is carried entirely in the compile-time parameter — so all queries
are spelled as `reflect[T].method()` (no parens after `[T]`).

- `is_struct()` - whether `T` is a Mojo struct type.
- `field_count()` - number of fields.
- `field_names()` - `Array[StaticString, N]` of field names.
- `field_types()` - a `TypeList` of field types.
- `field_index[name]()` - index of the named field.
- `field[name]` - `Reflected[FieldT]` for the named field's type.
- `field_at[idx]` - `Reflected[FieldT]` for the field at index `idx`.
- `field_offset[name=...]()` / `field_offset[index=...]()` - byte offset.
- `field_ref[idx](s)` - reference to field at index `idx` in value `s`.
- `annotations()` - the struct's `@__annotation` values as a `Tuple`.
- `field_annotations[field_idx]()` - a field's `@__annotation` values as a
  `Tuple`.

`reflect` is auto-imported via the prelude, so it is available without
an explicit import. `Reflected[T]` must be imported from `std.reflection`
when named in signatures.

Example:

```mojo
struct Point:
    var x: Int
    var y: Float64

def print_fields[T: AnyType]():
    comptime names = reflect[T].field_names()
    comptime for i in range(reflect[T].field_count()):
        print(materialize[names[i]]())

def main():
    print_fields[Point]()
```

The wrapped type is exposed as the `T` parameter, so the result of
`field[name]` can be used as a type directly:

```mojo
def main():
    comptime y_type = reflect[Point].field["y"]
    var v: y_type.T = 3.14  # y_type.T is Float64
```

## Aliases

### `reflect`

```mojo
comptime reflect[T: AnyType] = Reflected[T]
```

A compile-time alias for the reflection handle type of `T`.

Resolves to `Reflected[T]`, whose static methods expose introspection of `T`.
Use it as `reflect[T].method()` rather than constructing an instance.

`reflect` is auto-imported via the prelude.

Example:
```mojo
struct Point:
    var x: Int
    var y: Float64

def main():
    print(reflect[Point].field_count())  # 2
```

## Structs

### `Reflected`

```mojo
struct Reflected[T: AnyType]
```

A compile-time reflection handle type for a Mojo type.

`Reflected[T]` exposes compile-time introspection of `T` through static
methods. It has no runtime fields — `T` lives entirely in the compile-time
parameter — and is not constructible. Spell access as `reflect[T].method()`
(preferred) or `Reflected[T].method()`.

Member shape — when to use `@staticmethod` vs a `comptime` alias:

- A member that returns a **type** (e.g. `Reflected[FieldT]`) is a
  `comptime` member alias and is spelled without `()`. This keeps it
  composable in type position: `reflect[T].field["x"].T` reads as a
  type. `field[name]` and `field_at[idx]` are the type-returning
  members today.
- A member that returns a **value** (an `Int`, `StaticString`,
  `Array`, a `TypeList`, a typed `ref`, etc.) is an
  `@staticmethod` and is spelled with `()` — e.g.
  `reflect[T].field_count()`, `reflect[T].field_names()`,
  `reflect[T].field_index["x"]()`. The `()` at the call site signals
  "evaluate this comptime expression to a value." `field_types`
  returns a `TypeList` value (not a type) and so is a static method.

When adding a new member: pick a `comptime` alias if the result will be
used in type position, `@staticmethod` if it will be assigned to a
`comptime` variable or compared at the call site.

For best performance, assign the result of static methods that return
type-level values (such as `field_names`, `field_types`, `field_count`)
to `comptime` variables so the work happens at compile time.

Example:
```mojo
struct Point:
    var x: Int
    var y: Float64

def main():
    comptime if reflect[Point].is_struct():
        comptime names = reflect[Point].field_names()
        comptime for i in range(reflect[Point].field_count()):
            print(materialize[names[i]]())
```

Parameters:

- `T`: The type being introspected. The wrapped type is exposed via this parameter, so `reflect[T].T` is `T`.

Implemented traits: `AnyType`, `Deinitable`, `Movable`

Aliases:

- `field = Reflected[#kgen.struct_field_type_by_name<:trait<@std::@traits::@anytype::@AnyType> T, #kgen.param.decl.ref<"name.value`2"> : !kgen.string>]`: A reflection handle type for the named field's type.
- `field_at = Reflected[#kgen.struct_field_types<:trait<@std::@traits::@anytype::@AnyType> T>[SIMDLength(idx)]]`: A reflection handle type for the type of the field at the given index.

#### `Reflected.is_struct`

```mojo
def is_struct() -> Bool
```

Returns `True` if `T` is a Mojo struct type, `False` otherwise.

This distinguishes Mojo struct types from MLIR primitive types (such as
`__mlir_type.index` or `__mlir_type.i64`). The other reflection methods
produce a compile error on non-struct types, so `is_struct` is useful
as a `comptime if` guard when iterating over field types that may
contain MLIR primitives.

Example:
```mojo
def process_type[T: AnyType]():
    comptime if reflect[T].is_struct():
        print("struct with", reflect[T].field_count(), "fields")
    else:
        print("non-struct:", reflect[T].name())
```

Returns: `True` if `T` is a Mojo struct type, `False` if it is an MLIR type.

#### `Reflected.name`

```mojo
def name[*, qualified_builtins: Bool = False]() -> StaticString
```

Returns the struct name of `T`.

Example:
```mojo
struct Point:
    var x: Int
    var y: Float64

def main():
    print(reflect[Point].name())  # "Point" (or module-qualified if defined)
```

Parameters:

- `qualified_builtins`: Whether to print fully qualified builtin type names (e.g. `std.builtin.int.Int`) or shorten them (e.g. `Int`).

Returns: Type name.

#### `Reflected.base_name`

```mojo
def base_name() -> StaticString
```

Returns the name of the base type of a parameterized type.

For parameterized types like `List[Int]`, this returns `"List"`.
For non-parameterized types, it returns the type's simple name.

Unlike `name`, this method strips type parameters and returns only the
unqualified base type name.

Example:
```mojo
from std.collections import List, Dict

def main():
    print(reflect[List[Int]].base_name())          # "List"
    print(reflect[Dict[String, Int]].base_name())  # "Dict"
    print(reflect[Int].base_name())                # "Int"
```

Returns: The unqualified name of the base type as a `StaticString`.

#### `Reflected.field_count`

```mojo
def field_count() -> Int
```

Returns the number of fields in struct `T`.

Constraints: `T` must be a struct type.

Returns: The number of fields in the struct.

#### `Reflected.field_types`

```mojo
def field_types() -> TypeList[#kgen.struct_field_types<:trait<_std::_traits::_anytype::_AnyType> T>]
```

Returns the types of all fields in struct `T` as a `TypeList`.

For nested structs this returns the struct type itself, not its
flattened fields.

Example:
```mojo
struct Point:
    var x: Int
    var y: Float64

def main():
    comptime types = reflect[Point].field_types()
    comptime for i in range(reflect[Point].field_count()):
        print(reflect[types[i]].name())
```

Constraints: `T` must be a struct type.

Returns: A `TypeList` with one entry per field in the struct.

#### `Reflected.field_names`

```mojo
def field_names() -> Array[StringSpan[ImmStaticOrigin], Int(len(#kgen.struct_field_types<:trait<_std::_traits::_anytype::_AnyType> T>))]
```

Returns the names of all fields in struct `T`.

Constraints: `T` must be a struct type.

Returns: An `Array` of `StaticString`, one entry per field.

#### `Reflected.field_index`

```mojo
def field_index[name: StringLiteral[name.value]]() -> Int
```

Returns the index of the field with the given name in struct `T`.

Note: `T` must be a concrete type, not a generic type parameter, when
looking up by name.

Parameters:

- `name`: The name of the field to look up.

Returns: The zero-based index of the field.

#### `Reflected.field_ref`

```mojo
def field_ref[idx: Int](ref s: T) -> ref[s_is_mut] #kgen.struct_field_types<:trait<_std::_traits::_anytype::_AnyType> T>[SIMDLength(idx)]
```

Returns a reference to the field at the given index in `s`.

Returns a reference rather than a copy, so this works with
non-copyable field types and supports mutation through the result.

Example:
```mojo
@fieldwise_init
struct Container:
    var id: Int
    var name: String

def main():
    var c = Container(id=1, name="test")
    reflect[Container].field_ref[0](c) = 42  # mutates c.id
```

Constraints: `T` must be a struct type. `idx` must be in range
`[0, field_count())`.

Parameters:

- `idx`: The zero-based index of the field.

Args:

- `s`: The struct value to access.

Returns: A reference to the field at the specified index, with the same mutability as `s`.

#### `Reflected.field_offset`

```mojo
def field_offset[*, name: StringLiteral[name.value], target: CompilationTarget = CompilationTarget()]() -> Int
```

Returns the byte offset of the named field within struct `T`.

Accounts for alignment padding between fields. Computed using the
target's data layout.

Example:
```mojo
struct Point:
    var x: Int      # offset 0
    var y: Float64  # offset 8

def main():
    comptime x_off = reflect[Point].field_offset[name="x"]()  # 0
    comptime y_off = reflect[Point].field_offset[name="y"]()  # 8
```

Constraints: `T` must be a struct type with a field of the given name.

Parameters:

- `name`: The name of the field.
- `target`: The target architecture (defaults to the current target).

Returns: The byte offset of the field from the start of the struct.

```mojo
def field_offset[*, index: Int, target: CompilationTarget = CompilationTarget()]() -> Int
```

Returns the byte offset of the field at the given index.

Accounts for alignment padding between fields. Computed using the
target's data layout.

Constraints: `T` must be a struct type. `index` must be in range
`[0, field_count())`.

Parameters:

- `index`: The zero-based index of the field.
- `target`: The target architecture (defaults to the current target).

Returns: The byte offset of the field from the start of the struct.

#### `Reflected.annotations`

```mojo
def annotations() -> Tuple[*#kgen.param_list.tabulate(#kgen.get_num_annotations<:trait<_std::_traits::_anytype::_AnyType> T>, [idx: __mlir_type.index] #kgen.get_annotation_type<:trait<_std::_traits::_anytype::_AnyType> T, #kgen.cast_from_builtin<#kgen.param.decl.ref<"idx"> : index> : !kgen.scalar<index>>(Deinitable & Movable))]
```

Returns the `@__annotation` values on struct `T` as a `Tuple`.

Repeated decorators accumulate into one list in source order. Each
value is materialized from its compile-time form, so the result is an
ordinary runtime tuple. Its `Ts` parameter lists the annotation types,
and `len()` gives their count; a struct with no annotations yields an
empty tuple. A literal is stored in its materialized form, so
`@__annotation(9)` reads back as an `Int` and `@__annotation("x")` as
a `String`.

Example:
```mojo
@__annotation("a", 2)
struct Target:
    var value: String

def main():
    var values = reflect[Target].annotations()
    print(len(values), values[0], values[1])  # 2 a 2
    comptime assert type_of(values).Ts[1] == Int
```

Constraints: `T` must be a struct type.

Returns: A `Tuple` with one element per annotation value, in source order.

#### `Reflected.field_annotations`

```mojo
def field_annotations[field_index: Int]() -> Tuple[*#kgen.param_list.tabulate(#kgen.get_num_annotations<:trait<_std::_traits::_anytype::_AnyType> T, #lit.struct.extract<:!lit.struct<_std::_simd::_SIMD<:!lit.struct<_std::_builtin::_dtype::_DType> {:dtype index}, :!lit.struct<_std::_builtin::_simd_length::_SIMDLength> {1}>> *"field_index`2x", "_mlir_value"> : !kgen.scalar<index>>, [idx: __mlir_type.index] #kgen.get_annotation_type<:trait<_std::_traits::_anytype::_AnyType> T, #kgen.cast_from_builtin<#kgen.param.decl.ref<"idx"> : index> : !kgen.scalar<index>, #lit.struct.extract<:!lit.struct<_std::_simd::_SIMD<:!lit.struct<_std::_builtin::_dtype::_DType> {:dtype index}, :!lit.struct<_std::_builtin::_simd_length::_SIMDLength> {1}>> *"field_index`2x", "_mlir_value"> : !kgen.scalar<index>>(Deinitable & Movable))]
```

Returns the `@__annotation` values on a field of `T` as a `Tuple`.

Each value is materialized from its compile-time form, so the result
is an ordinary runtime tuple. Its `Ts` parameter lists the annotation
types, and `len()` gives their count; an undecorated field yields an
empty tuple.

Example:
```mojo
struct Target:
    @__annotation(3, "tag")
    var value: String

def main():
    var values = reflect[Target].field_annotations[0]()
    print(values[0], values[1])  # 3 tag
```

Constraints: `T` must be a struct type. `field_index` must be in range
`[0, field_count())`.

Parameters:

- `field_index`: The zero-based index of the field.

Returns: A `Tuple` with one element per annotation value, in source order.
