# `std.python.python_object`

Implements PythonObject.

You can import these APIs from the `python` package. For example:

```mojo
from std.python import PythonObject
```

## Structs

### `PythonObject`

```mojo
struct PythonObject
```

A Python object.

Implemented traits: `AnyType`, `Boolable`, `Copyable`, `Defaultable`, `Deinitable`, `Identifiable`, `ImplicitlyCopyable`, `Movable`, `RegisterPassable`, `SizedRaising`, `Writable`

#### `PythonObject.__init__`

```mojo
def __init__() -> Self
```

Initialize the object with a `None` value.

```mojo
def __init__(*, from_owned: PyObjectPtr) -> Self
```

Initialize this object from an owned reference-counted Python object pointer.

For example, this function should be used to construct a `PythonObject`
from the pointer returned by "New reference"-type objects from the
CPython API.

References:
- https://docs.python.org/3/glossary.html#term-strong-reference

Args:

- `from_owned`: An owned pointer to a Python object.

```mojo
def __init__(*, from_borrowed: PyObjectPtr) -> Self
```

Initialize this object from a borrowed reference-counted Python object pointer.

For example, this function should be used to construct a `PythonObject`
from the pointer returned by "Borrowed reference"-type objects from the
CPython API.

References:
- https://docs.python.org/3/glossary.html#term-borrowed-reference

Args:

- `from_borrowed`: A borrowed pointer to a Python object.

```mojo
def __init__(out self, var source: T) raises
```

Initialize this object from a value of some type that can be custom converted to a PythonObject.

Args:

- `source`: The value to convert to a PythonObject.

Raises: If the conversion to a PythonObject fails.

```mojo
def __init__[T: Deinitable & Movable](out self, *, var alloc: T) raises
```

Allocate a new `PythonObject` and store a Mojo value in it.

The newly allocated Python object will contain the provided Mojo `T`
instance directly, without attempting conversion to an equivalent Python
builtin type.

Only Mojo types that have a registered Python 'type' object can be stored
as a Python object. Mojo types are registered using a
`PythonTypeBuilder`.

Parameters:

- `T`: The Mojo type of the value that the resulting Python object holds.

Args:

- `alloc`: The Mojo value to store in the new Python object.

Raises: If no Python type object has been registered for `T` by a `PythonTypeBuilder`.

```mojo
def __init__(none: NoneType) -> Self
```

Initialize a none value object from a `None` literal.

Args:

- `none`: None.

```mojo
def __init__(value: Bool) -> Self
```

Initialize the object from a bool.

Args:

- `value`: The boolean value.

```mojo
def __init__[dtype: DType](value: Scalar[dtype]) -> Self
```

Initialize the object with a generic scalar value. If the scalar value type is bool, it is converted to a boolean. Otherwise, it is converted to the appropriate integer or floating point type.

Parameters:

- `dtype`: The scalar value type.

Args:

- `value`: The scalar value.

```mojo
def __init__(out self, string: StringSpan) raises
```

Initialize the object from a string.

Args:

- `string`: The string value.

Raises: If the string is not valid UTF-8.

```mojo
def __init__(out self, value: StringLiteral) raises
```

Initialize the object from a string literal.

Args:

- `value`: The string literal value.

Raises: If the string is not valid UTF-8.

```mojo
def __init__(out self, value: String) raises
```

Initialize the object from a string.

Args:

- `value`: The string value.

Raises: If the string is not valid UTF-8.

```mojo
def __init__(slice: Slice) -> Self
```

Initialize the object from a Mojo Slice.

Args:

- `slice`: The dictionary value.

```mojo
def __init__(out self, var *values: Self, *, __list_literal__: NoneType) raises
```

Construct an Python list of objects.

Args:

- `*values`: The values to initialize the list with.
- `__list_literal__`: Tell Mojo to use this method for list literals.

Returns: The constructed Python list.

Raises: If the list construction fails.

```mojo
def __init__(out self, var *values: Self, *, __set_literal__: NoneType) raises
```

Construct an Python set of objects.

Args:

- `*values`: The values to initialize the set with.
- `__set_literal__`: Tell Mojo to use this method for set literals.

Returns: The constructed Python set.

Raises: If adding an element to the set fails.

```mojo
def __init__(out self, var keys: List[Self], var values: List[Self], __dict_literal__: NoneType) raises
```

Construct a Python dictionary from a list of keys and a list of values.

Args:

- `keys`: The keys of the dictionary.
- `values`: The values of the dictionary.
- `__dict_literal__`: Tell Mojo to use this method for dict literals.

Raises: If setting a dictionary item fails.

```mojo
def __init__(*, copy: Self) -> Self
```

Copy the object.

This increments the underlying refcount of the existing object.

Args:

- `copy`: The value to copy.

#### `PythonObject.__deinit__`

```mojo
def __deinit__(deinit self)
```

Destroy the object.

Decrements the underlying refcount of the pointed-to object.
Safe to call from any thread; the GIL is acquired if not
already held.

#### `PythonObject.__bool__`

```mojo
def __bool__(self) -> Bool
```

Evaluate the boolean value of the object.

Returns: Whether the object evaluates as true.

#### `PythonObject.__getitem__`

```mojo
def __getitem__(self, *args: Self) raises -> Self
```

Return the value for the given key or keys.

Args:

- `*args`: The key or keys to access on this object.

Returns: The value corresponding to the given key for this object.

Raises: If the index is out of bounds or the key does not exist.

```mojo
def __getitem__(self, *args: Slice) raises -> Self
```

Return the sliced value for the given Slice or Slices.

Args:

- `*args`: The Slice or Slices to apply to this object.

Returns: The sliced value corresponding to the given Slice(s) for this object.

Raises: If the index is out of bounds or the key does not exist.

#### `PythonObject.__setitem__`

```mojo
def __setitem__(self, *args: Self, *, var value: Self) raises
```

Set the value with the given key or keys.

Args:

- `*args`: The key or keys to set on this object.
- `value`: The value to set.

Raises: If setting the item fails.

#### `PythonObject.__neg__`

```mojo
def __neg__(self) raises -> Self
```

Negative.

Calls the underlying object's `__neg__` method.

Returns: The result of prefixing this object with a `-` operator. For most numerical objects, this returns the negative.

Raises: If the operation fails.

#### `PythonObject.__pos__`

```mojo
def __pos__(self) raises -> Self
```

Positive.

Calls the underlying object's `__pos__` method.

Returns: The result of prefixing this object with a `+` operator. For most numerical objects, this does nothing.

Raises: If the operation fails.

#### `PythonObject.__invert__`

```mojo
def __invert__(self) raises -> Self
```

Inversion.

Calls the underlying object's `__invert__` method.

Returns: The logical inverse of this object: a bitwise representation where all bits are flipped, from zero to one, and from one to zero.

Raises: If the operation fails.

#### `PythonObject.__lt__`

```mojo
def __lt__(self, rhs: Self) raises -> Self
```

Less than (rich) comparison operator.

Args:

- `rhs`: The value of the right hand side of the comparison.

Returns: The result of the comparison, not necessarily a boolean.

Raises: If neither operand supports `<`, or if the comparison fails.

#### `PythonObject.__le__`

```mojo
def __le__(self, rhs: Self) raises -> Self
```

Less than or equal (rich) comparison operator.

Args:

- `rhs`: The value of the right hand side of the comparison.

Returns: The result of the comparison, not necessarily a boolean.

Raises: If neither operand supports `<=`, or if the comparison fails.

#### `PythonObject.__eq__`

```mojo
def __eq__(self, rhs: Self) raises -> Self
```

Equality (rich) comparison operator.

Operands that do not implement the comparison fall back to an identity
check and compare unequal, rather than raising.

Args:

- `rhs`: The value of the right hand side of the comparison.

Returns: The result of the comparison, not necessarily a boolean.

Raises: If the comparison fails.

#### `PythonObject.__ne__`

```mojo
def __ne__(self, rhs: Self) raises -> Self
```

Inequality (rich) comparison operator.

Operands that do not implement the comparison fall back to an identity
check and compare unequal, rather than raising.

Args:

- `rhs`: The value of the right hand side of the comparison.

Returns: The result of the comparison, not necessarily a boolean.

Raises: If the comparison fails.

#### `PythonObject.__gt__`

```mojo
def __gt__(self, rhs: Self) raises -> Self
```

Greater than (rich) comparison operator.

Args:

- `rhs`: The value of the right hand side of the comparison.

Returns: The result of the comparison, not necessarily a boolean.

Raises: If neither operand supports `>`, or if the comparison fails.

#### `PythonObject.__ge__`

```mojo
def __ge__(self, rhs: Self) raises -> Self
```

Greater than or equal (rich) comparison operator.

Args:

- `rhs`: The value of the right hand side of the comparison.

Returns: The result of the comparison, not necessarily a boolean.

Raises: If neither operand supports `>=`, or if the comparison fails.

#### `PythonObject.__is__`

```mojo
def __is__(self, other: Self) -> Bool
```

Test if the PythonObject is the `other` PythonObject, the same as `x is y` in Python.

Args:

- `other`: The right-hand-side value in the comparison.

Returns: True if they are the same object and False otherwise.

#### `PythonObject.__contains__`

```mojo
def __contains__(self, rhs: Self) raises -> Bool
```

Contains dunder.

Calls the underlying object's `__contains__` method, falling back to a
search by iteration if it is not implemented.

Args:

- `rhs`: Right hand value.

Returns: True if rhs is in self.

Raises: If the operation fails.

#### `PythonObject.__add__`

```mojo
def __add__(self, rhs: Self) raises -> Self
```

Addition and concatenation.

Calls the underlying object's `__add__` method, falling back to
`rhs.__radd__` if it is not implemented.

Args:

- `rhs`: Right hand value.

Returns: The sum or concatenated values.

Raises: If the operation is not supported.

#### `PythonObject.__sub__`

```mojo
def __sub__(self, rhs: Self) raises -> Self
```

Subtraction.

Calls the underlying object's `__sub__` method, falling back to
`rhs.__rsub__` if it is not implemented.

Args:

- `rhs`: Right hand value.

Returns: The difference.

Raises: If the operation is not supported.

#### `PythonObject.__mul__`

```mojo
def __mul__(self, rhs: Self) raises -> Self
```

Multiplication.

Calls the underlying object's `__mul__` method, falling back to
`rhs.__rmul__` if it is not implemented.

Args:

- `rhs`: Right hand value.

Returns: The product.

Raises: If the operation is not supported.

#### `PythonObject.__truediv__`

```mojo
def __truediv__(self, rhs: Self) raises -> Self
```

Division.

Calls the underlying object's `__truediv__` method, falling back to
`rhs.__rtruediv__` if it is not implemented.

Args:

- `rhs`: The right-hand-side value by which this object is divided.

Returns: The result of dividing the right-hand-side value by this.

Raises: If the operation fails.

#### `PythonObject.__floordiv__`

```mojo
def __floordiv__(self, rhs: Self) raises -> Self
```

Return the division of self and rhs rounded down to the nearest integer.

Calls the underlying object's `__floordiv__` method, falling back to
`rhs.__rfloordiv__` if it is not implemented.

Args:

- `rhs`: The right-hand-side value by which this object is divided.

Returns: The result of dividing this by the right-hand-side value, modulo any remainder.

Raises: If the operation fails.

#### `PythonObject.__mod__`

```mojo
def __mod__(self, rhs: Self) raises -> Self
```

Return the remainder of self divided by rhs.

Calls the underlying object's `__mod__` method, falling back to
`rhs.__rmod__` if it is not implemented.

Args:

- `rhs`: The value to divide on.

Returns: The remainder of dividing self by rhs.

Raises: If the operation fails.

#### `PythonObject.__pow__`

```mojo
def __pow__(self, exp: Self) raises -> Self
```

Raises this object to the power of the given value.

Args:

- `exp`: The exponent.

Returns: The result of raising this by the given exponent.

Raises: If the operation fails.

#### `PythonObject.__lshift__`

```mojo
def __lshift__(self, rhs: Self) raises -> Self
```

Bitwise left shift.

Args:

- `rhs`: The right-hand-side value by which this object is bitwise shifted to the left.

Returns: This value, shifted left by the given value.

Raises: If the operation fails.

#### `PythonObject.__rshift__`

```mojo
def __rshift__(self, rhs: Self) raises -> Self
```

Bitwise right shift.

Args:

- `rhs`: The right-hand-side value by which this object is bitwise shifted to the right.

Returns: This value, shifted right by the given value.

Raises: If the operation fails.

#### `PythonObject.__and__`

```mojo
def __and__(self, rhs: Self) raises -> Self
```

Bitwise AND.

Args:

- `rhs`: The right-hand-side value with which this object is bitwise AND'ed.

Returns: The bitwise AND result of this and the given value.

Raises: If the operation fails.

#### `PythonObject.__or__`

```mojo
def __or__(self, rhs: Self) raises -> Self
```

Bitwise OR.

Args:

- `rhs`: The right-hand-side value with which this object is bitwise OR'ed.

Returns: The bitwise OR result of this and the given value.

Raises: If the operation fails.

#### `PythonObject.__xor__`

```mojo
def __xor__(self, rhs: Self) raises -> Self
```

Exclusive OR.

Args:

- `rhs`: The right-hand-side value with which this object is exclusive OR'ed.

Returns: The exclusive OR result of this and the given value.

Raises: If the operation fails.

#### `PythonObject.__radd__`

```mojo
def __radd__(self, lhs: Self) raises -> Self
```

Reverse addition and concatenation.

Evaluates `lhs + self`, which calls `lhs.__add__` and falls back to
this object's `__radd__` if that is not implemented.

Args:

- `lhs`: The left-hand-side value to which this object is added or concatenated.

Returns: The sum.

Raises: If the operation is not supported.

#### `PythonObject.__rsub__`

```mojo
def __rsub__(self, lhs: Self) raises -> Self
```

Reverse subtraction.

Evaluates `lhs - self`, which calls `lhs.__sub__` and falls back to
this object's `__rsub__` if that is not implemented.

Args:

- `lhs`: The left-hand-side value from which this object is subtracted.

Returns: The result of subtracting this from the given value.

Raises: If the operation is not supported.

#### `PythonObject.__rmul__`

```mojo
def __rmul__(self, lhs: Self) raises -> Self
```

Reverse multiplication.

Evaluates `lhs * self`, which calls `lhs.__mul__` and falls back to
this object's `__rmul__` if that is not implemented.

Args:

- `lhs`: The left-hand-side value that is multiplied by this object.

Returns: The product of the multiplication.

Raises: If the operation is not supported.

#### `PythonObject.__rtruediv__`

```mojo
def __rtruediv__(self, lhs: Self) raises -> Self
```

Reverse division.

Evaluates `lhs / self`, which calls `lhs.__truediv__` and falls back to
this object's `__rtruediv__` if that is not implemented.

Args:

- `lhs`: The left-hand-side value that is divided by this object.

Returns: The result of dividing the given value by this.

Raises: If the operation fails.

#### `PythonObject.__rfloordiv__`

```mojo
def __rfloordiv__(self, lhs: Self) raises -> Self
```

Reverse floor division.

Evaluates `lhs // self`, which calls `lhs.__floordiv__` and falls back to
this object's `__rfloordiv__` if that is not implemented.

Args:

- `lhs`: The left-hand-side value that is divided by this object.

Returns: The result of dividing the given value by this, modulo any remainder.

Raises: If the operation fails.

#### `PythonObject.__rmod__`

```mojo
def __rmod__(self, lhs: Self) raises -> Self
```

Reverse modulo.

Evaluates `lhs % self`, which calls `lhs.__mod__` and falls back to
this object's `__rmod__` if that is not implemented.

Args:

- `lhs`: The left-hand-side value that is divided by this object.

Returns: The remainder from dividing the given value by this.

Raises: If the operation fails.

#### `PythonObject.__rpow__`

```mojo
def __rpow__(self, lhs: Self) raises -> Self
```

Reverse power of.

Args:

- `lhs`: The number that is raised to the power of this object.

Returns: The result of raising the given value by this exponent.

Raises: If the operation fails.

#### `PythonObject.__rlshift__`

```mojo
def __rlshift__(self, lhs: Self) raises -> Self
```

Reverse bitwise left shift.

Args:

- `lhs`: The left-hand-side value that is bitwise shifted to the left by this object.

Returns: The given value, shifted left by this.

Raises: If the operation fails.

#### `PythonObject.__rrshift__`

```mojo
def __rrshift__(self, lhs: Self) raises -> Self
```

Reverse bitwise right shift.

Args:

- `lhs`: The left-hand-side value that is bitwise shifted to the right by this object.

Returns: The given value, shifted right by this.

Raises: If the operation fails.

#### `PythonObject.__rand__`

```mojo
def __rand__(self, lhs: Self) raises -> Self
```

Reverse bitwise and.

Args:

- `lhs`: The left-hand-side value that is bitwise AND'ed with this object.

Returns: The bitwise AND result of the given value and this.

Raises: If the operation fails.

#### `PythonObject.__ror__`

```mojo
def __ror__(self, lhs: Self) raises -> Self
```

Reverse bitwise OR.

Args:

- `lhs`: The left-hand-side value that is bitwise OR'ed with this object.

Returns: The bitwise OR result of the given value and this.

Raises: If the operation fails.

#### `PythonObject.__rxor__`

```mojo
def __rxor__(self, lhs: Self) raises -> Self
```

Reverse exclusive OR.

Args:

- `lhs`: The left-hand-side value that is exclusive OR'ed with this object.

Returns: The exclusive OR result of the given value and this.

Raises: If the operation fails.

#### `PythonObject.__iadd__`

```mojo
def __iadd__(mut self, var rhs: Self) raises
```

Immediate addition and concatenation.

Args:

- `rhs`: The right-hand-side value that is added to this object.

Raises: If the operation is not supported.

#### `PythonObject.__isub__`

```mojo
def __isub__(mut self, var rhs: Self) raises
```

Immediate subtraction.

Args:

- `rhs`: The right-hand-side value that is subtracted from this object.

Raises: If the operation is not supported.

#### `PythonObject.__imul__`

```mojo
def __imul__(mut self, var rhs: Self) raises
```

In-place multiplication.

Calls the underlying object's `__imul__` method, falling back to
`__mul__` if it is not implemented.

Args:

- `rhs`: The right-hand-side value by which this object is multiplied.

Raises: If the operation is not supported.

#### `PythonObject.__itruediv__`

```mojo
def __itruediv__(mut self, var rhs: Self) raises
```

Immediate division.

Args:

- `rhs`: The value by which this object is divided.

Raises: If the operation fails.

#### `PythonObject.__ifloordiv__`

```mojo
def __ifloordiv__(mut self, var rhs: Self) raises
```

Immediate floor division.

Args:

- `rhs`: The value by which this object is divided.

Raises: If the operation fails.

#### `PythonObject.__imod__`

```mojo
def __imod__(mut self, var rhs: Self) raises
```

Immediate modulo.

Args:

- `rhs`: The right-hand-side value that is used to divide this object.

Raises: If the operation fails.

#### `PythonObject.__ipow__`

```mojo
def __ipow__(mut self, var rhs: Self) raises
```

Immediate power of.

Args:

- `rhs`: The exponent.

Raises: If the operation fails.

#### `PythonObject.__ilshift__`

```mojo
def __ilshift__(mut self, var rhs: Self) raises
```

Immediate bitwise left shift.

Args:

- `rhs`: The right-hand-side value by which this object is bitwise shifted to the left.

Raises: If the operation fails.

#### `PythonObject.__irshift__`

```mojo
def __irshift__(mut self, var rhs: Self) raises
```

Immediate bitwise right shift.

Args:

- `rhs`: The right-hand-side value by which this object is bitwise shifted to the right.

Raises: If the operation fails.

#### `PythonObject.__iand__`

```mojo
def __iand__(mut self, var rhs: Self) raises
```

Immediate bitwise AND.

Args:

- `rhs`: The right-hand-side value with which this object is bitwise AND'ed.

Raises: If the operation fails.

#### `PythonObject.__ixor__`

```mojo
def __ixor__(mut self, var rhs: Self) raises
```

Immediate exclusive OR.

Args:

- `rhs`: The right-hand-side value with which this object is exclusive OR'ed.

Raises: If the operation fails.

#### `PythonObject.__ior__`

```mojo
def __ior__(mut self, var rhs: Self) raises
```

Immediate bitwise OR.

Args:

- `rhs`: The right-hand-side value with which this object is bitwise OR'ed.

Raises: If the operation fails.

#### `PythonObject.__iter__`

```mojo
def __iter__(self) raises -> _PyIter
```

Iterate over the object.

Returns: An iterator object.

Raises: If the object is not iterable.

#### `PythonObject.__getattr__`

```mojo
def __getattr__(self, var name: String) raises -> Self
```

Return the value of the object attribute with the given name.

Args:

- `name`: The name of the object attribute to return.

Returns: The value of the object attribute with the given name.

Raises: If the attribute does not exist.

#### `PythonObject.__setattr__`

```mojo
def __setattr__(self, var name: String, var value: Self) raises
```

Set the given value for the object attribute with the given name.

Args:

- `name`: The name of the object attribute to set.
- `value`: The new value to be set for that attribute.

Raises: If setting the attribute fails.

#### `PythonObject.__call__`

```mojo
def __call__(self, *args: Self, *, var **kwargs: Self) raises -> Self
```

Call the underlying object as if it were a function.

Args:

- `*args`: Positional arguments to the function.
- `**kwargs`: Keyword arguments to the function.

Returns: The return value from the called object.

Raises: If the function cannot be called for any reason.

#### `PythonObject.__len__`

```mojo
def __len__(self) raises -> Int
```

Returns the length of the object.

Returns: The length of the object.

Raises: If the operation fails.

#### `PythonObject.__hash__`

```mojo
def __hash__(self) raises -> Int
```

Returns the hash value of the object.

Returns: The hash value of the object.

Raises: If the operation fails.

#### `PythonObject.__int__`

```mojo
def __int__(self) raises -> Self
```

Convert the PythonObject to a Python `int` (i.e. arbitrary precision integer).

Returns: A Python `int` object.

Raises: An error if the conversion failed.

#### `PythonObject.__float__`

```mojo
def __float__(self) raises -> Self
```

Convert the PythonObject to a Python `float` object.

Returns: A Python `float` object.

Raises: If the conversion fails.

#### `PythonObject.__str__`

```mojo
def __str__(self) raises -> Self
```

Convert the PythonObject to a Python `str`.

Returns: A Python `str` object.

Raises: An error if the conversion failed.

#### `PythonObject.write_to`

```mojo
def write_to(self, mut writer: T)
```

Formats this Python object to the provided Writer.

Args:

- `writer`: The object to write to.

#### `PythonObject.write_repr_to`

```mojo
def write_repr_to(self, mut writer: T)
```

Writes the repr of this `PythonObject` to a writer.

Uses Python's `repr()` to get the representation of the underlying
Python object.

Args:

- `writer`: The object to write to.

#### `PythonObject.steal_data`

```mojo
def steal_data(var self) -> PyObjectPtr
```

Take ownership of the underlying pointer from the Python object.

Returns: The underlying data.

#### `PythonObject.unsafe_get_as_pointer`

```mojo
def unsafe_get_as_pointer[dtype: DType](self) raises -> Pointer[Scalar[dtype], MutAnyOrigin]
```

Reinterpret a Python integer as a Mojo pointer.

Warning: converting from an integer to a pointer is unsafe! The
compiler assumes the resulting pointer DOES NOT alias any Mojo-derived
pointer. This is OK if the pointer originates from and is owned by
Python, e.g. the data underpinning a torch tensor.

Parameters:

- `dtype`: The desired DType of the pointer.

Returns: A pointer for the underlying Python data.

Raises: If the operation fails.

#### `PythonObject.downcast_value_ptr`

```mojo
def downcast_value_ptr[T: Deinitable](self, *, func: Optional[StringSpan[ImmStaticOrigin]] = None) raises -> Pointer[T, MutAnyOrigin]
```

Get a pointer to the expected contained Mojo value of type `T`.

This method validates that this object actually contains an instance of
`T`, and will raise an error if it does not.

Mojo values are stored as Python objects backed by the `PyMojoObject[T]`
struct.

Parameters:

- `T`: The type of the Mojo value that this Python object is expected to contain.

Args:

- `func`: Optional name of bound Mojo function that the raised TypeError should reference if downcasting fails.

Returns: A pointer to the inner Mojo value.

Raises: If the Python object does not contain an instance of the Mojo `T` type.

#### `PythonObject.unchecked_downcast_value_ptr`

```mojo
def unchecked_downcast_value_ptr[mut: Bool, origin: Origin[mut=mut], //, T: Deinitable](ref[origin] self) -> Pointer[T, origin]
```

Get a pointer to the expected Mojo value of type `T`.

This function assumes that this Python object was allocated as an
instance of `PyMojoObject[T]` and that the Mojo value has been
initialized.

Safety:

The user must be certain that this Python object type matches the bound
Python type object for `T`.

Parameters:

- `mut`: The mutability of self.
- `origin`: The origin of self.
- `T`: The type of the Mojo value stored in this object.

Returns: A pointer to the inner Mojo value.
