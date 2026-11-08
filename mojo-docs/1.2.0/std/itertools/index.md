# `std.itertools`

Iterator tools for lazy sequence generation and transformation.

The `itertools` package provides utilities for creating and composing iterators
for efficient lazy evaluation. It offers building blocks for:

- Generating infinite sequences (`count`, `cycle`, `repeat`)
- Computing Cartesian products (`product`)
- Slicing iterators by count (`take`, `drop`)
- Filtering elements conditionally (`take_while`, `drop_while`)

These tools enable functional programming patterns and memory-efficient iteration
over large or infinite sequences without materializing entire collections in
memory.

Use this package for generating sequences without explicit loops, creating
combinations of elements from multiple collections, or implementing functional
iteration patterns. These tools are particularly useful for nested loops,
grid-based computations, or any scenario requiring efficient lazy evaluation.

## Modules

- [`std.itertools.itertools`](itertools.md): Provides iterator utilities for common iteration patterns.
