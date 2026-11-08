# `std.algorithm.backend.tile`

Implementations of tile functions.

## Aliases

### `Static1DTileUnitFunc`

```mojo
comptime Static1DTileUnitFunc = def[width: Int](Int) -> None
```

Signature of a 1D tiled function with static tile size.

The function takes a static tile size parameter and an offset argument,
i.e. `func[tile_size: Int](offset: Int)`.

### `Dynamic1DTileUnitFunc`

```mojo
comptime Dynamic1DTileUnitFunc = def(Int, Int) -> None
```

Signature of a 1D tiled function with dynamic tile size.

The function takes a dynamic tile size and an offset argument,
i.e. `func(offset: Int, tile_size: Int)`.

### `BinaryTile1DTileUnitFunc`

```mojo
comptime BinaryTile1DTileUnitFunc = def[width: Int](Int, Int) -> None
```

Signature of a tiled function that performs some work with a dynamic tile size and a secondary static tile size.

### `Static2DTileUnitFunc`

```mojo
comptime Static2DTileUnitFunc = def[tile_x: Int, tile_y: Int](Int, Int) -> None
```

Signature of a 2D tiled function with static tile size.

The function takes static tile size parameters and offset arguments, i.e.
`func[tile_size_x: Int, tile_size_y: Int](offset_x: Int, offset_y: Int)`.

## Functions

### `tile`

```mojo
def tile[tile_size_list: List[Int]](offset: Int, upperbound: Int, workgroup_function: T)
```

A generator that launches work groups in specified list of tile sizes.

A workgroup function is a function that can process a configurable
consecutive "tile" of workload. E.g.
  `work_on[3](5)`
should launch computation on item 5,6,7, and should be semantically
equivalent to
  `work_on[1](5)`, `work_on[1](6)`, `work_on[1](7)`.

This generator will try to proceed with the given list of tile sizes on the
listed order. E.g.
    `tile[func, (3,2,1)](offset, upperbound)`
will try to call `func[3]` starting from offset until remaining work is less
than 3 from upperbound and then try `func[2]`, and then `func[1]`, etc.

Parameters:

- `tile_size_list`: List of tile sizes to launch work.

Args:

- `offset`: The initial index to start the work from.
- `upperbound`: The runtime upperbound that the work function should not exceed.
- `workgroup_function`: Workgroup function that processes one tile of workload.

```mojo
def tile(offset: Int, upperbound: Int, *tile_size_list: Int, *, workgroup_function: T)
```

A generator that launches work groups in specified list of tile sizes.

This is the version of tile generator for the case where work_group function
can take the tile size as a runtime value.

Args:

- `offset`: The initial index to start the work from.
- `upperbound`: The runtime upperbound that the work function should not exceed.
- `*tile_size_list`: List of tile sizes to launch work.
- `workgroup_function`: Workgroup function that processes one tile of workload.

```mojo
def tile[secondary_tile_size_list: List[Int], secondary_cleanup_tile: Int](offset: Int, upperbound: Int, *primary_tile_size_list: Int, *, primary_cleanup_tile: Int, workgroup_function: T)
```

A generator that launches work groups in specified list of tile sizes until the sum of primary_tile_sizes has exceeded the upperbound.

Parameters:

- `secondary_tile_size_list`: List of static tile sizes to launch work.
- `secondary_cleanup_tile`: Last static tile to use when primary tile sizes don't fit exactly within the upperbound.

Args:

- `offset`: The initial index to start the work from.
- `upperbound`: The runtime upperbound that the work function should not exceed.
- `*primary_tile_size_list`: List of dynamic tile sizes to launch work.
- `primary_cleanup_tile`: Last dynamic tile to use when primary tile sizes don't fit exactly within the upperbound.
- `workgroup_function`: Workgroup function that processes one tile of workload.

```mojo
def tile[tile_sizes_x: List[Int], tile_sizes_y: List[Int]](offset_x: Int, offset_y: Int, upperbound_x: Int, upperbound_y: Int, workgroup_function: T)
```

Launches workgroup_function using the largest tile sizes possible in each dimension, starting from the x and y offset, until the x and y upperbounds are reached.

Parameters:

- `tile_sizes_x`: List of tile sizes to use for the first parameter of workgroup_function.
- `tile_sizes_y`: List of tile sizes to use for the second parameter of workgroup_function.

Args:

- `offset_x`: Initial x offset passed to workgroup_function.
- `offset_y`: Initial y offset passed to workgroup_function.
- `upperbound_x`: Max offset in x dimension passed to workgroup function.
- `upperbound_y`: Max offset in y dimension passed to workgroup function.
- `workgroup_function`: Function that is invoked for each tile and offset.
