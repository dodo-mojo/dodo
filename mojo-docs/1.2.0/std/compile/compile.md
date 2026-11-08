# `std.compile.compile`

Provides utilities for compiling and inspecting Mojo code.

This module contains functionality for compiling Mojo functions and examining
their assembly, LLVM IR, or object code output. It is particularly useful for
kernel engineers who want to inspect the low-level implementation details of
specific functions without dealing with entire files or manual invocation of
compilation tools.

Key features:
- Compile individual functions to assembly, LLVM IR, or object code
- Get linkage names and module information
- Inspect number of captures and other function metadata
- Write compilation output to files
- Control compilation options and targets

Example:
```mojo
from std.compile import compile_info

def my_func(x: Int) -> Int:
    return x

# Get assembly for the function
info = compile_info[my_func]()
print(info)
```

## Structs

### `CompiledFunctionInfo`

```mojo
struct CompiledFunctionInfo[func_type: TrivialRegisterPassable, func: func_type, target: CompilationTarget]
```

Contains compilation information and results for a function.

Stores assembly/IR code, function metadata, and error information from
compiling a function.

Attributes:
    populate: Function to populate captures

Parameters:

- `func_type`: Type of the function being compiled.
- `func`: The function being compiled.
- `target`: The target architecture to compile for.

Fields:

- `asm` (`StaticString`): Generated assembly/IR code from the compilation process.
- `function_name` (`StaticString`): Mangled name of the compiled function, used for symbol resolution.
- `module_name` (`StaticString`): Name of the module containing the compiled function.
- `num_captures` (`Int`): Number of variables captured by the function closure.
- `capture_sizes` (`Pointer[UInt64, ImmUntrackedOrigin]`): Pointer to the sizes of the variables captured by the function closure.
- `emission_kind` (`StaticString`): The emission kind the object was emitted to.

Implemented traits: `AnyType`, `Copyable`, `Deinitable`, `ImplicitlyCopyable`, `Movable`, `RegisterPassable`, `TrivialRegisterPassable`, `Writable`

Aliases:

- `populate = rebind[def(Pointer[NoneType, MutAnyOrigin]) capturing thin -> None](#kgen.compile_offload_closure<*"target._mlir_value`", #kgen.param.decl.ref<"func"> : !kgen.param<:trait<@std::@builtin::@value::@RegisterPassable, @std::@builtin::@value::@TrivialRegisterPassable, @std::@traits::@anytype::@AnyType, @std::@traits::@copyable::@Copyable, @std::@traits::@copyable::@ImplicitlyCopyable, @std::@traits::@deinitable::@Deinitable, @std::@traits::@movable::@Movable> func_type>>.populate)`: Function pointer to populate captured variables in the function closure.

#### `CompiledFunctionInfo.__contains__`

```mojo
def __contains__(self, content: String) -> Bool
```

Checks if content exists in the assembly/IR.

Args:

- `content`: String to search for.

Returns: True if content is found, False otherwise.

#### `CompiledFunctionInfo.write_to`

```mojo
def write_to(self, mut writer: T)
```

Writes the assembly/IR to a writer.

Args:

- `writer`: Writer object to write the assembly to.

#### `CompiledFunctionInfo.write_text`

```mojo
def write_text[path_like: PathLike](self, path: path_like) raises
```

Writes the assembly/IR to a file.

Parameters:

- `path_like`: Type that implements the `PathLike` interface for file path representation.

Args:

- `path`: Path to write the file to.

Raises: If file writing operations fail.

## Functions

### `compile_info`

```mojo
def compile_info[func_type: TrivialRegisterPassable, //, func: func_type, /, *, emission_kind: StringSpan[ImmStaticOrigin] = StringSpan("asm"), target: CompilationTarget = CompilationTarget(), compile_options: StringSpan[ImmStaticOrigin] = CompilationTarget.default_compile_options(), link_options: StringSpan[ImmStaticOrigin] = StringSpan("")]() -> CompiledFunctionInfo[func_type, func, target]
```

Compiles a function and returns detailed compilation information.

This function takes a Mojo function and compiles it, providing access to the
generated assembly code, linkage information, and other compilation
artifacts. It can be used for inspection, debugging, and low-level
optimization.

Example:

```mojo
from std.compile import compile_info

def my_func(x: Int) -> Int:
    return x

info = compile_info[my_func]()
print(info)  # Print assembly
```

Note:
The compilation is always performed, even if the function is not used.
For performance-critical code, consider caching the compilation results.

Parameters:

- `func_type`: Type of the function to compile. Must be a trivially-copyable register type.
- `func`: The function to compile. Must match the specified func_type.
- `emission_kind`: The desired output format. Valid options are: - "asm": Assembly code (default). - "llvm": Unoptimized LLVM IR. - "llvm-opt": Optimized LLVM IR. - "object": Object code.
- `target`: The target architecture to compile for. Defaults to current architecture.
- `compile_options`: Additional compiler flags and options as a string.
- `link_options`: Additional linking flags and options as a string.

Returns: A `CompiledFunctionInfo` struct containing: - asm: The generated code in the requested format - linkage_name: The mangled function name for linking - module_hash: A unique hash of the compiled module - num_captures: Number of captured variables - error: Any error message (empty if successful) - failed: Boolean indicating if compilation failed
