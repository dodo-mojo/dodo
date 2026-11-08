# `std.stat.stat`

Provides constants and functions for interpreting file mode bits.

This module defines file type constants and functions for testing file modes,
similar to Python's `stat` module. It includes bit masks for identifying different
file types (regular files, directories, symbolic links, devices, etc.) and
convenience functions for mode testing.

## Aliases

### `S_IFMT`

```mojo
comptime S_IFMT = 61440
```

Bits that determine the file type.

### `S_IFDIR`

```mojo
comptime S_IFDIR = 16384
```

Bits that determine the directory.

### `S_IFCHR`

```mojo
comptime S_IFCHR = 8192
```

Bits that determine the char device.

### `S_IFBLK`

```mojo
comptime S_IFBLK = 24576
```

Bits that determine the block device.

### `S_IFREG`

```mojo
comptime S_IFREG = 32768
```

Bits that determine the regular file.

### `S_IFIFO`

```mojo
comptime S_IFIFO = 4096
```

Bits that determine the fifo.

### `S_IFLNK`

```mojo
comptime S_IFLNK = 40960
```

Bits that determine the symlink.

### `S_IFSOCK`

```mojo
comptime S_IFSOCK = 49152
```

Bits that determine the socket.

## Functions

### `S_ISLNK`

```mojo
def S_ISLNK[intable: Intable](mode: intable) -> Bool
```

Returns True if the mode is a symlink.

Parameters:

- `intable`: A type conforming to Intable.

Args:

- `mode`: The file mode.

Returns: True if the mode is a symlink and False otherwise.

### `S_ISREG`

```mojo
def S_ISREG[intable: Intable](mode: intable) -> Bool
```

Returns True if the mode is a regular file.

Parameters:

- `intable`: A type conforming to Intable.

Args:

- `mode`: The file mode.

Returns: True if the mode is a regular file and False otherwise.

### `S_ISDIR`

```mojo
def S_ISDIR[intable: Intable](mode: intable) -> Bool
```

Returns True if the mode is a directory.

Parameters:

- `intable`: A type conforming to Intable.

Args:

- `mode`: The file mode.

Returns: True if the mode is a directory and False otherwise.

### `S_ISCHR`

```mojo
def S_ISCHR[intable: Intable](mode: intable) -> Bool
```

Returns True if the mode is a character device.

Parameters:

- `intable`: A type conforming to Intable.

Args:

- `mode`: The file mode.

Returns: True if the mode is a character device and False otherwise.

### `S_ISBLK`

```mojo
def S_ISBLK[intable: Intable](mode: intable) -> Bool
```

Returns True if the mode is a block device.

Parameters:

- `intable`: A type conforming to Intable.

Args:

- `mode`: The file mode.

Returns: True if the mode is a block device and False otherwise.

### `S_ISFIFO`

```mojo
def S_ISFIFO[intable: Intable](mode: intable) -> Bool
```

Returns True if the mode is a fifo.

Parameters:

- `intable`: A type conforming to Intable.

Args:

- `mode`: The file mode.

Returns: True if the mode is a fifo and False otherwise.

### `S_ISSOCK`

```mojo
def S_ISSOCK[intable: Intable](mode: intable) -> Bool
```

Returns True if the mode is a socket.

Parameters:

- `intable`: A type conforming to Intable.

Args:

- `mode`: The file mode.

Returns: True if the mode is a socket and False otherwise.
