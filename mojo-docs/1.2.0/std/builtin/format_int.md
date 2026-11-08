# `std.builtin.format_int`

Provides the `hex` and `bin` functions.

These are Mojo built-ins, so you don't need to import them.

## Functions

### `bin`

```mojo
def bin(num: Scalar, /, *, prefix: StringSpan[ImmStaticOrigin] = StringSpan("0b")) -> String
```

Return the binary string representation an integral value.

```mojo
print(bin(123))
print(bin(-123))
```
```plaintext
'0b1111011'
'-0b1111011'
```

Args:

- `num`: An integral scalar value.
- `prefix`: The prefix of the formatted int.

Returns: The binary string representation of num.

```mojo
def bin(b: Scalar[DType.bool], /, *, prefix: StringSpan[ImmStaticOrigin] = StringSpan("0b")) -> String
```

Returns the binary representation of a scalar bool.

Args:

- `b`: A scalar bool value.
- `prefix`: The prefix of the formatted int.

Returns: The binary string representation of b.

```mojo
def bin[T: Intable, //](num: T, /, *, prefix: StringSpan[ImmStaticOrigin] = StringSpan("0b")) -> String
```

Returns the binary representation of an indexer type.

Parameters:

- `T`: The Intable type.

Args:

- `num`: An indexer value.
- `prefix`: The prefix of the formatted int.

Returns: The binary string representation of num.

### `hex`

```mojo
def hex(value: Scalar, /, *, prefix: StringSpan[ImmStaticOrigin] = StringSpan("0x")) -> String
```

Returns the hex string representation of the given integer.

The hexadecimal representation is a base-16 encoding of the integer value.

The returned string will be prefixed with "0x" to indicate that the
subsequent digits are hex.

Args:

- `value`: The integer value to format.
- `prefix`: The prefix of the formatted int.

Returns: A string containing the hex representation of the given integer.

```mojo
def hex[T: Intable, //](value: T, /, *, prefix: StringSpan[ImmStaticOrigin] = StringSpan("0x")) -> String
```

Returns the hex string representation of the given integer.

The hexadecimal representation is a base-16 encoding of the integer value.

The returned string will be prefixed with "0x" to indicate that the
subsequent digits are hex.

Parameters:

- `T`: The indexer type to represent in hexadecimal.

Args:

- `value`: The integer value to format.
- `prefix`: The prefix of the formatted int.

Returns: A string containing the hex representation of the given integer.

```mojo
def hex(value: Scalar[DType.bool], /, *, prefix: StringSpan[ImmStaticOrigin] = StringSpan("0x")) -> String
```

Returns the hex string representation of the given scalar bool.

The hexadecimal representation is a base-16 encoding of the bool.

The returned string will be prefixed with "0x" to indicate that the
subsequent digits are hex.

Args:

- `value`: The bool value to format.
- `prefix`: The prefix of the formatted int.

Returns: A string containing the hex representation of the given bool.

### `oct`

```mojo
def oct(value: Scalar, /, *, prefix: StringSpan[ImmStaticOrigin] = StringSpan("0o")) -> String
```

Returns the octal string representation of the given integer.

The octal representation is a base-8 encoding of the integer value.

The returned string will be prefixed with "0o" to indicate that the
subsequent digits are octal.

Args:

- `value`: The integer value to format.
- `prefix`: The prefix of the formatted int.

Returns: A string containing the octal representation of the given integer.

```mojo
def oct[T: Intable, //](value: T, /, *, prefix: StringSpan[ImmStaticOrigin] = StringSpan("0o")) -> String
```

Returns the octal string representation of the given integer.

The octal representation is a base-8 encoding of the integer value.

The returned string will be prefixed with "0o" to indicate that the
subsequent digits are octal.

Parameters:

- `T`: The intable type to represent in octal.

Args:

- `value`: The integer value to format.
- `prefix`: The prefix of the formatted int.

Returns: A string containing the octal representation of the given integer.

```mojo
def oct(value: Scalar[DType.bool], /, *, prefix: StringSpan[ImmStaticOrigin] = StringSpan("0o")) -> String
```

Returns the octal string representation of the given scalar bool.

The octal representation is a base-8 encoding of the bool.

The returned string will be prefixed with "0o" to indicate that the
subsequent digits are octal.

Args:

- `value`: The bool value to format.
- `prefix`: The prefix of the formatted int.

Returns: A string containing the octal representation of the given bool.
