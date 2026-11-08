# `std.testing.testing`

Implements various testing utils.

You can import these APIs from the `testing` package. For example:

```mojo
from std.testing import assert_true

def main() raises:
    x = 1
    y = 2
    try:
        assert_true(x==1)
        assert_true(y==2)
        assert_true((x+y)==3)
        print("All assertions succeeded")
    except e:
        print("At least one assertion failed:")
        print(e)
```

## Structs

### `assert_raises`

```mojo
struct assert_raises
```

Context manager that asserts that the block raises an exception.

You can use this to test expected error cases, and to test that the correct
errors are raised. Works with `Error` and any custom `Writable` error type.
For instance:

```mojo
from std.testing import assert_raises

# Good! Caught the raised error, test passes
with assert_raises():
    raise Error("SomeError")

# Also good!
with assert_raises(contains="Some"):
    raise Error("SomeError")

# This will assert, we didn't raise
with assert_raises():
    pass

# This will let the underlying error propagate, failing the test
with assert_raises(contains="Some"):
    raise Error("OtherError")
```

Fields:

- `message_contains` (`Optional[String]`): If present, check that the error message contains this literal string.
- `call_location` (`SourceLocation`): Assigned the value returned by call_locations() at Self.__init__.

Implemented traits: `AnyType`, `Deinitable`, `Movable`

#### `assert_raises.__init__`

```mojo
def __init__(out self, *, location: Optional[SourceLocation] = None)
```

Construct a context manager with no message pattern.

Args:

- `location`: The location of the error (defaults to `call_location`).

```mojo
def __init__(out self, *, contains: String, location: Optional[SourceLocation] = None)
```

Construct a context manager matching specific errors.

Args:

- `contains`: The test will only pass if the error message includes the literal text passed.
- `location`: The location of the error (defaults to `call_location`).

#### `assert_raises.__enter__`

```mojo
def __enter__(self)
```

Enter the context manager.

#### `assert_raises.__exit__`

```mojo
def __exit__(self) raises
```

Exit the context manager with no error.

Raises: AssertionError: Always. The block must raise to pass the test.

```mojo
def __exit__[E: AnyType](self, error: E) raises -> Bool
```

Exit the context manager with an error.

Works with `Error` and any custom `Writable` error type. When
`contains` is specified, the error type must be `Writable` so
it can be converted to a string for matching.

Parameters:

- `E`: The error type.

Args:

- `error`: The error raised.

Returns: True if the error was successfully caught and matched.

Raises: Error: If `contains` is set and the error message doesn't include the expected string, or if `contains` is set but the error type is not `Writable`.

## Functions

### `assert_true`

```mojo
def assert_true[T: Boolable, //](val: T, msg: String = "condition was unexpectedly False", *, location: Optional[SourceLocation] = None) raises
```

Asserts that the input value is True and raises an Error if it's not.

Parameters:

- `T`: The type of the value argument.

Args:

- `val`: The value to assert to be True.
- `msg`: The message to be printed if the assertion fails.
- `location`: The location of the error (defaults to `call_location`).

Raises: An Error with the provided message if assert fails and `None` otherwise.

### `assert_false`

```mojo
def assert_false[T: Boolable, //](val: T, msg: String = "condition was unexpectedly True", *, location: Optional[SourceLocation] = None) raises
```

Asserts that the input value is False and raises an Error if it's not.

Parameters:

- `T`: The type of the value argument.

Args:

- `val`: The value to assert to be False.
- `msg`: The message to be printed if the assertion fails.
- `location`: The location of the error (defaults to `call_location`).

Raises: An Error with the provided message if assert fails and `None` otherwise.

### `assert_equal`

```mojo
def assert_equal[T: Equatable & Writable, //](lhs: T, rhs: T, msg: String = "", *, location: Optional[SourceLocation] = None) raises
```

Asserts that the input values are equal. If it is not then an Error is raised.

Parameters:

- `T`: The type of the input values.

Args:

- `lhs`: The lhs of the equality.
- `rhs`: The rhs of the equality.
- `msg`: The message to be printed if the assertion fails.
- `location`: The location of the error (defaults to `call_location`).

Raises: An Error with the provided message if assert fails and `None` otherwise.

```mojo
def assert_equal[O1: ImmOrigin, O2: ImmOrigin](lhs: List[StringSpan[O1]], rhs: List[StringSpan[O2]], msg: String = "", *, location: Optional[SourceLocation] = None) raises
```

Asserts that two lists are equal.

Parameters:

- `O1`: The origin of lhs.
- `O2`: The origin of rhs.

Args:

- `lhs`: The left-hand side list.
- `rhs`: The right-hand side list.
- `msg`: The message to be printed if the assertion fails.
- `location`: The location of the error (defaults to `call_location`).

Raises: An Error with the provided message if assert fails and `None` otherwise.

```mojo
def assert_equal[T: Equatable & Writable](lhs: Span[T], rhs: Span[T], msg: String = "") raises
```

Asserts that two spans are equal.

Parameters:

- `T`: The element type of both spans.

Args:

- `lhs`: The left-hand side span.
- `rhs`: The right-hand side span.
- `msg`: The message to be printed if the assertion fails.

Raises: An Error with the provided message if assert fails and `None` otherwise.

```mojo
def assert_equal(lhs: StringSpan, rhs: StringSpan, msg: String = "", *, location: Optional[SourceLocation] = None) raises
```

Asserts that a `StringSlice` is equal to a `String`.

Args:

- `lhs`: The left-hand side value.
- `rhs`: The right-hand side value.
- `msg`: An optional custom error message.
- `location`: The source location of the assertion (defaults to caller location).

Raises: If the values are not equal.

### `assert_equal_pyobj`

```mojo
def assert_equal_pyobj(lhs: PythonObject, rhs: PythonObject, msg: String = "", *, location: Optional[SourceLocation] = None) raises
```

Asserts that the `PythonObject`s are equal. If it is not then an Error is raised.

Args:

- `lhs`: The lhs of the equality.
- `rhs`: The rhs of the equality.
- `msg`: The message to be printed if the assertion fails.
- `location`: The location of the error (default to the `call_location`).

Raises: An Error with the provided message if assert fails.

### `assert_not_equal`

```mojo
def assert_not_equal[T: Equatable & Writable, //](lhs: T, rhs: T, msg: String = "", *, location: Optional[SourceLocation] = None) raises
```

Asserts that the input values are not equal. If it is not then an Error is raised.

Parameters:

- `T`: The type of the input values.

Args:

- `lhs`: The lhs of the inequality.
- `rhs`: The rhs of the inequality.
- `msg`: The message to be printed if the assertion fails.
- `location`: The location of the error (defaults to `call_location`).

Raises: An Error with the provided message if assert fails and `None` otherwise.

### `assert_almost_equal`

```mojo
def assert_almost_equal[dtype: DType, size: SIMDLength](lhs: SIMD[dtype, size], rhs: SIMD[dtype, size], msg: String = "", *, atol: Float64 = 1.0E-8, rtol: Float64 = 1.0000000000000001E-5, equal_nan: Bool = False, location: Optional[SourceLocation] = None) raises
```

Asserts that the input values are equal up to a tolerance. If it is not then an Error is raised.

When the type is boolean or integral, then equality is checked. When the
type is floating-point, then this checks if the two input values are
numerically the close using the $abs(lhs - rhs) <= max(rtol * max(abs(lhs),
abs(rhs)), atol)$ formula.

Constraints: The type must be boolean, integral, or floating-point.

Parameters:

- `dtype`: The dtype of the left- and right-hand-side SIMD vectors.
- `size`: The width of the left- and right-hand-side SIMD vectors.

Args:

- `lhs`: The lhs of the equality.
- `rhs`: The rhs of the equality.
- `msg`: The message to print.
- `atol`: The absolute tolerance.
- `rtol`: The relative tolerance.
- `equal_nan`: Whether to treat nans as equal.
- `location`: The location of the error (defaults to `call_location`).

Raises: An Error with the provided message if assert fails and `None` otherwise.

### `assert_is`

```mojo
def assert_is[T: Identifiable & Writable, //](lhs: T, rhs: T, msg: String = "", *, location: Optional[SourceLocation] = None) raises
```

Asserts that the input values have the same identity. If they do not then an Error is raised.

Parameters:

- `T`: A Writable and Identifiable type.

Args:

- `lhs`: The lhs of the `is` statement.
- `rhs`: The rhs of the `is` statement.
- `msg`: The message to be printed if the assertion fails.
- `location`: The location of the error (defaults to `call_location`).

Raises: An Error with the provided message if assert fails and `None` otherwise.

### `assert_is_not`

```mojo
def assert_is_not[T: Identifiable & Writable, //](lhs: T, rhs: T, msg: String = "", *, location: Optional[SourceLocation] = None) raises
```

Asserts that the input values have different identities. If they do not then an Error is raised.

Parameters:

- `T`: A Writable and Identifiable type.

Args:

- `lhs`: The lhs of the `is not` statement.
- `rhs`: The rhs of the `is not` statement.
- `msg`: The message to be printed if the assertion fails.
- `location`: The location of the error (defaults to `call_location`).

Raises: An Error with the provided message if assert fails and `None` otherwise.
