# `std.os`

OS interface layer: environment, filesystem, process control.

The `os` package provides platform-independent access to operating system
functionality including filesystem operations, environment variables, and
process control. It offers portable interfaces to OS-dependent features,
abstracting platform differences while exposing system-level capabilities. This
package serves as the foundation for system programming in Mojo.

Use this package for system-level operations, filesystem management,
environment configuration, or platform abstraction. For file I/O operations,
use the built-in `open()` function. For path manipulation, see the `os.path`
package for path functions or the `pathlib` package for the object-oriented
`Path` type.

## Packages

- [`std.os.path`](path/index.md): Provides a set of operating-system independent functions for manipulating file system paths.

## Modules

- [`std.os.env`](env.md): Provides functions for working with environment variables.
- [`std.os.fstat`](fstat.md): Implements file system status operations.
- [`std.os.os`](os.md): Provides functions to access operating-system dependent functionality, including file system operations.
- [`std.os.pathlike`](pathlike.md): Implements the `PathLike` trait.
- [`std.os.process`](process.md): Implements os methods for dealing with processes.
