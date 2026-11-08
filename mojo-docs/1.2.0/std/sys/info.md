# `std.sys.info`

Implements methods for querying the host target info.

You can import these APIs from the `sys` package. For example:

```mojo
from std.sys import CompilationTarget

print(CompilationTarget.is_x86())
```

## Aliases

### `platform_type_map`

```mojo
comptime platform_type_map[Trait: AnyTrait[AnyType] = AnyType, *, linux: AnyType = _UnsupportedTarget[StringSpan("linux")], macos: AnyType = _UnsupportedTarget[StringSpan("macos")]] = linux if CompilationTarget.is_linux() else macos if CompilationTarget.is_macos() else _UnsupportedTarget[CompilationTarget._os()](Trait)
```

Selects a type for the current compilation target, the type-level counterpart of `platform_map`.

## Structs

### `CompilationTarget`

```mojo
struct CompilationTarget[_mlir_value: __mlir_type.`!kgen.target` = _current_target(), //]
```

A struct that provides information about a target architecture.

This struct encapsulates various methods to query target-specific
information such as architecture features, OS details, endianness, and
memory characteristics.

Parameters:

- `_mlir_value`: The raw target architecture to query. Defaults to the current target.

Implemented traits: `AnyType`, `Copyable`, `Deinitable`, `ImplicitlyCopyable`, `Movable`, `RegisterPassable`, `TrivialRegisterPassable`

Aliases:

- `current = CompilationTarget`: Get the current compilation target.
- `stdlib_plugin = TargetPluginSelector[CompilationTarget(), DefaultPlugin].selected.HookFor[_mlir_value, CompilationTarget()]`: The stdlib plugin to use for this target.

#### `CompilationTarget.__init__`

```mojo
def __init__() -> Self
```

Initialize a `CompilationTarget` with the default target.

#### `CompilationTarget.default_accelerator`

```mojo
def default_accelerator() -> CompilationTarget
```

Get the accelerator target.

This value is derived from the `--target-accelerator` command line flag.

Constraints: An accelerator target must be configured.

Returns: A value representing the current accelerator target.

#### `CompilationTarget.unsupported_target_error`

```mojo
def unsupported_target_error[*, operation: Optional[String] = None, note: Optional[String] = None]() -> Never
```

Produces a constraint failure when called indicating that some operation is not supported by the current compilation target.

Parameters:

- `operation`: Optional name of the operation that is not supported. Should be a function name or short description.
- `note`: Optional additional note to print.

#### `CompilationTarget.is_triple`

```mojo
def is_triple[name: StringLiteral[name.value]]() -> Bool
```

Returns True if the triple of this target matches the input and False otherwise.

Parameters:

- `name`: The name of the triple value.

Returns: True if the triple matches and False otherwise.

#### `CompilationTarget.default_compile_options`

```mojo
def default_compile_options() -> StaticString
```

Returns the default compile options for the compilation target.

Returns: The string of default compile options for the compilation target.

#### `CompilationTarget.has_sse4`

```mojo
def has_sse4() -> Bool
```

Checks if the target supports SSE4 instructions.

Returns: True if the target supports SSE4, False otherwise.

#### `CompilationTarget.has_avx`

```mojo
def has_avx() -> Bool
```

Returns True if the host system has AVX, otherwise returns False.

Returns: True if the host system has AVX, otherwise returns False.

#### `CompilationTarget.has_avx2`

```mojo
def has_avx2() -> Bool
```

Returns True if the host system has AVX2, otherwise returns False.

Returns: True if the host system has AVX2, otherwise returns False.

#### `CompilationTarget.has_avx512f`

```mojo
def has_avx512f() -> Bool
```

Returns True if the host system has AVX512, otherwise returns False.

Returns: True if the host system has AVX512, otherwise returns False.

#### `CompilationTarget.has_intel_amx`

```mojo
def has_intel_amx() -> Bool
```

Returns True if the host system has Intel AMX support, otherwise returns False.

Returns: True if the host system has Intel AMX and False otherwise.

#### `CompilationTarget.has_fma`

```mojo
def has_fma() -> Bool
```

Returns True if the target has FMA (Fused Multiply-Add) support, otherwise returns False.

Returns: True if the target has FMA support, otherwise returns False.

#### `CompilationTarget.has_vnni`

```mojo
def has_vnni() -> Bool
```

Returns True if the target has avx512_vnni, otherwise returns False.

Returns: True if the target has avx512_vnni, otherwise returns False.

#### `CompilationTarget.has_neon`

```mojo
def has_neon() -> Bool
```

Returns True if the target has Neon support, otherwise returns False.

Returns: True if the target support the Neon instruction set.

#### `CompilationTarget.has_neon_int8_dotprod`

```mojo
def has_neon_int8_dotprod() -> Bool
```

Returns True if the target has the Neon int8 dot product extension, otherwise returns False.

Returns: True if the target support the Neon int8 dot product extension and False otherwise.

#### `CompilationTarget.has_neon_int8_matmul`

```mojo
def has_neon_int8_matmul() -> Bool
```

Returns True if the target has the Neon int8 matrix multiplication extension (I8MM), otherwise returns False.

Returns: True if the target support the Neon int8 matrix multiplication extension (I8MM) and False otherwise.

#### `CompilationTarget.has_riscv_extension`

```mojo
def has_riscv_extension[name: StringSpan[ImmStaticOrigin]]() -> Bool
```

Returns True if the target implements a RISC-V ISA extension.

RISC-V has too many extensions to give each one a predicate, so this
takes the extension name directly. Use the lowercase name LLVM gives the
extension, which is the ISA-string spelling without the `rv32`/`rv64`
prefix and without any version: `"m"`, `"a"`, `"f"`, `"d"`, `"c"`,
`"v"`, `"zba"`, `"zicsr"`, and so on. `"g"` is not an extension; query
its members individually.

An extension implied by another one counts as present, so a target built
with `d` also reports `f`, and one built with `a` also reports `zaamo`
and `zalrsc`.

Example:

```mojo
from std.sys import CompilationTarget

def triple(x: Int32) -> Int32:
    comptime if CompilationTarget.has_riscv_extension["m"]():
        return x * 3
    return (x << 1) + x
```

Parameters:

- `name`: The extension to check for.

Returns: True if the target is RISC-V and implements the extension, False otherwise. Always False on a non-RISC-V target.

#### `CompilationTarget.is_x86`

```mojo
def is_x86() -> Bool
```

Checks if the target is an x86 architecture.

This is an architecture check, not an instruction-set check: use
`has_sse4()`, `has_avx2()`, and friends to gate code on a specific
extension.

Returns: True if the target is 32- or 64-bit x86, False otherwise.

#### `CompilationTarget.is_arm`

```mojo
def is_arm() -> Bool
```

Checks if the target is an ARM architecture.

This is an architecture check, not an instruction-set check: use
`has_neon()` and friends to gate code on a specific extension.

Returns: True if the target is 32- or 64-bit ARM, False otherwise.

#### `CompilationTarget.is_riscv`

```mojo
def is_riscv() -> Bool
```

Checks if the target is a RISC-V architecture.

This is an architecture check, not an instruction-set check: use
`has_riscv_extension()` to gate code on a specific extension.

Returns: True if the target is 32- or 64-bit RISC-V, False otherwise.

#### `CompilationTarget.is_rv32`

```mojo
def is_rv32() -> Bool
```

Checks if the target is a 32-bit RISC-V architecture.

Returns: True if the target is 32-bit RISC-V, False otherwise.

#### `CompilationTarget.is_rv64`

```mojo
def is_rv64() -> Bool
```

Checks if the target is a 64-bit RISC-V architecture.

Returns: True if the target is 64-bit RISC-V, False otherwise.

#### `CompilationTarget.is_apple_m1`

```mojo
def is_apple_m1() -> Bool
```

Check if the target is an Apple M1 system.

Returns: True if the host system is an Apple M1, False otherwise.

#### `CompilationTarget.is_apple_m2`

```mojo
def is_apple_m2() -> Bool
```

Check if the target is an Apple M2 system.

Returns: True if the host system is an Apple M2, False otherwise.

#### `CompilationTarget.is_apple_m3`

```mojo
def is_apple_m3() -> Bool
```

Check if the target is an Apple M3 system.

Returns: True if the host system is an Apple M3, False otherwise.

#### `CompilationTarget.is_apple_m4`

```mojo
def is_apple_m4() -> Bool
```

Check if the target is an Apple M4 system.

Returns: True if the host system is an Apple M4, False otherwise.

#### `CompilationTarget.is_apple_m5`

```mojo
def is_apple_m5() -> Bool
```

Check if the target is an Apple M5 system.

Returns: True if the host system is an Apple M5, False otherwise.

#### `CompilationTarget.is_apple_silicon`

```mojo
def is_apple_silicon() -> Bool
```

Check if the host system is an Apple Silicon with AMX support.

Returns: True if the host system is an Apple Silicon with AMX support, and False otherwise.

#### `CompilationTarget.is_neoverse_n1`

```mojo
def is_neoverse_n1() -> Bool
```

Returns True if the host system is a Neoverse N1 system, otherwise returns False.

Returns: True if the host system is a Neoverse N1 system and False otherwise.

#### `CompilationTarget.is_accelerator`

```mojo
def is_accelerator(self) -> Bool
```

Returns True if the target triple is an accelerator, and False otherwise.

Returns: True if the triple target is an accelerator and False otherwise.

#### `CompilationTarget.is_gpu`

```mojo
def is_gpu(self) -> Bool
```

Returns True if the target triple is a GPU and False otherwise.

Returns: True if the triple target is a GPU and False otherwise.

#### `CompilationTarget.is_nvidia_gpu`

```mojo
def is_nvidia_gpu[subarch: StringSpan[ImmStaticOrigin] = StringSpan("<any>")](self) -> Bool
```

Returns True if the target triple is `nvptx64-nvidia-cuda`, and optionally if the target is also the specified sub-architecture, and False otherwise.

Parameters:

- `subarch`: The subarchitecture (e.g. sm_80) (defaults to any).

Returns: True if the triple target is cuda and False otherwise.

#### `CompilationTarget.is_amd_gpu`

```mojo
def is_amd_gpu[subarch: StringSpan[ImmStaticOrigin] = StringSpan("<any>")](self) -> Bool
```

Returns True if the target triple is an AMD GPU triple, and optionally if the target is also the specified sub-architecture, and False otherwise.

Parameters:

- `subarch`: The AMD GPU sub-architecture to check for (e.g., "gfx90a") (defaults to any).

Returns: True if the triple target is amdgpu and False otherwise.

#### `CompilationTarget.is_apple_gpu`

```mojo
def is_apple_gpu[subarch: StringSpan[ImmStaticOrigin] = StringSpan("<any>")](self) -> Bool
```

Returns True if the target triple is for Apple GPU (Metal, `air64-apple-macosx`), and optionally if the target is alos the specified sub-architecture, and False otherwise.

Parameters:

- `subarch`: The subarchitecture (e.g. sm_80) (defaults to any).

Returns: True if the triple target is Apple GPU and False otherwise.

#### `CompilationTarget.is_linux`

```mojo
def is_linux() -> Bool
```

Returns True if the host operating system is Linux.

Returns: True if the host operating system is Linux and False otherwise.

#### `CompilationTarget.is_macos`

```mojo
def is_macos() -> Bool
```

Returns True if the host operating system is macOS.

Returns: True if the host operating system is macOS and False otherwise.

### `Endian`

```mojo
struct Endian
```

A byte order: the order in which a multi-byte value's bytes are stored.

`big` stores the most significant byte first, which is also the network
byte order, and `little` stores the least significant byte first.
`Endian.native()` returns whichever of the two the compilation target
uses, so data in that order needs no conversion.

Example:

```mojo
var bytes = UInt16(8080).as_bytes[endian=.big]()  # [0x1F, 0x90]
```

Implemented traits: `AnyType`, `Copyable`, `Deinitable`, `EnumLike`, `Equatable`, `ImplicitlyCopyable`, `Movable`, `RegisterPassable`, `TrivialRegisterPassable`, `Writable`

Aliases:

- `big = Endian(_value=Int8(0))`: Most significant byte first.
- `little = Endian(_value=Int8(1))`: Least significant byte first.

#### `Endian.native`

```mojo
def native[target: CompilationTarget = CompilationTarget()]() -> Self
```

Returns the byte order of a compilation target.

Parameters:

- `target`: The target whose byte order to return.

Returns: `Endian.big` or `Endian.little`.

## Functions

### `default_accelerator`

```mojo
def default_accelerator() -> CompilationTarget
```

Get the default accelerator target.

The default accelerator is determined automatically by the compiler, but
may be overridden by the `--target-accelerator` command line flag.

This function will always return the same value, whether called in host or
accelerator offload (`compile_info`) compilation context.

Constraints: An accelerator target must be configured.

Returns: A value representing the current accelerator target.

### `current_accelerator`

```mojo
def current_accelerator() -> CompilationTarget
```

Get the current compilation target, which must be an accelerator.

This function returns a value identical to `CompilationTarget.current()`,
but will error during compilation if the current target is not an
accelerator.

This function is expected to only be called within an offload compilation
(`compile_info`).

Prefer this function over `default_accelerator()` when used in Mojo code
intended only for use on an accelerators, such as kernel implementations.
Code that may run in host elaboration context should avoid this function.

Constraints: The compilation target of the current compilation context must be an
accelerator target.

Returns: A value representing the current accelerator target.

### `platform_map`

```mojo
def platform_map[T: Copyable, //, operation: Optional[String] = None, *, linux: Optional[T] = None, macos: Optional[T] = None]() -> T
```

Helper for defining a compile time value depending on the current compilation target, raising a compilation error if trying to access the value on an unsupported target.

Example:

```mojo
from std.sys.info import platform_map

comptime EDEADLK = platform_map["EDEADLK", linux=35, macos=11]()
```

Parameters:

- `T`: The type of the platform-specific value.
- `operation`: Optional operation name for error messages.
- `linux`: The value to use on Linux platforms.
- `macos`: The value to use on macOS platforms.

Returns: The platform-specific value for the current target.

### `is_triple`

```mojo
def is_triple[name: StringLiteral[name.value], target: CompilationTarget = CompilationTarget()]() -> Bool
```

**Deprecated:** use CompilationTarget.is_triple instead

Returns True if the target triple of the compiler matches the input and False otherwise.

Parameters:

- `name`: The name of the triple value.
- `target`: The triple value to be checked against.

Returns: True if the triple matches and False otherwise.

### `is_apple_m5`

```mojo
def is_apple_m5() -> Bool
```

Returns True if the target is an Apple M5 GPU and False otherwise.

Returns: True if the target is Apple M5 and False otherwise.

### `is_gpu`

```mojo
def is_gpu() -> Bool
```

Returns True if the target triple is GPU and False otherwise.

Equivalent to `CompilationTarget.current().is_gpu()`.

Returns: True if the current compilation target is a GPU.

### `is_nvidia_gpu`

```mojo
def is_nvidia_gpu[subarch: StringSpan[ImmStaticOrigin] = StringSpan("<any>")]() -> Bool
```

Checks whether the current compilation target is an NVIDIA GPU.

Equivalent to `CompilationTarget.current().is_nvidia_gpu[subarch]()`.

Parameters:

- `subarch`: The GPU sub-architecture to check for.

Returns: True if the current compilation target is an NVIDIA GPU.

### `is_amd_gpu`

```mojo
def is_amd_gpu[subarch: StringSpan[ImmStaticOrigin] = StringSpan("<any>")]() -> Bool
```

Checks whether the current compilation target is an AMD GPU.

Equivalent to `CompilationTarget.current().is_amd_gpu[subarch]()`.

Parameters:

- `subarch`: The GPU sub-architecture to check for.

Returns: True if the current compilation target is an AMD GPU.

### `is_apple_gpu`

```mojo
def is_apple_gpu[subarch: StringSpan[ImmStaticOrigin] = StringSpan("<any>")]() -> Bool
```

Checks whether the current compilation target is an Apple GPU.

Equivalent to `CompilationTarget.current().is_apple_gpu[subarch]()`.

Parameters:

- `subarch`: The GPU sub-architecture to check for.

Returns: True if the current compilation target is an Apple GPU.

### `is_little_endian`

```mojo
def is_little_endian[target: CompilationTarget = CompilationTarget()]() -> Bool
```

**Deprecated:** Use `Endian.native() == .little` instead.

Returns True if the target's endianness is little and False otherwise.

Parameters:

- `target`: The target architecture.

Returns: True if the target is little endian and False otherwise.

### `is_big_endian`

```mojo
def is_big_endian[target: CompilationTarget = CompilationTarget()]() -> Bool
```

**Deprecated:** Use `Endian.native() == .big` instead.

Returns True if the target's endianness is big and False otherwise.

Parameters:

- `target`: The target architecture.

Returns: True if the target is big endian and False otherwise.

### `is_32bit`

```mojo
def is_32bit[target: CompilationTarget = CompilationTarget()]() -> Bool
```

Returns True if the maximum integral value is 32 bit.

Parameters:

- `target`: The target architecture.

Returns: True if the maximum integral value is 32 bit, False otherwise.

### `is_64bit`

```mojo
def is_64bit[target: CompilationTarget = CompilationTarget()]() -> Bool
```

Returns True if the maximum integral value is 64 bit.

Parameters:

- `target`: The target architecture.

Returns: True if the maximum integral value is 64 bit, False otherwise.

### `simd_bit_width`

```mojo
def simd_bit_width[target: CompilationTarget = CompilationTarget()]() -> Int
```

Returns the vector size (in bits) of the specified target.

Parameters:

- `target`: The target architecture.

Returns: The vector size (in bits) of the specified target.

### `simd_byte_width`

```mojo
def simd_byte_width[target: CompilationTarget = CompilationTarget()]() -> Int
```

Returns the vector size (in bytes) of the specified target.

Parameters:

- `target`: The target architecture.

Returns: The vector size (in bytes) of the host system.

### `stdlib_plugin`

```mojo
def stdlib_plugin[target: __mlir_type.`!kgen.target` = _current_target()]() -> StaticString
```

Returns the stdlib plugin name for the specified target.

Parameters:

- `target`: The target architecture.

Returns: The stdlib plugin name for the specified target.

### `size_of`

```mojo
def size_of[type: AnyType, target: CompilationTarget = CompilationTarget()]() -> Int
```

Returns the size of (in bytes) of the type.

The size includes any padding required by the type's alignment, so it is
always a multiple of `align_of[type]()` and always matches the stride
between adjacent elements of an array of the type.

Example:
```mojo
from std.sys.info import size_of
def main() raises:
    print(
        size_of[UInt8]() == 1,
        size_of[UInt16]() == 2,
        size_of[Int32]() == 4,
        size_of[Float64]() == 8,
        size_of[
            SIMD[.uint8, 4]
        ]() == 4,
    )
```
Note: `align_of` is in same module.

Parameters:

- `type`: The type in question.
- `target`: The target architecture.

Returns: The size of the type in bytes.

```mojo
def size_of[dtype: DType, target: CompilationTarget = CompilationTarget()]() -> Int
```

Returns the size of (in bytes) of the dtype.

Parameters:

- `dtype`: The DType in question.
- `target`: The target architecture.

Returns: The size of the dtype in bytes.

### `align_of`

```mojo
def align_of[type: AnyType, target: CompilationTarget = CompilationTarget()]() -> Int
```

Returns the align of (in bytes) of the type.

Parameters:

- `type`: The type in question.
- `target`: The target architecture.

Returns: The alignment of the type in bytes.

```mojo
def align_of[dtype: DType, target: CompilationTarget = CompilationTarget()]() -> Int
```

Returns the align of (in bytes) of the dtype.

Parameters:

- `dtype`: The DType in question.
- `target`: The target architecture.

Returns: The alignment of the dtype in bytes.

### `bit_width_of`

```mojo
def bit_width_of[type: RegisterPassable, target: CompilationTarget = CompilationTarget()]() -> Int
```

Returns the size of (in bits) of the type.

Parameters:

- `type`: The type in question.
- `target`: The target architecture.

Returns: The size of the type in bits.

```mojo
def bit_width_of[dtype: DType, target: CompilationTarget = CompilationTarget()]() -> Int
```

Returns the size of (in bits) of the dtype.

Parameters:

- `dtype`: The type in question.
- `target`: The target architecture.

Returns: The size of the dtype in bits.

### `simd_width_of`

```mojo
def simd_width_of[type: RegisterPassable, target: CompilationTarget = CompilationTarget()]() -> Int
```

Returns the vector size of the type on the host system.

Parameters:

- `type`: The type in question.
- `target`: The target architecture.

Returns: The vector size of the type on the host system.

```mojo
def simd_width_of[dtype: DType, target: CompilationTarget = CompilationTarget()]() -> Int
```

Returns the vector size of the type on the host system.

Parameters:

- `dtype`: The DType in question.
- `target`: The target architecture.

Returns: The vector size of the dtype on the host system.

### `num_physical_cores`

```mojo
def num_physical_cores() -> Int
```

Returns the number of physical cores across all CPU sockets.

Returns: Int: The number of physical cores on the system.

### `num_logical_cores`

```mojo
def num_logical_cores() -> Int
```

Returns the number of hardware threads, including hyperthreads across all CPU sockets.

Returns: Int: The number of threads on the system.

### `num_performance_cores`

```mojo
def num_performance_cores() -> Int
```

Returns the number of physical performance cores across all CPU sockets. If not known, returns the total number of physical cores.

Returns: Int: The number of physical performance cores on the system.

### `has_accelerator`

```mojo
def has_accelerator() -> Bool
```

Returns True if the host system has an accelerator and False otherwise.

Returns: True if the host system has an accelerator.

### `has_amd_rdna_gpu_accelerator`

```mojo
def has_amd_rdna_gpu_accelerator() -> Bool
```

Returns True if the host system has an AMD RDNA GPU and False otherwise.

Returns: True if the host system has an AMD RDNA GPU.
