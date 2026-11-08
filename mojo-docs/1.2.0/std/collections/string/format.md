# `std.collections.string.format`

String formatting utilities for Mojo.

This module provides string formatting functionality similar to Python's
`str.format()` method. The `format()` method (available on the
[`String`](../../../std/collections/string/string.md#stringformat) and
[`StringSpan`](../../../std/collections/string/string_span.md#stringspanformat)
types) takes the current string as a template (or "format string"), which can
contain literal text and/or replacement fields delimited by curly braces (`{}`).
The replacement fields are replaced with the values of the arguments.

Replacement fields can mapped to the arguments in one of two ways:

- Automatic indexing by argument position:

  ```mojo
  var s = "{} is {}".format("Mojo", "🔥")
  ```

- Manual indexing by argument position:

  ```mojo
  var s = "{1} is {0}".format("hot", "🔥")
  ```

The replacement fields can also contain the `!r` or `!s` conversion flags, to
indicate whether the argument should be formatted using `repr()` or `String()`,
respectively:

```mojo
var s = "{!r}".format("test")
```

Note that the following features from Python's `str.format()` are
**not yet supported**:

- Named arguments (for example `"{name} is {adjective}"`).
- Accessing the attributes of an argument value (for example, `"{0.name}"`.
- Accessing an indexed value from the argument (for example, `"{1[0]}"`).
- Format specifiers for controlling output format (width, precision, and so on).

Examples:

```mojo
# Basic formatting
var s1 = "Hello {0}!".format("World")  # Hello World!

# Multiple arguments
var s2 = "{0} plus {1} equals {2}".format(1, 2, 3)  # 1 plus 2 equals 3

# Conversion flags
var s4 = "{!r}".format("test")  # "'test'"
```

This module has no public API; its functionality is available through the
[`String.format()`](../../../std/collections/string/string.md#stringformat) and
[`StringSpan.format()`](../../../std/collections/string/string_span.md#stringspanformat)
methods.
