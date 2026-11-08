# `std.origin`

Defines Mojo's origin types.

An origin is a compile-time value that names the variable a reference
borrows from, and whether that reference permits mutation. The compiler uses
origins to check that a reference never outlives the value it points to,
enforce mutable exclusivity between references, and destroy values as soon as
their last use.

Most origins are inferred automatically—from `ref` arguments, from parametric
types like `Pointer` and `Span`, or from `origin_of()`. Reach for `Origin` and
its aliases (`ImmOrigin`, `MutOrigin`, `ImmUntrackedOrigin`,
`MutUntrackedOrigin`, `ImmStaticOrigin`) when an API needs to name an origin
explicitly.

For the full picture, see the
[lifetimes guide](../../manual/values/lifetimes.md).

## Aliases

### `ImmOrigin`

```mojo
comptime ImmOrigin = ImmOrigin
```

Immutable origin reference type.

### `MutOrigin`

```mojo
comptime MutOrigin = MutOrigin
```

Mutable origin reference type.

### `AnyOrigin`

```mojo
comptime AnyOrigin[*, mut: Bool] = SomeUnsafeAnyOrigin
```

An origin that might access any memory value.

### `ImmutAnyOrigin`

```mojo
comptime ImmutAnyOrigin = ImmUnsafeAnyOrigin
```

The immutable origin that might access any memory value.

### `MutAnyOrigin`

```mojo
comptime MutAnyOrigin = MutUnsafeAnyOrigin
```

The mutable origin that might access any memory value.

### `UnsafeAnyOrigin`

```mojo
comptime UnsafeAnyOrigin[*, mut: Bool] = SomeUnsafeAnyOrigin
```

The universal origin: an unsafe origin that might alias any memory value.

Because a reference with this origin might alias any live value, it forces the
lifetime checker into its most conservative behavior, defeating the guarantees
the origin system is meant to provide:

- It extends unrelated lifetimes. Every other value in scope is kept alive for
  as long as the reference is live, even values it never points to, effectively
  halting ASAP destruction.
- It hides unused-variable warnings, since the compiler treats every in-scope
  variable as potentially aliased.
- It disables mutable exclusivity checking, since the compiler cannot prove
  which value the reference aliases.

**Safety:** This is a temporary compiler escape hatch from Mojo's early days,
not a capability to reach for. It will never be stabilized and is slated for
deprecation and removal. The `Unsafe` prefix marks every use as a place to
migrate away from; prefer a concrete origin so the compiler can continue to
track lifetimes and exclusivity.

### `ImmUnsafeAnyOrigin`

```mojo
comptime ImmUnsafeAnyOrigin = ImmUnsafeAnyOrigin
```

The immutable universal origin that might alias any memory value.

This is an unsafe escape hatch slated for removal. See `UnsafeAnyOrigin`.

### `MutUnsafeAnyOrigin`

```mojo
comptime MutUnsafeAnyOrigin = MutUnsafeAnyOrigin
```

The mutable universal origin that might alias any memory value.

This is an unsafe escape hatch slated for removal. See `UnsafeAnyOrigin`.

### `UntrackedOrigin`

```mojo
comptime UntrackedOrigin[*, mut: Bool] = UntrackedOrigin[mut]
```

An origin the lifetime checker does not track, because it aliases no existing value.

An untracked origin is the empty origin: it promises the reference aliases no
value the compiler is managing, so there is nothing for the lifetime checker to
track or extend. That is exactly the behavior you want when interfacing with
memory from outside the Mojo program. For example, the pointer returned by
`alloc()` carries an untracked origin, because the allocated block aliases no
Mojo-owned value.

### `ImmUntrackedOrigin`

```mojo
comptime ImmUntrackedOrigin = ImmUntrackedOrigin
```

An immutable origin the lifetime checker does not track.

### `MutUntrackedOrigin`

```mojo
comptime MutUntrackedOrigin = MutUntrackedOrigin
```

A mutable origin the lifetime checker does not track.

### `ImmStaticOrigin`

```mojo
comptime ImmStaticOrigin = ImmStaticOrigin
```

An origin for strings and other always-immutable static constants.

### `OriginSet`

```mojo
comptime OriginSet = LITOriginSet
```

A set of origin parameters.

## Structs

### `Origin`

```mojo
struct Origin[mut: Bool, _mlir_origin: LITOrigin[mut], //]
```

This represents a origin reference for a memory value.

Parameters:

- `mut`: Whether the origin is mutable.
- `_mlir_origin`: The raw MLIR origin value.

Implemented traits: `AnyType`, `Copyable`, `Deinitable`, `ImplicitlyCopyable`, `Movable`, `RegisterPassable`, `TrivialRegisterPassable`

Aliases:

- `equals = Bool(origin_eq(origin_of(_mlir_origin) == origin_of(_mlir_origin)))`: Is true if self is equal to rhs. This predicate can only be used in 'where' clauses and other expressions evaluated at parse time. It may not be used in 'comptime if' and similar expressions.
- `contains = Bool(origin_eq(origin_of(_mlir_origin) == origin_of(_mlir_origin, _mlir_origin)))`: Is true if self is a superset of element. This predicate can only be used in 'where' clauses and other expressions evaluated at parse time. It may not be used in 'comptime if' and similar expressions.

#### `Origin.__init__`

```mojo
def __init__() -> Self
```

Construct an Origin.

```mojo
def __init__(v: Origin[mut=v.mut]) -> ImmOrigin
```

Implicitly convert an origin to an immutable one.

Args:

- `v`: The origin to convert.

#### `Origin.unsafe_mut_cast`

```mojo
def unsafe_mut_cast[dest_mut: Bool]() -> Origin[mut=dest_mut]
```

Cast this origin to a different mutability, potentially introducing more mutability, which is an unsafe operation.

Parameters:

- `dest_mut`: The desired mutability of the resulting origin.

Returns: The same origin but with a new specified mutability.
