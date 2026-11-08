# `std.os.pathlike`

Implements the `PathLike` trait.

You can import the trait from the `os` package. For example:

```mojo
from std.os import PathLike
```

## Traits

### `PathLike`

```mojo
trait PathLike
```

A trait representing file system paths.

Inherits from: `AnyType`

#### `PathLike.__fspath__`

```mojo
def __fspath__(self) -> String
```

Return the file system path representation of the object.

Returns: The file system path representation as a string.
