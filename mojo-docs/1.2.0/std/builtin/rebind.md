# `std.builtin.rebind`

Implements type rebind/trait downcast.

These are Mojo built-ins, so you don't need to import them.

## Aliases

### `downcast`

```mojo
comptime downcast[T: AnyType, _Trait: AnyTrait[AnyType]] = T(_Trait)
```

Type alias for downcasting a type to conform to a trait.

## Functions

### `rebind`

```mojo
def rebind[src_type: TrivialRegisterPassable, //, dest_type: TrivialRegisterPassable](src: src_type) -> dest_type
```

Statically assert that a parameter input type `src_type` resolves to the same type as a parameter result type `dest_type` after function instantiation and "rebind" the input to the result type.

This function is meant to be used in uncommon cases where a parametric type
depends on the value of a constrained parameter in order to manually refine
the type with the constrained parameter value.

Parameters:

- `src_type`: The original type.
- `dest_type`: The type to rebind to.

Args:

- `src`: The value to rebind.

Returns: The rebound value of `dest_type`.

```mojo
def rebind[src_type: AnyType, //, dest_type: AnyType](ref src: src_type) -> ref[src] dest_type
```

Statically assert that a parameter input type `src_type` resolves to the same type as a parameter result type `dest_type` after function instantiation and "rebind" the input to the result type, returning a reference to the input value with an adjusted type.

This function is meant to be used in uncommon cases where a parametric type
depends on the value of a constrained parameter in order to manually refine
the type with the constrained parameter value.

Parameters:

- `src_type`: The original type.
- `dest_type`: The type to rebind to.

Args:

- `src`: The value to rebind.

Returns: A reference to the value rebound as `dest_type`.

### `rebind_var`

```mojo
def rebind_var[src_type: Movable, //, dest_type: Movable](var src: src_type, out dest: dest_type)
```

Statically assert that a parameter input type `src_type` resolves to the same type as a parameter result type `dest_type` after function instantiation and "rebind" the input to the result type, returning a owned variable with an adjusted type.

Unlike `rebind`, this function takes an owned variable and returns an owned
variable via moving the value from the input to the output.

This function is meant to be used in uncommon cases where a parametric type
depends on the value of a constrained parameter in order to manually refine
the type with the constrained parameter value.

Parameters:

- `src_type`: The original type.
- `dest_type`: The type to rebind to.

Args:

- `src`: The value to rebind.

Returns: An owned value rebound as `dest_type`.
