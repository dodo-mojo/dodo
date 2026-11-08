# `std.sys.compile`

Implements functions that return compile-time information.

## Aliases

### `OptimizationLevel`

```mojo
comptime OptimizationLevel = _OptimizationLevel()
```

Represents the optimization level used during compilation.

### `DebugLevel`

```mojo
comptime DebugLevel = _DebugLevel()
```

Represents the debug level used during compilation.

### `SanitizeAddress`

```mojo
comptime SanitizeAddress = is_defined[StringSpan("__SANITIZE_ADDRESS")]() and (get_defined_int[StringSpan("__SANITIZE_ADDRESS")]() == Int(1))
```

True if address sanitizer is enabled at compile-time.

## Functions

### `codegen_unreachable`

```mojo
def codegen_unreachable[cond: Bool, msg: StringSpan[ImmStaticOrigin], *extra: StringSpan[ImmStaticOrigin]]()
```

Compilation fails if cond is True and the caller of the function is being generated as runtime code.

Parameters:

- `cond`: The bool value for reachability.
- `msg`: The message to display on failure.
- `*extra`: Additional messages to concatenate to msg.
