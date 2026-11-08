# `std.io.io`

Provides utilities for working with input/output.

These are Mojo built-ins, so you don't need to import them.

## Functions

### `print`

```mojo
def print[*Ts: Writable](*values: *Ts.values, *, sep: StringSpan = " ", end: StringSpan = "\n", flush: Bool = False, var file: RawFileDescriptor = stdout)
```

Prints elements to the text stream. Each element is separated by `sep` and followed by `end`.

This function accepts any number of values, but their types must implement
the [`Writable`](../../std/format/index.md#writable) trait. Most built-in types
(like `Int`, `Float64`, `Bool`, `String`) implement the
[`Writable`](../../std/format/index.md#writable) trait.

For string formatting, you can use the
[`format()`](../../std/collections/string/string.md#stringformat) method
or, preferably, a template string
([`TString`](../../std/format/tstring.md#tstring), written `t"..."`)
which interpolates expressions directly without allocating an
intermediate `String`.

Examples:

```mojo
print("Hello, World!")                   # Hello, World!

print("The answer is", 42)               # The answer is 42

print("{} is {}".format("Mojo", "🔥"))   # Mojo is 🔥

var name = "Mojo"
print(t"{name} is 🔥")                   # Mojo is 🔥
```

Parameters:

- `*Ts`: The elements types.

Args:

- `*values`: The elements to print.
- `sep`: The separator used between elements.
- `end`: The String to write after printing the elements.
- `flush`: If set to true, then the stream is forcibly flushed.
- `file`: The output stream.

### `input`

```mojo
def input(prompt: String = "") raises -> String
```

Reads a line of input from the user.

Reads a line from standard input, converts it to a string, and returns that string.
If the prompt argument is present, it is written to standard output without a trailing newline.

Examples:
```mojo
name = input("Enter your name: ")
print("Hello", name)
```

If the user enters "Mojo" it prints "Hello Mojo".

Args:

- `prompt`: An optional string to be printed before reading input.

Returns: A string containing the line read from the user input.

Raises: If the operation fails.
