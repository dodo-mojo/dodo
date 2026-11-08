# `std.io`

Core I/O operations: console input/output, file handling, writing traits.

The `io` package provides fundamental input/output functionality for reading
from and writing to various sources including the console, files, and custom
streams. It defines the core traits for the I/O system (`Writer` and
`Writable`) that enable formatted output across different backends, along with
concrete implementations for file operations and standard streams.

Use this package for console interaction, file operations, implementing custom
output formatting for your types, or building I/O abstractions. Most programs
use `print()` and file operations from this package, while library authors
implement `Writable` to enable their types to work with any `Writer`.

## Modules

- [`std.io.file`](file.md): Provides APIs to read and write files.
- [`std.io.file_descriptor`](file_descriptor.md): Higher level abstraction for file stream.
- [`std.io.io`](io.md): Provides utilities for working with input/output.
- [`std.io.write`](write.md): Implements I/O write interfaces.
