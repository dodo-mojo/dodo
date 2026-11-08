# Intro to metaprogramming

*From Modular's Mojo docs (`Mojo/docs/site/manual/metaprogramming/index.mdx` at tag `mojo/v1.2.0`, Apache-2.0 with LLVM Exceptions, see `LICENSE.txt`), turned into plain Markdown by dodo.*

Many languages have facilities for *metaprogramming*: writing code
that generates or modifies code. Python has facilities for dynamic
metaprogramming: features like decorators, metaclasses, and many more. These
features make Python very flexible and productive, but since they're dynamic,
they come with run-time overhead. Other languages have static or compile-time
metaprogramming features, like C preprocessor macros and C++ templates. These
can be limiting and hard to use.

Mojo's compile-time metaprogramming system uses the same language as run-time
programs, so you don't have to learn a new language—just a few new features.
The primary features you'll need to learn are:

- Compile-time statements and expressions
- Parameters
- Traits

## Compile-time statements and expressions

The `comptime` keyword identifies a statement or expression that needs to be
evaluated at compile time. For example, the `comptime` keyword is used to
declare compile-time constant values and to introduce compile-time conditionals
and loops. For information on compile-time assignments and control flow, see
[Compile-time evaluation](../../manual/metaprogramming/comptime-evaluation.md).

## Parameters
Functions and structs can be *parameterized* with compile-time parameters,
allowing you to define a container that holds different data types, or a matrix
multiplication algorithm that's parameterized by the matrix dimensions.
Compile-time parameters are similar to C++ template parameters or Rust generic
parameters. At compile time, Mojo *specializes* parameterized code to make
*concrete* versions—that is, it replaces parameters with constant values.

For example, a matrix multiplication function parameterized on its matrix
dimensions can be specialized at compile time to select the most efficient
algorithm based on those dimensions. For information on parameterization, see
[Parameters](../../manual/parameters/index.md).

## Traits
Type-parameterized functions and structs work across many types. For example,
a list might hold `Int`, `Float32`, or `String` values. Type-parameterized
code needs to know what operations those types support.

A *trait* defines a set of behaviors that types provide. Instead of
pre-selecting specific types, a parameterized sort function can just require
`Comparable`. For more information, see [traits](../../manual/traits.md) and
[parameterized declarations](../../manual/generics.md).
