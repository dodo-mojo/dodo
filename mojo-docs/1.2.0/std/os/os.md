# `std.os.os`

Provides functions to access operating-system dependent functionality, including file system operations.

You can import a method from the `os` package. For example:

```mojo
from std.os import listdir
```

## Aliases

### `sep`

```mojo
comptime sep = "/"
```

The path separator for the current platform.

### `SEEK_SET`

```mojo
comptime SEEK_SET = UInt8(0)
```

Seek from the beginning of the file.

### `SEEK_CUR`

```mojo
comptime SEEK_CUR = UInt8(1)
```

Seek from the current position.

### `SEEK_END`

```mojo
comptime SEEK_END = UInt8(2)
```

Seek from the end of the file.

## Functions

### `getuid`

```mojo
def getuid() -> Int
```

Retrieve the user ID of the calling process.

Constraints: This function is constrained to run on Linux or macOS operating systems only.

Returns: The user ID of the calling process.

### `listdir`

```mojo
def listdir[PathLike: PathLike](path: PathLike) raises -> List[String]
```

Gets the list of entries contained in the path provided.

Parameters:

- `PathLike`: The a type conforming to the os.PathLike trait.

Args:

- `path`: The path to the directory.

Returns: Returns the list of entries in the path provided.

Raises: If the operation fails.

### `abort`

```mojo
def abort() -> Never
```

Terminates execution, using a target dependent trap instruction if available.

```mojo
def abort[*, prefix: StringSpan[ImmStaticOrigin] = StringSpan("ABORT:")](message: String, *, location: Optional[SourceLocation] = Optional()) -> Never
```

Calls a target dependent trap instruction if available.

Parameters:

- `prefix`: A static string prefix to include before the message.

Args:

- `message`: The message to include when aborting.
- `location`: The optional source location to include.

```mojo
def abort[*, prefix: StringSpan[ImmStaticOrigin] = StringSpan("ABORT:")](message: TString, *, location: Optional[SourceLocation] = Optional()) -> Never
```

Calls a target dependent trap instruction if available.

Parameters:

- `prefix`: A static string prefix to include before the message.

Args:

- `message`: The t-string message to include when aborting.
- `location`: The optional source location to include.

### `remove`

```mojo
def remove[PathLike: PathLike](path: PathLike) raises
```

Removes the specified file.

If the path is a directory or it can not be deleted, an error is raised.
Absolute and relative paths are allowed, relative paths are resolved from cwd.

Parameters:

- `PathLike`: The a type conforming to the os.PathLike trait.

Args:

- `path`: The path to the file.

Raises: If the operation fails.

### `unlink`

```mojo
def unlink[PathLike: PathLike](path: PathLike) raises
```

Removes the specified file.

If the path is a directory or it can not be deleted, an error is raised.
Absolute and relative paths are allowed, relative paths are resolved from cwd.

Parameters:

- `PathLike`: The a type conforming to the os.PathLike trait.

Args:

- `path`: The path to the file.

Raises: If the operation fails.

### `symlink`

```mojo
def symlink[TargetType: PathLike, LinkType: PathLike](target: TargetType, linkpath: LinkType) raises
```

Creates a symlink.

If linkpath already exists it will not be overwritten.
See `symlink(2)`

Parameters:

- `TargetType`: The path type of the link target.
- `LinkType`: The path type of the link.

Args:

- `target`: The target of the symbolic link.
- `linkpath`: The path of the symbolic link to create.

Raises: If the operation fails.

### `link`

```mojo
def link[OldType: PathLike, NewType: PathLike](oldpath: OldType, newpath: NewType) raises
```

Creates a new hard-link to an existing file.

Parameters:

- `OldType`: The path type of the existing file.
- `NewType`: The path type of the file to create.

Args:

- `oldpath`: The existing file.
- `newpath`: The new file.

Raises: If the operation fails.

### `mkdir`

```mojo
def mkdir[PathLike: PathLike](path: PathLike, mode: Int = Int(511)) raises
```

Creates a directory at the specified path.

If the directory can not be created an error is raised.
Absolute and relative paths are allowed, relative paths are resolved from cwd.

Parameters:

- `PathLike`: The a type conforming to the os.PathLike trait.

Args:

- `path`: The path to the directory.
- `mode`: The mode to create the directory with.

Raises: If the operation fails.

### `makedirs`

```mojo
def makedirs[PathLike: PathLike](path: PathLike, mode: Int = Int(511), exist_ok: Bool = False) raises
```

Creates a specified leaf directory along with any necessary intermediate directories that don't already exist.

Parameters:

- `PathLike`: The a type conforming to the os.PathLike trait.

Args:

- `path`: The path to the directory.
- `mode`: The mode to create the directory with.
- `exist_ok`: Ignore error if `True` and path exists (default `False`).

Raises: If the operation fails.

### `rmdir`

```mojo
def rmdir[PathLike: PathLike](path: PathLike) raises
```

Removes the specified directory.

If the path is not a directory or it can not be deleted, an error is raised.
Absolute and relative paths are allowed, relative paths are resolved from cwd.

Parameters:

- `PathLike`: The a type conforming to the os.PathLike trait.

Args:

- `path`: The path to the directory.

Raises: If the operation fails.

### `removedirs`

```mojo
def removedirs[PathLike: PathLike](path: PathLike) raises
```

Removes a leaf directory and all empty intermediate ones.

Directories corresponding to rightmost path segments will be pruned away
until either the whole path is consumed or an error occurs. Errors during
this latter phase are ignored, which occur when a directory was not empty.

Parameters:

- `PathLike`: A type conforming to the os.PathLike trait.

Args:

- `path`: The path to the directory.

Raises: If the operation fails.

### `isatty`

```mojo
def isatty(fd: Int) -> Bool
```

Checks whether a file descriptor refers to a terminal.

Returns `True` if the file descriptor `fd` is open and connected to a
tty(-like) device, otherwise `False`. On GPUs, the function always returns
`False`.

Examples:
```mojo
from std.os import isatty

# Check if stdout (fd=1) is a terminal
if isatty(1):
    print("Running in a terminal")
else:
    print("Output is redirected")
```

Args:

- `fd`: A file descriptor.

Returns: `True` if `fd` is connected to a terminal, `False` otherwise.

### `chdir`

```mojo
def chdir[PathLike: PathLike](path: PathLike) raises
```

Changes the current working directory.

Parameters:

- `PathLike`: A type conforming to the os.PathLike trait.

Args:

- `path`: The path to the new working directory.

Raises: If the operation fails.
