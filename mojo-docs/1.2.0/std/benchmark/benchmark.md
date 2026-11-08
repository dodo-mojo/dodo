# `std.benchmark.benchmark`

Implements the benchmark module for runtime benchmarking.

You can import these APIs from the `benchmark` package. For example:

```mojo
from std.benchmark import run, Unit
from std.time import sleep
```

You can pass any function as an argument into `run()`, it will return
a `Report` where you can get the mean, duration, max, and more:

```mojo
from std.benchmark import run
from std.time import sleep

def sleeper():
    sleep(.01)

var report = run(sleeper)
print(report.mean())
```

```output
0.012256487394957985
```

You can print a full report:

```mojo
from std.benchmark import run
from std.time import sleep

def sleeper():
    sleep(.01)

var report = run(sleeper)
report.print()
```

```output
---------------------
Benchmark Report (s)
---------------------
Mean: 0.012265747899159664
Total: 1.459624
Iters: 119
Warmup Total: 0.025020000000000001
Fastest Mean: 0.0121578
Slowest Mean: 0.012321428571428572

```

Or all the batch runs:

```mojo
from std.benchmark import run
from std.time import sleep

def sleeper():
    sleep(.01)

var report = run(sleeper)
report.print_full()
```

```output
---------------------
Benchmark Report (s)
---------------------
Mean: 0.012368649122807017
Total: 1.410026
Iters: 114
Warmup Total: 0.023341000000000001
Fastest Mean: 0.012295586956521738
Slowest Mean: 0.012508099999999999

Batch: 1
Iterations: 20
Mean: 0.012508099999999999
Duration: 0.250162

Batch: 2
Iterations: 46
Mean: 0.012295586956521738
Duration: 0.56559700000000002

Batch: 3
Iterations: 48
Mean: 0.012380562499999999
Duration: 0.59426699999999999
```

If you want to use a different time unit you can bring in the Unit and pass
it in as an argument:

```mojo
from std.benchmark import run, Unit
from std.time import sleep

def sleeper():
    sleep(.01)

var report = run(sleeper)
report.print(Unit.ms)
```

```output
---------------------
Benchmark Report (ms)
---------------------
Mean: 0.012312411764705882
Total: 1.465177
Iters: 119
Warmup Total: 0.025010999999999999
Fastest Mean: 0.012015649999999999
Slowest Mean: 0.012421204081632654
```

The unit's are just aliases for string constants, so you can for example:

```mojo
from std.benchmark import run
from std.time import sleep

def sleeper():
    sleep(.01)

var report = run(sleeper)
print(report.mean("ms"))
```

```output
12.199145299145298
```

Benchmark.run takes four arguments to change the behaviour, to set warmup
iterations to 5:

```mojo
from std.benchmark import run
from std.time import sleep

def sleeper():
    sleep(.01)

var r = run(sleeper, 5)
```

```output
0.012004808080808081
```

To set 1 warmup iteration, 2 max iterations, a min total time of 3 sec, and a
max total time of 4 s:

```mojo
from std.benchmark import run
from std.time import sleep

def sleeper():
    sleep(.01)

var r = run(sleeper, 1, 2, 3, 4)
```

Note that benchmarking continues until `min_runtime_secs` has
elapsed and either `max_runtime_secs` OR `max_iters` is achieved.

## Structs

### `Batch`

```mojo
struct Batch
```

A batch of benchmarks, the benchmark.run() function works out how many iterations to run in each batch based the how long the previous iterations took.

Fields:

- `duration` (`Int`): Total duration of batch stored as nanoseconds.
- `iterations` (`Int`): Total iterations in the batch.

Implemented traits: `AnyType`, `Copyable`, `Deinitable`, `ImplicitlyCopyable`, `Movable`, `RegisterPassable`, `TrivialRegisterPassable`, `Writable`

#### `Batch.mean`

```mojo
def mean(self, unit: String = Unit.s) -> Float64
```

Returns the average duration of the batch.

Args:

- `unit`: The time unit to display for example: ns, ms, s (default `s`).

Returns: The average duration of the batch.

#### `Batch.write_to`

```mojo
def write_to(self, mut writer: T)
```

Formats this `Batch` to the provided Writer.

Args:

- `writer`: The object to write to.

#### `Batch.write_repr_to`

```mojo
def write_repr_to(self, mut writer: T)
```

Writes the repr of this `Batch` to a writer.

Args:

- `writer`: The object to write to.

### `Unit`

```mojo
struct Unit
```

Time Unit used by Benchmark Report.

Implemented traits: `AnyType`, `Deinitable`, `Movable`

Aliases:

- `ns = "ns"`: Nanoseconds.
- `us = "us"`: Microseconds.
- `ms = "ms"`: Milliseconds.
- `s = "s"`: Seconds.

### `Report`

```mojo
struct Report
```

Contains the average execution time, iterations, min and max of each batch.

Fields:

- `warmup_duration` (`Int`): The total duration it took to warmup.
- `runs` (`List[Batch]`): A `List` of benchmark runs.

Implemented traits: `AnyType`, `Copyable`, `Defaultable`, `Deinitable`, `Movable`

#### `Report.__init__`

```mojo
def __init__(out self)
```

Default initializer for the Report.

Sets all values to 0

#### `Report.iters`

```mojo
def iters(self) -> Int
```

The total benchmark iterations.

Returns: The total benchmark iterations.

#### `Report.duration`

```mojo
def duration(self, unit: String = Unit.s) -> Float64
```

The total duration it took to run all benchmarks.

Args:

- `unit`: The time unit to display for example: ns, us, ms, s (default `s`).

Returns: The total duration it took to run all benchmarks.

#### `Report.mean`

```mojo
def mean(self, unit: String = Unit.s) -> Float64
```

The average duration of all benchmark runs.

Args:

- `unit`: The time unit to display for example: ns, us, ms, s (default `s`).

Returns: The average duration of all benchmark runs.

#### `Report.min`

```mojo
def min(self, unit: String = Unit.s) -> Float64
```

The batch of benchmarks that was the fastest to run.

Args:

- `unit`: The time unit to display for example: ns, us, ms, s (default `s`).

Returns: The fastest duration out of all batches.

#### `Report.max`

```mojo
def max(self, unit: String = Unit.s) -> Float64
```

The batch of benchmarks that was the slowest to run.

Args:

- `unit`: The time unit to display for example: ns, us, ms, s (default `s`).

Returns: The slowest duration out of all batches.

#### `Report.as_string`

```mojo
def as_string(self, unit: String = Unit.s) -> String
```

Converts the Report to a String.

Args:

- `unit`: The time unit to display for example: ns, us, ms, s (default `s`).

Returns: The string representation of the Report.

#### `Report.print`

```mojo
def print(self, unit: String = Unit.s)
```

Prints out the shortened version of the report.

Args:

- `unit`: The time unit to display for example: ns, us, ms, s (default `s`).

#### `Report.print_full`

```mojo
def print_full(self, unit: String = Unit.s)
```

Prints out the full version of the report with each batch of benchmark runs.

Args:

- `unit`: The time unit to display for example: ns, us, ms, s (default `s`).

## Functions

### `run`

```mojo
def run(f: T, num_warmup_iters: Int = Int(1), max_iters: Int = Int(1000000000), min_runtime_secs: Float64 = 0.10000000000000001, max_runtime_secs: Float64 = Float64("60"), max_batch_size: Int = Int(0)) raises -> Report
```

Benchmarks the function passed in as an argument.

Benchmarking continues until `min_runtime_secs` has elapsed and either
`max_runtime_secs` OR `max_iters` is achieved.

Args:

- `f`: The function to benchmark. Accepts a unified closure, so `f` can be a thin function or a closure that captures state.
- `num_warmup_iters`: Number of warmup iterations.
- `max_iters`: Max number of iterations to run (default `1_000_000_000`).
- `min_runtime_secs`: Lower bound on benchmarking time in secs (default `0.1`).
- `max_runtime_secs`: Upper bound on benchmarking time in secs (default `60`).
- `max_batch_size`: The maximum number of iterations to perform per time measurement.

Returns: Average execution time of func in ns.

Raises: If the operation fails.
