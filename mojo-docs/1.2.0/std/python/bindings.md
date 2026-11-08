# `std.python.bindings`

Provides infrastructure for creating Python bindings to Mojo code.

This module implements the core machinery for exposing Mojo functions and types
to Python through CPython's C API. It includes builder types for constructing
Python modules and type objects, wrapper functions for converting between Mojo
and Python calling conventions, and utilities for argument validation and type
conversion. This enables seamless bidirectional interoperability between Mojo
and Python code.

## Aliases

### `MOJO_PYTHON_TYPE_OBJECTS`

```mojo
comptime MOJO_PYTHON_TYPE_OBJECTS = _Global[StringSpan("MOJO_PYTHON_TYPE_OBJECTS"), __init__[StringSpan[ImmStaticOrigin], PythonObject, AHasher[SIMD[.uint64, 4](0)]]]
```

Mapping of Mojo type identifiers to unique `PyTypeObject*` binding that Mojo type to this CPython interpreter instance.

### `PyFunctionRaising`

```mojo
comptime PyFunctionRaising = def(mut PythonObject, mut PythonObject) raises thin -> PythonObject
```

The generic function type for raising Python bindings.

The first argument is the self object, and the second argument is a tuple of the
positional arguments. These functions always return a Python object (could be a
`None` object).

### `PyFunctionWithKeywordsRaising`

```mojo
comptime PyFunctionWithKeywordsRaising = def(mut PythonObject, mut PythonObject, mut PythonObject) raises thin -> PythonObject
```

The generic function type for raising Python bindings with keyword arguments.

The first argument is the self object, the second argument is a tuple of the
positional arguments, and the third argument is a dictionary of the keyword arguments.

### `GenericPyFunction`

```mojo
comptime GenericPyFunction = Variant[def(mut PythonObject, mut PythonObject) raises thin -> PythonObject, def(mut PythonObject, mut PythonObject, mut PythonObject) raises thin -> PythonObject]
```

A variant type that can hold either a PyFunctionRaising or PyFunctionWithKeywordsRaising.

## Structs

### `PyMojoObject`

```mojo
struct PyMojoObject[T: Deinitable]
```

Storage backing a PyObject* wrapping a Mojo value.

This struct represents the C-level layout of a Python object that contains
a wrapped Mojo value. It must be ABI-compatible with CPython's PyObject
structure to enable seamless interoperability between Mojo and Python.

The struct follows Python's object model where all Python objects begin
with a PyObject header (ob_base), followed by type-specific data. In this
case, the type-specific data is a Mojo value of type T.

See https://docs.python.org/3/c-api/structures.html#c.PyObject for more details.

Parameters:

- `T`: The Mojo type being wrapped. Can be any type that satisfies `AnyType`.

Fields:

- `ob_base` (`PyObject`): The standard Python object header containing reference count and type information.
- `mojo_value` (`T`): The actual Mojo value being wrapped and exposed to Python.
- `is_initialized` (`Bool`): Whether the Mojo value has been initialized.

Implemented traits: `AnyType`, `Deinitable`, `Movable`

### `PythonModuleBuilder`

```mojo
struct PythonModuleBuilder
```

A builder for creating Python modules with Mojo function and type bindings.

This builder provides a high-level API for declaring Python bindings for Mojo
functions and types within a Python module. It manages the registration of
functions, types, and their associated metadata, then finalizes everything
into a complete Python module object.

The builder follows a declarative pattern where you:
1. Create a builder instance with a module name
2. Add function bindings using `def_function()`, `def_py_function()`, `def_py_c_function()`
3. Add type bindings using `add_type[T]()` and configure them
4. Call `finalize()` to finish building the Python module.

Example:
```mojo
from std.python import PythonObject
from std.python.bindings import PythonModuleBuilder

def my_func(arg: PythonObject) -> PythonObject:
    return arg

var builder = PythonModuleBuilder("my_module")
builder.def_function[my_func]("my_func", "Documentation for my_func")

var module = builder.finalize()
```

Note:
After calling `finalize()`, the builder's internal state is cleared and
it should not be reused for creating additional modules.

TODO: This should be enforced programmatically in the future.

Fields:

- `module` (`PythonObject`): The Python module being built.
- `functions` (`List[PyMethodDef]`): List of function definitions that will be exposed in the module.
- `type_builders` (`List[PythonTypeBuilder]`): List of type builders for types that will be exposed in the module.

Implemented traits: `AnyType`, `Deinitable`, `Movable`

#### `PythonModuleBuilder.__init__`

```mojo
def __init__(out self, name: StringSpan[ImmStaticOrigin]) raises
```

Construct a Python module builder with the given module name.

Args:

- `name`: The name of the module.

Raises: If the module creation fails.

```mojo
def __init__(out self, module: PythonObject)
```

Construct a Python module builder with the given module.

Args:

- `module`: The module to build.

#### `PythonModuleBuilder.add_type`

```mojo
def add_type[T: Deinitable](mut self, type_name: StringSpan[ImmStaticOrigin]) -> ref[self.type_builders["element"]] PythonTypeBuilder
```

Add a type to the module and return a builder for it.

Parameters:

- `T`: The mojo type to bind in the module.

Args:

- `type_name`: The name of the type to expose in the module.

Returns: A reference to a type builder registered in the module builder.

#### `PythonModuleBuilder.def_py_c_function`

```mojo
def def_py_c_function(mut self, func: def(PyObjectPtr, PyObjectPtr) abi("C") thin -> PyObjectPtr, func_name: StringSpan[ImmStaticOrigin], docstring: StringSpan[ImmStaticOrigin] = StringSpan(""))
```

Declare a binding for a function with PyCFunction signature in the module.

Args:

- `func`: The function to declare a binding for.
- `func_name`: The name with which the function will be exposed in the module.
- `docstring`: The docstring for the function in the module.

```mojo
def def_py_c_function(mut self, func: def(PyObjectPtr, PyObjectPtr, PyObjectPtr) abi("C") thin -> PyObjectPtr, func_name: StringSpan[ImmStaticOrigin], docstring: StringSpan[ImmStaticOrigin] = StringSpan(""))
```

Declare a binding for a function with PyCFunctionWithKeywords signature in the module.

Args:

- `func`: The function to declare a binding for.
- `func_name`: The name with which the function will be exposed in the module.
- `docstring`: The docstring for the function in the module.

```mojo
def def_py_c_function(mut self, func: def(PyObjectPtr, Pointer[PyObjectPtr, MutUntrackedOrigin], Int) abi("C") thin -> PyObjectPtr, func_name: StringSpan[ImmStaticOrigin], docstring: StringSpan[ImmStaticOrigin] = StringSpan(""))
```

Declare a binding for a function with `PyCFunctionFast` signature (`METH_FASTCALL`) in the module.

Args:

- `func`: The function to declare a binding for.
- `func_name`: The name with which the function will be exposed in the module.
- `docstring`: The docstring for the function in the module.

#### `PythonModuleBuilder.def_py_function`

```mojo
def def_py_function[func: def(mut PythonObject, mut PythonObject) raises thin -> PythonObject](mut self, func_name: StringSpan[ImmStaticOrigin], docstring: StringSpan[ImmStaticOrigin] = StringSpan(""))
```

Declare a binding for a function with PyFunctionRaising signature in the module.

Parameters:

- `func`: The function to declare a binding for.

Args:

- `func_name`: The name with which the function will be exposed in the module.
- `docstring`: The docstring for the function in the module.

```mojo
def def_py_function[func: def(mut PythonObject, mut PythonObject, mut PythonObject) raises thin -> PythonObject](mut self, func_name: StringSpan[ImmStaticOrigin], docstring: StringSpan[ImmStaticOrigin] = StringSpan(""))
```

Declare a binding for a function with PyFunctionWithKeywordsRaising signature in the module.

Parameters:

- `func`: The function to declare a binding for.

Args:

- `func_name`: The name with which the function will be exposed in the module.
- `docstring`: The docstring for the function in the module.

#### `PythonModuleBuilder.def_function`

```mojo
def def_function[PyArgs: TypeList[PyArgs.values], RetType: Deinitable & Movable, //, func: def(*args: *PyArgs, var **kwargs: PythonObject) raises thin -> RetType](mut self, func_name: StringSpan[ImmStaticOrigin], docstring: StringSpan[ImmStaticOrigin] = StringSpan("")) where Bool(identical(RetType, PythonObject)) or Bool(identical(RetType, None))
```

Declare a binding for a module-level function.

Accepts functions with PythonObject arguments, can optionally
return a PythonObject, and can raise. Functions can also accept keyword
arguments via `var **kwargs: PythonObject`.

Non-kwargs callables register through CPython's `METH_FASTCALL`
calling convention; kwargs-accepting callables use
`METH_VARARGS | METH_KEYWORDS`.

Example signatures:
```mojo
from std.python import PythonObject

def func(arg1: PythonObject) -> PythonObject: ...
def func(arg1: PythonObject, arg2: PythonObject) raises: ...
def func(var **kwargs: PythonObject) -> PythonObject: ...
def func(arg1: PythonObject, var **kwargs: PythonObject) raises: ...
```

Parameters:

- `func`: The function to declare a binding for.

Args:

- `func_name`: The name with which the function will be exposed in the module.
- `docstring`: The docstring for the function in the module.

#### `PythonModuleBuilder.finalize`

```mojo
def finalize(mut self) raises -> PythonObject
```

Finalize the module builder, creating the module object.

All types and functions added to the builder will be built and exposed
in the module. After calling this method, the builder's internal state
is cleared and it should not be reused for creating additional modules.

Returns: The finalized Python module containing all registered functions and types.

Raises: If the module creation fails or if we fail to add any of the declared functions or types to the module.

### `PythonTypeBuilder`

```mojo
struct PythonTypeBuilder
```

A builder for a Python 'type' binding.

This is typically used to build a type description of a `PyMojoObject[T]`.

This builder is used to declare method bindings for a Python type, and then
create the type binding.

Finalizing builder created with `PythonTypeObject.bind[T]()` will globally
register the resulting Python 'type' object as the single canonical type
object for the Mojo type `T`. Subsequent attempts to register a Python type
for `T` will raise an exception.

Registering a Python type object for `T` is necessary to be able to
construct a `PythonObject` from an instance of `T`, or to downcast an
existing `PythonObject` to a pointer to the inner `T` value.

Fields:

- `type_name` (`StaticString`): The name the type will be exposed as in the Python module.
- `basicsize` (`Int`): The required allocation size to hold an instance of this type as a Python object.
- `methods` (`List[PyMethodDef]`): List of method definitions that will be exposed on the Python type.

Implemented traits: `AnyType`, `Copyable`, `Deinitable`, `Movable`

#### `PythonTypeBuilder.__init__`

```mojo
def __init__(out self, type_name: StringSpan[ImmStaticOrigin], *, basicsize: Int)
```

Construct a new builder for a Python type binding.

Args:

- `type_name`: The name the type will be exposed as in the Python module.
- `basicsize`: The required allocation size to hold an instance of this type as a Python object.

#### `PythonTypeBuilder.bind`

```mojo
def bind[T: Deinitable](type_name: StringSpan[ImmStaticOrigin]) -> Self
```

Construct a new builder for a Python type that binds a Mojo type.

Parameters:

- `T`: The mojo type to bind.

Args:

- `type_name`: The name the type will be exposed as in the Python module.

Returns: A new type builder instance.

#### `PythonTypeBuilder.finalize`

```mojo
def finalize(mut self, module: PythonObject) raises
```

Finalize the builder and add the created type to a Python module.

This method completes the type building process by calling the
parameterless `finalize()` method to create the Python type object, then
automatically adds the resulting type to the specified Python module
using the builder's configured type name. After successful completion,
the builder's method list is cleared to prevent accidental reuse.

This is a convenience method that combines type finalization and module
registration in a single operation, which is the most common use case
when creating Python-accessible Mojo types.

Note:
After calling this method, the builder's internal state is modified
(methods list is cleared), so the builder should not be reused for
creating additional type objects. If you need the type object for
further operations, use the parameterless `finalize()` method
instead and manually add it to the module.

Args:

- `module`: The Python module to which the finalized type will be added. The type will be accessible from Python code that imports this module using the name specified during builder construction.

Raises: If the type object creation fails (see `finalize()` for details) or if adding the type to the module fails, typically due to name conflicts or module state issues.

#### `PythonTypeBuilder.def_init_defaultable`

```mojo
def def_init_defaultable[T: Defaultable & Deinitable & Movable](mut self) raises -> ref[self] Self
```

Declare a binding for the `__init__` method of the type which initializes the type with a default value.

Parameters:

- `T`: The Mojo type to bind, which must be `Defaultable` and `Movable`.

Returns: A reference to self for method chaining.

Raises: If the slot insertion fails.

#### `PythonTypeBuilder.def_py_init`

```mojo
def def_py_init[T: Deinitable & Movable, //, init_func: def(args: PythonObject, kwargs: PythonObject) thin -> T](mut self) raises -> ref[self] Self
```

Declare a binding for the `__init__` method of the type.

Parameters:

- `T`: The Mojo type to bind.
- `init_func`: The initialization function to bind.

Returns: A reference to self for method chaining.

Raises: If the slot insertion fails.

```mojo
def def_py_init[T: Deinitable & Movable, //, init_func: def(args: PythonObject, kwargs: PythonObject) raises thin -> T](mut self) raises -> ref[self] Self
```

Declare a binding for the `__init__` method of the type.

Parameters:

- `T`: The Mojo type to bind.
- `init_func`: The initialization function to bind (may raise).

Returns: A reference to self for method chaining.

Raises: If the slot insertion fails.

#### `PythonTypeBuilder.def_py_c_method`

```mojo
def def_py_c_method[static_method: Bool = False](mut self, method: def(PyObjectPtr, PyObjectPtr) abi("C") thin -> PyObjectPtr, method_name: StringSpan[ImmStaticOrigin], docstring: StringSpan[ImmStaticOrigin] = StringSpan()) -> ref[self] Self
```

Declare a binding for a method with PyObjectPtr signature for the type.

Parameters:

- `static_method`: Whether the method is exposed as a staticmethod. Default is False. Note that CPython will pass a null pointer for the first argument for static methods (i.e. instead of passing the self object). See [METH_STATIC](https://docs.python.org/3/c-api/structures.html#c.METH_STATIC).

Args:

- `method`: The method to declare a binding for.
- `method_name`: The name with which the method will be exposed on the type.
- `docstring`: The docstring for the method of the type.

Returns: The builder with the method binding declared.

```mojo
def def_py_c_method[static_method: Bool = False](mut self, method: def(PyObjectPtr, PyObjectPtr, PyObjectPtr) abi("C") thin -> PyObjectPtr, method_name: StringSpan[ImmStaticOrigin], docstring: StringSpan[ImmStaticOrigin] = StringSpan()) -> ref[self] Self
```

Declare a binding for a method with PyCFunctionWithKeywords signature for the type.

Parameters:

- `static_method`: Whether the method is exposed as a staticmethod. Default is False. Note that CPython will pass a null pointer for the first argument for static methods (i.e. instead of passing the self object). See [METH_STATIC](https://docs.python.org/3/c-api/structures.html#c.METH_STATIC).

Args:

- `method`: The method to declare a binding for.
- `method_name`: The name with which the method will be exposed on the type.
- `docstring`: The docstring for the method of the type.

Returns: The builder with the method binding declared.

```mojo
def def_py_c_method[static_method: Bool = False](mut self, method: def(PyObjectPtr, Pointer[PyObjectPtr, MutUntrackedOrigin], Int) abi("C") thin -> PyObjectPtr, method_name: StringSpan[ImmStaticOrigin], docstring: StringSpan[ImmStaticOrigin] = StringSpan()) -> ref[self] Self
```

Declare a binding for a method with `PyCFunctionFast` signature (`METH_FASTCALL`) for the type.

Parameters:

- `static_method`: Whether the method is exposed as a staticmethod. Default is False.

Args:

- `method`: The fastcall method to declare a binding for.
- `method_name`: The name with which the method will be exposed on the type.
- `docstring`: The docstring for the method of the type.

Returns: The builder with the method binding declared.

#### `PythonTypeBuilder.def_py_method`

```mojo
def def_py_method[method: def(mut PythonObject, mut PythonObject) raises thin -> PythonObject, static_method: Bool = False](mut self, method_name: StringSpan[ImmStaticOrigin], docstring: StringSpan[ImmStaticOrigin] = StringSpan()) -> ref[self] Self
```

Declare a binding for a method with PyFunctionRaising signature.

Accepts methods with signature: `def (mut PythonObject, mut PythonObject) thin raises -> PythonObject`
where the first arg is self and the second is a tuple of arguments.

Parameters:

- `method`: The method to declare a binding for.
- `static_method`: Whether the method is exposed as a staticmethod.

Args:

- `method_name`: The name with which the method will be exposed on the type.
- `docstring`: The docstring for the method of the type.

Returns: The builder with the method binding declared.

```mojo
def def_py_method[method: def(mut PythonObject, mut PythonObject, mut PythonObject) raises thin -> PythonObject, static_method: Bool = False](mut self, method_name: StringSpan[ImmStaticOrigin], docstring: StringSpan[ImmStaticOrigin] = StringSpan()) -> ref[self] Self
```

Declare a binding for a method with PyFunctionWithKeywordsRaising signature.

Accepts methods with signature:
`def (mut PythonObject, mut PythonObject, mut PythonObject) thin raises -> PythonObject`
where the first arg is self, the second is a tuple of arguments, and the third is a dict of keyword arguments.

Parameters:

- `method`: The method to declare a binding for.
- `static_method`: Whether the method is exposed as a staticmethod.

Args:

- `method_name`: The name with which the method will be exposed on the type.
- `docstring`: The docstring for the method of the type.

Returns: The builder with the method binding declared.

#### `PythonTypeBuilder.def_method`

```mojo
def def_method[SelfType: Deinitable, PyArgs: TypeList[PyArgs.values], RetType: Deinitable & Movable, //, method: def(self_: Pointer[SelfType, MutUnsafeAnyOrigin], *args: *PyArgs, var **kwargs: PythonObject) raises thin -> RetType](mut self, method_name: StringSpan[ImmStaticOrigin], docstring: StringSpan[ImmStaticOrigin] = StringSpan("")) -> ref[self] Self where Bool(identical(RetType, PythonObject)) or Bool(identical(RetType, None))
```

Declares a binding for a method with an automatically downcast self.

The method receives a pointer to the wrapped Mojo value. Methods that
need generic Python object access can receive `PythonObject` instead.

Non-kwargs methods register through CPython's `METH_FASTCALL`
calling convention; kwargs-accepting methods use
`METH_VARARGS | METH_KEYWORDS`.

Example signatures:
```mojo
from std.python import PythonObject

def method(
    self: Pointer[Self, MutUnsafeAnyOrigin],
    arg: PythonObject,
    var **kwargs: PythonObject,
) raises -> PythonObject: ...
```

Parameters:

- `SelfType`: The wrapped Mojo self type.
- `PyArgs`: The method's positional Python argument types.
- `RetType`: The method's return type.
- `method`: The method to declare a binding for.

Args:

- `method_name`: The name with which the method will be exposed on the type.
- `docstring`: The docstring for the method of the type.

Returns: The builder with the method binding declared.

#### `PythonTypeBuilder.def_staticmethod`

```mojo
def def_staticmethod[PyArgs: TypeList[PyArgs.values], RetType: Deinitable & Movable, //, method: def(*args: *PyArgs, var **kwargs: PythonObject) raises thin -> RetType](mut self, method_name: StringSpan[ImmStaticOrigin], docstring: StringSpan[ImmStaticOrigin] = StringSpan()) -> ref[self] Self where Bool(identical(RetType, PythonObject)) or Bool(identical(RetType, None))
```

Declares a binding for a static method with optional keyword arguments.

Accepts methods with `PythonObject` positional and keyword arguments.
The method can return a `PythonObject` or `None`, and can raise.

Non-kwargs static methods register through CPython's `METH_FASTCALL`
calling convention; kwargs-accepting static methods use
`METH_VARARGS | METH_KEYWORDS`.

Example signatures:
```mojo
from std.python import PythonObject

def static_method(arg1: PythonObject) -> PythonObject: ...
def static_method(arg1: PythonObject, arg2: PythonObject) raises: ...
def static_method(
    arg: PythonObject, var **kwargs: PythonObject
) raises -> PythonObject: ...
```

Parameters:

- `method`: The static method to declare a binding for.

Args:

- `method_name`: The name with which the method will be exposed on the type.
- `docstring`: The docstring for the method of the type.

Returns: The builder with the method binding declared.

### `ExceptionType`

```mojo
struct ExceptionType
```

A CPython global exception type used to translate a Mojo `Error` into a Python exception.

Fields:

- `global_name` (`StaticString`): The name of the backing CPython global, for example `PyExc_TypeError`.

Implemented traits: `AnyType`, `Copyable`, `Deinitable`, `ImplicitlyCopyable`, `Movable`, `RegisterPassable`, `TrivialRegisterPassable`

Aliases:

- `Exception = ExceptionType(StringSpan("PyExc_Exception"))`: The base `Exception` type.
- `TypeError = ExceptionType(StringSpan("PyExc_TypeError"))`: The `TypeError` type.
- `ValueError = ExceptionType(StringSpan("PyExc_ValueError"))`: The `ValueError` type.

## Functions

### `lookup_py_type_object`

```mojo
def lookup_py_type_object[T: AnyType]() raises -> PythonObject
```

Retrieve a reference to the unique Python type describing Python objects containing Mojo values of type `T`.

This function looks up the Python type object that was previously registered
for the Mojo type `T` using a `PythonTypeBuilder`. The returned type object
can be used to create Python objects that wrap Mojo values of type `T`.

Parameters:

- `T`: The Mojo type to look up.

Returns: A `PythonObject` representing the Python type object that binds the Mojo type `T` to the current CPython interpreter instance.

Raises: If no `PythonTypeBuilder` was ever finalized for type `T`, or if no Python type object has been registered for the provided type identifier.

### `raise_python_exception`

```mojo
def raise_python_exception(e: Error, exc_type: ExceptionType = ExceptionType.Exception) -> PyObjectPtr
```

Translate a Mojo `Error` into a Python exception and return NULL.

Sets the active Python exception via `PyErr_SetString` so that the
calling `PyCFunction` wrapper can return the resulting null `PyObjectPtr`
to signal the error to CPython.

Example:

```mojo
from std.python import PythonObject
from std.python._cpython import PyObjectPtr
from std.python.bindings import raise_python_exception

def do_work(args: PyObjectPtr) -> PythonObject:
    # Your wrapper's real work, which may raise a Mojo `Error`.
    return PythonObject(from_borrowed=args)

def my_wrapper(py_self: PyObjectPtr, args: PyObjectPtr) -> PyObjectPtr:
    try:
        return do_work(args).steal_data()
    except e:
        return raise_python_exception(e)
```

Args:

- `e`: The Mojo error to translate.
- `exc_type`: The CPython global exception type to set. Defaults to `ExceptionType.Exception`.

Returns: A null `PyObjectPtr`, which signals the error to CPython.

### `check_arguments_arity`

```mojo
def check_arguments_arity(arity: Int, args: PythonObject) raises
```

Validate that the provided arguments match the expected function arity.

This function checks if the number of arguments in the provided tuple object
matches the expected arity for a function call. If the counts don't match,
it raises a descriptive error message similar to Python's built-in TypeError
messages.

Args:

- `arity`: The expected number of arguments for the function.
- `args`: A tuple containing the actual arguments passed to the function.

Raises: If the argument count doesn't match the expected arity. The error message follows Python's convention for `TypeError` messages, indicating whether too few or too many arguments were provided.

```mojo
def check_arguments_arity(arity: Int, args: PythonObject, func_name: StringSpan) raises
```

Validate that the provided arguments match the expected function arity.

This function checks if the number of arguments in the provided tuple object
matches the expected arity for a function call. If the counts don't match,
it raises a descriptive error message similar to Python's built-in TypeError
messages.

Args:

- `arity`: The expected number of arguments for the function.
- `args`: A tuple containing the actual arguments passed to the function.
- `func_name`: The name of the function being called, used in error messages to provide better debugging information.

Raises: If the argument count doesn't match the expected arity. The error message follows Python's convention for TypeError messages, indicating whether too few or too many arguments were provided, along with the specific function name.

```mojo
def check_arguments_arity(arity: Int, arg_count: Int) raises
```

Validate that the provided argument count matches the expected arity.

Fastcall-friendly overload: takes the already-known number of positional
arguments rather than computing it from a tuple object. Used by the
`METH_FASTCALL` dispatch path, which receives `nargs: Py_ssize_t`
directly from CPython and never materializes a tuple.

Args:

- `arity`: The expected number of arguments for the function.
- `arg_count`: The actual number of arguments passed to the function.

Raises: If `arg_count` differs from `arity`. The error message follows Python's `TypeError` convention.

```mojo
def check_arguments_arity(arity: Int, arg_count: Int, func_name: StringSpan) raises
```

Validate that the provided argument count matches the expected arity.

Fastcall-friendly overload that accepts a precomputed arg count and a
function name. See the `arg_count`-only overload for the rationale.

Args:

- `arity`: The expected number of arguments for the function.
- `arg_count`: The actual number of arguments passed to the function.
- `func_name`: The name of the function being called, used in error messages.

Raises: If `arg_count` differs from `arity`.

### `check_and_get_arg`

```mojo
def check_and_get_arg[T: Deinitable](func_name: StringSpan[ImmStaticOrigin], py_args: PythonObject, index: Int) raises -> Pointer[T, MutUnsafeAnyOrigin]
```

Get the argument at the given index and downcast it to a given Mojo type.

Parameters:

- `T`: The Mojo type to downcast the argument to.

Args:

- `func_name`: The name of the function referenced in the error message if the downcast fails.
- `py_args`: The Python tuple object containing the arguments.
- `index`: The index of the argument.

Returns: A pointer to the Mojo value contained in the argument.

Raises: If the argument cannot be downcast to the given type.

### `check_and_get_or_convert_arg`

```mojo
def check_and_get_or_convert_arg[T: ConvertibleFromPython](func_name: StringSpan[ImmStaticOrigin], py_args: PythonObject, index: Int) raises -> Pointer[T, MutUnsafeAnyOrigin]
```

Get the argument at the given index and convert it to a given Mojo type.

If the argument cannot be directly downcast to the given type, it will be
converted to it.

Parameters:

- `T`: The Mojo type to downcast or convert the argument to.

Args:

- `func_name`: The name of the function referenced in the error message if the downcast fails.
- `py_args`: The Python tuple object containing the arguments.
- `index`: The index of the argument.

Returns: A pointer to the Mojo value contained in or converted from the argument.

Raises: If the argument cannot be downcast or converted to the given type.
