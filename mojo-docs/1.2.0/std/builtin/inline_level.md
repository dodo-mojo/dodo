# `std.builtin.inline_level`

Provides the levels the `@inline` decorator accepts.

These are in the prelude, so they need no import.

## Structs

### `InlineLevel`

```mojo
struct InlineLevel
```

Names the levels the `@inline` decorator accepts.

`@inline` takes one of these, so a misspelling is caught where it is
written, and a comptime expression can choose a level per instantiation:

```mojo
@inline(.always)
def doubled(x: Int) -> Int:
    return x * 2

@inline(policy)
def scaled[policy: InlineLevel](x: Int) -> Int:
    return x * 3

def main():
    print(doubled(1) + scaled[.never](2))
```

Implemented traits: `AnyType`, `Copyable`, `Deinitable`, `Equatable`, `ImplicitlyCopyable`, `Movable`, `RegisterPassable`, `TrivialRegisterPassable`

Aliases:

- `automatic = InlineLevel(value=Int(0))`: Leaves the decision to the compiler's heuristics.
- `always = InlineLevel(value=Int(1))`: Always inlines the function.
- `nodebug = InlineLevel(value=Int(2))`: Always inlines the function, and drops its debug info when inlining.
- `never = InlineLevel(value=Int(4))`: Never inlines the function.

#### `InlineLevel.__eq__`

```mojo
def __eq__(self, rhs: Self) -> Bool
```

Compare two levels.

Args:

- `rhs`: The level to compare against.

Returns: True if the levels are the same.
