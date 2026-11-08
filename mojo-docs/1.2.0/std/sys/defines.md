# `std.sys.defines`

Implements functions for retrieving compile-time defines.

You can use these functions to set parameter values or runtime constants based on
name-value pairs defined on the command line. For example:

```mojo
  from std.sys import is_defined

  comptime float_type = DType.float32 if is_defined["FLOAT32"]() else DType.float64

  # Use `float_type` as a constant.
```

And on the command line:

```
  mojo -D FLOAT32 main.mojo
```

For more information, see the [Mojo build docs](https://mojolang.org/docs/cli/build/#d-keyvalue).
The `mojo run` command also supports the `-D` option.

You can import these APIs from the `sys` package. For example:

```mojo
from std.sys import is_defined
```

## Aliases

### `MOJO_VERSION`

```mojo
comptime MOJO_VERSION = MojoVersion()
```

The version of the Mojo language used for the current compilation, available at compile time.

## Structs

### `MojoVersion`

```mojo
struct MojoVersion
```

Represents the Mojo version as major, minor, and patch numbers.

Fields:

- `major` (`Int`): The major version number.
- `minor` (`Int`): The minor version number.
- `patch` (`Int`): The patch version number.

Implemented traits: `AnyType`, `Copyable`, `Deinitable`, `ImplicitlyCopyable`, `Movable`, `RegisterPassable`, `TrivialRegisterPassable`

#### `MojoVersion.__init__`

```mojo
def __init__() -> Self
```

Initializes the version by reading it from the compiler at compile time.

## Functions

### `is_defined`

```mojo
def is_defined[name: StringSpan[ImmStaticOrigin]]() -> Bool
```

Return true if the named value is defined.

Parameters:

- `name`: The name to test.

Returns: True if the name is defined.

### `get_defined_bool`

```mojo
def get_defined_bool[name: StringSpan[ImmStaticOrigin], default: Bool = False]() -> Bool
```

Get a boolean-valued define. If the name is not defined, return a default value instead. If the name is defined this will return `True` if the value is ("1", "true", "True", "TRUE", "on", "On", "ON") otherwise it will return `False`.

Parameters:

- `name`: The name of the define.
- `default`: The default value to use.

Returns: A boolean parameter value.

### `get_defined_int`

```mojo
def get_defined_int[name: StringSpan[ImmStaticOrigin]]() -> Int
```

Try to get an integer-valued define. Compilation fails if the name is not defined.

Parameters:

- `name`: The name of the define.

Returns: An integer parameter value.

```mojo
def get_defined_int[name: StringSpan[ImmStaticOrigin], default: Int]() -> Int
```

Try to get an integer-valued define. If the name is not defined, return a default value instead.

Example:
```mojo
from std.sys.defines import get_defined_int

def main() raises:
    comptime number = get_defined_int[
        "favorite_number",
        1 # Default value
    ]()
    parametrized[number]()

def parametrized[num: Int]():
    print(num)
```

If the program is `app.mojo`:
- `mojo run -D favorite_number=2 app.mojo`
- `mojo run -D app.mojo`

Note: useful for parameterizing SIMD vector sizes.

Parameters:

- `name`: The name of the define.
- `default`: The default value to use.

Returns: An integer parameter value.

### `get_defined_string`

```mojo
def get_defined_string[name: StringSpan[ImmStaticOrigin]]() -> StaticString
```

Try to get a string-valued define. Compilation fails if the name is not defined.

Parameters:

- `name`: The name of the define.

Returns: A string parameter value.

```mojo
def get_defined_string[name: StringSpan[ImmStaticOrigin], default: StringSpan[ImmStaticOrigin]]() -> StaticString
```

Try to get a string-valued define. If the name is not defined, return a default value instead.

Parameters:

- `name`: The name of the define.
- `default`: The default value to use.

Returns: A string parameter value.

### `get_defined_dtype`

```mojo
def get_defined_dtype[name: StringSpan[ImmStaticOrigin], default: DType]() -> DType
```

Try to get a DType-valued define. If the name is not defined, return a default value instead.

Parameters:

- `name`: The name of the define.
- `default`: The default value to use.

Returns: A DType parameter value.
