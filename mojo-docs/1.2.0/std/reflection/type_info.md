# `std.reflection.type_info`

Provides function name introspection utilities.

For type-name introspection, use the static methods on `Reflected[T]`
(obtained via `reflect[T]`):

- `reflect[T].name()` - returns the name of a type.
- `reflect[T].base_name()` - returns the unqualified name of a type's base
  type.

This module exposes the function-side counterparts:

- `get_function_name[func]()` - returns the source name of a function.
- `get_linkage_name[func]()` - returns the symbol/linkage name of a function.

Example:

```mojo
from std.reflection import reflect, get_function_name

struct Point:
    var x: Int
    var y: Float64

def my_function():
    pass

def main():
    print(reflect[Point].name())             # "Point"
    print(get_function_name[my_function]())  # "my_function"
```

## Functions

### `get_linkage_name`

```mojo
def get_linkage_name[func_type: AnyType, //, func: func_type, *, target: CompilationTarget = CompilationTarget()]() -> StaticString
```

Returns `func`'s symbol name.

Parameters:

- `func_type`: Type of func.
- `func`: A mojo function.
- `target`: The compilation target, defaults to the current target.

Returns: Symbol name.

### `get_function_name`

```mojo
def get_function_name[func_type: AnyType, //, func: func_type]() -> StaticString
```

Returns `func`'s name as declared in the source code.

The returned name does not include any information about the function's
parameters, arguments, or return type, just the name as declared in the
source code.

Parameters:

- `func_type`: Type of func.
- `func`: A mojo function.

Returns: The function's name as declared in the source code.
