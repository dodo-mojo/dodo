# `std.testing.prop.strategy`

Implements the `Strategy` trait and exports built-in strategies for property-based testing.

## Modules

- [`std.testing.prop.strategy.list_strategy`](list_strategy.md): Implements the list strategy for generating random `List` values in property tests.
- [`std.testing.prop.strategy.simd_strategy`](simd_strategy.md): Implements the SIMD strategy for generating random `SIMD` values in property tests.
- [`std.testing.prop.strategy.string_strategy`](string_strategy.md): Implements the string strategy for generating random `String` values in property tests.

## Traits

### `Strategy`

```mojo
trait Strategy
```

A type used to produce random inputs for property tests.

Strategies are a core building block of property testing. They are used to
produce the random input values for the properties being tested.

Inherits from: `AnyType`, `Deinitable`, `Movable`

Aliases:

- `Value`: The type the strategy produces.

#### `Strategy.value`

```mojo
def value(mut self, mut rng: Rng) raises -> Self.Value
```

Produces a random value using this strategy.

Args:

- `rng`: The random number generator to use.

Returns: A random value.

Raises: If the underlying `Rng` raises an error.
