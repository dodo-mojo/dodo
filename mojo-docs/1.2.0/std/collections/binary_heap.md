# `std.collections.binary_heap`

Defines a BinaryHeap type.

## Structs

### `BinaryHeap`

```mojo
struct BinaryHeap[T: Comparable & Copyable & Deinitable]
```

A List-backed binary max-heap.

push and pop have complexity `O(log(n))` where `n = len(self)`

Examples:
```mojo
from std.collections.binary_heap import BinaryHeap
var heap = BinaryHeap[Int]()
heap.push(5)
heap.push(10)
heap.push(3)

print(heap.peek()) # 10
print(heap.pop()) # 10
print(heap.pop()) # 5
print(heap.pop()) # 3
```

Parameters:

- `T`: Element type.

Implemented traits: `AnyType`, `Copyable`, `Defaultable`, `Deinitable`, `Movable`, `Sized`

#### `BinaryHeap.__init__`

```mojo
def __init__(out self)
```

Constructs an empty heap.

```mojo
def __init__(out self, *, capacity: Int)
```

Constructs a heap with a given capacity.

Args:

- `capacity`: The capacity of the heap.

#### `BinaryHeap.__len__`

```mojo
def __len__(self) -> Int
```

Gets the size of the binary heap.

Returns: The number of elements in the heap.

#### `BinaryHeap.clear`

```mojo
def clear(mut self)
```

Clears the elements in the heap.

#### `BinaryHeap.push`

```mojo
def push(mut self, var val: T)
```

Adds a value to the heap.

Args:

- `val`: The value to add.

#### `BinaryHeap.pop`

```mojo
def pop(mut self) -> T
```

Removes the largest item from the heap and returns it.

Aborts if the heap is empty.

Returns: The largest item in the heap.

#### `BinaryHeap.peek`

```mojo
def peek(self) -> ref[self._data["element"]] T
```

Gets a reference to the largest element in the heap.

Examples:

```mojo
from std.collections.binary_heap import BinaryHeap
var heap = BinaryHeap[Int]()
heap.push(1)
heap.push(2)
var two = heap.peek() # returns a reference to "2"
```

Returns: The largest element in the heap.
