# `std.time.time`

Implements basic utils for working with time.

You can import these APIs from the `time` package. For example:

```mojo
from std.time import perf_counter_ns
```

## Functions

### `perf_counter`

```mojo
def perf_counter() -> Float64
```

Return the value (in fractional seconds) of a performance counter, i.e. a clock with the highest available resolution to measure a short duration. It does include time elapsed during sleep and is system-wide. The reference point of the returned value is undefined, so that only the difference between the results of two calls is valid.

Returns: The current time in ns.

### `perf_counter_ns`

```mojo
def perf_counter_ns() -> Int
```

Return the value (in nanoseconds) of a performance counter, i.e. a clock with the highest available resolution to measure a short duration. It does include time elapsed during sleep and is system-wide. The reference point of the returned value is undefined, so that only the difference between the results of two calls is valid.

Returns: The current time in ns.

### `global_perf_counter_ns`

```mojo
def global_perf_counter_ns() -> UInt64
```

Returns the current value in the global nanosecond resolution timer. This value is common across all SM's.

On NVIDIA GPUs, this uses the globaltimer register which provides nanosecond
resolution. On AMD GPUs, this uses the realtime counter (constant-speed clock)
converted to nanoseconds. On other platforms, this falls back to
perf_counter_ns().

Returns: The current time in ns.

### `monotonic`

```mojo
def monotonic() -> Int
```

Returns the current monotonic time time in nanoseconds. This function queries the current platform's monotonic clock, making it useful for measuring time differences, but the significance of the returned value varies depending on the underlying implementation.

Returns: The current time in ns.

### `time_function`

```mojo
def time_function[FuncType: def() raises -> None](func: FuncType) raises -> Int
```

Measures the time spent in the function.

Parameters:

- `FuncType`: The function type to time.

Args:

- `func`: The closure carrying the captured state of the timed function.

Returns: The time elapsed in the function in ns.

Raises: If the operation fails.

```mojo
def time_function[FuncType: def() -> None](func: FuncType) -> Int
```

Measures the time spent in the function.

Parameters:

- `FuncType`: The function type to time.

Args:

- `func`: The closure carrying the captured state of the timed function.

Returns: The time elapsed in the function in ns.

### `sleep`

```mojo
def sleep(sec: Float64)
```

Suspends the current thread for the seconds specified.

Args:

- `sec`: The number of seconds to sleep for. Values <= 0 return immediately.

```mojo
def sleep(sec: Int)
```

Suspends the current thread for the seconds specified.

Args:

- `sec`: The number of seconds to sleep for.
