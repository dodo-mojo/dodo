# Mojo decorators

*From Modular's Mojo docs (`Mojo/docs/site/reference/decorators/index.mdx` at tag `mojo/v1.2.0`, Apache-2.0 with LLVM Exceptions, see `LICENSE.txt`), turned into plain Markdown by dodo.*

A Mojo decorator modifies or extends the behavior of a struct, function, or
other declaration at compile time. You place the decorator on the line
above the declaration it applies to, prefixed with `@`.

```mojo
@fieldwise_init
struct Point:
    var x: Float64
    var y: Float64
```

After the `@`, a decorator is followed by a name, with optional arguments
in parentheses. Each decorator goes on its own line. You can stack multiple
decorators on a single declaration:

```mojo
@fieldwise_init
@align(64)
struct CacheLine:
    var data: SIMD[DType.float32, 16]
```

Decorators apply bottom-up: the one closest to the declaration
is applied first.

**Note: No custom decorators**
Mojo doesn't support custom decorators. The decorators in this section
are built into the compiler.

## Decorators

The following pages describe each built-in decorator with examples.

- [@__copy_capture](../../reference/decorators/copy-capture.md): Captures register-passable typed values by copy (deprecated).
- [@__parameter](../../reference/decorators/parameter.md): Declares a legacy closure (deprecated).
- [@align](../../reference/decorators/align.md): Specifies a minimum alignment for a struct.
- [@always_inline](../../reference/decorators/always-inline.md): Copies the body of a function directly into the body of the calling function (in new code, use @inline instead).
- [@deprecated](../../reference/decorators/deprecated.md): Mojo's `@deprecated` decorator marks outdated APIs and schedules them for removal. When used with the `use` parameter, it also provides migration suggestions.
- [@doc_hidden](../../reference/decorators/doc-hidden.md): Hides declarations from generated documentation.
- [@export](../../reference/decorators/export.md): Marks a function for export.
- [@fieldwise_init](../../reference/decorators/fieldwise-init.md): Generates fieldwise initializer for a struct.
- [@implicit](../../reference/decorators/implicit.md): Marks an initializer as eligible for implicit conversion.
- [@inline](../../reference/decorators/inline.md): Sets a function's inline level.
- [@no_inline](../../reference/decorators/no-inline.md): Prevents a function from being inlined (in new code, use @inline instead).
- [@staticmethod](../../reference/decorators/staticmethod.md): Declares a struct method as static.

## Decorator targets

Not every decorator works on every declaration. This table shows
which decorators are valid on which targets.

| Decorator                     | `struct` | `def`           | method | `trait` | `comptime` | `var` | field |
|-------------------------------|----------|-----------------|--------|---------|------------|-------|-------|
| `@align`                      | yes      |                 |        |         |            |       |       |
| `@always_inline` <sup>1</sup> |          | yes             | yes    |         |            |       |       |
| `@__copy_capture`             |          | yes<sup>2</sup> |        |         |            |       |       |
| `@deprecated`                 | yes      | yes             | yes    | yes     | yes        |       |       |
| `@doc_hidden`                 | yes      | yes             | yes    |         | yes        |       | yes   |
| `@export`                     |          | yes             |        |         |            |       |       |
| `@fieldwise_init`             | yes      |                 |        |         |            |       |       |
| `@implicit`                   |          |                 | yes    |         |            |       |       |
| `@inline`                     |          | yes             | yes    |         |            |       |       |
| `@no_inline` <sup>1</sup>     |          | yes             | yes    |         |            |       |       |
| `@__parameter`                |          | yes<sup>2</sup> |        |         |            |       |       |
| `@staticmethod`               |          |                 | yes    |         |            |       |       |

<sup>1</sup>Prefer `@inline` for new code.

<sup>2</sup>`@__copy_capture` and `@__parameter` work only on *nested*
functions.
