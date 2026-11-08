# `std.ffi`

Foreign function interface (FFI) for calling C code and loading libraries.

This module provides tools for interfacing Mojo with C libraries and other
foreign code. It includes:

- **C type aliases**: `c_int`, `c_char`, `c_long`, `c_size_t`, etc. for
  portable type definitions that match C's type sizes on each platform.
- **Dynamic library loading**: `OwnedDLHandle` for loading shared libraries
  at runtime and calling their functions.
- **External function calls**: `external_call()` for calling C functions
  by name with compile-time resolution.
- **String interop**: `CStringSpan` for working with null-terminated C strings.

Example:

```mojo
from std.ffi import c_int, external_call

def get_random() -> c_int:
    return external_call["rand", c_int]()
```

For loading dynamic libraries:

```mojo
from std.ffi import OwnedDLHandle

def main() raises:
    var lib = OwnedDLHandle("libm.so")
    var sqrt = lib.get_function[Float64]("sqrt")
    print(sqrt(4.0))  # 2.0
```

## Modules

- [`std.ffi.cstring`](cstring.md): Implements C string interoperability utilities.
- [`std.ffi.unsafe_union`](unsafe_union.md): Defines an untagged union type for C FFI interoperability.

## Aliases

### `c_char`

```mojo
comptime c_char = Scalar[_c_char_dtype()]
```

C `char` type.

Plain `char`'s signedness is implementation-defined and differs by ABI.
Use `c_uchar` for a field explicitly declared `unsigned char`, which is always
unsigned.

### `c_uchar`

```mojo
comptime c_uchar = UInt8
```

C `unsigned char` type.

### `c_int`

```mojo
comptime c_int = Int32
```

C `int` type.

The C `int` type is typically a signed 32-bit integer on commonly used targets
today.

### `c_uint`

```mojo
comptime c_uint = UInt32
```

C `unsigned int` type.

### `c_short`

```mojo
comptime c_short = Int16
```

C `short` type.

### `c_ushort`

```mojo
comptime c_ushort = UInt16
```

C `unsigned short` type.

### `c_long`

```mojo
comptime c_long = Scalar[_c_long_dtype()]
```

C `long` type.

The C `long` type is typically a signed 64-bit integer on macOS and Linux, and a
32-bit integer on Windows.

### `c_long_long`

```mojo
comptime c_long_long = Scalar[_c_long_long_dtype()]
```

C `long long` type.

The C `long long` type is typically a signed 64-bit integer on commonly used
targets today.

### `c_ulong`

```mojo
comptime c_ulong = Scalar[_c_long_dtype[True]()]
```

C `unsigned long` type.

The C `unsigned long` type is typically a 64-bit integer on commonly used
targets today.

### `c_ulong_long`

```mojo
comptime c_ulong_long = Scalar[_c_long_long_dtype[True]()]
```

C `unsigned long long` type.

The C `unsigned long long` type is typically a 64-bit integer on commonly used
targets today.

### `c_size_t`

```mojo
comptime c_size_t = UInt
```

C `size_t` type.

### `c_ssize_t`

```mojo
comptime c_ssize_t = Int
```

C `ssize_t` type.

### `c_float`

```mojo
comptime c_float = Float32
```

C `float` type.

### `c_double`

```mojo
comptime c_double = Float64
```

C `double` type.

### `c_pid_t`

```mojo
comptime c_pid_t = Int
```

C `pid_t` type.

### `MAX_PATH`

```mojo
comptime MAX_PATH = _get_max_path()
```

Maximum path length for the current platform.

### `DEFAULT_RTLD`

```mojo
comptime DEFAULT_RTLD = (Int(2) | Int(256) if CompilationTarget.is_linux() else Int(8))
```

Default runtime linker flags for dynamic library loading.

## Structs

### `RTLD`

```mojo
struct RTLD
```

Enumeration of the RTLD flags used during dynamic library loading.

Implemented traits: `AnyType`, `Deinitable`, `Movable`

Aliases:

- `LAZY = 1`: Load library lazily (defer function resolution until needed).
- `NOW = 2`: Load library immediately (resolve all symbols on load).
- `LOCAL = Int(0) if CompilationTarget.is_linux() else Int(4)`: Make symbols not available for symbol resolution of subsequently loaded libraries.
- `GLOBAL = Int(256) if CompilationTarget.is_linux() else Int(8)`: Make symbols available for symbol resolution of subsequently loaded libraries.
- `NODELETE = Int(4096) if CompilationTarget.is_linux() else Int(128)`: Do not delete the library when the process exits.

### `OwnedDLHandle`

```mojo
struct OwnedDLHandle
```

Represents an owned handle to a dynamically linked library with RAII semantics.

`OwnedDLHandle` owns the library handle and automatically calls `dlclose()`
when the object is destroyed. This prevents resource leaks and double-free
bugs.

Example usage:
```mojo
from std.ffi import OwnedDLHandle

def main() raises:
    var lib = OwnedDLHandle("libm.so")
    var sqrt = lib.get_function[Float64]("sqrt")
    print(sqrt(4.0))  # Prints: 2.0
    # Library automatically closed when lib goes out of scope
```

Implemented traits: `AnyType`, `Boolable`, `Deinitable`, `Movable`

#### `OwnedDLHandle.__init__`

```mojo
def __init__(out self, flags: Int = Int(Int(256) if CompilationTarget.is_linux() else Int(8) or 2)) raises
```

Initialize an owned handle to all global symbols in the current process.

Args:

- `flags`: The flags to load the dynamic library.

Raises: If `dlopen(nullptr, flags)` fails.

```mojo
def __init__[PathLike: PathLike, //](out self, path: PathLike, flags: Int = Int(Int(256) if CompilationTarget.is_linux() else Int(8) or 2)) raises
```

Initialize an OwnedDLHandle by loading the dynamic library at the given path.

Parameters:

- `PathLike`: The type conforming to the `os.PathLike` trait.

Args:

- `path`: The path to the dynamic library file.
- `flags`: The flags to load the dynamic library.

Raises: If `dlopen(path, flags)` fails.

#### `OwnedDLHandle.__deinit__`

```mojo
def __deinit__(deinit self)
```

Unload the associated dynamic library.

This automatically calls `dlclose()` on the underlying library handle.

#### `OwnedDLHandle.__bool__`

```mojo
def __bool__(self) -> Bool
```

Checks if the handle is valid.

Returns: `True` if the handle is not null and `False` otherwise.

#### `OwnedDLHandle.borrow`

```mojo
def borrow(self) -> _DLHandle
```

Returns a non-owning reference to this handle.

The returned `_DLHandle` does not own the library and should not be
used after this `OwnedDLHandle` is destroyed.

Returns: A non-owning reference to the library handle.

#### `OwnedDLHandle.check_symbol`

```mojo
def check_symbol(self, var name: String) -> Bool
```

Check that the symbol exists in the dynamic library.

Args:

- `name`: The symbol to check.

Returns: `True` if the symbol exists.

#### `OwnedDLHandle.get_function`

```mojo
def get_function[return_type: RegisterPassable = NoneType](ref self, var name: String) raises -> _DLCallable[return_type, origin_of(self)]
```

Returns a callable for the function with the given name in the dynamic library.

The returned callable carries an immutable borrow of `self`, so the
library cannot be `dlclose`d until after the callable is invoked.
This prevents the dangling-function-pointer crash that would occur
if the raw function pointer were returned directly and ASAP
destruction ran `dlclose` between `dlsym` and the call.

Argument forwarding uses the C ABI (see the `_DLCallable` notes).

Missing symbols raise `Error("symbol not found: ...")` rather than
aborting the process, so callers can probe for optional symbols.

Example:
```mojo
from std.ffi import OwnedDLHandle

var lib = OwnedDLHandle("libm.so")
var sqrt = lib.get_function[Float64]("sqrt")
print(sqrt(4.0))  # 2.0
```

Parameters:

- `return_type`: The return type of the underlying C function. Defaults to `NoneType` for void-returning functions.

Args:

- `name`: The name of the function to get the handle for.

Returns: A callable proxy that forwards to the resolved function and keeps the owning handle alive for the duration of each call.

Raises: If the symbol cannot be resolved in the dynamic library.

#### `OwnedDLHandle.get_symbol`

```mojo
def get_symbol[mut: Bool, origin: Origin[mut=mut], //, result_type: AnyType](ref[origin] self, name: StringSpan) -> Optional[Pointer[result_type, origin]]
```

Returns a pointer to the symbol with the given name in the dynamic library, or `None` if the symbol is not found.

The returned pointer borrows `self`, so the library cannot be
`dlclose`d while the pointer is live. Its mutability follows the
handle's: a symbol resolved through an immutable handle is read-only.

Example:
```mojo
from std.ffi import OwnedDLHandle, c_int

var lib = OwnedDLHandle("libcounters.so")
var counter = lib.get_symbol[c_int]("live_connections")
if case .Some(ptr) = counter:
    print(ptr[])
```

Parameters:

- `mut`: The mutability of self.
- `origin`: The origin of self.
- `result_type`: The type of the symbol to return.

Args:

- `name`: The name of the symbol to get the handle for.

Returns: An optional pointer to the symbol, or `None` if not found.

```mojo
def get_symbol[mut: Bool, origin: Origin[mut=mut], //, result_type: AnyType](ref[origin] self, *, cstr_name: CStringSpan) -> Optional[Pointer[result_type, origin]]
```

Returns a pointer to the symbol with the given name in the dynamic library, or `None` if the symbol is not found.

See the `name` overload for how the returned pointer's origin and
mutability relate to the handle.

Parameters:

- `mut`: The mutability of self.
- `origin`: The origin of self.
- `result_type`: The type of the symbol to return.

Args:

- `cstr_name`: The name of the symbol to get the handle for.

Returns: An optional pointer to the symbol, or `None` if not found.

#### `OwnedDLHandle.call`

```mojo
def call[name: StringSpan[ImmStaticOrigin], return_type: RegisterPassable = NoneType, *T: AnyType = *?](self, *args: *T.values) -> return_type
```

Call a function with any amount of arguments.

Parameters:

- `name`: The name of the function.
- `return_type`: The return type of the function.
- `*T`: The types of `args`.

Args:

- `*args`: The arguments.

Returns: The result.

## Functions

### `external_call`

```mojo
def external_call[callee: StringSpan[ImmStaticOrigin], return_type: RegisterPassable, *types: AnyType, *, num_fixed_args: Optional[Int] = None](*args: *types.values) -> return_type
```

Calls an external function.

By default every argument is a fixed argument of a non-variadic callee.
Pass `num_fixed_args` to call a C variadic function such as `open()` or
`snprintf()`, giving how many of the first arguments are fixed arguments of
the callee; the arguments after those are passed as variadic arguments.
This matters because ABIs such as AAPCS on ARM64 macOS pass variadic
arguments differently from fixed ones.

Examples:

```mojo
from std.ffi import c_char, c_int, external_call

# int open(const char *path, int oflag, ...);
var path_str = path
var fd = external_call["open", c_int, num_fixed_args=2](
    path_str.as_c_string_span(), c_int(flags), c_int(0o666)
)
```

Constraints: `num_fixed_args` must not be negative.

Parameters:

- `callee`: The name of the external function.
- `return_type`: The return type.
- `*types`: The argument types.
- `num_fixed_args`: The number of fixed arguments of a C variadic callee, or `None` for a non-variadic callee. A count of `0` declares a callee whose every argument is variadic, which `None` cannot express. An argument pack is flattened into one argument per element, so the count must cover the elements rather than the pack, and the fixed arguments must precede any pack.

Args:

- `*args`: The arguments to pass to the external function.

Returns: The external call result.
