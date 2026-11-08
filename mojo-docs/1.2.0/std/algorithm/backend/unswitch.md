# `std.algorithm.backend.unswitch`

Implementations of unswitch and tile_and_unswitch functions.

## Aliases

### `SwitchedFunction`

```mojo
comptime SwitchedFunction = def[sw: Bool]() raises -> None
```

Signature of a function that unswitch can take.

### `SwitchedFunction2`

```mojo
comptime SwitchedFunction2 = def[sw0: Bool, sw1: Bool]() -> None
```

Signature for unswitch supporting 2 predicates.

### `Static1DTileUnswitchUnitFunc`

```mojo
comptime Static1DTileUnswitchUnitFunc = def[width: Int, sw: Bool](Int, Int) -> None
```

Signature of a tiled function with static tile size and unswitch flag.

The function takes a static tile size parameter and offset arguments,
i.e. `func[tile_size: Int](offset: Int)`.

### `Static1DTileUnitFuncWithFlag`

```mojo
comptime Static1DTileUnitFuncWithFlag = def[width: Int, flag: Bool](Int) -> None
```

Signature of a tiled function with a static tile size, offset, and flag.

### `Dynamic1DTileUnswitchUnitFunc`

```mojo
comptime Dynamic1DTileUnswitchUnitFunc = def[sw: Bool](Int, Int, Int) -> None
```

Signature of a dynamic tiled unswitch unit function.

### `Static1DTileUnitFuncWithFlags`

```mojo
comptime Static1DTileUnitFuncWithFlags = def[width: Int, left_flag: Bool, right_flag: Bool](Int) -> None
```

Signature of a tiled function with left and right boundary flags.

## Functions

### `unswitch`

```mojo
def unswitch(dynamic_switch: Bool, switched_func: T) raises
```

Performs a functional unswitch transformation.

Unswitch is a simple pattern that is similar idea to loop unswitching
pass but extended to functional patterns. The pattern facilitates the
following code transformation that reduces the number of branches in the
generated code

Before:

```mojo
for i in range(...)
    if i < xxx:
        ...
```

After:

```mojo
if i < ...
    for i in range(...)
        ...
else
    for i in range(...)
        if i < xxx:
            ...
```

This unswitch function generalizes that pattern with the help of meta
parameters and can be used to perform both loop unswitching and other
tile predicate lifting like in simd and amx.

TODO: Generalize to support multiple predicates.
TODO: Once nested lambdas compose well should make unswitch compose with
tile in an easy way.

Args:

- `dynamic_switch`: The dynamic condition that enables the unswitched code path.
- `switched_func`: The function containing the inner loop logic that can be unswitched.

Raises: If the operation fails.

```mojo
def unswitch(dynamic_switch: Bool, switched_func: T)
```

Performs a functional unswitch transformation.

Unswitch is a simple pattern that is similar idea to loop unswitching
pass but extended to functional patterns. The pattern facilitates the
following code transformation that reduces the number of branches in the
generated code

Before:

```mojo
for i in range(...)
    if i < xxx:
        ...
```

After:

```mojo
if i < ...
    for i in range(...)
        ...
else
    for i in range(...)
        if i < xxx:
            ...
```

This unswitch function generalizes that pattern with the help of meta
parameters and can be used to perform both loop unswitching and other
tile predicate lifting like in simd and amx.

TODO: Generalize to support multiple predicates.
TODO: Once nested lambdas compose well should make unswitch compose with
tile in an easy way.

Args:

- `dynamic_switch`: The dynamic condition that enables the unswitched code path.
- `switched_func`: The function containing the inner loop logic that can be unswitched.

```mojo
def unswitch(dynamic_switch_a: Bool, dynamic_switch_b: Bool, switched_func: T)
```

Performs a functional 2-predicates unswitch transformation.

Args:

- `dynamic_switch_a`: The first dynamic condition that enables the outer unswitched code path.
- `dynamic_switch_b`: The second dynamic condition that enables the inner unswitched code path.
- `switched_func`: The function containing the inner loop logic that has 2 predicates which can be unswitched.

### `tile_and_unswitch`

```mojo
def tile_and_unswitch[tile_size_list: List[Int]](offset: Int, upperbound: Int, workgroup_function: T)
```

Performs time and unswitch functional transformation.

A variant of static tile given a workgroup function that can be unswitched.
This generator is a fused version of tile and unswitch, where the static
unswitch is true throughout the "inner" portion of the workload and is
false only on the residue tile.

Parameters:

- `tile_size_list`: List of tile sizes to launch work.

Args:

- `offset`: The initial index to start the work from.
- `upperbound`: The runtime upperbound that the work function should not exceed.
- `workgroup_function`: Workgroup function that processes one tile of workload.

```mojo
def tile_and_unswitch(offset: Int, upperbound: Int, *tile_size_list: Int, *, workgroup_function: T)
```

Performs time and unswitch functional transformation.

A variant of dynamic tile given a workgroup function that can be
unswitched. This generator is a fused version of tile and unswitch, where
the static unswitch is true throughout the "inner" portion of the workload
and is false only on the residue tile.

Args:

- `offset`: The initial index to start the work from.
- `upperbound`: The runtime upperbound that the work function should not exceed.
- `*tile_size_list`: List of tile sizes to launch work.
- `workgroup_function`: Workgroup function that processes one tile of workload.

### `tile_middle_unswitch_boundaries`

```mojo
def tile_middle_unswitch_boundaries[middle_tile_sizes: List[Int], left_tile_size: Int = Int(1), right_tile_size: Int = Int(1)](left_boundary_start: Int, left_boundary_end: Int, right_boundary_start: Int, right_boundary_end: Int, work_fn: T)
```

Divides 1d iteration space into three parts and tiles them with different steps.

The 1d iteration space is divided into:

```mojo
1. [left_boundary_start, left_boundary_end), effected by left boundary.
2. [left_boundary_end, right_boundary_start), not effected by any boundary.
3. [right_boundary_start, right_boundary_end), effected by right boundary.
```

work_fn's switch is true for the left and right boundaries, implying boundary
conditions like padding in convolution. The middle part is tiled with static
tile sizes with the switch as false.

`middle_tile_sizes` should be in descending order for optimal performance.
(Larger tile size appeared later in the list fails the while-loop.)

Parameters:

- `middle_tile_sizes`: List of tile sizes for the middle part.
- `left_tile_size`: Tile size for the left boundary region.
- `right_tile_size`: Tile size for the right boundary region.

Args:

- `left_boundary_start`: Start index of the left boundary.
- `left_boundary_end`: End index of the left boundary.
- `right_boundary_start`: Start index of the right boundary.
- `right_boundary_end`: End index of the right boundary.
- `work_fn`: Work function that processes one tile of workload.

```mojo
def tile_middle_unswitch_boundaries[tile_size: Int, size: Int](work_fn: T)
```

Tile 1d iteration space with boundary conditions at both ends.

This generator is primarily for convolution with static shapes. `work_fn`'s
flags hints the function to handle padding at the boundary. The size is the
static output row size, i.e., WO dimension.

Parameters:

- `tile_size`: 1D Tile size.
- `size`: Iteration range is [0, size).

Args:

- `work_fn`: Work function that updates one tile. It has two flags for left and right boundaries, respectively.
