# `std.pathlib.path`

Path manipulation module.

This module defines a platform-independent API for working with filesystem
paths. `Path`, its core type, represents a filesystem path. It exposes
operations such as path composition, existence checks, file I/O, and
access to file attributes.

To use these features import the `Path` type from this module.

Example:

```mojo
from std.pathlib import Path
var p = Path("a") / "b" / "c.txt"
print(p)  # a/b/c.txt
```

## Aliases

### `DIR_SEPARATOR`

```mojo
comptime DIR_SEPARATOR = "/"
```

The directory separator character for path operations.

## Structs

### `Path`

```mojo
struct Path
```

The Path object.

Fields:

- `path` (`String`): The underlying path string representation.

Implemented traits: `AnyType`, `Boolable`, `Comparable`, `Copyable`, `Deinitable`, `Equatable`, `Hashable`, `ImplicitlyCopyable`, `Movable`, `PathLike`, `Writable`

#### `Path.__init__`

```mojo
def __init__(out self) raises
```

Initializes a path with the current directory.

Raises: If the operation fails.

```mojo
def __init__(out self, path: StringSpan)
```

Initializes a path with the provided path.

Args:

- `path`: The file system path.

```mojo
def __init__(out self, var path: String)
```

Initializes a path with the provided path.

Args:

- `path`: The file system path.

```mojo
def __init__(out self, path: StringLiteral)
```

Initializes a path with the provided path.

Args:

- `path`: The file system path.

#### `Path.__bool__`

```mojo
def __bool__(self) -> Bool
```

Checks if the path is not empty.

Returns: True if the path length is greater than zero, and False otherwise.

#### `Path.__lt__`

```mojo
def __lt__(self, other: Self) -> Bool
```

Returns True if this path is less than the other path.

Comparison uses lexicographic ordering of the underlying path strings.

Args:

- `other`: The other path to compare against.

Returns: True if this path is less than the other path, and False otherwise.

#### `Path.__eq__`

```mojo
def __eq__(self, other: Self) -> Bool
```

Returns True if the two paths are equal.

Args:

- `other`: The other path to compare against.

Returns: True if the paths are equal and False otherwise.

```mojo
def __eq__(self, other: StringSpan) -> Bool
```

Returns True if the two paths are equal.

Args:

- `other`: The other path to compare against.

Returns: True if the String and Path are equal, and False otherwise.

#### `Path.__truediv__`

```mojo
def __truediv__(self, suffix: Self) -> Self
```

Joins two paths using the system-defined path separator.

Args:

- `suffix`: The suffix to append to the path.

Returns: A new path with the suffix appended to the current path.

```mojo
def __truediv__(self, suffix: StringSpan) -> Self
```

Joins two paths using the system-defined path separator.

Args:

- `suffix`: The suffix to append to the path.

Returns: A new path with the suffix appended to the current path.

#### `Path.__itruediv__`

```mojo
def __itruediv__(mut self, suffix: StringSpan)
```

Joins two paths using the system-defined path separator.

Args:

- `suffix`: The suffix to append to the path.

#### `Path.write_to`

```mojo
def write_to(self, mut writer: T)
```

Formats this path to the provided Writer.

Args:

- `writer`: The object to write to.

#### `Path.write_repr_to`

```mojo
def write_repr_to(self, mut writer: T)
```

Write the repr of this `Path` to a writer.

Writes the path in the format `Path('...')`.

Args:

- `writer`: The object to write to.

#### `Path.__fspath__`

```mojo
def __fspath__(self) -> String
```

Returns a string representation of the path.

Returns: A string representation of the path.

#### `Path.stat`

```mojo
def stat(self) raises -> stat_result
```

Returns the stat information on the path.

Example:

```mojo
from std.pathlib import Path
var p = Path()       # Path to cwd
print(p.stat())      # os.stat_result(...)
```

Returns: A stat_result object containing information about the path.

Raises: If the operation fails.

#### `Path.lstat`

```mojo
def lstat(self) raises -> stat_result
```

Returns the lstat information on the path. This is similar to stat, but if the file is a symlink then it gives you information about the symlink rather than the target.

Returns: A stat_result object containing information about the path.

Raises: If the operation fails.

#### `Path.exists`

```mojo
def exists(self) -> Bool
```

Returns True if the path exists and False otherwise.

Example:

```mojo
from std.pathlib import Path

var p = Path("./path/to/nowhere/does-not-exist")
print("Exists" if p.exists() else "Does not exist") # Does not exist
```

Returns: True if the path exists on disk and False otherwise.

#### `Path.expanduser`

```mojo
def expanduser(self) raises -> Self
```

Expands a prefixed `~` with `$HOME` on posix If environment variables are not set or the `path` is not prefixed with `~`, returns the `path` unmodified.

Example:

```mojo
from std.pathlib import Path
from std.testing import assert_true

var p = Path("~")
assert_true(p.expanduser() == Path.home())
```

Returns: The expanded path.

Raises: If the operation fails.

#### `Path.home`

```mojo
def home() raises -> Self
```

Returns `$HOME` on posix. If environment variables are not set it returns `~`.

Example:

```mojo
from std.pathlib import Path
from std.testing import assert_true

var p = Path("~")
assert_true(p.expanduser() == Path.home())
```

Returns: Path to user home directory.

Raises: If the operation fails.

#### `Path.is_dir`

```mojo
def is_dir(self) -> Bool
```

Returns True if the path is a directory and False otherwise.

Example:

```mojo
from std.pathlib import Path
from std.testing import assert_true

var p = Path.home()
assert_true(p.is_dir())
```

Returns: Return True if the path points to a directory (or a link pointing to a directory).

#### `Path.is_file`

```mojo
def is_file(self) -> Bool
```

Returns True if the path is a file and False otherwise.

Example:

```mojo
from std.pathlib import Path
from std.testing import assert_false

var p = Path.home()
assert_false(p.is_file())
```

Returns: Return True if the path points to a file (or a link pointing to a file).

#### `Path.read_text`

```mojo
def read_text(self) raises -> String
```

Returns content of the file.

Example:

```mojo
from std.pathlib import Path

var p = Path("testfile.txt")
p.write_text("Hello Mojo")
if p.exists():
    var contents = p.read_text()
    print(contents) # Hello Mojo
```

Returns: Contents of file as string.

Raises: If the operation fails.

#### `Path.read_bytes`

```mojo
def read_bytes(self) raises -> List[UInt8]
```

Returns content of the file as bytes.

Example:

```mojo
from std.pathlib import Path
from std.testing import assert_true

var p = Path("testfile.txt")
p.write_text("test")
if p.exists():
    var contents = p.read_bytes()
    assert_true(contents[0] == 116)
```

Returns: Contents of file as list of bytes.

Raises: If the operation fails.

#### `Path.write_text`

```mojo
def write_text[T: Writable](self, value: T) raises
```

Writes the value to the file as text.

Example:

```mojo
from std.pathlib import Path

var p = Path("testfile")
p.write_text("Hello")
if p.exists():
    var contents = p.read_text()
    print(contents) # Hello
```

Parameters:

- `T`: The type of an object conforming to the `Writable` trait.

Args:

- `value`: The value to write.

Raises: If the operation fails.

#### `Path.write_bytes`

```mojo
def write_bytes(self, bytes: Span[UInt8]) raises
```

Writes bytes to the file.

Example:

```mojo
from std.pathlib import Path

var p = Path("testfile")
var s = "Hello"
p.write_bytes(s.as_bytes())
if p.exists():
    var contents = p.read_text()
    print(contents) # Hello
```

Args:

- `bytes`: The bytes to write to this file.

Raises: If the operation fails.

#### `Path.suffix`

```mojo
def suffix(self) -> String
```

The path's extension, if any. This includes the leading period. For example: '.txt'. If no extension is found, returns the empty string.

Example:

```mojo
from std.pathlib import Path
from std.testing import assert_true

var p = Path("testfile.txt")
print(p.suffix())
assert_true(p.suffix() == ".txt")

p = Path(".hiddenfile")
assert_true(p.suffix() == "") # No suffix
```

Returns: The path's extension.

#### `Path.joinpath`

```mojo
def joinpath(self, *pathsegments: String) -> Self
```

Joins the Path using the pathsegments.

Example:

```mojo
from std.pathlib import Path
from std.tempfile import gettempdir
from std.testing import assert_true

# gettmpdir() has no guarantee of trailing /
# Use joinpath to ensure path construction
var p = Path("/tmp")
p = p.joinpath("testdir")  # No trailing /
p = p.joinpath("testfile.txt")
assert_true(p == Path("/tmp/testdir/testfile.txt"))

p = Path("/tmp/")
p = p.joinpath("testdir/")  # Trailing /
p = p.joinpath("testfile.txt")
assert_true(p == Path("/tmp/testdir/testfile.txt"))
```

Args:

- `*pathsegments`: The path segments.

Returns: The path concatenation with the pathsegments using the directory separator.

#### `Path.listdir`

```mojo
def listdir(self) raises -> List[Self]
```

Gets the list of entries contained in the path provided.

Example:

```mojo
from std.pathlib import Path, cwd

for item in cwd().listdir():
    print(item) # each item name in working directory
```

Returns: The list of entries in the path provided.

Raises: If the operation fails.

#### `Path.name`

```mojo
def name(self) -> String
```

Returns the name of the path.

Example:

```mojo
from std.pathlib import Path

Path("a/path/foo.txt").name()  # returns "foo.txt"
```

Returns: The name of the path.

#### `Path.parts`

```mojo
def parts(self) -> List[StringSpan[origin_of(self.path["bytes"])]]
```

Returns the parts of the path separated by `DIR_SEPARATOR`.

Example:

```mojo
from std.pathlib import Path
from std.testing import assert_true

for p, q in zip(Path("a/path/foo.txt").parts(), ["a", "path", "foo.txt"]):
    assert_true(p == q)
```

Returns: The parts of the path separated by `DIR_SEPARATOR`.

## Functions

### `cwd`

```mojo
def cwd() raises -> Path
```

Gets the current directory.

Example:

```mojo
from std.pathlib import cwd

var string_path = cwd()
print(string_path)
```

Returns: The current directory.

Raises: If the operation fails.
