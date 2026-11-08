# `std.os.env`

Provides functions for working with environment variables.

You can import these APIs from the `os` package. For example:

```mojo
from std.os import setenv
```

## Functions

### `setenv`

```mojo
def setenv(var name: String, var value: String, overwrite: Bool = True) -> Bool
```

Changes or adds an environment variable.

Constraints: The function only works on macOS or Linux and returns False otherwise.

Args:

- `name`: The name of the environment variable.
- `value`: The value of the environment variable.
- `overwrite`: If an environment variable with the given name already exists, its value is not changed unless `overwrite` is True.

Returns: False if the name is empty or contains an `=` character. In any other case, True is returned.

### `unsetenv`

```mojo
def unsetenv(var name: String) -> Bool
```

Unsets an environment variable.

Args:

- `name`: The name of the environment variable.

Returns: True if unsetting the variable succeeded. Otherwise, False is returned.

### `getenv`

```mojo
def getenv(var name: String, default: String = "") -> String
```

Returns the value of the given environment variable.

Constraints: The function only works on macOS or Linux and returns an empty string
otherwise.

Args:

- `name`: The name of the environment variable.
- `default`: The default value to return if the environment variable doesn't exist.

Returns: The value of the environment variable.
