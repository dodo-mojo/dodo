# `std.format.tstring`

Implements `TString`, a template string that captures interpolated values at compile-time.

## Structs

### `TString`

```mojo
struct TString[origins: ImmOrigin, array_origin: ImmOrigin]
```

A template string that captures interpolated values at compile-time.

TString is a zero-cost abstraction for string interpolation that preserves
type information and defers formatting until explicitly requested. Unlike
regular strings or f-strings, TString retains the original format template
and typed values, enabling efficient lazy formatting and type-safe string
composition.

TString instances are created by the compiler when using t-string literal
syntax: `t"Hello {name}!"`.

Parameters:

- `origins`: The union of the origins of the interpolated values.
- `array_origin`: The origin of the array holding those values, which the t-string expression owns and this `TString` borrows.

Implemented traits: `AnyType`, `Deinitable`, `Movable`, `RegisterPassable`, `Writable`

#### `TString.write_to`

```mojo
def write_to(self, mut writer: T)
```

Write the formatted string to a writer.

This method implements the `Writable` trait by formatting the TString's
template with its interpolated values and writing the result to the
provided writer.

Args:

- `writer`: The writer to output the formatted string to.

#### `TString.write_repr_to`

```mojo
def write_repr_to(self, mut writer: T)
```

Write a debug representation of the TString to a writer.

The interpolated values are type-erased, so neither their types nor
their values are recoverable here; use `write_to` to render them.

Args:

- `writer`: The writer to output the debug representation to.
