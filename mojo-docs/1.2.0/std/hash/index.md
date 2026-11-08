# `std.hash`

Cryptographic and non-cryptographic hashing with customizable algorithms.

The `hash` package provides hashing functionality for computing hash values
of data. It defines the core hashing infrastructure through the `Hasher` trait
for implementing hash algorithms and the `Hashable` trait for types that can be
hashed. The package supports both compile-time and runtime hashing with
pluggable hash algorithm implementations.

Use this package for implementing hash-based data structures, creating hashable
types, computing checksums, or building custom hash algorithms. Types that
implement `Hashable` can be used as dictionary keys or in sets.

## Modules

- [`std.hash.hash`](hash.md): Implements the `Hashable` trait and `hash()` built-in function.
- [`std.hash.hasher`](hasher.md): Defines the Hasher trait and default hasher implementations.
