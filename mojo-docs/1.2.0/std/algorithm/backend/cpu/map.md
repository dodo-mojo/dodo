# `std.algorithm.backend.cpu.map`

CPU implementation of the map function.

## Functions

### `map`

```mojo
def map(size: Int, func: T)
```

Maps a function over the integer range [0, size). This lets you apply an integer index-based operation across data captured by the mapped function (for example, an indexed buffer).

For example:

```mojo
from std.algorithm import map

def main() raises:
    # Create list with initial values to act on
    var list: List[Float32] = [1.0, 2.0, 3.0, 4.0, 5.0]

    # Function applied to the value at each index
    def exponent_2(idx: Int) {mut}:
        list[idx] = 2.0 ** list[idx]

    # Apply the mapped function across the index range
    map(len(list), exponent_2)

    # Show results
    for idx in range(len(list)):
        print(list[idx])
```

Example output:

```output
2.0
4.0
8.0
16.0
32.0
```

:::note
Don't confuse `algorithm.map` (this eager, index-based helper) with
[`iter.map`](../../../../std/iter/index.md#map),
which returns a lazy iterator that applies a function to each element.
:::

Args:

- `size`: Number of elements in the index range.
- `func`: Parameterized function applied at each index.
