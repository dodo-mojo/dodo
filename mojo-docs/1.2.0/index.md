# Mojo 1.2.0

> The Mojo 1.2.0 manual, language reference, tools guides, release notes and standard library API as plain Markdown. Saved by dodo from Modular's `mojo/v1.2.0` tag; Modular's license is in `LICENSE.txt`.

Every relative link below is a file of these docs. `std/` has one page per module: `std/collections/list.md` documents `std.collections.list`, and `std/collections/index.md` the package.

## Start here

- [What changed in Mojo 1.x](changes-in-1x.md): Old syntax next to the 1.x form, for code and habits from before 1.0.
- [Install Mojo](install.md): You can install Mojo using pixi, uv, conda, pip, or other Python/Conda package managers.
- [System requirements](requirements.md): Operating system, hardware, and software requirements for Mojo.
- [Pixi basics](pixi.md)
- [Mojo FAQ](faq.md): Answers to questions we expect about Mojo.

## Manual

- [Mojo Manual](manual/index.md): A comprehensive guide to the Mojo programming language.
- [Mojo language basics](manual/basics.md): An overview of the Mojo language.
- [Types](manual/types.md): Standard Mojo data types.
- [Value lifecycles](manual/lifecycle/index.md): How Mojo values are created, initialized, and destroyed.
- [Initialization state](manual/lifecycle/initialization.md): Understand when a value is initialized and ready to use.
- [Explicit destruction](manual/lifecycle/explicit-destroy.md): Require values to be deliberately destroyed in code.
- [Automatic destruction](manual/lifecycle/death.md): Let Mojo destroy values automatically after their last use.
- [Creating values](manual/lifecycle/life.md): Construct values with generated and custom initializers.
- [Intro to pointers](manual/pointers/index.md): An overview of accessing memory using Mojo's pointer types.
- [Using pointers](manual/pointers/using-pointers.md): Using pointers and dynamically-allocated memory.
- [Python interoperability](manual/python/index.md): Using Python and Mojo together.
- [Calling Python from Mojo](manual/python/python-from-mojo.md): How to import and use Python modules in Mojo code.
- [Calling Mojo from Python](manual/python/mojo-from-python.md): How to import and use Mojo modules in Python code.
- [Python types](manual/python/types.md): Using Mojo types in Python, and Python types in Mojo.
- [Mojo structs](manual/structs/index.md): Introduction to Mojo structures (structs).
- [Add operator support to custom types](manual/structs/operator-support.md): Implement operators for your custom types by creating dunder methods in your struct.
- [Self-referential structs](manual/structs/reference.md): Mojo structs can't directly contain themselves. Learn how to use pointers to build linked lists, trees, and other self-referential data structures.
- [Intro to value ownership](manual/values/index.md): Introduction to Mojo value ownership.
- [Value semantics](manual/values/value-semantics.md): An explanation of Mojo's value-semantic defaults.
- [Ownership](manual/values/ownership.md): How Mojo shares references through function arguments.
- [Lifetimes, origins, and references](manual/values/lifetimes.md): Working with origins and references.
- [Functions](manual/functions.md): Introduction to Mojo functions.
- [Variables](manual/variables.md): Introduction to Mojo variables.
- [Modules and packages](manual/packages.md): Learn how to organize Mojo code into modules and packages.
- [Operators](manual/operators.md): Arithmetic, comparison, bitwise, boolean, and assignment operators in Mojo, with precedence and examples.
- [Control flow](manual/control-flow.md): Mojo control flow statements.
- [Errors, error handling, and context managers](manual/errors.md)
- [Get started with Mojo](manual/get-started.md): Learn Mojo syntax by building Conway's Game of Life
- [Mojo quickstart](manual/quickstart.md): Get up and running fast with the Mojo programming language
- [Mojo tips for Python devs](manual/python-to-mojo.md): Learn where Python instincts apply in Mojo and where they don't.
- [Parameterized declarations](manual/generics.md): Write code that builds and runs across many types using parameterized declarations.
- [Traits](manual/traits.md): What a trait is, why Mojo needs them, and how to use one.
- [Using Mojo's C foreign function interface to call C libraries](manual/c-ffi.md): Call C libraries from Mojo. Pass values, pointers, strings, and structs safely across the FFI boundary.
- [Closures](manual/functions/closures.md): Functions that capture values from their surrounding scope
- [Lambda expressions](manual/functions/lambda.md): Lambda expressions are small anonymous functions that let you write immediate custom behavior for use in other statements and functions.
- [Intro to metaprogramming](manual/metaprogramming/index.md): An overview of Mojo's metaprogramming features.
- [Compile-time evaluation](manual/metaprogramming/comptime-evaluation.md): When and how code is executed at compile time.
- [Comptime constraints and assertions](manual/metaprogramming/constraints.md): How to use Mojo's constraint system to express program guarantees.
- [Materializing compile-time values at run time](manual/metaprogramming/materialization.md): How to use compile-time values at run time.
- [Reflection](manual/metaprogramming/reflection.md)
- [Parameterization](manual/parameters/index.md): Creating and using parameterized structs and functions.

## Cheat sheets

- [Mojo cheat sheets](reference/cheat-sheets/index.md): Quick reference cards for Mojo essentials.
- [Mojo basics cheat sheet](reference/cheat-sheets/basics.md): Syntax essentials: the core you reach for first.
- [Mojo compile-time cheat sheet](reference/cheat-sheets/compile-time.md): Reasoning and optimization. What the compiler knows and does with facts.
- [Mojo conversions cheat sheet](reference/cheat-sheets/conversions.md): Make one, convert one, access one. Remember to cast.
- [Mojo ownership cheat sheet](reference/cheat-sheets/ownership.md): Who owns a value, and how it passes between functions.
- [Mojo traits cheat sheet](reference/cheat-sheets/traits.md): What each standard library trait does, when you need it, and where it bites.
- [Mojo types & literals cheat sheet](reference/cheat-sheets/types-and-literals.md): Numbers, SIMD, conversions, and how to write values.

## Language reference

- [Mojo language reference](reference/index.md): Reference for the syntax, keywords, decorators, and more
- [Mojo closure declarations reference](reference/closure-declarations.md): Reference for Mojo closure declaration syntax. Covers capture lists, capture conventions, the transfer sigil, parametric closures, declaration-level effects, nesting, and the common capture-list errors.
- [Mojo compound statements reference](reference/compound-statements.md): Complete reference for Mojo compound statements. Covers if statements, match statements and patterns, if case and while case, loops, error handling with try/except, context managers with with, and compile-time control flow with comptime if/for/match.
- [Mojo docstring reference](reference/docstrings.md): Complete reference for Mojo docstrings. Covers placement, first-sentence rules, structured sections (Parameters, Args, Returns, Raises, Constraints), freeform sections, code examples, the %# hidden-line directive, inline formatting, math, and the @doc_hidden decorator.
- [Mojo expression reference](reference/expressions.md): Complete reference for Mojo expressions. Covers parenthesized expressions, tuples, collection literal expressions, member access, calls, subscripts, slices, ternary conditionals, walrus operator, compile-time expressions, and comprehensions.
- [Mojo function declarations reference](reference/function-declarations.md): Reference for Mojo function declaration syntax. Covers signatures, argument conventions, markers, variadic arguments, effects, return types, and special methods.
- [Mojo function overload reference](reference/function-overloads.md): Reference for function overloads, one of two or more function declarations that share a name but differ in their signature.
- [Mojo identifiers, keywords, and conventions reference](reference/keywords.md): Complete reference for Mojo identifiers, keywords, and conventions. Covers naming rules, reserved words, escaped identifiers, argument and variable conventions, and signature clauses.
- [Mojo inline MLIR reference](reference/inline-mlir.md): Use Mojo's inline MLIR built-ins to call hardware intrinsics, atomic operations, and GPU dialect operations that the language doesn't yet expose natively.
- [Mojo lambda expressions reference](reference/lambda-expressions.md): Reference for Mojo lambda expressions. Covers lambda signature grammar, capture lists and return types, thin lambdas versus lambda closures.
- [Mojo lexical structure reference](reference/lexical-structure.md): Complete reference for Mojo lexical structure. Covers source text, lines, indentation, line continuation, comments, semicolons, commas, delimiters, and token separation.
- [Mojo literals reference](reference/literals.md): Complete reference for Mojo literal syntax. Covers integer, floating-point, string, t-string, boolean, None, Self, discard, and ellipsis literals with lexical rules and examples.
- [Mojo numeric types reference](reference/numeric-types.md): Complete reference for Mojo numeric types. Covers SIMD, DType, Scalar, Int, UInt, sized integers, floating-point types, Byte, numeric literals, and explicit conversions.
- [Mojo operator reference](reference/operators.md): Operator precedence, associativity, and symbols for Mojo.
- [Mojo simple statements reference](reference/simple-statements.md): Complete reference for Mojo simple statements. Covers import statements, expression statements, assignment statements, and other simple statements.
- [Mojo struct declarations reference](reference/struct-declarations.md): Reference for Mojo struct declarations, fields, methods, parameters, trait conformance, initializers, and lifecycle methods.
- [Mojo trait declarations](reference/trait-declarations.md): Reference for Mojo trait declarations, required and provided methods, associated types, trait refinement, trait composition, and conformance rules.
- [Mojo types reference](reference/types.md): Reference for Mojo's built-in types: the numeric, string, collection, memory, and other types every program can use without an import.
- [Mojo decorators](reference/decorators/index.md): A reference of Mojo's built-in decorators
- [@__copy_capture](reference/decorators/copy-capture.md): Captures register-passable typed values by copy (deprecated).
- [@__parameter](reference/decorators/parameter.md): Declares a legacy closure (deprecated).
- [@align](reference/decorators/align.md): Specifies a minimum alignment for a struct.
- [@always_inline](reference/decorators/always-inline.md): Copies the body of a function directly into the body of the calling function (in new code, use @inline instead).
- [@deprecated](reference/decorators/deprecated.md): Mojo's `@deprecated` decorator marks outdated APIs and schedules them for removal. When used with the `use` parameter, it also provides migration suggestions.
- [@doc_hidden](reference/decorators/doc-hidden.md): Hides declarations from generated documentation.
- [@export](reference/decorators/export.md): Marks a function for export.
- [@fieldwise_init](reference/decorators/fieldwise-init.md): Generates fieldwise initializer for a struct.
- [@implicit](reference/decorators/implicit.md): Marks an initializer as eligible for implicit conversion.
- [@inline](reference/decorators/inline.md): Sets a function's inline level.
- [@no_inline](reference/decorators/no-inline.md): Prevents a function from being inlined (in new code, use @inline instead).
- [@staticmethod](reference/decorators/staticmethod.md): Declares a struct method as static.

## Tools

- [Compilation targets](tools/compilation.md): Build Mojo code for a different architecture, CPU, or GPU than your development machine.
- [Mojo compilation feature toggles](tools/feature-toggles.md): How to conditionally enable or disable behavior in Mojo code at compile time.
- [Debugging](tools/debugging.md): Debugging Mojo programs.
- [Testing](tools/testing.md): Testing Mojo programs.
- [Jupyter notebooks](tools/notebooks.md): Using Mojo in local and Colab Jupyter Notebooks
- [Mojo AI skills](tools/skills.md): Official AI agent skills for developing projects with Mojo and MAX. Follows the Agent Skills Standard and encodes best practices for AI coding agents.
- [Packaging](tools/packaging.md): How to package your Mojo project for distribution

## API docs and stability

- [How to read the standard library API documentation](api-docs/index.md): Read Mojo API and function signatures, including declaration syntax, parameters, brackets, parentheses, and slashes.
- [Mojo stability guarantees](api-docs/stability.md): Learn which Mojo language features and APIs are considered stable and which are subject to change or removal.

## Release notes

- [Mojo v1.0.0](releases/v1.0.0.md): What changed in Mojo 1.0.0.
- [Mojo v1.1.0](releases/v1.1.0.md): What changed in Mojo 1.1.0.
- [Mojo v1.2.0](releases/v1.2.0.md): What changed in Mojo 1.2.0.

## Direction

- [Mojo roadmap](roadmap.md): A summary of our plans and priorities to improve the Mojo language.
- [Mojo vision](vision.md): Our motivations and the design decisions that define the Mojo programming language

## Standard library

- [`std`](std/index.md): All the data types, structs, traits, functions, and other APIs included with Mojo.
- [`std.simd`](std/simd.md): Implements SIMD primitives and abstractions.
- [`std.algorithm`](std/algorithm/index.md): High performance data operations including vectorization, functional map, and tiling.
- [`std.algorithm.functional`](std/algorithm/functional.md): Implements higher-order functions.
- [`std.algorithm.backend`](std/algorithm/backend/index.md): Implements algorithm backend utilities including tiling and unswitching.
- [`std.algorithm.backend.tile`](std/algorithm/backend/tile.md): Implementations of tile functions.
- [`std.algorithm.backend.unswitch`](std/algorithm/backend/unswitch.md): Implementations of unswitch and tile_and_unswitch functions.
- [`std.algorithm.backend.vectorize`](std/algorithm/backend/vectorize.md): Implementations of vectorize functions.
- [`std.algorithm.backend.cpu`](std/algorithm/backend/cpu/index.md): Implements CPU algorithm backend utilities including map, tiling, and vectorization.
- [`std.algorithm.backend.cpu.map`](std/algorithm/backend/cpu/map.md): CPU implementation of the map function.
- [`std.atomic`](std/atomic/index.md): Atomic operations and memory orderings.
- [`std.atomic.atomic`](std/atomic/atomic.md): Implements the `Atomic` struct.
- [`std.base64`](std/base64/index.md): Binary data encoding: base64 and base16 encode/decode functions.
- [`std.base64.base64`](std/base64/base64.md): Provides functions for base64 encoding strings.
- [`std.benchmark`](std/benchmark/index.md): Performance benchmarking: statistical analysis and detailed reports.
- [`std.benchmark.bencher`](std/benchmark/bencher.md): Implements comprehensive benchmarking infrastructure with statistical analysis.
- [`std.benchmark.benchmark`](std/benchmark/benchmark.md): Implements the benchmark module for runtime benchmarking.
- [`std.benchmark.compiler`](std/benchmark/compiler.md): Provides compiler hints to prevent optimization of benchmark code.
- [`std.benchmark.memory`](std/benchmark/memory.md): Provides memory barrier utilities for preventing compiler optimizations.
- [`std.benchmark.quick_bench`](std/benchmark/quick_bench.md): Provides simplified benchmarking interface with automatic boilerplate handling.
- [`std.bit`](std/bit/index.md): Bitwise operations: manipulation, counting, rotation, and power-of-two utilities.
- [`std.bit.bit`](std/bit/bit.md): Provides functions for bit manipulation.
- [`std.bit.mask`](std/bit/mask.md): Provides functions for bit masks.
- [`std.builtin`](std/builtin/index.md): Language foundation: built-in types, traits, and fundamental operations.
- [`std.builtin.anytype`](std/builtin/anytype.md): Existential-type helpers built on `AnyType`, plus deprecated aliases for the traits that used to live in this module.
- [`std.builtin.bool`](std/builtin/bool.md): Implements the Bool class.
- [`std.builtin.breakpoint`](std/builtin/breakpoint.md): This module includes the builtin breakpoint function.
- [`std.builtin.builtin_slice`](std/builtin/builtin_slice.md): Implements slice.
- [`std.builtin.comparable`](std/builtin/comparable.md): Implements comparison and equality traits for Mojo types.
- [`std.builtin.constrained`](std/builtin/constrained.md): Implements compile-time constraint helpers used by trait conformance checks.
- [`std.builtin.debug_assert`](std/builtin/debug_assert.md): Implements run-time assertions.
- [`std.builtin.device_passable`](std/builtin/device_passable.md): Implements the `DevicePassable` trait for types transferable to accelerator devices.
- [`std.builtin.dtype`](std/builtin/dtype.md): Implements the DType class.
- [`std.builtin.enum_like`](std/builtin/enum_like.md): Defines the `EnumLike` trait used by enum-style pattern matching.
- [`std.builtin.error`](std/builtin/error.md): Implements the Error class.
- [`std.builtin.float_literal`](std/builtin/float_literal.md): Implements the FloatLiteral class.
- [`std.builtin.floatable`](std/builtin/floatable.md): Implements the `Floatable` and `FloatableRaising` traits.
- [`std.builtin.format_int`](std/builtin/format_int.md): Provides the `hex` and `bin` functions.
- [`std.builtin.globals`](std/builtin/globals.md): Utilities for working with global constants.
- [`std.builtin.identifiable`](std/builtin/identifiable.md): Defines the Identifiable trait for identity-based comparisons.
- [`std.builtin.inline_level`](std/builtin/inline_level.md): Provides the levels the `@inline` decorator accepts.
- [`std.builtin.int`](std/builtin/int.md): Implements the Int class.
- [`std.builtin.int_literal`](std/builtin/int_literal.md): Implements the IntLiteral class.
- [`std.builtin.len`](std/builtin/len.md): Provides the `len()` function and its associated traits.
- [`std.builtin.none`](std/builtin/none.md): Defines the builtin `NoneType`.
- [`std.builtin.range`](std/builtin/range.md): Defines Mojo's built-in `range()` function.
- [`std.builtin.rebind`](std/builtin/rebind.md): Implements type rebind/trait downcast.
- [`std.builtin.reversed`](std/builtin/reversed.md): Provides the `reversed` function for reverse iteration over collections.
- [`std.builtin.simd_length`](std/builtin/simd_length.md): Implements `SIMDLength`, which is a wrapper around the MLIR `index` type.
- [`std.builtin.sort`](std/builtin/sort.md): Implements the built-in `sort` function.
- [`std.builtin.string_literal`](std/builtin/string_literal.md): Implements the StringLiteral struct.
- [`std.builtin.swap`](std/builtin/swap.md): Implements the built-in `swap` function.
- [`std.builtin.tuple`](std/builtin/tuple.md): Implements the Tuple type.
- [`std.builtin.type_aliases`](std/builtin/type_aliases.md): Defines some type aliases.
- [`std.builtin.value`](std/builtin/value.md): Defines `Defaultable`, `RegisterPassable`, and `TrivialRegisterPassable`, plus deprecated aliases for the value-semantics traits that used to live in this module.
- [`std.builtin.variadics`](std/builtin/variadics.md): Implements the VariadicList, ParameterList and VariadicPack types.
- [`std.collections`](std/collections/index.md): Core data types: List, Dict, Set, Optional, String, and other collections.
- [`std.collections.array`](std/collections/array.md): Provides a fixed-size array implementation with compile-time size checking.
- [`std.collections.binary_heap`](std/collections/binary_heap.md): Defines a BinaryHeap type.
- [`std.collections.bitset`](std/collections/bitset.md): Provides a compact set of non-negative integers backed by inline storage.
- [`std.collections.check_bounds`](std/collections/check_bounds.md): Contains bounds checks which are on by default for CPU and off by default for GPU.
- [`std.collections.counter`](std/collections/counter.md): Defines the `Counter` type.
- [`std.collections.deque`](std/collections/deque.md): Defines the Deque type.
- [`std.collections.dict`](std/collections/dict.md): Defines `Dict`, a collection that stores key-value pairs.
- [`std.collections.interval`](std/collections/interval.md): A self-balancing interval tree is a specialized binary search tree designed to efficiently store and query intervals.
- [`std.collections.linked_list`](std/collections/linked_list.md): Implements a doubly-linked list data structure.
- [`std.collections.list`](std/collections/list.md): Defines the List type.
- [`std.collections.optional`](std/collections/optional.md): Defines Optional, a type modeling a value which may or may not be present.
- [`std.collections.set`](std/collections/set.md): Implements the Set datatype.
- [`std.collections.span`](std/collections/span.md): Implements the `Span` type.
- [`std.collections.type_dict`](std/collections/type_dict.md): Provides a data structure which acts to map a value of a given type to one of a set of types.
- [`std.collections.string`](std/collections/string/index.md): Provides comprehensive Unicode string functionality.
- [`std.collections.string.codepoint`](std/collections/string/codepoint.md): Unicode codepoint handling.
- [`std.collections.string.format`](std/collections/string/format.md): String formatting utilities for Mojo.
- [`std.collections.string.iterators`](std/collections/string/iterators.md): Implements the iterators and related utilities for efficient string operations.
- [`std.collections.string.string`](std/collections/string/string.md): Implements the core `String` type and related utilities.
- [`std.collections.string.string_span`](std/collections/string/string_span.md): Implements the `StringSpan` type and related utilities for efficient string operations.
- [`std.compile`](std/compile/index.md): Runtime function compilation and introspection: assembly, IR, linkage, metadata.
- [`std.compile.compile`](std/compile/compile.md): Provides utilities for compiling and inspecting Mojo code.
- [`std.complex`](std/complex/index.md): Complex numbers: SIMD types, scalar types, and operations.
- [`std.complex.complex`](std/complex/complex.md): Implements the Complex dtype.
- [`std.documentation`](std/documentation/index.md): Documentation built-ins: decorators and utilities for doc generation.
- [`std.documentation.documentation`](std/documentation/documentation.md): Provides decorators and utilities for interacting with Mojo documentation generation and validation.
- [`std.ffi`](std/ffi/index.md): Foreign function interface (FFI) for calling C code and loading libraries.
- [`std.ffi.cstring`](std/ffi/cstring.md): Implements C string interoperability utilities.
- [`std.ffi.unsafe_union`](std/ffi/unsafe_union.md): Defines an untagged union type for C FFI interoperability.
- [`std.format`](std/format/index.md): Provides formatting traits for converting types to text.
- [`std.format.repr`](std/format/repr.md): Implements the `repr()` function for producing string representations of values.
- [`std.format.tstring`](std/format/tstring.md): Implements `TString`, a template string that captures interpolated values at compile-time.
- [`std.hash`](std/hash/index.md): Cryptographic and non-cryptographic hashing with customizable algorithms.
- [`std.hash.hash`](std/hash/hash.md): Implements the `Hashable` trait and `hash()` built-in function.
- [`std.hash.hasher`](std/hash/hasher.md): Defines the Hasher trait and default hasher implementations.
- [`std.io`](std/io/index.md): Core I/O operations: console input/output, file handling, writing traits.
- [`std.io.file`](std/io/file.md): Provides APIs to read and write files.
- [`std.io.file_descriptor`](std/io/file_descriptor.md): Higher level abstraction for file stream.
- [`std.io.io`](std/io/io.md): Provides utilities for working with input/output.
- [`std.io.write`](std/io/write.md): Implements I/O write interfaces.
- [`std.iter`](std/iter/index.md): Iteration traits and utilities: Iterable, IterableOwned, Iterator, enumerate, zip, map.
- [`std.itertools`](std/itertools/index.md): Iterator tools for lazy sequence generation and transformation.
- [`std.itertools.itertools`](std/itertools/itertools.md): Provides iterator utilities for common iteration patterns.
- [`std.logger`](std/logger/index.md): Logging with configurable severity levels.
- [`std.logger.logger`](std/logger/logger.md): Provides logging functionality with different severity levels.
- [`std.math`](std/math/index.md): Math functions and constants: trig, exponential, logarithmic, and special functions.
- [`std.math.constants`](std/math/constants.md): Defines math utilities.
- [`std.math.fast`](std/math/fast.md): Defines fast math approximation utilities.
- [`std.math.math`](std/math/math.md): Defines math utilities.
- [`std.math.polynomial`](std/math/polynomial.md): Provides two implementations for evaluating polynomials.
- [`std.math.uutils`](std/math/uutils.md): Utilities for doing unsigned division and modulo operations on `Int`.
- [`std.memory`](std/memory/index.md): Low-level memory management: pointers, allocations, address spaces.
- [`std.memory.address_space`](std/memory/address_space.md): Implements `AddressSpace`, the memory address space of a pointer.
- [`std.memory.alloc`](std/memory/alloc.md): Implements layout-aware memory allocation and deallocation.
- [`std.memory.arc_pointer`](std/memory/arc_pointer.md): Reference-counted smart pointers.
- [`std.memory.maybe_uninit`](std/memory/maybe_uninit.md): Implements `MaybeUninit`, a wrapper for memory that may or may not be initialized.
- [`std.memory.memory`](std/memory/memory.md): Defines functions for memory manipulations.
- [`std.memory.owned_pointer`](std/memory/owned_pointer.md): Implements `OwnedPointer`, a safe, single-ownership smart pointer.
- [`std.memory.pointer`](std/memory/pointer.md): Implements `Pointer`, Mojo's primary pointer type for indirect memory access.
- [`std.memory.stack_allocation`](std/memory/stack_allocation.md): Defines the `unsafe_stack_allocation` function for stack-based memory allocation.
- [`std.memory.unsafe`](std/memory/unsafe.md): Provides utility functions for unsafe manipulation of SIMD values.
- [`std.memory.unsafe_pointer`](std/memory/unsafe_pointer.md): Defines `UnsafePointer` as a backward-compatible name for `Pointer`.
- [`std.net`](std/net/index.md): Provides networking support.
- [`std.origin`](std/origin/index.md): Defines Mojo's origin types.
- [`std.os`](std/os/index.md): OS interface layer: environment, filesystem, process control.
- [`std.os.env`](std/os/env.md): Provides functions for working with environment variables.
- [`std.os.fstat`](std/os/fstat.md): Implements file system status operations.
- [`std.os.os`](std/os/os.md): Provides functions to access operating-system dependent functionality, including file system operations.
- [`std.os.pathlike`](std/os/pathlike.md): Implements the `PathLike` trait.
- [`std.os.process`](std/os/process.md): Implements os methods for dealing with processes.
- [`std.os.path`](std/os/path/index.md): Provides a set of operating-system independent functions for manipulating file system paths.
- [`std.os.path.path`](std/os/path/path.md): Provides a set of operating-system independent functions for manipulating file system paths.
- [`std.pathlib`](std/pathlib/index.md): Filesystem path manipulation and navigation.
- [`std.pathlib.path`](std/pathlib/path.md): Path manipulation module.
- [`std.prelude`](std/prelude/index.md): Standard library prelude: fundamental types, traits, and operations auto-imported.
- [`std.pwd`](std/pwd/index.md): Password database lookups for user account information.
- [`std.pwd.pwd`](std/pwd/pwd.md): Provides access to the user password database on Unix-like systems.
- [`std.python`](std/python/index.md): Python interoperability: import packages and modules, call functions, type conversion.
- [`std.python.bindings`](std/python/bindings.md): Provides infrastructure for creating Python bindings to Mojo code.
- [`std.python.conversions`](std/python/conversions.md): Implements conversion traits to and from PythonObject.
- [`std.python.numpy`](std/python/numpy.md): NumPy interoperability helpers for Mojo collections.
- [`std.python.python`](std/python/python.md): Implements Python interoperability.
- [`std.python.python_object`](std/python/python_object.md): Implements PythonObject.
- [`std.random`](std/random/index.md): Pseudorandom number generation with uniform and normal distributions.
- [`std.random.philox`](std/random/philox.md): Random number generation using the Philox algorithm.
- [`std.random.random`](std/random/random.md): Provides functions for pseudorandom numbers.
- [`std.reflection`](std/reflection/index.md): Compile-time reflection utilities for introspecting Mojo types and functions.
- [`std.reflection.function`](std/reflection/function.md): Compile-time reflection over function values.
- [`std.reflection.location`](std/reflection/location.md): Implements utilities to capture and represent source code location.
- [`std.reflection.reflect`](std/reflection/reflect.md): Provides the unified `reflect[T]` / `Reflected[T]` reflection API.
- [`std.reflection.type_info`](std/reflection/type_info.md): Provides function name introspection utilities.
- [`std.runtime`](std/runtime/index.md): Runtime services: runtime initialization and worker-thread queries.
- [`std.stat`](std/stat/index.md): File type constants and detection from stat system calls.
- [`std.stat.stat`](std/stat/stat.md): Provides constants and functions for interpreting file mode bits.
- [`std.subprocess`](std/subprocess/index.md): Execute external processes and commands.
- [`std.subprocess.subprocess`](std/subprocess/subprocess.md): Provides utilities for executing shell commands and capturing output.
- [`std.sys`](std/sys/index.md): System runtime: I/O, hardware info, intrinsics, compile-time utils.
- [`std.sys.arg`](std/sys/arg.md): Implements functions and variables for interacting with execution and system environment.
- [`std.sys.compile`](std/sys/compile.md): Implements functions that return compile-time information.
- [`std.sys.debug`](std/sys/debug.md): This module includes the debug hook functions.
- [`std.sys.defines`](std/sys/defines.md): Implements functions for retrieving compile-time defines.
- [`std.sys.info`](std/sys/info.md): Implements methods for querying the host target info.
- [`std.sys.intrinsics`](std/sys/intrinsics.md): Defines intrinsics.
- [`std.sys.terminate`](std/sys/terminate.md): This module includes the exit functions.
- [`std.tempfile`](std/tempfile/index.md): Manage temporary files and directories: create, locate, and cleanup.
- [`std.tempfile.tempfile`](std/tempfile/tempfile.md): Temporary file and directory creation.
- [`std.testing`](std/testing/index.md): Unit testing: Assertions (equal, true, raises) and test suites.
- [`std.testing.assert_aborts`](std/testing/assert_aborts.md): Asserts that code aborts the process, without losing the rest of the test suite.
- [`std.testing.suite`](std/testing/suite.md): Implements test suite infrastructure for organizing and running tests.
- [`std.testing.testing`](std/testing/testing.md): Implements various testing utils.
- [`std.testing.prop`](std/testing/prop/index.md): A property testing package.
- [`std.testing.prop.random`](std/testing/prop/random.md): Implements random number generation for property-based testing.
- [`std.testing.prop.runner`](std/testing/prop/runner.md): Implements the property test runner and configuration.
- [`std.testing.prop.strategy`](std/testing/prop/strategy/index.md): Implements the `Strategy` trait and exports built-in strategies for property-based testing.
- [`std.testing.prop.strategy.list_strategy`](std/testing/prop/strategy/list_strategy.md): Implements the list strategy for generating random `List` values in property tests.
- [`std.testing.prop.strategy.simd_strategy`](std/testing/prop/strategy/simd_strategy.md): Implements the SIMD strategy for generating random `SIMD` values in property tests.
- [`std.testing.prop.strategy.string_strategy`](std/testing/prop/strategy/string_strategy.md): Implements the string strategy for generating random `String` values in property tests.
- [`std.time`](std/time/index.md): Timing operations: monotonic clocks, performance counters, sleep, time_function.
- [`std.time.time`](std/time/time.md): Implements basic utils for working with time.
- [`std.traits`](std/traits/index.md): Core object-lifetime and value-semantics traits.
- [`std.traits.anytype`](std/traits/anytype.md): Defines `AnyType`, the most basic trait that all Mojo types extend by default.
- [`std.traits.copyable`](std/traits/copyable.md): Defines `Copyable` and `ImplicitlyCopyable`, the traits for types whose value can be copied.
- [`std.traits.deinitable`](std/traits/deinitable.md): Defines `Deinitable`, the trait for types with lifetime management through destructors.
- [`std.traits.movable`](std/traits/movable.md): Defines `Movable`, the trait for types whose value can be moved.
- [`std.utils`](std/utils/index.md): General utils: indexing, variants, static tuples, and thread synchronization.
- [`std.utils.coord`](std/utils/coord.md): Unified layout system for mixed compile-time and runtime indices.
- [`std.utils.fast_div`](std/utils/fast_div.md): Implements the fast division algorithm.
- [`std.utils.index`](std/utils/index.md): Implements `IndexList` which is commonly used to represent N-D indices.
- [`std.utils.lock`](std/utils/lock.md): Implements thread synchronization primitives including spin locks.
- [`std.utils.numerics`](std/utils/numerics.md): Defines utilities to work with numeric types.
- [`std.utils.static_tuple`](std/utils/static_tuple.md): Implements StaticTuple, a statically-sized uniform container.
- [`std.utils.variant`](std/utils/variant.md): Defines a Variant type.

## License

- [LICENSE.txt](LICENSE.txt): Apache-2.0 with LLVM Exceptions, Modular's terms for these docs
