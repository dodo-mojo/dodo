# `std.io.file`

Provides APIs to read and write files.

These are Mojo built-ins, so you don't need to import them.

For example, here's how to read a file:

```mojo
var  f = open("my_file.txt", "r")
print(f.read())
f.close()
```

Or use a `with` statement to close the file automatically:

```mojo
with open("my_file.txt", "r") as f:
  print(f.read())
```

## Aliases

### `O_RDONLY`

```mojo
comptime O_RDONLY = 0
```

Open file for reading only.

### `O_WRONLY`

```mojo
comptime O_WRONLY = 1
```

Open file for writing only.

### `O_RDWR`

```mojo
comptime O_RDWR = 2
```

Open file for reading and writing.

### `O_CREAT`

```mojo
comptime O_CREAT = platform_map[Optional(String("O_CREAT")), linux=Optional(Int(64)), macos=Optional(Int(512))]()
```

Create file if it doesn't exist.

### `O_TRUNC`

```mojo
comptime O_TRUNC = platform_map[Optional(String("O_TRUNC")), linux=Optional(Int(512)), macos=Optional(Int(1024))]()
```

Truncate file to zero length.

### `O_APPEND`

```mojo
comptime O_APPEND = platform_map[Optional(String("O_APPEND")), linux=Optional(Int(1024)), macos=Optional(Int(8))]()
```

Append mode: writes always go to end of file.

### `O_CLOEXEC`

```mojo
comptime O_CLOEXEC = platform_map[Optional(String("O_CLOEXEC")), linux=Optional(Int(524288)), macos=Optional(Int(16777216))]()
```

Close file descriptor on exec.

## Structs

### `FileHandle`

```mojo
struct FileHandle
```

File handle to an opened file.

Fields:

- `handle` (`Int`): The underlying file descriptor (Unix fd).

Implemented traits: `AnyType`, `Defaultable`, `Deinitable`, `Movable`, `Writer`

#### `FileHandle.__init__`

```mojo
def __init__(out self)
```

Default constructor.

```mojo
def __init__(out self, path: StringSpan, mode: StringSpan) raises
```

Construct the FileHandle using the file path and mode.

Args:

- `path`: The file path.
- `mode`: The mode to open the file in: {"r", "w", "rw", "a"}.

Raises: If file open mode is not one of the supported modes. If there is an error when opening the file.

#### `FileHandle.__deinit__`

```mojo
def __deinit__(deinit self)
```

Closes the file handle.

#### `FileHandle.close`

```mojo
def close(mut self) raises
```

Closes the file handle.

Raises: If the operation fails.

#### `FileHandle.read`

```mojo
def read(self, size: Int = Int(-1)) raises -> String
```

Reads data from a file and sets the file handle seek position. If size is left as the default of -1, it will read to the end of the file. Setting size to a number larger than what's in the file will set the String length to the total number of bytes, and read all the data.

Examples:

Read the entire file into a String:

```mojo
var file = open("/tmp/example.txt", "r")
var string = file.read()
print(string)
```

Read the first 8 bytes, skip 2 bytes, and then read the next 8 bytes:

```mojo
from std.os import SEEK_CUR
var file = open("/tmp/example.txt", "r")
var word1 = file.read(8)
print(word1)
_ = file.seek(2, SEEK_CUR)
var word2 = file.read(8)
print(word2)
```

Read the last 8 bytes in the file, then the first 8 bytes
```mojo
from std.os import SEEK_SET, SEEK_END
var file = open("/tmp/example.txt", "r")
_ = file.seek(-8, SEEK_END)
var last_word = file.read(8)
print(last_word)
_ = file.seek(8, SEEK_SET) # SEEK_SET is the default start of file
var first_word = file.read(8)
print(first_word)
```

Args:

- `size`: Requested number of bytes to read (Default: -1 = EOF).

Returns: The contents of the file.

Raises: An error if this file handle is invalid, or if the file read returned a failure.

```mojo
def read[dtype: DType, origin: MutOrigin](self, buffer: Span[Scalar[dtype], origin]) raises -> Int
```

Read data from the file into the Span.

This will read n bytes from the file into the input Span where
`0 <= n <= len(buffer)`.

0 is returned when the file is at EOF, or a 0-sized buffer is
passed in.

Examples:

```mojo
from std.os import SEEK_CUR
from std.sys.info import size_of

comptime file_name = "/tmp/example.txt"
var file = open(file_name, "r")

# Allocate and load 8 elements
var buffer = Array[Float32, length=8](fill=0)
var bytes = file.read(buffer)
print("bytes read", bytes)

var first_element = buffer[0]
print(first_element)

# Skip 2 elements
_ = file.seek(2 * size_of[DType.float32](), SEEK_CUR)

# Allocate and load 8 more elements from file handle seek position
var buffer2 = Array[Float32, length=8](fill=0)
var bytes2 = file.read(buffer2)

var eleventh_element = buffer2[0]
var twelvth_element = buffer2[1]
print(eleventh_element, twelvth_element)
```

Parameters:

- `dtype`: The type that the data will be represented as.
- `origin`: The origin of the passed in Span.

Args:

- `buffer`: The mutable Span to read data into.

Returns: The total amount of data that was read in bytes.

Raises: An error if this file handle is invalid, or if the file read returned a failure.

#### `FileHandle.read_bytes`

```mojo
def read_bytes(self, size: Int = Int(-1)) raises -> List[UInt8]
```

Reads data from a file and sets the file handle seek position. If size is left as default of -1, it will read to the end of the file. Setting size to a number larger than what's in the file will be handled and set the List length to the total number of bytes in the file.

Examples:

Reading the entire file into a List[Int8]:

```mojo
var file = open("/tmp/example.txt", "r")
var string = file.read_bytes()
```

Reading the first 8 bytes, skipping 2 bytes, and then reading the next
8 bytes:

```mojo
from std.os import SEEK_CUR
var file = open("/tmp/example.txt", "r")
var list1 = file.read(8)
_ = file.seek(2, SEEK_CUR)
var list2 = file.read(8)
```

Reading the last 8 bytes in the file, then the first 8 bytes:

```mojo
from std.os import SEEK_SET, SEEK_END
var file = open("/tmp/example.txt", "r")
_ = file.seek(-8, SEEK_END)
var last_data = file.read(8)
_ = file.seek(8, SEEK_SET) # SEEK_SET is the default start of file
var first_data = file.read(8)
```

Args:

- `size`: Requested number of bytes to read (Default: -1 = EOF).

Returns: The contents of the file.

Raises: An error if this file handle is invalid, or if the file read returned a failure.

#### `FileHandle.seek`

```mojo
def seek(self, offset: Int, whence: UInt8 = UInt8(0)) raises -> UInt64
```

Seeks to the given offset in the file.

Examples:

Skip 32 bytes from the current read position:

```mojo
from std.os import SEEK_CUR
var f = open("/tmp/example.txt", "r")
_ = f.seek(32, SEEK_CUR)
```

Start from 32 bytes from the end of the file:

```mojo
from std.os import SEEK_END
var f = open("/tmp/example.txt", "r")
_ = f.seek(-32, SEEK_END)
```

Args:

- `offset`: The byte offset to seek to, relative to `whence`. May be negative when `whence` is `os.SEEK_CUR` or `os.SEEK_END`.
- `whence`: The reference point for the offset: os.SEEK_SET = 0: start of file (Default). os.SEEK_CUR = 1: current position. os.SEEK_END = 2: end of file.

Returns: The resulting byte offset from the start of the file.

Raises: An error if this file handle is invalid, or if file seek returned a failure.

#### `FileHandle.write_once`

```mojo
def write_once(mut self, bytes: Span[UInt8]) raises -> Int
```

Attempt to write bytes to the file, returning the number of bytes written.

This is a low-level method that performs a single write syscall. It may
write fewer bytes than requested (partial write), which is not an error.
Most users should use `write_bytes()` instead, which handles partial
writes automatically.

Notes:
Similar to Rust's `Write::write()`, this method represents one attempt
to write data and may not write all bytes. Use `write_bytes()` for
guaranteed complete writes (equivalent to Rust's `write_all()`).

Examples:

```mojo
var file = open("/tmp/example.txt", "w")
var data = String("Hello, World!").as_bytes()

# May write fewer bytes than requested
var bytes_written = file.write_once(data)
print("Wrote", bytes_written, "of", len(data), "bytes")
```

Args:

- `bytes`: The byte span to write to this file.

Returns: The number of bytes actually written. This may be less than `len(bytes)`.

Raises: If the file handle is invalid or the write syscall fails.

#### `FileHandle.write_all`

```mojo
def write_all(mut self, bytes: Span[UInt8]) raises
```

Write all bytes to the file, handling partial writes automatically.

This method guarantees that all bytes are written by looping until
complete or an error occurs. This is equivalent to Rust's `write_all()`.

Notes:
Unlike `write_once()`, this method will not return until all bytes
are written or an unrecoverable error occurs. Use this method when
you need proper error handling for write operations.

Examples:

```mojo
var file = open("/tmp/example.txt", "w")
var data = String("Hello, World!").as_bytes()

# Writes all bytes, handling partial writes automatically
file.write_all(data)
```

Args:

- `bytes`: The byte span to write to this file.

Raises: If the file handle is invalid or the write operation fails.

#### `FileHandle.write_bytes`

```mojo
def write_bytes(mut self, bytes: Span[UInt8])
```

Write a span of bytes to the file.

This method is required by the Writer trait and handles partial writes
automatically by looping until all bytes are written. On write failure,
the program will abort. For better error handling, use `write_all()`.

Notes:
This method satisfies the Writer trait requirement. On write failure,
the program will abort. Use `write_all()` for proper error handling.

We use abort() instead of raising errors because the Writer trait
currently requires write_bytes() to be non-raising. This allows
the trait to work with both infallible writers (String) and fallible
writers (files). A future improvement would be to make the Writer
trait allow raises, enabling proper error handling here.

Examples:

```mojo
var file = open("/tmp/example.txt", "w")
var data = String("Hello, World!").as_bytes()
file.write_bytes(data)  # Aborts on error - use write_all() instead
```

Args:

- `bytes`: The byte span to write to this file.

#### `FileHandle.write_string`

```mojo
def write_string(mut self, string: StringSpan)
```

Write a `StringSlice` to this `FileHandle`.

This method is required by the `Writer` trait.

Args:

- `string`: The `StringSlice` to write to this `FileHandle`.

#### `FileHandle.write`

```mojo
def write[*Ts: Writable](mut self, *args: *Ts.values)
```

Write a sequence of Writable arguments to the provided Writer.

Notes:
Passing an invalid file handle (e.g., after calling `close()`) is
undefined behavior. In debug builds, this will trigger an assertion.

Parameters:

- `*Ts`: Types of the provided argument sequence.

Args:

- `*args`: Sequence of arguments to write to this Writer.

#### `FileHandle.__enter__`

```mojo
def __enter__(var self) -> Self
```

The function to call when entering the context.

Returns: The file handle.

## Functions

### `open`

```mojo
def open[PathLike: PathLike](path: PathLike, mode: StringSpan) raises -> FileHandle
```

Opens the file specified by path using the mode provided, returning a FileHandle.

Parameters:

- `PathLike`: The a type conforming to the os.PathLike trait.

Args:

- `path`: The path to the file to open.
- `mode`: The mode to open the file in: {"r", "w", "rw", "a"}.

Returns: A file handle.

Raises: If file open mode is not one of the supported modes. If there is an error when opening the file.
