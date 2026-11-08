# `std.builtin.range`

Defines Mojo's built-in `range()` function.

In Mojo, ranges are values, not loop constructs, generators, or lists. Every
range is a half-open interval, [start, end).

The stand-alone `range()` function constructs zero-based, sequential, and
strided ranges.

`range()` is built in. You don't need to import it.

## Functions

### `range`

```mojo
def range[T: Indexer, //](end: T) -> _ZeroStartingRange
```

Returns the integer sequence `[0, end)`.

Integer ranges are values. They support `len()`, O(1) indexing, and
`reversed()` without allocating. `reversed(range(n))` iterates from
`n - 1` down to `0`.

Performance:
O(1) construction. O(1) indexing. No list allocation.

Examples:

```mojo
for i in range(5):
    print(i)  # 0, 1, 2, 3, 4

var steps = range(1000)
print(steps[499])  # 499
print(len(steps))  # 1000

for i in reversed(range(5)):
    print(i)  # 4, 3, 2, 1, 0
```

Parameters:

- `T`: The type of the end value. Constrained to `Indexer`.

Args:

- `end`: The exclusive upper bound. Negative values produce an empty range.

Returns: A zero-based integer range over `[0, end)`.

```mojo
def range[T: Indexer, //](start: T, end: T) -> _SequentialRange
```

Returns the integer sequence `[start, end)`.

**The two-argument form never counts down.** `range(7, 3)` is empty,
not `[7, 6, 5, 4]`. Use the three-argument form with a negative step to
count downward. The range supports `len()`, O(1) indexing, and
`reversed()`.

Performance:
O(1) construction. O(1) indexing. No list allocation.

Examples:

```mojo
for i in range(3, 7):
    print(i)  # 3, 4, 5, 6

for i in range(-3, 4):
    print(i)  # -3, -2, -1, 0, 1, 2, 3

print(len(range(7, 3)))  # 0
```

Parameters:

- `T`: The type of the start and end values. Constrained to `Indexer`.

Args:

- `start`: The inclusive lower bound.
- `end`: The exclusive upper bound. When `end <= start`, the range is empty.

Returns: A sequential integer range over `[start, end)`.

```mojo
def range[T: Indexer, //](start: T, end: T, step: T) -> _StridedRange
```

Returns the integer sequence `[start, end)` with a given step.

When you don't know which bound is larger, choose the direction with an
inline conditional:

```mojo
var step = 1 if end > start else -1
for i in range(start, end, step):
    ...
```

Performance:
O(1) construction. O(1) indexing. No list allocation.

Examples:

```mojo
for i in range(0, 10, 2):
    print(i)  # 0, 2, 4, 6, 8

for i in range(7, 3, -1):
    print(i)  # 7, 6, 5, 4

var evens = range(0, 2_000_000, 2)
print(evens[999_999])  # 1_999_998
print(len(evens))      # 1_000_000
```

Parameters:

- `T`: The type of the start, end, and step values. Constrained to `Indexer`.

Args:

- `start`: The inclusive lower bound when stepping forward, or the inclusive upper bound when stepping backward.
- `end`: The exclusive bound in the direction of the step.
- `step`: The increment per iteration. A positive step counts up, and a negative step counts down. A zero step produces an empty range.

Returns: A strided integer range over `[start, end)` by `step`.

```mojo
def range[dtype: DType, //](end: Scalar[dtype]) -> _ZeroStartingRange[dtype]
```

Returns the scalar sequence `[0, end)` with elements of type `dtype`.

Use this overload when you need typed scalar elements.

The `dtype` is inferred from the argument, so `Int32(8)` produces
`Int32` elements. This form requires an integer `dtype`; floating-point
ranges require an explicit step. These integer ranges support `len()`
and O(1) indexing. Signed-integer ranges can be reversed; reversing an
unsigned range is a compile-time error.

Performance:
O(1). No list allocation.

Examples:

```mojo
for i in range(UInt8(4)):
    print(i)  # 0, 1, 2, 3 (each value is UInt8)
```

Parameters:

- `dtype`: The `DType` of the sequence elements. Inferred from `end`.

Args:

- `end`: The exclusive upper bound. Negative values produce an empty range.

Returns: A zero-based scalar range over `[0, end)`.

```mojo
def range[dtype: DType, //](start: Scalar[dtype], end: Scalar[dtype]) -> _SequentialRange[dtype]
```

Returns the scalar sequence `[start, end)` with elements of type `dtype`.

**The two-argument form never counts down.** The range is empty
when `end <= start`. Use the three-argument form with a negative
step to count downward. This form requires an integer `dtype`;
floating-point ranges require an explicit step. These integer ranges
support `len()` and O(1) indexing. Signed-integer ranges can be
reversed; reversing an unsigned range is a compile-time error.

Performance:
O(1). No list allocation.

Examples:

```mojo
for i in range(Int32(3), Int32(7)):
    print(i)  # 3, 4, 5, 6  — each value is Int32
```

Parameters:

- `dtype`: The `DType` of the sequence elements. Inferred from the arguments.

Args:

- `start`: The inclusive lower bound.
- `end`: The exclusive upper bound. When `end <= start`, the range is empty.

Returns: A sequential scalar range over `[start, end)`.

```mojo
def range[dtype: DType, //](start: Scalar[dtype], end: Scalar[dtype], step: Scalar[dtype]) -> _StridedRange[dtype]
```

Returns the scalar sequence `[start, end)` with a given step.

Integer scalar ranges support `len()`, O(1) indexing, and `reversed()`,
including unsigned ranges. Float ranges are iteration-only. Each element
is computed as `fma(i, step, start)`, and `reversed()` is a bit-for-bit
mirror of forward iteration.

**Float endpoints are exclusive.** To include a specific endpoint, push
`end` past it by a fraction of the step:

```mojo
# [0.0, 0.25, 0.5, 0.75] — 1.0 not included
for t in range(Float64(0.0), Float64(1.0), Float64(0.25)):
    print(t)

# [0.0, 0.25, 0.5, 0.75, 1.0] — endpoint included
var tolerance = Float64(0.1)
for t in range(Float64(0.0), Float64(1) + tolerance, Float64(0.25)):
    print(t)
```

**A zero step yields an empty range.** A step of zero has no direction, so
the range has no elements regardless of the bounds.

Performance:
O(1). No list allocation.

Examples:

```mojo
# Walk t over [0, 1)
for t in range(Float64(0.0), Float64(1.0), Float64(0.25)):
    print(t)  # 0.0, 0.25, 0.5, 0.75

# Integer scalar range — len() and indexed access work
var r = range(Int32(0), Int32(20), Int32(2))
print(len(r))       # 10
print(r[Int32(3)])  # 6
```

Parameters:

- `dtype`: The `DType` of the sequence elements. Inferred from the arguments.

Args:

- `start`: The inclusive lower bound when stepping forward, or the inclusive upper bound when stepping backward.
- `end`: The exclusive bound in the direction of the step.
- `step`: The increment per iteration. A positive step counts up, and a negative step counts down. A zero step yields an empty range.

Returns: A strided scalar range over `[start, end)` by `step`.
