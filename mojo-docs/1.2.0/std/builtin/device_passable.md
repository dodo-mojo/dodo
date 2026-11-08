# `std.builtin.device_passable`

Implements the `DevicePassable` trait for types transferable to accelerator devices.

## Traits

### `DevicePassable`

```mojo
trait DevicePassable
```

This trait marks types as passable to accelerator devices.

Inherits from: `AnyType`

Aliases:

- `device_type`: Indicate the type being used on accelerator devices.

#### `DevicePassable.get_type_name`

```mojo
def get_type_name() -> String
```

Gets the name of the host type (the one implementing this trait). For example, Int would return "Int", DeviceBuffer[.float32] would return "DeviceBuffer[DType.float32]". This is used for error messages when passing types to the device. TODO: This method will be retired soon when better kernel call error messages arrive.

Returns: The host type's name.

### `DevicePointerLike`

```mojo
trait DevicePointerLike
```

Describes the device-pointer information used during device encoding.

Inherits from: `AnyType`

Aliases:

- `PointeeType`: The type of the values referenced by this pointer.

#### `DevicePointerLike.unsafe_ptr`

```mojo
def unsafe_ptr(ref self) -> Pointer[Self.PointeeType, MutAnyOrigin]
```

Returns the offset-adjusted raw device pointer.

Returns: Device pointer as raw pointer.

### `DeviceTypeEncoder`

```mojo
trait DeviceTypeEncoder
```

This trait marks types as capable of encoding device types.

Used in `DevicePassable._to_device_type()` to enable target specific
encoding of device types at the boundary where functions are enqueued for
execution on an accelerator device.

Inherits from: `AnyType`

#### `DeviceTypeEncoder.target`

```mojo
def target() -> CompilationTarget
```

Returns the target architecture this encoder is encoding for.

Layout-sensitive queries (`size_of`, `align_of`,
`reflect[T].field_offset[...]`) inside `encode` /
`encode_device_ptr` and inside `DevicePassable._to_device_type`
implementations should pass `target=Self.target()` so that the
device's data layout — not the host's — is consulted.

Returns: The target architecture this encoder is encoding for.

#### `DeviceTypeEncoder.encode`

```mojo
def encode[ValueType: AnyType](mut self, value: ValueType, dst: Pointer[NoneType])
```

Encodes `value` into `dst` by copying its bits.

This is the default device encoding for a type whose
`DevicePassable.device_type` is `Self`.

Constraints: - `ValueType` must conform to `DevicePassable` or `RegisterPassable`.
- `ValueType` must conform to `Copyable & Deinitable`.
- If `ValueType` is `DevicePassable`, it must be its own leaf
`device_type`
(`ValueType._is_convertible_to_device_type[ValueType]()`), since a
bit-copy only encodes an identity mapping correctly.

Parameters:

- `ValueType`: The type of `value`, see constraints.

Args:

- `value`: The variable to encode.
- `dst`: The opaque destination pointer to encode into. Must point to uninitialized storage at least `size_of[ValueType, target=Self.target()]()` bytes wide.

#### `DeviceTypeEncoder.encode_closure_state`

```mojo
def encode_closure_state[StructType: AnyType, //, DeviceStructType: AnyType](mut self, value: StructType, dst: Pointer[NoneType])
```

Encodes a compiler-synthesized closure-state struct into `dst`.

Closure wrappers hold their captured state in a struct that is encoded
for device transfer. When the closure captures a single value, that
struct has exactly one field and the compiler flattens it down to the
field's representation. `encode_fields` would reflect the field with
`field_ref`, which lowers to an identity GEP into the flattened struct
that the verifier rejects, so for the single-field case the sole field
is encoded directly (its offset is 0) using the same per-field dispatch
`encode_fields` applies. Multi-field state is forwarded to
`encode_fields` with the synthesized `device_type`.

Parameters:

- `StructType`: The closure-state struct type whose captures are being encoded.
- `DeviceStructType`: The synthesized device representation of the closure-state struct.

Args:

- `value`: The closure-state value to encode.
- `dst`: The opaque destination pointer that receives the encoded state.

#### `DeviceTypeEncoder.encode_fields`

```mojo
def encode_fields[StructType: AnyType, //, DeviceStructType: AnyType = StructType](mut self, value: StructType, dst: Pointer[NoneType])
```

Encodes each field of `value` into `dst` at its device offset.

For each field of `StructType`:

- If it conforms to `DevicePassable`, dispatch to its own
  `_to_device_type()`.
- Otherwise, if it is a composite transitively containing a
  `DevicePassable` member, recurse into `encode_fields`.
- Otherwise, delegate to `encode` (a bit-copy for a register-passable
  field; any other type is rejected there at compile time).

Source fields are read from `StructType`, while destination offsets are
calculated from `DeviceStructType`. `DeviceStructType` defaults to
`StructType`, but callers with a distinct device representation can
provide it explicitly. Field offsets use the encoder's target data
layout (`Self.target()`) rather than the host's.

Constraints: - `StructType` must be a Mojo struct type conforming to
`DevicePassable` or `RegisterPassable`.
- Every field must either conform to `DevicePassable`, be a
composite transitively containing a `DevicePassable` member,
conform to `ImplicitlyCopyable & Deinitable`, or
conform to `Copyable & Deinitable`.

Parameters:

- `StructType`: The composite host-side type whose fields are being encoded.
- `DeviceStructType`: The destination struct layout. Defaults to `StructType`.

Args:

- `value`: The composite host-side value to encode.
- `dst`: The opaque destination pointer that receives the encoded fields.

#### `DeviceTypeEncoder.encode_static_tuple`

```mojo
def encode_static_tuple[ElementType: RegisterPassable & ImplicitlyCopyable & Deinitable, size: Int, //](mut self, value: StaticTuple[ElementType, size], dst: Pointer[NoneType])
```

Encodes each element of a `StaticTuple` into `dst` element-wise.

`StaticTuple`'s `!pop.array` storage is opaque to field reflection
(see MOCO-4018), so `encode_fields` cannot iterate it. This encodes the
tuple by element instead, applying the same dispatch `encode_fields`
uses per field:

- If `ElementType` conforms to `DevicePassable`, dispatch to its own
  `_to_device_type()` so any host-to-device conversion runs.
- Otherwise, if `ElementType` is a composite transitively containing a
  `DevicePassable` member, recurse into `encode_fields`.
- Otherwise, bit-copy via `encode`.

Elements are placed at `i * size_of[device-element-type]` in the
encoder's target data layout (`Self.target()`), matching the device
layout of `StaticTuple.device_type`.

Parameters:

- `ElementType`: The tuple's element type (inferred).
- `size`: The number of elements (inferred).

Args:

- `value`: The `StaticTuple` to encode.
- `dst`: The opaque destination pointer that receives the encoded elements.

#### `DeviceTypeEncoder.encode_array`

```mojo
def encode_array[ElementType: Movable, size: Int, //](mut self, value: Array[ElementType, size], dst: Pointer[NoneType])
```

Encodes each element of an `Array` into `dst` element-wise.

Like `encode_static_tuple`, but for `Array`. The array's
`!pop.array` storage is opaque to field reflection (see MOCO-4018), so
this encodes by element, applying the same dispatch `encode_fields`
uses per field:

- If `ElementType` conforms to `DevicePassable`, dispatch to its own
  `_to_device_type()` so any host-to-device conversion runs.
- Otherwise, if `ElementType` is a composite transitively containing a
  `DevicePassable` member, recurse into `encode_fields`.
- Otherwise, bit-copy via `encode`.

Elements are placed at `i * size_of[device-element-type]` in the
encoder's target data layout (`Self.target()`), matching the device
layout of `Array.device_type`.

Parameters:

- `ElementType`: The array's element type (inferred).
- `size`: The number of elements (inferred).

Args:

- `value`: The `Array` to encode.
- `dst`: The opaque destination pointer that receives the encoded elements.

#### `DeviceTypeEncoder.encode_device_ptr`

```mojo
def encode_device_ptr[DevicePointerType: DevicePointerLike](mut self, value: DevicePointerType, dst: Pointer[NoneType])
```

Encodes a device pointer into `dst`.

Parameters:

- `DevicePointerType`: The type of the device pointer.

Args:

- `value`: The device pointer to encode.
- `dst`: The opaque destination pointer to encode into.
