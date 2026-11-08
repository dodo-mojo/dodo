# `std.collections.string`

Provides comprehensive Unicode string functionality.

Core features:

- Unicode support with UTF-8 encoding
- Efficient string slicing and views
- String formatting and interpolation
- Memory-safe string operations
- Unicode case conversion
- Unicode property lookups and validation

Key components:

- [`String`](../../../std/collections/string/string.md#string):
  Mutable and owning string

  - Uses a smart three-mode allocation strategy: static memory
  references for string literals, small string optimization (SSO) for strings
  ≤23 bytes (stored directly within the `String` object with zero allocation
  cost), and reference-counted heap allocation for larger strings. This design
  makes the vast majority of real-world strings extremely fast.

  - Owns its data and manages memory automatically when heap-allocated.

  - Mutable and grows dynamically as needed.

- [`StringSpan`](../../../std/collections/string/string_span.md#stringspan):
  Non-owning string view

  - Performs zero heap allocations: stores only a pointer and length
  that reference existing string data owned by another object.

  - Does not own the data pointed to, so it can't outlive the data it
  references.

- [`StaticString`](../../../std/collections/string/string_span.md#staticstring):
  Compile-time constant (immutable) string reference

  - Performs zero heap allocations: stores a pointer and length to a
  compile-time constant or static program memory.

  - References data with a static lifetime that exists for the entire program
  duration, unlike `StringSpan` which can reference temporary data.

- [`Codepoint`](../../../std/collections/string/codepoint.md#codepoint):
  Unicode codepoint representation and operations

  - Represents a single Unicode codepoint as a 32-bit value.

  - Enables iteration over string contents at the Unicode codepoint level
  rather than byte level for proper Unicode text processing.

- [`format`](../../../std/collections/string/format.md): Built-in string
formatting and interpolation utilities.

:::note Note

String stores data using UTF-8, and all operations (unless clearly noted) are intended to
be fully Unicode compliant and maintain correct UTF-8 encoded data.
A handful of operations are known to not be Unicode / UTF-8 compliant yet, but will be
fixed as time permits.

:::

## Modules

- [`std.collections.string.codepoint`](codepoint.md): Unicode codepoint handling.
- [`std.collections.string.format`](format.md): String formatting utilities for Mojo.
- [`std.collections.string.iterators`](iterators.md): Implements the iterators and related utilities for efficient string operations.
- [`std.collections.string.string`](string.md): Implements the core `String` type and related utilities.
- [`std.collections.string.string_span`](string_span.md): Implements the `StringSpan` type and related utilities for efficient string operations.
