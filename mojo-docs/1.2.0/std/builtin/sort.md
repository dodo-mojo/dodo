# `std.builtin.sort`

Implements the built-in `sort` function.

These are Mojo built-ins, so you don't need to import them.

## Aliases

### `insertion_sort_threshold`

```mojo
comptime insertion_sort_threshold = 32
```

Threshold below which insertion sort is used instead of quicksort.

## Functions

### `partition`

```mojo
def partition[T: Copyable, origin: MutOrigin, //](span: Span[T, origin], k: Int, cmp_fn: T)
```

Partition the input buffer inplace such that first k elements are the largest (or smallest if cmp_fn is < operator) elements. The ordering of the first k elements is undefined.

Parameters:

- `T`: Type of the underlying data.
- `origin`: Origin of span.

Args:

- `span`: Input buffer.
- `k`: Index of the partition element.
- `cmp_fn`: The comparison function.

### `sort`

```mojo
def sort[T: Copyable, origin: MutOrigin, //, *, stable: Bool = False](span: Span[T, origin], cmp_fn: T)
```

Sort a span in-place. The function doesn't return anything, the span is updated in-place.

Parameters:

- `T`: Type of the underlying data.
- `origin`: Origin of span.
- `stable`: Whether the sort should be stable.

Args:

- `span`: The span to be sorted.
- `cmp_fn`: The comparison function.

```mojo
def sort[T: Comparable & Copyable, origin: MutOrigin, //, *, stable: Bool = False](span: Span[T, origin])
```

Sort a span of comparable elements in-place.

Parameters:

- `T`: The order comparable collection element type.
- `origin`: Origin of span.
- `stable`: Whether the sort should be stable.

Args:

- `span`: The span to be sorted.
