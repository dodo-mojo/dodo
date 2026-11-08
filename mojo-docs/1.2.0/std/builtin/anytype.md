# `std.builtin.anytype`

Existential-type helpers built on `AnyType`, plus deprecated aliases for the traits that used to live in this module.

This module defines `Some` and `SomeTypeList`, aliases that let a function
signature express "any type conforming to trait `X`" without introducing an
explicit type parameter. It also keeps deprecated aliases for `AnyType` and
`Deinitable`, both of which are now defined in `std.traits`.

## Aliases

### `AnyType`

```mojo
comptime AnyType = AnyType
```

**Deprecated:** `AnyType` has moved to `std.traits`. It's still exported from the prelude, so most code needs no changes; for the explicit import path use `std.traits.anytype.AnyType`.

Deprecated: The most basic trait that all Mojo types extend by default.

This trait has moved to `std.traits.anytype`. It's exported from the
prelude, so most code doesn't need to change. This alias will be removed in
a future version of Mojo.

### `Deinitable`

```mojo
comptime Deinitable = Deinitable
```

**Deprecated:** `Deinitable` has moved to `std.traits`. It's still exported from the prelude, so most code needs no changes; for the explicit import path use `std.traits.deinitable.Deinitable`.

Deprecated: A trait for types that require lifetime management through destructors.

This trait has moved to `std.traits.deinitable`. It's exported from the
prelude, so most code doesn't need to change. This alias will be removed in
a future version of Mojo.

### `Some`

```mojo
comptime Some[Trait: AnyTrait[AnyType]] = comptime[T: Trait] T
```

An alias allowing users to tersely express that a function argument is an instance of a type that implements a trait or trait composition.

For example, instead of writing

```mojo
def foo[T: Intable, //](x: T) -> Int:
    return x.__int__()
```

one can write:

```mojo
def foo(x: Some[Intable]) -> Int:
    return x.__int__()
```

### `SomeTypeList`

```mojo
comptime SomeTypeList[Trait: AnyTrait[AnyType]] = comptime[values: KGENParamList[Trait]] TypeList[values]()
```

An alias allowing users to tersely express that a function argument is a list of types that implement a trait or trait composition. This is particularly useful for variadic packs.

For example, instead of writing

```mojo
def foo[*arg_types: Copyable](*args: *arg_types) -> Int: ...
```

one can write:

```mojo
def foo(*args: *SomeTypeList[Copyable]) -> Int: ...
```
