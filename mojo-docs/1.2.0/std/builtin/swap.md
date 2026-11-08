# `std.builtin.swap`

Implements the built-in `swap` function.

These are Mojo built-ins, so you don't need to import them.

## Functions

### `swap`

```mojo
def swap[T: Movable](mut lhs: T, mut rhs: T)
```

Swaps the two given arguments.

Parameters:

- `T`: Constrained to Movable types.

Args:

- `lhs`: Argument value swapped with rhs.
- `rhs`: Argument value swapped with lhs.
