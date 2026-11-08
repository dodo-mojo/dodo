# `std.collections`

Core data types: List, Dict, Set, Optional, String, and other collections.

The `collections` package provides fundamental data structures for organizing
and managing data in Mojo programs. It includes general-purpose collections
like dynamic arrays, hash maps, and sets, along with specialized structures for
specific use cases. These types form the foundation for most data manipulation
in Mojo and integrate seamlessly with the language's iteration and memory
management systems.

Use this package for general data storage and manipulation, implementing
algorithms, building custom data structures, or any task requiring collection
types beyond basic primitives.

## Packages

- [`std.collections.string`](string/index.md): Provides comprehensive Unicode string functionality.

## Modules

- [`std.collections.array`](array.md): Provides a fixed-size array implementation with compile-time size checking.
- [`std.collections.binary_heap`](binary_heap.md): Defines a BinaryHeap type.
- [`std.collections.bitset`](bitset.md): Provides a compact set of non-negative integers backed by inline storage.
- [`std.collections.check_bounds`](check_bounds.md): Contains bounds checks which are on by default for CPU and off by default for GPU.
- [`std.collections.counter`](counter.md): Defines the `Counter` type.
- [`std.collections.deque`](deque.md): Defines the Deque type.
- [`std.collections.dict`](dict.md): Defines `Dict`, a collection that stores key-value pairs.
- [`std.collections.interval`](interval.md): A self-balancing interval tree is a specialized binary search tree designed to efficiently store and query intervals.
- [`std.collections.linked_list`](linked_list.md): Implements a doubly-linked list data structure.
- [`std.collections.list`](list.md): Defines the List type.
- [`std.collections.optional`](optional.md): Defines Optional, a type modeling a value which may or may not be present.
- [`std.collections.set`](set.md): Implements the Set datatype.
- [`std.collections.span`](span.md): Implements the `Span` type.
- [`std.collections.type_dict`](type_dict.md): Provides a data structure which acts to map a value of a given type to one of a set of types.
