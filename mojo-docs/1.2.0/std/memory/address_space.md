# `std.memory.address_space`

Implements `AddressSpace`, the memory address space of a pointer.

You can import this API from the `memory` package. For example:

```mojo
from std.memory import AddressSpace
```

## Structs

### `AddressSpace`

```mojo
struct AddressSpace
```

Address space of the pointer.

This type represents memory address spaces for both CPU and GPU targets.
On CPUs, typically only GENERIC is used. On GPUs (NVIDIA/AMD), various
address spaces provide access to different memory regions with different
performance characteristics.

Implemented traits: `AnyType`, `Copyable`, `Deinitable`, `EnumLike`, `Equatable`, `ImplicitlyCopyable`, `Intable`, `Movable`, `RegisterPassable`, `TrivialRegisterPassable`, `Writable`

Aliases:

- `GENERIC = AddressSpace.GENERIC`: Generic address space. Used for CPU memory and default GPU memory.
- `GLOBAL = AddressSpace(1)`: Global GPU memory address space.
- `SHARED = AddressSpace(3)`: Shared GPU memory address space (per thread block/workgroup).
- `CONSTANT = AddressSpace(4)`: Constant GPU memory address space (read-only).
- `LOCAL = AddressSpace(5)`: Local GPU memory address space (per thread, private).
- `SHARED_CLUSTER = AddressSpace(7)`: Shared cluster GPU memory address space (NVIDIA-specific).
- `BUFFER_RESOURCE = AddressSpace(8)`: Buffer resource GPU memory address space (AMD-specific).

#### `AddressSpace.__init__`

```mojo
def __init__(value: SIMDLength) -> Self
```

Initializes the address space from the underlying integral value.

Args:

- `value`: The address space value.

#### `AddressSpace.__eq__`

```mojo
def __eq__(self, other: Self) -> Bool
```

Checks if the two address spaces are equal.

Args:

- `other`: The other address space value.

Returns: True if the two address spaces are equal and False otherwise.

#### `AddressSpace.__getattr_param__`

```mojo
def __getattr_param__[name: StringSpan[ImmStaticOrigin]]() -> Self
```

Resolves a target-specific named address space.

The address spaces above (`GENERIC`, `GLOBAL`, `SHARED`, ...) are the
built-in GPU set. Accessing any *other* name as `AddressSpace.<NAME>`
routes here, which consults the active `PluginHooks` backend. This
keeps the set of valid names open and target-extensible — for example
an accelerator backend can provide scratchpad-style spaces that do not
exist on GPUs — instead of a fixed portable enum.

Constraints: `name` must be defined by the active `PluginHooks` backend;
otherwise this is a compile-time error.

Parameters:

- `name`: The address-space name being accessed.

Returns: The `AddressSpace` the active backend defines for `name`.

#### `AddressSpace.value`

```mojo
def value(self) -> SIMDLength
```

The integral value of the address space.

Returns: The integral value of the address space.

#### `AddressSpace.__int__`

```mojo
def __int__(self) -> Int
```

The integral value of the address space.

Returns: The integral value of the address space.

#### `AddressSpace.write_to`

```mojo
def write_to(self, mut writer: T)
```

Formats the address space to the provided Writer.

Args:

- `writer`: The object to write to.

#### `AddressSpace.write_repr_to`

```mojo
def write_repr_to(self, mut writer: T)
```

Write the string representation of the AddressSpace.

Args:

- `writer`: The object to write to.
