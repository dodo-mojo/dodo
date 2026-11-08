# `std.os.fstat`

Implements file system status operations.

You can import these APIs from the `os` package. For example:

```mojo
from std.os import stat
```

## Structs

### `stat_result`

```mojo
struct stat_result
```

Object whose fields correspond  to the members of the stat structure.

Fields:

- `st_mode` (`Int`): File mode: file type and file mode bits (permissions).
- `st_ino` (`Int`): Platform dependent, but if non-zero, uniquely identifies the file for a given value of st_dev.
- `st_dev` (`Int`): Identifier of the device on which this file resides.
- `st_nlink` (`Int`): Number of hard links.
- `st_uid` (`Int`): User identifier of the file owner.
- `st_gid` (`Int`): Group identifier of the file owner.
- `st_size` (`Int`): Size of the file in bytes, if it is a regular file or a symbolic link.
- `st_atimespec` (`_CTimeSpec`): Time of file most recent access.
- `st_mtimespec` (`_CTimeSpec`): Time of file most recent modification.
- `st_ctimespec` (`_CTimeSpec`): Time of file most recent change.
- `st_birthtimespec` (`_CTimeSpec`): Time of file creation.
- `st_blocks` (`Int`): Number of 512-byte blocks allocated for file.
- `st_blksize` (`Int`): Preferred blocksize for efficient file system I/O.
- `st_rdev` (`Int`): Type of device if an inode device.
- `st_flags` (`Int`): User defined flags for file.

Implemented traits: `AnyType`, `Copyable`, `Deinitable`, `Movable`, `Writable`

#### `stat_result.__init__`

```mojo
def __init__(out self, *, st_mode: Int, st_ino: Int, st_dev: Int, st_nlink: Int, st_uid: Int, st_gid: Int, st_size: Int, st_atimespec: _CTimeSpec, st_mtimespec: _CTimeSpec, st_ctimespec: _CTimeSpec, st_birthtimespec: _CTimeSpec, st_blocks: Int, st_blksize: Int, st_rdev: Int, st_flags: Int)
```

Initialize the stat_result structure.

Args:

- `st_mode`: File mode: file type and file mode bits (permissions).
- `st_ino`: Uniquely identifier for a file.
- `st_dev`: Identifier of the device on which this file resides.
- `st_nlink`: Number of hard links.
- `st_uid`: User identifier of the file owner.
- `st_gid`: Group identifier of the file owner.
- `st_size`: Size of the file (bytes), if it is a file or a symlink.
- `st_atimespec`: Time of file most recent access.
- `st_mtimespec`: Time of file most recent modification.
- `st_ctimespec`: Time of file most recent change.
- `st_birthtimespec`: Time of file creation.
- `st_blocks`: Number of 512-byte blocks allocated for file.
- `st_blksize`: Preferred blocksize for efficient file system I/O.
- `st_rdev`: Type of device if an inode device.
- `st_flags`: User defined flags for file.

#### `stat_result.write_to`

```mojo
def write_to(self, mut writer: T)
```

Formats this path to the provided Writer.

Args:

- `writer`: The object to write to.

## Functions

### `stat`

```mojo
def stat[PathLike: PathLike](path: PathLike) raises -> stat_result
```

Get the status of a file or a file descriptor.

Parameters:

- `PathLike`: The a type conforming to the os.PathLike trait.

Args:

- `path`: The path to the directory.

Returns: Returns the stat_result on the path.

Raises: If the operation fails.

### `lstat`

```mojo
def lstat[PathLike: PathLike](path: PathLike) raises -> stat_result
```

Get the status of a file or a file descriptor (similar to stat, but does not follow symlinks).

Parameters:

- `PathLike`: The a type conforming to the os.PathLike trait.

Args:

- `path`: The path to the directory.

Returns: Returns the stat_result on the path.

Raises: If the operation fails.
