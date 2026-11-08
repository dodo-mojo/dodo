# `std.os.path.path`

Provides a set of operating-system independent functions for manipulating file system paths.

You can import these APIs from the `os.path` package. For example:

```mojo
from std.os.path import isdir
```

## Functions

### `expanduser`

```mojo
def expanduser[PathLike: PathLike, //](path: PathLike) raises -> String
```

Expands a tilde "~" prefix in `path` to the user's home directory.

For example, `~/folder` becomes `/home/current_user/folder`. On macOS and
Linux a path starting with `~user/` will expand to the specified user's home
directory, so `~user/folder` becomes `/home/user/folder`.

If the home directory cannot be determined, or the `path` is not prefixed
with "~", the original path is returned unchanged.

Parameters:

- `PathLike`: The type conforming to the os.PathLike trait.

Args:

- `path`: The path that is being expanded.

Returns: The expanded path.

Raises: If the operation fails.

### `isdir`

```mojo
def isdir[PathLike: PathLike, //](path: PathLike) -> Bool
```

Return True if path is an existing directory. This follows symbolic links, so both islink() and isdir() can be true for the same path.

Example:
```mojo
from std.os.path import isdir

print(isdir("/tmp")) # True
print(isdir("noexist")) # False
```

Parameters:

- `PathLike`: The type conforming to the os.PathLike trait.

Args:

- `path`: The path to the directory.

Returns: True if the path is a directory or a link to a directory and False otherwise.

### `isfile`

```mojo
def isfile[PathLike: PathLike, //](path: PathLike) -> Bool
```

Test whether a path is a regular file.

Example:
```mojo
from std.os.path import isfile

print(isfile("/etc/hosts")) # True
print(isfile("/tmp")) # False (it's a directory)
```

Parameters:

- `PathLike`: The type conforming to the os.PathLike trait.

Args:

- `path`: The path to the directory.

Returns: Returns True if the path is a regular file.

### `islink`

```mojo
def islink[PathLike: PathLike, //](path: PathLike) -> Bool
```

Return True if path refers to an existing directory entry that is a symbolic link.

Example:
```mojo
from std.os.path import islink

print(islink("/etc/hosts"))  # False (regular file, not a symlink)
```

Parameters:

- `PathLike`: The type conforming to the os.PathLike trait.

Args:

- `path`: The path to the directory.

Returns: True if the path is a link to a directory and False otherwise.

### `dirname`

```mojo
def dirname[PathLike: PathLike, //](path: PathLike) -> String
```

Returns the directory component of a pathname.

Example:
```mojo
from std.os.path import dirname

print(dirname("/a/b/c.txt")) # "/a/b"
print(dirname("c.txt")) # ""
```

Parameters:

- `PathLike`: The type conforming to the os.PathLike trait.

Args:

- `path`: The path to a file.

Returns: The directory component of a pathname.

### `realpath`

```mojo
def realpath[PathLike: PathLike & Deinitable, //](path: PathLike) raises -> String
```

Expands all symbolic links and resolves references to /./, /../ and extra '/' characters in the null-terminated string named by path to produce a canonicalized absolute pathname.The resulting path will have no symbolic link, /./ or /../ components.

Parameters:

- `PathLike`: The type conforming to the os.PathLike trait.

Args:

- `path`: The path to resolve.

Returns: A String of the resolved path.

Raises: - Read or search permission was denied for a component of the path prefix. - path is NULL. - An I/O error occurred while reading from the filesystem. - Too many symbolic links were encountered in translating the pathname. - A component of a pathname exceeded NAME_MAX characters, or an entire pathname exceeded PATH_MAX characters. - The named file does not exist. - Out of memory. - A component of the path prefix is not a directory.

### `exists`

```mojo
def exists[PathLike: PathLike, //](path: PathLike) -> Bool
```

Return True if path exists.

Example:
```mojo
from std.os.path import exists

print(exists("/tmp")) # True
print(exists("noexist")) # False
```

Parameters:

- `PathLike`: The type conforming to the os.PathLike trait.

Args:

- `path`: The path to the directory.

Returns: Returns True if the path exists and is not a broken symbolic link.

### `lexists`

```mojo
def lexists[PathLike: PathLike, //](path: PathLike) -> Bool
```

Return True if path exists or is a broken symlink.

Parameters:

- `PathLike`: The type conforming to the os.PathLike trait.

Args:

- `path`: The path to the directory.

Returns: Returns True if the path exists or is a broken symbolic link.

### `getsize`

```mojo
def getsize[PathLike: PathLike, //](path: PathLike) raises -> Int
```

Return the size, in bytes, of the specified path.

Parameters:

- `PathLike`: The type conforming to the os.PathLike trait.

Args:

- `path`: The path to the file.

Returns: The size of the path in bytes.

Raises: If the operation fails.

### `is_absolute`

```mojo
def is_absolute[PathLike: PathLike, //](path: PathLike) -> Bool
```

Return True if `path` is an absolute path name. On Unix, that means it begins with a slash.

Example:
```mojo
from std.os.path import is_absolute

print(is_absolute("/usr/bin")) # True
print(is_absolute("relative")) # False
```

Parameters:

- `PathLike`: The type conforming to the os.PathLike trait.

Args:

- `path`: The path to check.

Returns: Return `True` if path is an absolute path name.

### `join`

```mojo
def join(var path: String, *paths: String) -> String
```

Join two or more pathname components, inserting '/' as needed. If any component is an absolute path, all previous path components will be discarded.  An empty last part will result in a path that ends with a separator.

Example:
```mojo
from std.os.path import join

print(join("a", "b", "c")) # "a/b/c"
print(join("a", "/b", "c")) # "/b/c" (absolute resets)
```

Args:

- `path`: The path to join.
- `*paths`: The paths to join.

Returns: The joined path.

### `split`

```mojo
def split[PathLike: PathLike, //](path: PathLike) -> Tuple[String, String]
```

Split a given pathname into two components: head and tail. This is useful for separating the directory path from the filename. If the input path ends with a separator, the tail component will be empty. If there is no separator in the path, the head component will be empty, and the entire path will be considered the tail. Trailing separators in the head are stripped unless the head is the root directory.

Example:
```mojo
from std.os.path import split

print(split("/a/b/c.txt")) # ("/a/b", "c.txt")
print(split("/a/b/")) # ("/a/b", "")
```

Parameters:

- `PathLike`: The type conforming to the os.PathLike trait.

Args:

- `path`: The path to be split.

Returns: A tuple containing two strings: (head, tail).

### `basename`

```mojo
def basename[PathLike: PathLike, //](path: PathLike) -> String
```

Returns the tail section of a path.

```mojo
from std.os.path import basename

print(basename("a/path/foo.txt")) # "foo.txt"
```

Parameters:

- `PathLike`: The type conforming to the os.PathLike trait.

Args:

- `path`: The path to retrieve the basename from.

Returns: The basename from the path.

### `split_extension`

```mojo
def split_extension[PathLike: PathLike, //](path: PathLike) raises -> Tuple[String, String]
```

Splits `path` into the root and extension.

Example:
```mojo
from std.os.path import split_extension

print(split_extension("foo.tar.gz")) # ("foo.tar", ".gz")
print(split_extension("README")) # ("README", "")
```

Parameters:

- `PathLike`: The type conforming to the os.PathLike trait.

Args:

- `path`: The path to be split.

Returns: A tuple containing two strings: (root, extension).

Raises: If the operation fails.

### `splitroot`

```mojo
def splitroot[PathLike: PathLike, //](path: PathLike) -> Tuple[String, String, String]
```

Splits `path` into drive, root and tail. The tail contains anything after the root.

Parameters:

- `PathLike`: The type conforming to the os.PathLike trait.

Args:

- `path`: The path to be split.

Returns: A tuple containing three strings: (drive, root, tail).

### `expandvars`

```mojo
def expandvars[PathLike: PathLike, //](path: PathLike) -> String
```

Replaces `${var}` or `$var` in the path with values from the current environment variables. Malformed variable names and references to non-existing variables are left unchanged.

Parameters:

- `PathLike`: The type conforming to the os.PathLike trait.

Args:

- `path`: The path that is being expanded.

Returns: The expanded path.
