# `std.builtin.error`

Implements the Error class.

These are Mojo built-ins, so you don't need to import them.

## Structs

### `StackTrace`

```mojo
struct StackTrace
```

Holds a stack trace captured at a specific location.

A `StackTrace` instance always contains a valid stack trace. Use the
`collect_if_enabled()` static method to conditionally capture a stack
trace, which returns `None` if stack trace collection is disabled or
unavailable.

Copying a `StackTrace` shares the captured trace instead of duplicating it,
so copies cost a reference count increment.

Implemented traits: `AnyType`, `Copyable`, `Deinitable`, `ImplicitlyCopyable`, `Movable`, `Writable`

#### `StackTrace.__init__`

```mojo
def __init__(out self, *, unsafe_from_raw_pointer: Pointer[UInt8, MutUntrackedOrigin])
```

Construct a StackTrace from a raw pointer to a C string.

Safety:
The pointer must be valid and point to a null-terminated string.
The caller transfers ownership to this StackTrace.

Args:

- `unsafe_from_raw_pointer`: A pointer to a null-terminated C string containing the stack trace. The StackTrace takes ownership.

#### `StackTrace.collect_if_enabled`

```mojo
def collect_if_enabled(depth: Int = Int(0)) -> Optional[Self]
```

Collect a stack trace if enabled by configuration.

This method checks the `max-debug.stack-trace-on-error` Config key
(settable via the `MODULAR_DEBUG=stack-trace-on-error` environment
variable) and collects a stack trace only if it is enabled. Returns
`None` if stack traces are disabled, on GPU, or if collection fails.

Args:

- `depth`: The maximum depth of the stack trace to collect. When `depth` is zero, the entire stack trace is collected. When `depth` is negative, no stack trace is collected.

Returns: An `Optional[StackTrace]` containing the stack trace if collection succeeded, or `None` if disabled or unavailable.

#### `StackTrace.write_to`

```mojo
def write_to(self, mut writer: T)
```

Writes the StackTrace to the provided Writer.

Args:

- `writer`: The object to write to.

#### `StackTrace.write_repr_to`

```mojo
def write_repr_to(self, mut writer: T)
```

Writes the StackTrace to the provided Writer in repr format.

Args:

- `writer`: The object to write to.

### `Error`

```mojo
struct Error
```

This type represents an Error.

An `Error` is cheap to copy: the message and the optional stack trace are
both reference counted, so re-raising a caught error with `raise e` costs a
reference count increment. Transfer with `raise e^` to avoid even that.

Implemented traits: `AnyType`, `Copyable`, `Deinitable`, `ImplicitlyCopyable`, `Movable`, `Writable`

#### `Error.__init__`

```mojo
def __init__(out self, var value: String, *, depth: Int = Int(-1))
```

Construct an Error object with a given String.

Args:

- `value`: The error message.
- `depth`: The depth of the stack trace to collect. When negative, no stack trace is collected.

```mojo
def __init__(out self, value: StringLiteral)
```

Construct an Error object with a given string literal.

Args:

- `value`: The error message.

```mojo
def __init__[*Ts: Writable](out self, *args: *Ts.values)
```

Construct an Error by concatenating a sequence of Writable arguments.

Parameters:

- `*Ts`: The types of the arguments to format. Each type must be satisfy `Writable`.

Args:

- `*args`: A sequence of Writable arguments.

#### `Error.write_to`

```mojo
def write_to(self, mut writer: T)
```

Formats this error to the provided Writer.

Args:

- `writer`: The object to write to.

#### `Error.write_repr_to`

```mojo
def write_repr_to(self, mut writer: T)
```

Formats this error to the provided Writer.

Args:

- `writer`: The object to write to.

#### `Error.get_stack_trace`

```mojo
def get_stack_trace(self) -> Optional[String]
```

Returns the stack trace of the error, if available.

Returns: An `Optional[String]` containing the stack trace if one was collected, or `None` if stack trace collection was disabled or unavailable.
