# `std.reflection.function`

Compile-time reflection over function values.

`reflect_fn[func]` is a `comptime` alias for the `ReflectedFn[func]` handle
type, exposing function introspection through static methods. This is the
function-side counterpart to `reflect[T]` / `Reflected[T]` for types.

```mojo
from std.reflection import reflect_fn

def my_func(x: Int) -> Int:
    return x + 1

def main():
    print(reflect_fn[my_func].display_name())   # "my_func"
    print(reflect_fn[my_func].linkage_name())   # mangled symbol name
```

## Aliases

### `reflect_fn`

```mojo
comptime reflect_fn[func_type: AnyType, //, func: func_type] = ReflectedFn[func]
```

A compile-time alias for the reflection handle type of function `func`.

Resolves to `ReflectedFn[func]`, a type whose static methods expose function
introspection. Use it as `reflect_fn[my_func].display_name()` rather than
constructing an instance.

Example:
```mojo
from std.reflection import reflect_fn

def add(a: Int, b: Int) -> Int:
    return a + b

def main():
    print(reflect_fn[add].display_name())  # "add"
```

## Structs

### `ReflectedFn`

```mojo
struct ReflectedFn[func_type: AnyType, //, func: func_type]
```

A compile-time reflection handle type for a function value.

All methods are `@staticmethod` — the handle has no runtime state, only
compile-time parameters. Spell access as `reflect_fn[func].display_name()`
(preferred) or `ReflectedFn[func].display_name()`.

Example:
```mojo
from std.reflection import reflect_fn

def my_func(x: Int) -> Int:
    return x

def main():
    print(reflect_fn[my_func].display_name())  # "my_func"
```

Parameters:

- `func_type`: The function's type. Inferred from `func`.
- `func`: The function value being introspected.

Implemented traits: `AnyType`, `Deinitable`, `Movable`

#### `ReflectedFn.display_name`

```mojo
def display_name() -> StaticString
```

Returns the function's name as declared in source.

The returned name does not include any information about the function's
parameters, arguments, or return type.

Example:
```mojo
from std.reflection import reflect_fn

def my_func(): pass
print(reflect_fn[my_func].display_name())  # "my_func"
```

Returns: The function's source-level name.

#### `ReflectedFn.linkage_name`

```mojo
def linkage_name[*, target: CompilationTarget = CompilationTarget()]() -> StaticString
```

Returns the function's mangled linkage / symbol name.

Parameters:

- `target`: The compilation target (defaults to the current target).

Returns: The symbol name as it appears in the linker.
