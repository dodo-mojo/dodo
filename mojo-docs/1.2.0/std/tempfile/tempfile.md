# `std.tempfile.tempfile`

Temporary file and directory creation.

This module provides a safe API for creating temporary files and directories.
It includes helpers for creating temporary directories (`mkdtemp`),
temporary files (`NamedTemporaryFile`), querying the default temporary
directory (`gettempdir`), and a context manager for managing the lifetime of
temporary directories (`TemporaryDirectory`).

To use these features, import the desired functions or classes from this module.

```mojo
# Import from the tempfile module
from std.tempfile import gettempdir
```

## Aliases

### `TMP_MAX`

```mojo
comptime TMP_MAX = 10000
```

Maximum number of attempts when generating unique temporary file names.

## Structs

### `TemporaryDirectory`

```mojo
struct TemporaryDirectory
```

Temporary directory that cleans up automatically.

Creates a directory that's deleted when the context exits:
```mojo
from std.tempfile import TemporaryDirectory
import std.os

def main() raises:
    var temp_path: String
    with TemporaryDirectory() as tmpdir:
        temp_path = tmpdir
        print(std.os.path.exists(tmpdir))  # True
        # Use tmpdir for temporary work

    print(std.os.path.exists(temp_path))  # False - cleaned up
```

The directory and all its contents are removed on exit, even if an error occurs.
Set `ignore_cleanup_errors=True` to suppress cleanup failures.

Fields:

- `name` (`String`): The name of the temporary directory.

Implemented traits: `AnyType`, `Deinitable`, `Movable`

#### `TemporaryDirectory.__init__`

```mojo
def __init__(out self, suffix: String = "", prefix: String = "tmp", dir: Optional[String] = None, ignore_cleanup_errors: Bool = False) raises
```

Create a temporary directory.

Can be used as a context manager. When used as a context manager,
the directory is removed when the context manager exits.

Args:

- `suffix`: Suffix to use for the directory name.
- `prefix`: Prefix to use for the directory name.
- `dir`: Directory in which the directory will be created.
- `ignore_cleanup_errors`: Whether to ignore cleanup errors.

Raises: If the operation fails.

#### `TemporaryDirectory.__enter__`

```mojo
def __enter__(self) -> String
```

The function to call when entering the context.

Returns: The temporary directory name.

#### `TemporaryDirectory.__exit__`

```mojo
def __exit__(self) raises
```

Called when exiting the context with no error.

Raises: If the operation fails.

```mojo
def __exit__(self, err: Error) -> Bool
```

Called when exiting the context with an error.

Args:

- `err`: The error raised inside the context.

Returns: True if the temporary directory was removed successfully.

### `NamedTemporaryFile`

```mojo
struct NamedTemporaryFile
```

Temporary file with automatic cleanup.

Creates a file that's deleted when closed (by default):
```mojo
from std.tempfile import NamedTemporaryFile

with NamedTemporaryFile(mode="rw") as f:
    f.write("Hello world!")
    f.seek(0)
    print(f.read())  # "Hello world!"
    print(f.name)    # Access path while open
# File deleted automatically
```

Set `delete=False` to keep the file after closing.
Use `mode="r"` for reading, `mode="w"` for writing, `mode="rw"` for both.

Fields:

- `name` (`String`): Name of the file.

Implemented traits: `AnyType`, `Deinitable`, `Movable`

#### `NamedTemporaryFile.__init__`

```mojo
def __init__(out self, mode: String = "w", name: Optional[String] = None, suffix: String = "", prefix: String = "tmp", dir: Optional[String] = None, delete: Bool = True) raises
```

Create a named temporary file.

This is a wrapper around a `FileHandle`,
`os.remove()` is called in the `close()` method if `delete` is True.

Can be used as a context manager. When used as a context manager, the
`close()` is called when the context manager exits.

Args:

- `mode`: The mode to open the file in (the mode can be "r" or "w").
- `name`: The name of the temp file. If it is unspecified, then a random name will be provided.
- `suffix`: Suffix to use for the file name if name is not provided.
- `prefix`: Prefix to use for the file name if name is not provided.
- `dir`: Directory in which the file will be created.
- `delete`: Whether the file is deleted on close.

Raises: If the operation fails.

#### `NamedTemporaryFile.__deinit__`

```mojo
def __deinit__(deinit self)
```

Closes the file handle.

#### `NamedTemporaryFile.close`

```mojo
def close(mut self) raises
```

Closes the file handle.

Example:

```mojo
from std.tempfile import NamedTemporaryFile
import std.os

var temp_file = NamedTemporaryFile() # delete=True by default
temp_file.write("Temporary data")
temp_file.close() # File is deleted if delete=True
print(std.os.path.exists(temp_file.name)) # False

temp_file = NamedTemporaryFile(delete=False)
temp_file.write("Temporary data")
temp_file.close() # File is not deleted
print(std.os.path.exists(temp_file.name)) # True
std.os.remove(temp_file.name) # Clean up manually
```

Raises: If the operation fails.

#### `NamedTemporaryFile.read`

```mojo
def read(self, size: Int = Int(-1)) raises -> String
```

Reads the data from the file.

Example:

```mojo
from std.tempfile import NamedTemporaryFile
from std.pathlib import Path

var p: Path
with NamedTemporaryFile(mode="rw") as f:
    p = f.name.copy()
    f.write("Hello world!")
    _ = f.seek(0)
    print(
        f.read() == "Hello world!"
    )
print(p.exists()) # False
```

Args:

- `size`: Requested number of bytes to read.

Returns: The contents of the file.

Raises: If the operation fails.

#### `NamedTemporaryFile.read_bytes`

```mojo
def read_bytes(self, size: Int = Int(-1)) raises -> List[UInt8]
```

Read from file buffer until we have `size` characters or we hit EOF. If `size` is negative or omitted, read until EOF.

Example:

```mojo
from std.tempfile import NamedTemporaryFile
from std.pathlib import Path

var p: Path
var bytes = [Byte(0x48), 0x65, 0x6C, 0x6C, 0x6F] # "Hello"

with NamedTemporaryFile(mode="rw") as f:
    p = f.name.copy()
    f.write_bytes(bytes[:])
    _ = f.seek(0)

    var b = f.read_bytes()
    print(b == bytes) # True

    var s = String(from_utf8_lossy=b)
    print(s) # "Hello"

print(p.exists()) # False
```

Args:

- `size`: Requested number of bytes to read.

Returns: The contents of the file.

Raises: If the operation fails.

#### `NamedTemporaryFile.seek`

```mojo
def seek(self, offset: Int, whence: UInt8 = UInt8(0)) raises -> UInt64
```

Seeks to the given offset in the file.

Example:

```mojo
from std.tempfile import NamedTemporaryFile
from std.pathlib import Path

var p: Path
var bytes = [Byte(0x48), 0x65, 0x6C, 0x6C, 0x6F] # "Hello"

with NamedTemporaryFile(mode="rw") as f:
    p = f.name.copy()
    f.write_bytes(bytes[:])
    _ = f.seek(0)

    var b = f.read_bytes()
    print(b == bytes) # True
    print(String(from_utf8_lossy=b)) # "Hello"
```

Args:

- `offset`: The byte offset to seek to, relative to `whence`. May be negative when `whence` is `os.SEEK_CUR` or `os.SEEK_END`.
- `whence`: The reference point for the offset: os.SEEK_SET = 0: start of file (Default). os.SEEK_CUR = 1: current position. os.SEEK_END = 2: end of file.

Returns: The resulting byte offset from the start of the file.

Raises: An error if this file handle is invalid, or if file seek returned a failure.

#### `NamedTemporaryFile.write`

```mojo
def write[*Ts: Writable](mut self, *args: *Ts.values)
```

Write a sequence of Writable arguments to the provided Writer.

Example:
```mojo
from std.tempfile import NamedTemporaryFile
from std.pathlib import Path

var p: Path
with NamedTemporaryFile(mode="rw") as f:
    p = f.name
    f.write("Hello world!")
    _ = f.seek(0)
    print(
        f.read() == "Hello world!"
    )
```

Parameters:

- `*Ts`: Types of the provided argument sequence.

Args:

- `*args`: Sequence of arguments to write to this Writer.

#### `NamedTemporaryFile.write_bytes`

```mojo
def write_bytes(mut self, bytes: Span[UInt8])
```

Write a span of bytes to the file.

Example:

```mojo
from std.tempfile import NamedTemporaryFile

var bytes = [Byte(0x48), 0x65, 0x6C, 0x6C, 0x6F]  # "Hello" in ASCII

with NamedTemporaryFile(mode="rw") as f:
    f.write_bytes(bytes[:])
    _ = f.seek(0)

    var b = f.read_bytes()
    print(b == bytes) # True

    var s = String(from_utf8_lossy=b)
    print(s) # "Hello"
```

Args:

- `bytes`: The byte span to write to this file.

#### `NamedTemporaryFile.__enter__`

```mojo
def __enter__(var self) -> Self
```

The function to call when entering the context.

Returns: The file handle.

## Functions

### `gettempdir`

```mojo
def gettempdir() -> Optional[String]
```

Return the default directory to use for temporary files.

Example:

```mojo
from std.tempfile import gettempdir

print(gettempdir())
```

Returns: The name of the default temporary directory.

### `mkdtemp`

```mojo
def mkdtemp(suffix: String = "", prefix: String = "tmp", dir: Optional[String] = None) raises -> String
```

Create a temporary directory.

Caller is responsible for deleting the directory when done with it.

Example:

```mojo
from std.tempfile import mkdtemp
from std.os import rmdir

var temp_dir = mkdtemp()
print(temp_dir)
rmdir(temp_dir)
```

Args:

- `suffix`: Suffix to use for the directory name.
- `prefix`: Prefix to use for the directory name.
- `dir`: Directory in which the directory will be created.

Returns: The name of the created directory.

Raises: If the directory can not be created.
