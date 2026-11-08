# What changed in Mojo 1.x

*Written by dodo, not by Modular. Old Mojo code and old habits next to the
1.x form. Every row marked "built" was compiled with Mojo 1.2.0 on
2026-11-08: the new form builds with no warning, and the right column is what
the compiler said about the old form. Rows marked "notes" come from the
[release notes](releases/v1.0.0.md) and were not built here.*

## Keywords and declarations

| Before | Now | Mojo 1.2.0 on the old form |
|---|---|---|
| `fn add(a: Int) -> Int:` | `def add(a: Int) -> Int:` | built: error, `'fn' has been removed; use 'def' instead` |
| `alias N = 4` | `comptime N = 4` | built: error |
| `@parameter` then `for ...` / `if ...` | `comptime for ...` / `comptime if ...` | built: error, `'for' statement does not support decorators` |
| `constrained[n > 0, "msg"]()` | `comptime assert n > 0, "msg"` | built: error, `unknown declaration 'constrained'` |
| `__comptime_assert n > 0, "msg"` | `comptime assert n > 0, "msg"`, or `def f[n: Int]() where n > 0:` | built: error, `unknown declaration` |
| `def f[x: Int where x > 0]():` | `def f[x: Int]() where x > 0:` | built: error, `'where' clauses inside parameter lists are no longer supported` |
| `x = 1` (first use) | `var x = 1` | built: error, `implicit declaration of 'x' is not allowed` |
| `def f(): raise Error("bad")` | `def f() raises: raise Error("bad")` | built: error, `'raise' requires ... the enclosing function to declare 'raises'` |
| `if var v := d.get("a"):` | `var v: Optional[Int]` then `if v := d.get("a"):` | built: error. The walrus only assigns to a variable that exists. |
| `async def f():` | `__async def f():` (async is still unstable) | built: warning, `async/await support in Mojo is experimental` |
| `def f() -> ():` | `def f() -> Tuple[]:` | built: error, `expected a type, found a tuple value` |

## Arguments

| Before | Now | Mojo 1.2.0 on the old form |
|---|---|---|
| `inout x: Int` | `mut x: Int` | built: error (parse error) |
| `borrowed s: String` | `s: String` (the default, `imm`) | built: error (parse error) |
| `read s: String` | `imm s: String`, or just `s: String` | built: error, `'read' was removed; use 'imm'` |
| `owned s: String` | `var s: String` | built: error (parse error) |
| `**kwargs: Int` | `var **kwargs: Int` | built: error, `variadic keyword arguments only support the 'var' convention` |
| `def foo(self: Foo[Int]):` | `def foo(self) where Self.T == Int:` | built: error, `'self' argument must have type 'Self'` |

## Structs and traits

| Before | Now | Mojo 1.2.0 on the old form |
|---|---|---|
| `@value struct P:` | `@fieldwise_init struct P(Copyable):` | built: error, `unknown declaration 'value'` |
| `var q = p` on a `Copyable` struct | `var q = p.copy()`, or make the struct `ImplicitlyCopyable` | built: error, `cannot be implicitly copied` |
| `def __del__(deinit self):` | `def __deinit__(deinit self):` | built: warning, `'__del__' is deprecated` |
| `def __del__(owned self):` | `def __deinit__(deinit self):` | built: error (parse error) |
| `struct R(ImplicitlyDestructible):` | `struct R(Deinitable):` | built: error, `unknown declaration` |
| `@explicit_destroy struct R:` | `struct R(Deinitable where False):`, or `@explicit_destroy("why")` | built: error, `@explicit_destroy requires an argument` |
| a struct with `__call__` used as a closure | name the closure trait: `struct Double(def(Int) -> Int):` | notes (1.0) |
| struct is not `Movable` unless it says so | every struct is `Movable`; opt out with `Movable where False` | notes (1.0) |

## Imports

| Before | Now | Mojo 1.2.0 on the old form |
|---|---|---|
| `from collections import Dict` | `from std.collections import Dict` | built: error, `unable to locate module 'collections'` |
| `from std.hashlib import hash` | `from std.hash import hash` | built: error, `unable to locate module 'hashlib'` |
| `from std.gpu import thread_idx` | `from max.gpu import thread_idx` | built: error for the old form. The new form needs the MAX Mojo package, which this environment does not ship (notes, 1.1) |
| `import .foo` | `from . import foo` | notes (1.0) |
| a module using a name from its own package without importing it | `from . import foo` | notes: an error since 1.1 |
| `.mojopkg` packages | `.mojoc` packages | notes: removed in 1.1 |

## Renamed library names

| Before | Now | Mojo 1.2.0 on the old form |
|---|---|---|
| `InlineArray[Int, 3](fill=0)` | `Array[Int, 3](fill=0)` | built: error, `unknown declaration 'InlineArray'` |
| `StringSlice(s)` | `StringSpan(s)` | built: still works, with no warning (an alias) |
| `v.size` on `SIMD` or `Array` | `v.length` (a `SIMDLength`; `Int(v.length)` to print it) | built: error, `no attribute 'size'` |
| `String.write(a, b, sep=", ")` | `String(a, b, sep=", ")` | built: error, `no matching function` |
| `UnsafePointer[Int].alloc(2)`, `p.init_pointee_copy(7)`, `p.free()` | `var a = alloc(Layout[Int](count=2))` (from `std.memory.alloc`), `a.unsafe_ptr().unsafe_write(7)`, `dealloc(a^)` | built: error, `'Pointer[Int, _]' value has no attribute 'alloc'`, and a warning that `UnsafePointer` is deprecated |
| `p[0]` on a pointer | `p[unsafe_offset=0]` | built: warning, `positional __getitem__ is deprecated` |
| `memcpy`, `memset`, `memset_zero` | `unsafe_memcpy`, `unsafe_memset`, `unsafe_memset_zero` | built: error, `package 'memory' does not contain 'memcpy'` |
| `sort[less](list)` with a `@parameter` closure | `sort(list, lambda (a: Int, b: Int) -> Bool: a > b)` | built: error, `no matching function in call to 'sort'` |
| `has_nvidia_gpu_accelerator()` | `default_accelerator().is_nvidia_gpu()` (from `std.sys`) | built: error, `'sys' does not contain` |
| `List.steal_data()`, `OwnedPointer.steal_data()` | `unsafe_take_allocation()` | notes: removed in 1.1 |
| `OwnedPointer.take()`, `Variant.take()` | `into_inner()`, `unwrap()` | notes: removed in 1.1 |
| `ConditionalType[...]` | `T if cond else U` | notes: removed in 1.1 |
| `StringLiteral` indexing `lit[i]` | `[byte=i]`, `[codepoint=i]` or `[grapheme=i]` on a `StaticString` | notes: removed in 1.0 |

## Changes that do not stop the build

These compile, but do something different from before.

- `var x = [1, 2, 3]` makes an `Array[Int, 3]`, not a `List`. Write
  `var x: List[Int] = [1, 2, 3]` for a list (built: `x.append(4)` on the
  first form is an error).
- `for c in my_string` gives grapheme clusters (what a person sees as one
  character). Use `codepoints()` for Unicode scalars and `bytes()` for UTF-8
  bytes (notes, 1.0).
- `Int` is `Scalar[DType.int]`, so some conversions are stricter. `Int` and
  `UInt` can no longer go to a GPU kernel; use `Int32` and friends (notes, 1.0).
- `size_of[T]()` is the allocation size, rounded up to the alignment (notes, 1.0).
- Indexing with a bad slice stops the program instead of clamping it (notes, 1.0).
- `b64decode()` always validates and raises on bad input (notes, 1.1).
