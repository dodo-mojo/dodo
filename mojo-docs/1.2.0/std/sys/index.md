# `std.sys`

System runtime: I/O, hardware info, intrinsics, compile-time utils.

The `sys` package provides low-level access to system functionality and runtime
information. It includes tools for interacting with the operating system,
querying hardware capabilities, and accessing compiler intrinsics. This package
bridges Mojo code and the underlying system environment.

Use this package for system-level programming, hardware-specific optimizations,
or when you need direct access to platform capabilities and compiler features.
For foreign function interface (FFI) functionality, use the `ffi` module.

## Modules

- [`std.sys.arg`](arg.md): Implements functions and variables for interacting with execution and system environment.
- [`std.sys.compile`](compile.md): Implements functions that return compile-time information.
- [`std.sys.debug`](debug.md): This module includes the debug hook functions.
- [`std.sys.defines`](defines.md): Implements functions for retrieving compile-time defines.
- [`std.sys.info`](info.md): Implements methods for querying the host target info.
- [`std.sys.intrinsics`](intrinsics.md): Defines intrinsics.
- [`std.sys.terminate`](terminate.md): This module includes the exit functions.
