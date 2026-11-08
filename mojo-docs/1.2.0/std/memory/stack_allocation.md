# `std.memory.stack_allocation`

Defines the `unsafe_stack_allocation` function for stack-based memory allocation.

You can import these APIs from the `memory` package. For example:

```mojo
from std.memory import unsafe_stack_allocation
```

## Functions

### `unsafe_stack_allocation`

```mojo
def unsafe_stack_allocation[count: Int, dtype: DType, /, alignment: Int = align_of[dtype](), address_space: AddressSpace = .GENERIC]() -> Pointer[Scalar[dtype], MutUntrackedOrigin, address_space=address_space]
```

Allocates data buffer space on the stack given a data type and number of elements.

Parameters:

- `count`: Number of elements to allocate memory for.
- `dtype`: The data type of each element.
- `alignment`: Address alignment of the allocated data.
- `address_space`: The address space of the pointer.

Returns: A data pointer of the given type pointing to the allocated space.

```mojo
def unsafe_stack_allocation[count: Int, type: AnyType, /, name: Optional[StringSpan[ImmStaticOrigin]] = None, alignment: Int = Int((get_alignof type, _current_target())), address_space: AddressSpace = .GENERIC]() -> Pointer[type, MutUntrackedOrigin, address_space=address_space]
```

Allocates data buffer space on the stack given a data type and number of elements.

Parameters:

- `count`: Number of elements to allocate memory for.
- `type`: The data type of each element.
- `name`: The name of the global variable (only honored in certain cases).
- `alignment`: Address alignment of the allocated data.
- `address_space`: The address space of the pointer.

Returns: A data pointer of the given type pointing to the allocated space.

### `stack_allocation`

```mojo
def stack_allocation[count: Int, dtype: DType, /, alignment: Int = align_of[dtype](), address_space: AddressSpace = .GENERIC]() -> Pointer[Scalar[dtype], MutUntrackedOrigin, address_space=address_space]
```

Allocates data buffer space on the stack given a data type and number of elements.

Parameters:

- `count`: Number of elements to allocate memory for.
- `dtype`: The data type of each element.
- `alignment`: Address alignment of the allocated data.
- `address_space`: The address space of the pointer.

Returns: A data pointer of the given type pointing to the allocated space.

```mojo
def stack_allocation[count: Int, type: AnyType, /, name: Optional[StringSpan[ImmStaticOrigin]] = None, alignment: Int = Int((get_alignof type, _current_target())), address_space: AddressSpace = .GENERIC]() -> Pointer[type, MutUntrackedOrigin, address_space=address_space]
```

Allocates data buffer space on the stack given a data type and number of elements.

Parameters:

- `count`: Number of elements to allocate memory for.
- `type`: The data type of each element.
- `name`: The name of the global variable (only honored in certain cases).
- `alignment`: Address alignment of the allocated data.
- `address_space`: The address space of the pointer.

Returns: A data pointer of the given type pointing to the allocated space.
