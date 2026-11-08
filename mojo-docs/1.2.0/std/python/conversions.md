# `std.python.conversions`

Implements conversion traits to and from PythonObject.

You can import these APIs from the `python` package. For example:

```mojo
from std.python import ConvertibleToPython
```

## Traits

### `ConvertibleToPython`

```mojo
trait ConvertibleToPython
```

A trait that indicates a type can be converted to a PythonObject, and that specifies the behavior with a `to_python_object` method.

Inherits from: `AnyType`, `Deinitable`

#### `ConvertibleToPython.to_python_object`

```mojo
def to_python_object(var self) raises -> PythonObject
```

Convert a value to a PythonObject.

Returns: A PythonObject representing the value.

Raises: If the conversion to a PythonObject failed.

### `ConvertibleFromPython`

```mojo
trait ConvertibleFromPython
```

Denotes a type that can attempt construction from a read-only Python object.

Inherits from: `AnyType`, `Copyable`, `Deinitable`, `Movable`

#### `ConvertibleFromPython.__init__`

```mojo
def __init__(out self, *, py: PythonObject) raises
```

Attempt to construct an instance of this object from a read-only Python value.

Args:

- `py`: The Python object to convert from.

Raises: If conversion was not successful.
