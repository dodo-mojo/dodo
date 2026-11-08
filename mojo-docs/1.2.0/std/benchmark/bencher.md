# `std.benchmark.bencher`

Implements comprehensive benchmarking infrastructure with statistical analysis.

This module provides the core types and functions for running benchmarks with
configurable execution parameters, statistical analysis, and formatted output.
It includes support for throughput metrics, warmup iterations, batch execution,
and both CPU and GPU kernel benchmarking.

## Structs

### `BenchMetric`

```mojo
struct BenchMetric
```

Defines a benchmark throughput metric.

Fields:

- `code` (`Int`): Op-code of the Metric.
- `name` (`String`): Metric's name.
- `unit` (`String`): Metric's throughput rate unit (count/second).

Implemented traits: `AnyType`, `Copyable`, `Deinitable`, `ImplicitlyCopyable`, `Movable`, `Writable`

Aliases:

- `elements = BenchMetric(Int(0), String("throughput"), String("GElems/s"))`: Metric for measuring throughput in elements per second.
- `bytes = BenchMetric(Int(1), String("DataMovement"), String("GB/s"))`: Metric for measuring data movement in bytes per second.
- `flops = BenchMetric(Int(2), String("Arithmetic"), String("GFLOPS/s"))`: Metric for measuring floating point operations per second.
- `theoretical_flops = BenchMetric(Int(3), String("TheoreticalArithmetic"), String("GFLOPS/s"))`: Metric for measuring theoretical floating point operations per second.
- `DEFAULTS = List(BenchMetric.elements, BenchMetric.bytes, BenchMetric.flops, __list_literal__=NoneType(None))`: Default set of benchmark metrics.

#### `BenchMetric.__eq__`

```mojo
def __eq__(self, other: Self) -> Bool
```

Compares two metrics for equality.

Args:

- `other`: The metric to compare.

Returns: True if the two metrics are equal.

#### `BenchMetric.__ne__`

```mojo
def __ne__(self, other: Self) -> Bool
```

Compares two metrics for inequality.

Args:

- `other`: The metric to compare.

Returns: True if the two metrics are NOT equal.

#### `BenchMetric.write_to`

```mojo
def write_to(self, mut writer: T)
```

Formats this BenchMetric to the provided Writer.

Args:

- `writer`: The object to write to.

#### `BenchMetric.write_repr_to`

```mojo
def write_repr_to(self, mut writer: T)
```

Writes the repr of this `BenchMetric` to a writer.

Args:

- `writer`: The object to write to.

#### `BenchMetric.check_name`

```mojo
def check_name(self, alt_name: String) -> Bool
```

Checks whether a string contains the metric's name.

Args:

- `alt_name`: Alternative name of a metric.

Returns: True if 'alt_name' is valid alternative of the metric's name.

#### `BenchMetric.get_metric_from_list`

```mojo
def get_metric_from_list(name: String, metric_list: List[Self]) raises -> Self
```

Gets a metric from a given list using only the metric's name.

Args:

- `name`: Metric's name.
- `metric_list`: List of metrics to search.

Returns: The selected metric.

Raises: If the operation fails.

### `ThroughputMeasure`

```mojo
struct ThroughputMeasure
```

Records a throughput metric of metric BenchMetric and value.

Fields:

- `metric` (`BenchMetric`): Type of throughput metric.
- `value` (`Int`): Measured count of throughput metric.

Implemented traits: `AnyType`, `Copyable`, `Deinitable`, `ImplicitlyCopyable`, `Movable`, `Writable`

#### `ThroughputMeasure.__init__`

```mojo
def __init__(out self, name: String, value: Int, reference: List[BenchMetric] = BenchMetric.DEFAULTS) raises
```

Creates a `ThroughputMeasure` based on metric's name.

Example:

```mojo
For the default bench metrics `BenchMetric.DEFAULTS` the
following are equivalent:
    - `ThroughputMeasure(BenchMetric.fmas, 1024)`
    - `ThroughputMeasure("fmas", 1024)`
    - `ThroughputMeasure("fmas", 1024, BenchMetric.DEFAULTS)`
```

Args:

- `name`: The name of BenchMetric in its corresponding reference.
- `value`: The measured value to assign to this metric.
- `reference`: List of BenchMetrics that contains this metric.

Raises: If the operation fails.

#### `ThroughputMeasure.write_to`

```mojo
def write_to(self, mut writer: T)
```

Formats this ThroughputMeasure to the provided Writer.

Args:

- `writer`: The object to write to.

#### `ThroughputMeasure.write_repr_to`

```mojo
def write_repr_to(self, mut writer: T)
```

Writes the repr of this `ThroughputMeasure` to a writer.

Args:

- `writer`: The object to write to.

#### `ThroughputMeasure.compute`

```mojo
def compute(self, elapsed_sec: Float64) -> Float64
```

Computes throughput rate for this metric per unit of time (second).

Args:

- `elapsed_sec`: Elapsed time measured in seconds.

Returns: The throughput values as a floating point 64.

### `Format`

```mojo
struct Format
```

Defines a format for the benchmark output when printing or writing to a file.

Fields:

- `value` (`StaticString`): The format to print results.

Implemented traits: `AnyType`, `Copyable`, `Deinitable`, `ImplicitlyCopyable`, `Movable`, `Writable`

Aliases:

- `csv = Format(StringSpan("csv"))`: Comma separated values with no alignment.
- `tabular = Format(StringSpan("tabular"))`: Comma separated values with dynamically aligned columns.
- `table = Format(StringSpan("table"))`: Table format with dynamically aligned columns.

#### `Format.__init__`

```mojo
def __init__(out self, value: StringSpan)
```

Constructs a Format object from a string.

Args:

- `value`: The format to print results.

#### `Format.__eq__`

```mojo
def __eq__(self, other: Self) -> Bool
```

Checks if two Format objects are equal.

Args:

- `other`: The `Format` to compare with.

Returns: True if the two `Format` objects are equal, false otherwise.

#### `Format.write_to`

```mojo
def write_to(self, mut writer: T)
```

Writes the format to a writer.

Args:

- `writer`: The writer to write the `Format` to.

#### `Format.write_repr_to`

```mojo
def write_repr_to(self, mut writer: T)
```

Writes the repr of this `Format` to a writer.

Args:

- `writer`: The writer to write to.

### `BenchConfig`

```mojo
struct BenchConfig
```

Defines a benchmark configuration struct to control execution times and frequency.

Fields:

- `out_file` (`Optional[Path]`): Output file to write results to.
- `min_runtime_secs` (`Float64`): Lower bound on benchmarking time in secs.
- `max_runtime_secs` (`Float64`): Upper bound on benchmarking time in secs.
- `num_warmup_iters` (`Int`): Number of warmup iterations.
- `max_batch_size` (`Int`): The maximum number of iterations to perform per time measurement.
- `max_iters` (`Int`): Max number of iterations to run.
- `num_repetitions` (`Int`): Number of times the benchmark has to be repeated.
- `flush_denormals` (`Bool`): Whether or not the denormal values are flushed.
- `show_progress` (`Bool`): If True, print progress of each benchmark.
- `format` (`Format`): The format to print results. (default: "table").
- `out_file_format` (`Format`): The format to write out the file with `dump_file` (default: "csv").
- `verbose_timing` (`Bool`): Whether to print verbose timing results.
- `verbose_metric_names` (`Bool`): If True print the metric name and unit, else print the unit only.

Implemented traits: `AnyType`, `Copyable`, `Deinitable`, `Movable`

Aliases:

- `VERBOSE_TIMING_LABELS = List(String("min (ms)"), String("mean (ms)"), String("max (ms)"), String("duration (ms)"), __list_literal__=NoneType(None))`: Labels to print verbose timing results.

#### `BenchConfig.__init__`

```mojo
def __init__(out self, out_file: Optional[Path] = None, min_runtime_secs: Float64 = 0, max_runtime_secs: Float64 = 1, num_warmup_iters: Int = Int(10), max_batch_size: Int = Int(0), max_iters: Int = Int(1000), num_repetitions: Int = Int(1), flush_denormals: Bool = True) raises
```

Constructs and initializes Benchmark config object with default and inputted values.

Args:

- `out_file`: Output file to write results to.
- `min_runtime_secs`: Lower bound on benchmarking time in secs (default `0.0`).
- `max_runtime_secs`: Upper bound on benchmarking time in secs (default `1.0`).
- `num_warmup_iters`: Number of warmup iterations (default `10`).
- `max_batch_size`: The maximum number of iterations to perform per time measurement.
- `max_iters`: Max number of iterations to run (default `1_000`).
- `num_repetitions`: Number of times the benchmark has to be repeated.
- `flush_denormals`: Whether or not the denormal values are flushed.

Raises: If the operation fails.

### `BenchId`

```mojo
struct BenchId
```

Defines a benchmark Id struct to identify and represent a particular benchmark execution.

Fields:

- `func_name` (`String`): The target function name.
- `input_id` (`Optional[String]`): The target function input id phrase.

Implemented traits: `AnyType`, `Copyable`, `Deinitable`, `Equatable`, `Hashable`, `Movable`, `Writable`

#### `BenchId.__init__`

```mojo
def __init__(out self, func_name: String, input_id: String)
```

Constructs a Benchmark Id object from input function name and Id phrase.

Args:

- `func_name`: The target function name.
- `input_id`: The target function input id phrase.

```mojo
def __init__(out self, func_name: String)
```

Constructs a Benchmark Id object from input function name.

Args:

- `func_name`: The target function name.

```mojo
def __init__(out self, func_name: StringLiteral)
```

Constructs a Benchmark Id object from input function name.

Args:

- `func_name`: The target function name.

### `BenchmarkInfo`

```mojo
struct BenchmarkInfo
```

Defines a Benchmark Info struct to record execution Statistics.

Fields:

- `name` (`String`): The name of the benchmark.
- `result` (`Report`): The output report after executing a benchmark.
- `measures` (`List[ThroughputMeasure]`): Optional arg used to represent a list of ThroughputMeasure's.
- `verbose_timing` (`Bool`): Whether to print verbose timing results.

Implemented traits: `AnyType`, `Copyable`, `Deinitable`, `Movable`

#### `BenchmarkInfo.__init__`

```mojo
def __init__(out self, name: String, var result: Report, var measures: List[ThroughputMeasure] = List(), verbose_timing: Bool = False)
```

Constructs a `BenchmarkInfo` object to return benchmark report and statistics.

Args:

- `name`: The name of the benchmark.
- `result`: The output report after executing a benchmark.
- `measures`: Optional arg used to represent a list of ThroughputMeasure's.
- `verbose_timing`: Whether to print verbose timing results.

### `Mode`

```mojo
struct Mode
```

Defines a Benchmark Mode to distinguish between test runs and actual benchmarks.

Fields:

- `value` (`Int`): Represents the mode type.

Implemented traits: `AnyType`, `Copyable`, `Deinitable`, `ImplicitlyCopyable`, `Movable`

Aliases:

- `Benchmark = Mode(Int(0))`: Mode for running actual benchmarks.
- `Test = Mode(Int(1))`: Mode for running tests.

#### `Mode.__eq__`

```mojo
def __eq__(self, other: Self) -> Bool
```

Check if its Benchmark mode or test mode.

Args:

- `other`: The mode to be compared against.

Returns: If its a test mode or benchmark mode.

### `Bench`

```mojo
struct Bench
```

Constructs a Benchmark object, used for running multiple benchmarks and comparing the results.

Example:

```mojo
from std.benchmark import (
    Bench,
    BenchConfig,
    Bencher,
    BenchId,
    ThroughputMeasure,
    BenchMetric,
    Format,
)
from std.utils import IndexList
from max.gpu.host import DeviceContext
from std.pathlib import Path

def example_kernel():
    print("example_kernel")

var shape = IndexList[2](1024, 1024)
var bench = Bench(BenchConfig(max_iters=100))

@inline(.always)
def example(mut b: Bencher, shape: IndexList[2]) raises:
    @inline(.always)
    def kernel_launch(ctx: DeviceContext) raises {imm}:
        ctx.enqueue_function[example_kernel](
            grid_dim=shape[0], block_dim=shape[1]
        )

    var bench_ctx = DeviceContext()
    b.iter_custom(kernel_launch, bench_ctx)

bench.bench_with_input(
    example,
    BenchId("top_k_custom", "gpu"),
    shape,
    [
        ThroughputMeasure(
        BenchMetric.elements, shape.flattened_length()
        ),
        ThroughputMeasure(
            BenchMetric.flops, shape.flattened_length() * 3 # number of ops
        ),
    ]
)
# Add more benchmarks like above to compare results

# Pretty print in table format
print(bench)

# Dump report to csv file
bench.config.out_file = Path("out.csv")
bench.dump_report()

# Print in tabular csv format
bench.config.format = Format.tabular
print(bench)
```

You can pass arguments when running a program that makes use of `Bench`:

```sh
mojo benchmark.mojo -o out.csv -r 10
```

This will repeat the benchmarks 10 times and write the output to `out.csv`
in csv format.

Fields:

- `config` (`BenchConfig`): Constructs a Benchmark object based on specific configuration and mode.
- `mode` (`Mode`): Benchmark mode object representing benchmark or test mode.
- `info_vec` (`List[BenchmarkInfo]`): A list containing the benchmark info.

Implemented traits: `AnyType`, `Deinitable`, `Movable`, `Writable`

#### `Bench.__init__`

```mojo
def __init__(out self, config: Optional[BenchConfig] = None, mode: Mode = Mode.Benchmark) raises
```

Constructs a Benchmark object based on specific configuration and mode.

Args:

- `config`: Benchmark configuration object to control length and frequency of benchmarks.
- `mode`: Benchmark mode object representing benchmark or test mode.

Raises: If the operation fails.

#### `Bench.check_mpirun`

```mojo
def check_mpirun(mut self) raises -> Int
```

Check environment to examine whether the benchmark is called via mpirun. If so, use pe_rank=OMPI_COMM_WORLD_RANK as a suffix for output file.

Returns: An integer representing pe rank (default=-1).

Raises: If the operation fails.

#### `Bench.append_output_suffix`

```mojo
def append_output_suffix(mut self, suffix: String)
```

Append a suffix string to output file name.

Args:

- `suffix`: Suffix string to append to output file name.

#### `Bench.bench_with_input`

```mojo
def bench_with_input[T: AnyType, FuncType: def(mut Bencher, T) raises -> None](mut self, func: FuncType, bench_id: BenchId, input: T, measures: List[ThroughputMeasure] = List()) raises
```

Benchmarks an input function with input args of type AnyType.

Parameters:

- `T`: Benchmark function input type.
- `FuncType`: The body function type.

Args:

- `func`: The closure carrying the captured state of the body function.
- `bench_id`: The benchmark Id object used for identification.
- `input`: Represents the target function's input arguments.
- `measures`: Optional arg used to represent a list of ThroughputMeasure's.

Raises: If the operation fails.

```mojo
def bench_with_input[T: TrivialRegisterPassable, FuncType: def(mut Bencher, T) -> None](mut self, func: FuncType, bench_id: BenchId, input: T, measures: List[ThroughputMeasure] = List()) raises
```

Benchmarks an input function with input args of type TrivialRegisterPassable.

Parameters:

- `T`: Benchmark function input type.
- `FuncType`: The body function type.

Args:

- `func`: The closure carrying the captured state of the body function.
- `bench_id`: The benchmark Id object used for identification.
- `input`: Represents the target function's input arguments.
- `measures`: Optional arg used to represent a list of ThroughputMeasure's.

Raises: If the operation fails.

```mojo
def bench_with_input[T: TrivialRegisterPassable, FuncType: def(mut Bencher, T) raises -> None](mut self, func: FuncType, bench_id: BenchId, input: T, measures: List[ThroughputMeasure] = List()) raises
```

Benchmarks an input function with input args of type TrivialRegisterPassable.

Parameters:

- `T`: Benchmark function input type.
- `FuncType`: The body function type.

Args:

- `func`: The closure carrying the captured state of the body function.
- `bench_id`: The benchmark Id object used for identification.
- `input`: Represents the target function's input arguments.
- `measures`: Optional arg used to represent a list of ThroughputMeasure's.

Raises: If the operation fails.

#### `Bench.bench_function`

```mojo
def bench_function[FuncType: def() raises -> None](mut self, func: FuncType, bench_id: BenchId, measures: List[ThroughputMeasure] = List(), fixed_iterations: Optional[Int] = None) raises
```

Benchmarks or Tests an input function.

Parameters:

- `FuncType`: The body function type.

Args:

- `func`: The closure carrying the captured state of the body function.
- `bench_id`: The benchmark Id object used for identification.
- `measures`: Optional arg used to represent a list of ThroughputMeasure's.
- `fixed_iterations`: Just run a fixed number of iterations.

Raises: If the operation fails.

```mojo
def bench_function[FuncType: def(mut Bencher) raises -> None](mut self, func: FuncType, bench_id: BenchId, measures: List[ThroughputMeasure] = List(), fixed_iterations: Optional[Int] = None) raises
```

Benchmarks or Tests an input function.

Parameters:

- `FuncType`: The body function type.

Args:

- `func`: The closure carrying the captured state of the body function.
- `bench_id`: The benchmark Id object used for identification.
- `measures`: Optional arg used to represent a list of ThroughputMeasure's.
- `fixed_iterations`: Just run a fixed number of iterations.

Raises: If the operation fails.

#### `Bench.dump_report`

```mojo
def dump_report(mut self) raises
```

Prints out the report from a Benchmark execution. If `Bench.config.out_file` is set, it will also write the output in the format set in `out_file_format` to the file defined in `out_file`.

Raises: If the operation fails.

#### `Bench.pad`

```mojo
def pad[pad_str: StringSpan[ImmStaticOrigin] = StringSpan(" ")](self, width: Int, string: String) -> String
```

Pads a string to a given width.

Parameters:

- `pad_str`: The length 1 string to use for the padding.

Args:

- `width`: The width to pad the string to.
- `string`: The string to pad.

Returns: A string padded to the given width.

#### `Bench.write_to`

```mojo
def write_to(self, mut writer: T)
```

Writes the benchmark results to a writer.

Args:

- `writer`: The writer to write to.

#### `Bench.write_repr_to`

```mojo
def write_repr_to(self, mut writer: T)
```

Writes the repr of this `Bench` to a writer.

Args:

- `writer`: The writer to write to.

### `Bencher`

```mojo
struct Bencher
```

Defines a Bencher struct which facilitates the timing of a target function.

Fields:

- `num_iters` (`Int`): Number of iterations to run the target function.
- `elapsed` (`Int`): The total time elapsed when running the target function.

Implemented traits: `AnyType`, `Deinitable`, `Movable`, `RegisterPassable`

#### `Bencher.__init__`

```mojo
def __init__(num_iters: Int) -> Self
```

Constructs a Bencher object to run and time a function.

Args:

- `num_iters`: Number of times to run the target function.

#### `Bencher.iter`

```mojo
def iter[IterFn: def() -> None](mut self, f: IterFn)
```

Returns the total elapsed time by running a target closure a particular number of times.

Parameters:

- `IterFn`: Type of the closure to benchmark.

Args:

- `f`: The closure to benchmark.

```mojo
def iter[IterFn: def() raises -> None](mut self, f: IterFn) raises
```

Returns the total elapsed time by running a raising target closure a particular number of times.

Parameters:

- `IterFn`: Type of the closure to benchmark.

Args:

- `f`: The closure to benchmark.

Raises: If the closure raises.

#### `Bencher.iter_preproc`

```mojo
def iter_preproc[T: AnyType, //, IterFn: def(mut T) -> None, PreprocFn: def(mut T) -> None](mut self, mut state: T, iter_fn: IterFn, preproc_fn: PreprocFn)
```

Accumulates the total elapsed time of a target function over the configured number of iterations, running a preprocess function to prepare the state before each timed call.

Both functions receive `state` mutably; only the target function's
run time is measured.

Parameters:

- `T`: The type of the state passed to both functions.
- `IterFn`: The target function type.
- `PreprocFn`: The preprocess function type.

Args:

- `state`: The state prepared by the preprocess function and consumed by the target function each iteration.
- `iter_fn`: The target function to benchmark.
- `preproc_fn`: The function preparing the state before each timed call.

#### `Bencher.iter_custom`

```mojo
def iter_custom[FuncType: def(Int) -> Int](mut self, func: FuncType)
```

Times a target function with custom number of iterations.

Parameters:

- `FuncType`: The target function type.

Args:

- `func`: The closure carrying the captured state of the target function.
