# `std.format.repr`

Implements the `repr()` function for producing string representations of values.

## Functions

### `repr`

```mojo
def repr[T: Writable](value: T) -> String
```

Returns the string representation of the given value.

Parameters:

- `T`: The type of `value`. Must implement the `Writable` trait.

Args:

- `value`: The value to get the string representation of.

Returns: The string representation of the given value.

```mojo
def repr(value: None) -> String
```

Returns the string representation of `None`.

Args:

- `value`: A `None` value.

Returns: The string representation of `None`.
