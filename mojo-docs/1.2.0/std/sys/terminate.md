# `std.sys.terminate`

This module includes the exit functions.

## Functions

### `exit`

```mojo
def exit()
```

Exits from Mojo. Unlike the Python implementation this does not raise an exception to exit.

```mojo
def exit[intable: Intable](code: intable)
```

Exits from Mojo. Unlike the Python implementation this does not raise an exception to exit.

Parameters:

- `intable`: The type of the exit code.

Args:

- `code`: The exit code.
