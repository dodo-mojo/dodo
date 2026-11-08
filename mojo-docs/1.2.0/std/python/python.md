# `std.python.python`

Implements Python interoperability.

You can import these APIs from the `python` package. For example:

```mojo
from std.python import Python
```

## Structs

### `Python`

```mojo
struct Python
```

Provides methods that help you use Python code in Mojo.

Implemented traits: `AnyType`, `Copyable`, `Defaultable`, `Deinitable`, `ImplicitlyCopyable`, `Movable`

#### `Python.__init__`

```mojo
def __init__(out self)
```

Construct a new `Python` instance.

```mojo
def __init__(out self, ref[ImmStaticOrigin] cpython: CPython)
```

Construct a `Python` instance from an existing reference to the lower-level singleton `CPython` instance.

Args:

- `cpython`: Reference to the `CPython` singleton.

#### `Python.cpython`

```mojo
def cpython(self) -> ref[ImmStaticOrigin] CPython
```

Handle to the low-level C API of the CPython interpreter present in the current process.

Returns: Handle to the CPython interpreter instance in the current process.

#### `Python.eval`

```mojo
def eval(self, var code: String) -> Bool
```

Executes the given Python code.

Args:

- `code`: The python code to execute.

Returns: `True` if the code executed successfully or `False` if the code raised an exception.

#### `Python.evaluate`

```mojo
def evaluate(var expr: String, file: Bool = False, name: StringSpan[ImmStaticOrigin] = StringSpan("__main__")) raises -> PythonObject
```

Executes the given Python code.

Args:

- `expr`: The Python expression to evaluate.
- `file`: Evaluate as a file and return the module.
- `name`: The name of the module (most relevant if `file` is True).

Returns: `PythonObject` containing the result of the evaluation.

Raises: If the operation fails.

#### `Python.add_to_path`

```mojo
def add_to_path(dir_path: StringSpan) raises
```

Adds a directory to the Python path.

This might be necessary to import a Python module via `import_module()`.
For example:

```mojo
from std.python import Python

# Specify path to `mypython.py` module
Python.add_to_path("path/to/module")
var mypython = Python.import_module("mypython")

var c = mypython.my_algorithm(2, 3)
```

Args:

- `dir_path`: The path to a Python module you want to import.

Raises: If the operation fails.

#### `Python.import_module`

```mojo
def import_module(var module: String) raises -> PythonObject
```

Imports a Python module.

This provides you with a module object you can use just like you would
in Python. For example:

```mojo
from std.python import Python

# This is equivalent to Python's `import numpy as np`
np = Python.import_module("numpy")
a = np.array(Python.list(1, 2, 3))
```

Args:

- `module`: The Python module name. This module must be visible from the list of available Python paths (you might need to add the module's path with `add_to_path()`).

Returns: The Python module.

Raises: If the operation fails.

#### `Python.create_module`

```mojo
def create_module(name: StringSpan[ImmStaticOrigin]) raises -> PythonObject
```

Creates a Python module using the provided name.

Inspired by https://github.com/pybind/pybind11/blob/a1d00916b26b187e583f3bce39cd59c3b0652c32/include/pybind11/pybind11.h#L1227

TODO: allow specifying a doc-string to attach to the module upon creation or lazily added?

Args:

- `name`: The Python module name.

Returns: The Python module.

Raises: If the operation fails.

#### `Python.add_functions`

```mojo
def add_functions(module: PythonObject, var functions: List[PyMethodDef]) raises
```

Adds functions to a Python module object.

Args:

- `module`: The Python module object.
- `functions`: List of function data.

Raises: If we fail to add the functions to the module.

#### `Python.add_object`

```mojo
def add_object(module: PythonObject, var name: String, value: PythonObject) raises
```

Add a new object to `module` with the given name and value.

The provided object can be any type of Python object: an instance,
a type object, a function, etc.

The added value will be inserted into the `__dict__` of the provided
module.

Args:

- `module`: The Python module to modify.
- `name`: The name of the new object.
- `value`: The python object value.

Raises: If the operation fails.

#### `Python.dict`

```mojo
def dict(*, var **kwargs: PythonObject) raises -> PythonObject
```

Construct an Python dictionary from keyword arguments.

Args:

- `**kwargs`: The keyword arguments to construct the dictionary with.

Returns: The constructed Python dictionary.

Raises: On failure to construct the dictionary or convert the values to Python objects.

```mojo
def dict(tuples: Span[Tuple[PythonObject, PythonObject]]) raises -> PythonObject
```

Construct an Python dictionary from a list of key-value tuples.

Args:

- `tuples`: The list of key-value tuples to construct the dictionary with.

Returns: The constructed Python dictionary.

Raises: On failure to construct the dictionary or convert the keys or values to Python objects.

#### `Python.list`

```mojo
def list(values: Span[PythonObject]) raises -> PythonObject
```

Initialize the object from a list of values.

Args:

- `values`: The values to initialize the list with.

Returns: A PythonObject representing the list.

Raises: If the operation fails.

```mojo
def list(var *values: PythonObject) raises -> PythonObject
```

Construct an Python list of objects.

Args:

- `*values`: The values to initialize the list with.

Returns: The constructed Python list.

Raises: If the operation fails.

#### `Python.tuple`

```mojo
def tuple(var *values: PythonObject) raises -> PythonObject
```

Construct an Python tuple of objects.

Args:

- `*values`: The values to initialize the tuple with.

Returns: The constructed Python tuple.

Raises: If the operation fails.

#### `Python.as_string_slice`

```mojo
def as_string_slice(self, obj: PythonObject) -> StringSpan[ImmutAnyOrigin]
```

Return a string representing the given Python object.

Args:

- `obj`: The Python object.

Returns: Mojo string representing the given Python object.

#### `Python.type`

```mojo
def type(obj: PythonObject) -> PythonObject
```

Return Type of this PythonObject.

Args:

- `obj`: PythonObject we want the type of.

Returns: A PythonObject that holds the type object.

#### `Python.none`

```mojo
def none() -> PythonObject
```

Get a `PythonObject` representing `None`.

Returns: `PythonObject` representing `None`.

#### `Python.str`

```mojo
def str(obj: PythonObject) raises -> PythonObject
```

Convert a PythonObject to a Python `str`.

Args:

- `obj`: The PythonObject to convert.

Returns: A Python `str` object.

Raises: An error if the conversion failed.

#### `Python.int`

```mojo
def int(obj: PythonObject) raises -> PythonObject
```

Convert a PythonObject to a Python `int` (i.e. arbitrary precision integer).

Args:

- `obj`: The PythonObject to convert.

Returns: A PythonObject representing the result of the conversion to `int`.

Raises: If the conversion to `int` fails.

#### `Python.float`

```mojo
def float(obj: PythonObject) raises -> PythonObject
```

Convert a PythonObject to a Python `float` object.

Args:

- `obj`: The PythonObject to convert.

Returns: A Python `float` object.

Raises: If the conversion fails.

#### `Python.py_long_as_ssize_t`

```mojo
def py_long_as_ssize_t(obj: PythonObject) raises -> Py_ssize_t
```

Get the value of a Python `long` object.

Args:

- `obj`: The Python `long` object.

Returns: The value of the `long` object as a `Py_ssize_t`.

Raises: If `obj` is not a Python `long` object, or if the `long` object value overflows `Py_ssize_t`.

#### `Python.py_long_as_size_t`

```mojo
def py_long_as_size_t(obj: PythonObject) raises -> c_size_t
```

Get the value of a Python `long` object as an unsigned `size_t`.

Args:

- `obj`: The Python `long` object.

Returns: The value of the `long` object as a `size_t`.

Raises: If `obj` is not a Python `long` object, if the `long` object value is negative, or if it overflows `size_t`.

#### `Python.is_true`

```mojo
def is_true(obj: PythonObject) raises -> Bool
```

Check if the PythonObject is truthy.

Args:

- `obj`: The PythonObject to check.

Returns: True if the PythonObject is truthy and False otherwise.

Raises: If the boolean value of the PythonObject cannot be determined.
