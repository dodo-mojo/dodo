# `std.format`

Provides formatting traits for converting types to text.

The `format` package provides traits that control how types format themselves as
text and where that text gets written. The `Writable` trait describes how a
type converts itself to UTF-8 text, while the `Writer` trait accepts formatted
output from writable types. Together, they enable efficient formatting without
unnecessary allocations by writing directly to destinations like files, strings,
or network sockets.

Use this package to implement custom text formatting for your types, control
output representation, or write formatted data directly to various destinations.

## Quick Start

The `Writable` trait has a default implementation that uses reflection to
automatically format all struct fields. Simply declare the trait conformance:

```mojo
@fieldwise_init
struct Point(Writable):
    var x: Float64
    var y: Float64

var p = Point(1.5, 2.7)
print(p)  # Point(x=1.5, y=2.7)
print(repr(p)) # Point(x=Float64(1.5), y=Float64(2.7))
```

## Custom Formatting

Override `write_to()` for custom output:

```mojo
@fieldwise_init
struct Point(Writable):
    var x: Float64
    var y: Float64

    def write_to(self, mut writer: Some[Writer]):
        writer.write("(", self.x, ", ", self.y, ")")

var p = Point(1.5, 2.7)
print(p)  # (1.5, 2.7)
```

## Debug Formatting

Override `write_repr_to()` to provide different debug output:

```mojo
@fieldwise_init
struct Point(Writable):
    var x: Float64
    var y: Float64

    def write_repr_to(self, mut writer: Some[Writer]):
        writer.write("Point: x=", self.x, ", y=", self.y)

var p = Point(1.5, 2.7)
print(repr(p)) # Point: x=1.5, y=2.7
```

## Modules

- [`std.format.repr`](repr.md): Implements the `repr()` function for producing string representations of values.
- [`std.format.tstring`](tstring.md): Implements `TString`, a template string that captures interpolated values at compile-time.

## Traits

### `Writer`

```mojo
trait Writer
```

A destination for formatted text output.

`Writer` is implemented by types that can accept UTF-8 formatted text, such
as strings, files, or network sockets. Types implementing `Writable` write
their output to a `Writer`.

The core method is `write_string()`, which accepts a `StringSlice` for
efficient, allocation-free output. The convenience method `write()` accepts
multiple `Writable` arguments.

Example:

```mojo
@fieldwise_init
struct StringBuilder(Writer):
    var s: String

    def write_string(mut self, string: StringSlice):
        self.s += string

var builder = StringBuilder("")
builder.write("Count: ", 42)  # Writes multiple values at once
print(builder.s)  # Count: 42
```

Inherits from: `AnyType`

#### `Writer.write_string`

```mojo
def write_string(mut self, string: StringSpan)
```

Write a `StringSlice` to this `Writer`.

Args:

- `string`: The string slice to write to this Writer.

#### `Writer.write`

```mojo
def write[*Ts: Writable](mut self, *args: *Ts.values)
```

Write a sequence of Writable arguments to the provided Writer.

Parameters:

- `*Ts`: Types of the provided argument sequence.

Args:

- `*args`: Sequence of arguments to write to this Writer.

### `Writable`

```mojo
trait Writable
```

A trait for types that can format themselves as text.

The `Writable` trait provides a simple, straightforward interface for types
that need to convert themselves to text. Types implementing `Writable` write
directly to a `Writer`, making formatting efficient and allocation-free.

Both `write_to()` and `write_repr_to()` have default implementations that
use reflection to automatically format all fields. This means simple structs
can conform to `Writable` without any method implementations:

```mojo
@fieldwise_init
struct Point(Writable):
    var x: Int
    var y: Int

var p = Point(1, 3)
print(p)       # Point(x=1, y=3)
print(repr(p)) # Point(x=Int(1), y=Int(3))
```

Override either for different normal and debug output:

```mojo
@fieldwise_init
struct Point(Writable):
    var x: Float64
    var y: Float64

    def write_to(self, mut writer: Some[Writer]):
        writer.write("(", self.x, ", ", self.y, ")")

    def write_repr_to(self, mut writer: Some[Writer]):
        writer.write("Point: x=", self.x, ", y=", self.y)

var p = Point(1.5, 2.7)
print(p)       # (1.5, 2.7)
print(repr(p)) # Point: x=1.5, y=2.7
```

Note: The default reflection-based implementations iterate over all fields
at compile time. For mutually recursive types (e.g., struct `A` has a field
of type `List[B]` and struct `B` has a field of type `A`), this creates an
infinite monomorphization cycle that causes the compiler to hang. To fix
this, provide explicit `write_to()` and `write_repr_to()` implementations
for at least one type in the cycle.

Inherits from: `AnyType`

#### `Writable.write_to`

```mojo
def write_to(self, mut writer: T)
```

Write this value's text representation to a writer.

This method is called by `print()`, `String()`, and format strings to
convert the value to text. Override this method to define how your type
appears when printed or converted to a string.

The default implementation uses reflection to format all fields as
`TypeName(field1=value1, field2=value2, ...)`, calling `write_to()`
on each field. All fields must conform to `Writable`. `EnumLike` types
are instead formatted as `TypeName.case(payload)`, or `TypeName.case`
when the active case's payload is `NoneType`.

**Example:**

```mojo
@fieldwise_init
struct Point(Writable):
    var x: Float64
    var y: Float64

    def write_to(self, mut writer: Some[Writer]):
        writer.write("(", self.x, ", ", self.y, ")")
```

Args:

- `writer`: The destination for formatted output.

#### `Writable.write_repr_to`

```mojo
def write_repr_to(self, mut writer: T)
```

Write this value's debug representation to a writer.

This method is called by `repr(value)` or the `"{!r}"` format specifier
and should produce unambiguous, developer-facing output that shows the
internal state of the value.

The default implementation uses reflection to format all fields as
`TypeName(field1=value1, field2=value2, ...)`, calling `write_repr_to()`
on each field. All fields must conform to `Writable`. `EnumLike` types
are instead formatted as `TypeName.case(payload)`, or `TypeName.case`
when the active case's payload is `NoneType`.

**Example:**

```mojo
@fieldwise_init
struct Point(Writable):
    var x: Float64
    var y: Float64

    def write_repr_to(self, mut writer: Some[Writer]):
        writer.write("Point: x=", self.x, ", y=", self.y)
```

Notes:
Mojo's repr always prints single quotes (`'`) at the start and end
of the repr. Any single quote inside a string should be escaped
(`\'`).

Args:

- `writer`: The destination for formatted output.
