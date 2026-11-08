# `dodo.json.dtoa`

## Functions

### `shortest_digits`

```mojo
def shortest_digits(value: Float64, mut digits: Array[UInt8, Int(24)]) -> Tuple[Int, Int]
```

Decimal digits of a finite non-zero `value`, and its exponent.

The value equals `0.d1 d2 ... dn * 10**(K + n)` where `n` is the
returned count and `K` the returned exponent; equivalently, the
digit string read as an integer, times ten to the `K`.

Args:

- `value`: A finite, non-zero, positive `Float64`.
- `digits`: Filled with ASCII digits.

Returns: The digit count and the decimal exponent `K`.
