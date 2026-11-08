# `std.io.file_descriptor`

Higher level abstraction for file stream.

These are Mojo built-ins, so you don't need to import them.

For example, here's how to print to a file

```mojo
var f = open("my_file.txt", "w")
var fd = RawFileDescriptor(f)
print("hello", file=fd)
f.close()
```

## Structs

### `RawFileDescriptor`

```mojo
struct RawFileDescriptor
```

File descriptor of a file.

Fields:

- `value` (`c_int`): The underlying value of the file descriptor.

Implemented traits: `AnyType`, `Copyable`, `Deinitable`, `ImplicitlyCopyable`, `Movable`, `RegisterPassable`, `TrivialRegisterPassable`, `Writer`

#### `RawFileDescriptor.__init__`

```mojo
def __init__(value: Int32 = Int32(1)) -> Self
```

Constructs the file descriptor from an integer.

Args:

- `value`: The file identifier (Default 1 = stdout).

```mojo
def __init__(f: FileHandle) -> Self
```

Constructs the file descriptor from a file handle.

Args:

- `f`: The file handle.

#### `RawFileDescriptor.write_bytes`

```mojo
def write_bytes(mut self, bytes: Span[UInt8])
```

Write a span of bytes to the file.

Args:

- `bytes`: The byte span to write to this file.

#### `RawFileDescriptor.write_string`

```mojo
def write_string(mut self, string: StringSpan)
```

Write a `StringSlice` to this `RawFileDescriptor`.

This method is required by the `Writer` trait.

Args:

- `string`: The `StringSlice` to write to this `RawFileDescriptor`.

#### `RawFileDescriptor.read_bytes`

```mojo
def read_bytes(mut self, buffer: Span[UInt8]) raises -> Int
```

Read a number of bytes from the file into a buffer.

Notes:
[Reference](https://pubs.opengroup.org/onlinepubs/9799919799/functions/read.html).

Args:

- `buffer`: A `Span[Byte]` to read bytes into. Read up to `len(buffer)` number of bytes.

Returns: Actual number of bytes read.

Raises: If the operation fails.

#### `RawFileDescriptor.isatty`

```mojo
def isatty(self) -> Bool
```

Checks whether a file descriptor refers to a terminal.

Returns `True` if the file descriptor is open and connected to a
tty(-like) device, otherwise `False`. On GPUs, the function always
returns `False`.

Examples:
```mojo
from std.sys import stdout

# Check if stdout is a terminal
if stdout.isatty():
    print("Running in a terminal")
else:
    print("Output is redirected")
```

Returns: `True` if the file descriptor is connected to a terminal, `False` otherwise.

#### `RawFileDescriptor.fchdir`

```mojo
def fchdir(self) raises
```

Changes the current working directory to the one    represented by this fd.

Raises: If the operations fails. In particular if the fd is not a directory.
