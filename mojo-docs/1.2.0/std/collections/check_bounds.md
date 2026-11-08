# `std.collections.check_bounds`

Contains bounds checks which are on by default for CPU and off by default for GPU.

## Functions

### `check_bounds`

```mojo
def check_bounds[cpu_default: Bool = True](idx: T, size: Int, location: Optional[SourceLocation] = None)
```

Bounds check which is on by default for CPU, and off by default for GPU.

You can turn off CPU bounds checks for a specific collection by setting
`check_bounds[cpu_default=False](idx, size, loc)`, but turn them on for
tests with:

```bash
mojo build -D ASSERT=all main.mojo
```

The defaults are optimal for most use cases, where CPU bounds checks are
cheap and valuable, but GPU bounds checks are too expensive due to branching
costs. For maximum performance you can turn off all asserts regardless of
defaults with:

```bash
mojo build -D ASSERT=none main.mojo
```

Parameters:

- `cpu_default`: If the bounds check is on by default on CPU.

Args:

- `idx`: The index for the bounds check.
- `size`: The size of the container, and first index that would be out of range.
- `location`: `SourceLocation` shown on assert error. Defaults to showing the callsite two levels of function calls above this one. So if `check_bounds` is called inside a `__getitem__` method, it will show the source location where the incorrect index was provided.

### `check_slice_bounds`

```mojo
def check_slice_bounds[cpu_default: Bool = True](slice: ContiguousSlice, len: Int, location: Optional[SourceLocation] = None) -> Tuple[Int, Int]
```

Bounds check for slice indexing, which is on by default for CPU, and off by default for GPU.

Resolves `slice`'s optional `start`/`end` against `len` and aborts if the
resolved start or end index is out of bounds, or if start is greater than
end. `ContiguousSlice` does not support negative (from-the-end) indices,
so a negative start or end is always out of bounds.

Parameters:

- `cpu_default`: If the bounds check is on by default on CPU.

Args:

- `slice`: The slice to resolve and bounds check.
- `len`: The size of the container.
- `location`: `SourceLocation` shown on assert error. Defaults to showing the callsite two levels of function calls above this one. So if `check_slice_bounds` is called inside a `__getitem__` method, it will show the source location where the incorrect slice was provided.

Returns: The slice's resolved `(start, end)`.
