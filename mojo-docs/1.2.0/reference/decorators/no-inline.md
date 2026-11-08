# @no_inline

*From Modular's Mojo docs (`Mojo/docs/site/reference/decorators/no-inline.mdx` at tag `mojo/v1.2.0`, Apache-2.0 with LLVM Exceptions, see `LICENSE.txt`), turned into plain Markdown by dodo.*

**Caution**

In new code, prefer [`@inline`](../../reference/decorators/inline.md), which sets
the same inline levels and can also take the level from a parameter.
`@no_inline` is equivalent to `@inline(.never)`.

You can add the `@no_inline` decorator on any function to prevent it from being
inlined by the compiler.

```mojo
@no_inline
def my_large_function():
    ...
```

Inlining is an optimization that reduces function call overhead for small,
frequently-called functions. Functions can be explicitly marked for inlining
using
[`@always_inline`](../../reference/decorators/always-inline.md), or may be inlined
automatically by the compiler.

Too many inlined functions can slow compilation and substantially increase the
binary size of the compiled program. In particular, large or complex functions
may not benefit as much from inlining.
