# `std.memory.unsafe_pointer`

Defines `UnsafePointer` as a backward-compatible name for `Pointer`.

`UnsafePointer` is a `comptime` alias for `Pointer`, kept for code written
before the two pointer types were unified. Prefer `Pointer` directly in new
code; see `std.memory.pointer` for the type's docstring and its `unsafe_`
method surface.

## Aliases

### `UnsafePointer`

```mojo
comptime UnsafePointer[mut: Bool, //, T: AnyType, origin: Origin[mut=mut], *, address_space: AddressSpace = .GENERIC] = Pointer[T, origin, address_space=address_space]
```

**Deprecated:** 'UnsafePointer' is deprecated, use 'Pointer' instead

An indirect reference to one or more values of `T` consecutively in memory, and can refer to uninitialized memory.
