# `std.reflection.location`

Implements utilities to capture and represent source code location.

This module provides compile-time and runtime introspection of source locations:

- `SourceLocation` - A struct holding file name, line, and column information.
- `source_location()` - Returns the location where this function is called.
- `call_location()` - Returns the caller's location (for use in inlined functions).

These utilities are useful for error reporting, logging, debugging, and building
custom assertion functions that report meaningful locations to users.

Example using `source_location()` to get the current location:

```mojo
from std.reflection import source_location

def main():
    var loc = source_location()
    print(loc)  # Prints: /path/to/file.mojo:5:15
    print("Line:", loc.line(), "Column:", loc.column())
```

Example using `call_location()` for a custom assertion that reports the
caller's location. Note that `@inline(.always)` is required for `call_location()`
to work - the function must be inlined so the compiler can capture the caller's
location:

```mojo
from std.reflection import call_location

@inline(.always)  # Required for call_location() to work
def my_assert(cond: Bool, msg: String = "assertion failed") raises:
    if not cond:
        raise Error(call_location().prefix(msg))

def main() raises:
    var x = 5
    my_assert(x > 10, "x must be > 10")  # Error points to THIS line
```

## Structs

### `SourceLocation`

```mojo
struct SourceLocation
```

Type to carry file name, line, and column information.

This struct stores source location data and provides utilities for formatting
location-prefixed messages, which is useful for error reporting and debugging.

Example:

```mojo
from std.reflection import source_location, SourceLocation

def main():
    # Get current location
    var loc = source_location()
    print(loc)  # Prints: /path/to/file.mojo:6:19

    # Use prefix() for error-style messages
    print(loc.prefix("something went wrong"))
    # Prints: At /path/to/file.mojo:6:19: something went wrong

    # Access individual fields
    print("File:", loc.file_name())
    print("Line:", loc.line())
    print("Column:", loc.column())
```

Implemented traits: `AnyType`, `Copyable`, `Deinitable`, `ImplicitlyCopyable`, `Movable`, `RegisterPassable`, `TrivialRegisterPassable`, `UnsafeNicheable`, `UnsafeSingleNicheable`, `Writable`

#### `SourceLocation.line`

```mojo
def line(self) -> Int
```

Returns the 1-indexed line number.

Returns: The line number.

#### `SourceLocation.column`

```mojo
def column(self) -> Int
```

Returns the 1-indexed column number.

Returns: The column number.

#### `SourceLocation.file_name`

```mojo
def file_name(self) -> StaticString
```

Returns the file name.

Returns: The file name.

#### `SourceLocation.prefix`

```mojo
def prefix[T: Writable](self, msg: T) -> String
```

Returns the given message prefixed with the source location.

Parameters:

- `T`: The type of the message.

Args:

- `msg`: The message to attach the prefix to.

Returns: A string in the format "At file:line:col: msg".

#### `SourceLocation.write_to`

```mojo
def write_to(self, mut writer: T)
```

Formats the source location to the provided Writer.

Args:

- `writer`: The object to write to.

## Functions

### `source_location`

```mojo
def source_location() -> SourceLocation
```

Returns the location for where this function is called.

This currently doesn't work when called in a parameter expression.

Example:

```mojo
from std.reflection import source_location

def log_message(msg: String):
    var loc = source_location()
    print("[", loc.file_name(), ":", loc.line(), "]", msg)

def main():
    log_message("hello")  # Prints: [ /path/to/file.mojo : 4 ] hello
```

Returns: The location information of the `source_location()` call.

### `call_location`

```mojo
def call_location[*, inline_count: Int = Int(1)]() -> SourceLocation
```

Returns the location for where the caller of this function is called.

An optional `inline_count` parameter can be specified to skip over that many
levels of calling functions.

This should only be used when enclosed in a series of `@inline(.always)` or
`@inline(.nodebug)` function calls, where the layers of calling
functions is no fewer than `inline_count`.

For example, when `inline_count = 1`, only the caller of this function needs
to be `@inline(.always)` or `@inline(.nodebug)`. This function will
return the source location of the caller's invocation.

When `inline_count = 2`, the caller of the caller of this function also
needs to be inlined. This function will return the source location of the
caller's caller's invocation.

This currently doesn't work when the `inline_count`-th wrapping caller is
called in a parameter expression.

Example:

```mojo
from std.reflection import call_location

@inline(.always)  # Required for call_location() to work
def assert_positive(value: Int) raises:
    # call_location() returns where assert_positive() was called,
    # not where call_location() itself is called.
    if value <= 0:
        raise Error(call_location().prefix("value must be positive"))

def main():
    try:
        assert_positive(-1)  # Error will point to THIS line
    except e:
        print(e)
```

Parameters:

- `inline_count`: The number of inline call levels to skip.

Returns: The location information of where the caller of this function (i.e. the function whose body `call_location()` is used in) is called.
