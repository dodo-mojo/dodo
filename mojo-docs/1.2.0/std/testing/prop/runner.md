# `std.testing.prop.runner`

Implements the property test runner and configuration.

## Structs

### `PropTestConfig`

```mojo
struct PropTestConfig
```

A configuration for a property test.

Fields:

- `runs` (`Int`): The number of successful test runs to achieve before stopping the test.
- `seed` (`Int`): The seed for the random number generator.

Implemented traits: `AnyType`, `Copyable`, `Deinitable`, `Movable`

#### `PropTestConfig.__init__`

```mojo
def __init__(out self, *, runs: Int = Int(100), seed: Optional[Int] = None)
```

Construct a new property test configuration.

Args:

- `runs`: The number of successful test runs to achieve before stopping the test.
- `seed`: The seed for the random number generator.

### `PropTest`

```mojo
struct PropTest
```

A property test runner.

Implemented traits: `AnyType`, `Deinitable`, `Movable`

#### `PropTest.__init__`

```mojo
def __init__(out self)
```

Construct a new property test runner with the default configuration.

Returns: A new property test runner with the default configuration.

```mojo
def __init__(out self, *, var config: PropTestConfig)
```

Construct a new property test runner.

Args:

- `config`: The configuration for the property test.

#### `PropTest.test`

```mojo
def test[StrategyType: Strategy, //, f: def(var StrategyType.Value) raises thin -> None](self, var strategy: StrategyType) raises
```

Run a property test with the given strategy.

Parameters:

- `StrategyType`: The strategy type to use for the property test.
- `f`: The function to test.

Args:

- `strategy`: The strategy value to use for the property test.

Raises: An error if the property test fails.
