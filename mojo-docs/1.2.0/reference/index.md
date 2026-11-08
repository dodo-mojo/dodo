# Mojo language reference

*From Modular's Mojo docs (`Mojo/docs/site/reference/index.mdx` at tag `mojo/v1.2.0`, Apache-2.0 with LLVM Exceptions, see `LICENSE.txt`), turned into plain Markdown by dodo.*

The Mojo language reference provides a concise guide for Mojo's syntax,
organized by grammar construct and designed for quick lookup when you need the
exact rules or form of a language element.

  - [Mojo cheat sheets](../reference/cheat-sheets/index.md): Quick reference cards for Mojo's syntax and keywords
  - [Identifiers and keywords](../reference/keywords.md): Naming rules, reserved words, escaped identifiers, and argument conventions
  - [Lexical structure](../reference/lexical-structure.md): Lines, indentation, line continuation, comments, semicolons, commas, and delimiters
  - [Literals](../reference/literals.md): Integer, floating-point, string, t-string, boolean, None, and Self literals
  - [Types](../reference/types.md): Built-in types available without an import
  - [Numeric types](../reference/numeric-types.md): `SIMD`, `DType`, `Scalar`, `Int`, integers, floating-point, `Byte`, and conversions
  - [Operators](../reference/operators.md): Operator precedence, associativity, and implementing operators for custom types
  - [Expressions](../reference/expressions.md): Tuples, collection displays, member access, calls, subscripts, ternary conditionals, and comprehensions
  - [Simple statements](../reference/simple-statements.md): Imports, assignments, return, raise, break, continue, and compile-time declarations
  - [Compound statements](../reference/compound-statements.md): `if` statements, loops, error handling with `try`/`except`, context managers, and compile-time control flow
  - [Function declarations](../reference/function-declarations.md): Signatures, parameters, arguments, default values, constraints, effects, overloads, and special methods
  - [Function overloads](../reference/function-overloads.md): One of two or more function declarationsthat share a name but differ in their signature.
  - [Struct declarations](../reference/struct-declarations.md): Fields, methods, initializers, deinitializers, and trait conformance for structs
  - [Trait declarations](../reference/trait-declarations.md): Required and provided methods, associated types, trait refinement, trait composition, and conformance
  - [Closure declarations](../reference/closure-declarations.md): Capture lists, capture conventions, transfer capture, parametric closures, and effects
  - [Lambda expressions](../reference/lambda-expressions.md): Anonymous single-expression functions, omitted capture lists, and thin function values
  - [Inline MLIR](../reference/inline-mlir.md): Built-ins for calling MLIR operations the language doesn't expose natively
  - [Docstrings](../reference/docstrings.md): Sections, placement, formatting, code examples, and compiler checks
  - [Decorators](../reference/decorators/index.md): Modify or extend the behavior of structs, functions, and other declarations at compile time
