# `std.math.polynomial`

Provides two implementations for evaluating polynomials.

You can import these APIs from the `math` package. For example:

```mojo
from std.math.polynomial import polynomial_evaluate
```

## Functions

### `polynomial_evaluate`

```mojo
def polynomial_evaluate[dtype: DType, width: SIMDLength, //, coefficients: Span[Scalar[dtype], coefficients.origin]](x: SIMD[dtype, width]) -> SIMD[dtype, width]
```

Evaluates the polynomial.

Parameters:

- `dtype`: The dtype of the value.
- `width`: The width of the computed value.
- `coefficients`: The coefficients.

Args:

- `x`: The value to compute the polynomial with.

Returns: The polynomial evaluation results using the specified value and the constant coefficients.
