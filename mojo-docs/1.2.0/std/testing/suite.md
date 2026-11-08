# `std.testing.suite`

Implements test suite infrastructure for organizing and running tests.

This module provides the `TestSuite` type for collecting, filtering, and
executing unit tests with automatic discovery, command-line filtering, and
formatted reporting. It includes support for colored output, timing statistics,
and flexible test selection via CLI arguments.

## Structs

### `TestResult`

```mojo
struct TestResult
```

A test result code.

Implemented traits: `AnyType`, `Copyable`, `Deinitable`, `EnumLike`, `Equatable`, `ImplicitlyCopyable`, `Movable`, `Writable`

Aliases:

- `PASS = TestResult(Int(0))`: The test passed.
- `FAIL = TestResult(Int(1))`: The test failed.
- `SKIP = TestResult(Int(2))`: The test was skipped.

#### `TestResult.__eq__`

```mojo
def __eq__(self, rhs: Self) -> Bool
```

Compare two test result codes for equality.

Args:

- `rhs`: The other test result code to compare against.

Returns: True if the result codes are equal, False otherwise.

#### `TestResult.write_to`

```mojo
def write_to(self, mut writer: T)
```

Write the result code to the writer.

Args:

- `writer`: The writer to output the result code to.

#### `TestResult.write_repr_to`

```mojo
def write_repr_to(self, mut writer: T)
```

Write the repr of this test result to a writer.

Args:

- `writer`: The writer to output to.

### `TestReport`

```mojo
struct TestReport
```

A report for a single unit test.

Fields:

- `name` (`String`): The name of the test.
- `duration_ns` (`Int`): The duration of the test in nanoseconds.
- `result` (`TestResult`): The result code of the test.
- `error` (`Optional[Error]`): The error associated with a failing test.

Implemented traits: `AnyType`, `Copyable`, `Deinitable`, `Movable`, `Writable`

#### `TestReport.passed`

```mojo
def passed(*, var name: String, duration_ns: Int) -> Self
```

Create a passing test report.

Args:

- `name`: The name of the test.
- `duration_ns`: The duration of the test in nanoseconds.

Returns: A new passing test report.

#### `TestReport.failed`

```mojo
def failed(*, var name: String, duration_ns: Int, var error: Error) -> Self
```

Create a failing test report.

Args:

- `name`: The name of the test.
- `duration_ns`: The duration of the test in nanoseconds.
- `error`: The error raised by the failing test.

Returns: A new failing test report.

#### `TestReport.skipped`

```mojo
def skipped(*, var name: String) -> Self
```

Create a skipped test report.

Args:

- `name`: The name of the test.

Returns: A new skipped test report.

#### `TestReport.write_to`

```mojo
def write_to(self, mut writer: T)
```

Write the formatted test report to the writer.

Args:

- `writer`: The writer to output the formatted report to.

#### `TestReport.write_repr_to`

```mojo
def write_repr_to(self, mut writer: T)
```

Write the repr of this test report to a writer.

Args:

- `writer`: The writer to output to.

### `TestSuiteReport`

```mojo
struct TestSuiteReport
```

A report for an entire test suite.

Fields:

- `reports` (`List[TestReport]`): The reports for each test in the suite.
- `total_duration_ns` (`Int`): The total duration of the suite in nanoseconds.
- `failures` (`Int`): The number of tests that failed.
- `skipped` (`Int`): The number of tests skipped.
- `passed` (`Int`): The number of tests that passed.
- `location` (`SourceLocation`): The source location of the test suite.

Implemented traits: `AnyType`, `Copyable`, `Deinitable`, `Movable`, `Writable`

#### `TestSuiteReport.__init__`

```mojo
def __init__(out self, *, var reports: List[TestReport], location: SourceLocation)
```

Initialize a test suite report.

Args:

- `reports`: The list of individual test reports.
- `location`: The source location where the test suite is defined.

#### `TestSuiteReport.write_to`

```mojo
def write_to(self, mut writer: T)
```

Write the formatted test suite report to the writer.

Args:

- `writer`: The writer to output the formatted suite report to.

#### `TestSuiteReport.write_repr_to`

```mojo
def write_repr_to(self, mut writer: T)
```

Write the repr of this test suite report to a writer.

Args:

- `writer`: The writer to output to.

### `TestSuite`

```mojo
struct TestSuite
```

A suite of tests to run.

You can automatically collect and register test functions starting with
`test_` by calling the `discover_tests` static method, and then running the
entire suite by calling the `run` method.

Example:

```mojo
from std.testing import assert_equal, TestSuite

def test_something() raises:
    assert_equal(1 + 1, 2)

def test_some_other_thing() raises:
    assert_equal(2 + 2, 4)

def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
```

Alternatively, you can manually register tests by calling the `test` method.

```mojo
from std.testing import assert_equal, TestSuite

def some_test() raises:
    assert_equal(1 + 1, 2)

def main() raises:
    var suite = TestSuite()
    suite.test[some_test]()
    suite^.run()
```

Fields:

- `tests` (`List[_Test]`): The list of tests registered in this suite.
- `location` (`SourceLocation`): The source location where the test suite was created.
- `skip_list` (`Set[String]`): The list of tests to skip in this suite.
- `allow_list` (`Optional[Set[String]]`): The list of tests to allow in this suite.
- `cli_args` (`List[StringSpan[ImmStaticOrigin]]`): The raw command line arguments passed to the test suite.

Implemented traits: `AnyType`, `Movable`

#### `TestSuite.__init__`

```mojo
def __init__(out self, *, location: Optional[SourceLocation] = None, var cli_args: Optional[List[StringSpan[ImmStaticOrigin]]] = None)
```

Create a new test suite.

Args:

- `location`: The location of the test suite (defaults to `call_location`).
- `cli_args`: The command line arguments to pass to the test suite (defaults to `sys.argv()`).

#### `TestSuite.discover_tests`

```mojo
def discover_tests[test_funcs: Tuple[test_funcs.Ts], /](*, location: Optional[SourceLocation] = None, var cli_args: Optional[List[StringSpan[ImmStaticOrigin]]] = None) raises -> Self
```

Discover tests from the given list of functions, and register them.

Parameters:

- `test_funcs`: The pack of functions to discover tests from. In most cases, callers should pass `__functions_in_module()`.

Args:

- `location`: The location of the test suite (defaults to `call_location`).
- `cli_args`: The command line arguments to pass to the test suite (defaults to `sys.argv()`).

Returns: A new TestSuite with all discovered tests registered.

Raises: If test discovery fails (e.g. because of a nonconforming test function signature).

#### `TestSuite.test`

```mojo
def test[f: def() raises thin -> None](mut self)
```

Registers a test to be run.

Parameters:

- `f`: The function to run.

#### `TestSuite.skip`

```mojo
def skip[f: def() raises thin -> None](mut self)
```

Registers a test to be skipped.

If attempting to skip a test that is not registered in the suite (either
explicitly or via automatic discovery), an error will be raised when the
suite is run.

Parameters:

- `f`: The function to skip.

#### `TestSuite.generate_report`

```mojo
def generate_report(mut self, skip_all: Bool = False) raises -> TestSuiteReport
```

Runs the test suite and generates a report.

Args:

- `skip_all`: Only collect tests, but don't execute them (defaults to `False`).

Returns: A report containing the results of all tests.

Raises: If an error occurs during test collection.

#### `TestSuite.run`

```mojo
def run(deinit self, *, quiet: Bool = False, skip_all: Bool = False) raises
```

Runs the test suite and prints the results to the console.

Args:

- `quiet`: Suppresses printing the report when the suite does not fail (defaults to `False`).
- `skip_all`: Only collect tests, but don't execute them (defaults to `False`).

Raises: If a test in the test suite fails or if an error occurs during test collection.

#### `TestSuite.abandon`

```mojo
def abandon(deinit self)
```

Destroy a test suite without running any tests.
