# `std.logger.logger`

Provides logging functionality with different severity levels.

This module implements a simple logging system with configurable severity
levels: `NOTSET`, `DEBUG`, `INFO`, `WARNING`, `ERROR`, and `CRITICAL`. The
logging level can be set via the LOGGING_LEVEL environment variable.

The main components are:

- `Level`: An enum-like struct defining the available logging levels
- `Logger`: A struct that handles logging messages with different severity levels

Example:

```mojo
from std.logger import Logger

var logger = Logger()  # Uses default level from LOGGING_LEVEL env var
logger.info("Starting process")
logger.debug("Debug information")
logger.error("An error occurred")
```

The logger can be configured to write to different file descriptors (default
stdout). Messages below the configured level will be silently ignored.

## Aliases

### `DEFAULT_LEVEL`

```mojo
comptime DEFAULT_LEVEL = Level._from_str(get_defined_string[StringSpan("LOGGING_LEVEL"), StringSpan("NOTSET")]())
```

The default logging level, determined by the LOGGING_LEVEL environment variable.

## Structs

### `Level`

```mojo
struct Level
```

Represents logging severity levels.

Defines the available logging levels in ascending order of severity.

Implemented traits: `AnyType`, `Comparable`, `Copyable`, `Deinitable`, `Equatable`, `ImplicitlyCopyable`, `Movable`, `Writable`

Aliases:

- `NOTSET = Level(Int(0))`: Lowest level, used when no level is set.
- `TRACE = Level(Int(10))`: Repetitive trace information, Indicates repeated execution or IO-coupled activity, typically only of interest when diagnosing hangs or ensuring a section of code is executing.
- `DEBUG = Level(Int(20))`: Detailed information, typically of interest only when diagnosing problems.
- `INFO = Level(Int(30))`: Confirmation that things are working as expected.
- `WARNING = Level(Int(40))`: Indication that something unexpected happened, or may happen in the near future.
- `ERROR = Level(Int(50))`: Due to a more serious problem, the software has not been able to perform some function.
- `CRITICAL = Level(Int(60))`: A serious error indicating that the program itself may be unable to continue running.

#### `Level.__lt__`

```mojo
def __lt__(self, other: Self) -> Bool
```

Returns True if this level is less than the other level.

Args:

- `other`: The level to compare with.

Returns: Bool: True if this level is less than the other level, False otherwise.

#### `Level.__eq__`

```mojo
def __eq__(self, other: Self) -> Bool
```

Returns True if this level equals the other level.

Args:

- `other`: The level to compare with.

Returns: Bool: True if the levels are equal, False otherwise.

#### `Level.color`

```mojo
def color(self) -> Color
```

Returns the ANSI color of the level.

Returns: The corresponding Color of the level.

#### `Level.write_to`

```mojo
def write_to(self, mut writer: T)
```

Writes the string representation of this level to a writer.

Args:

- `writer`: The writer to write to.

### `Logger`

```mojo
struct Logger[level: Level = DEFAULT_LEVEL]
```

A logger that outputs messages at or above a specified severity level.

Parameters:

- `level`: The minimum severity level for messages to be logged.

Implemented traits: `AnyType`, `Copyable`, `Deinitable`, `ImplicitlyCopyable`, `Movable`

#### `Logger.__init__`

```mojo
def __init__(out self, fd: RawFileDescriptor = stdout, *, prefix: String = "", source_location: Bool = False)
```

Initializes a new Logger.

Args:

- `fd`: The file descriptor to write log messages to (defaults to stdout).
- `prefix`: The prefix to prepend to each log message (defaults to an empty string).
- `source_location`: Whether to include the source location in the log message (defaults to False).

#### `Logger.trace`

```mojo
def trace[*Ts: Writable](self, *values: *Ts.values, *, sep: StringSpan[ImmStaticOrigin] = StringSpan(" "), end: StringSpan[ImmStaticOrigin] = StringSpan("\n"), location: Optional[SourceLocation] = None)
```

Logs a trace message.

Parameters:

- `*Ts`: The types of values to log.

Args:

- `*values`: The values to log.
- `sep`: The separator to use between values (defaults to a space).
- `end`: The string to append to the end of the message (defaults to a newline).
- `location`: The location of the error (defaults to `call_location`).

#### `Logger.debug`

```mojo
def debug[*Ts: Writable](self, *values: *Ts.values, *, sep: StringSpan[ImmStaticOrigin] = StringSpan(" "), end: StringSpan[ImmStaticOrigin] = StringSpan("\n"), location: Optional[SourceLocation] = None)
```

Logs a debug message.

Parameters:

- `*Ts`: The types of values to log.

Args:

- `*values`: The values to log.
- `sep`: The separator to use between values (defaults to a space).
- `end`: The string to append to the end of the message (defaults to a newline).
- `location`: The location of the error (defaults to `call_location`).

#### `Logger.info`

```mojo
def info[*Ts: Writable](self, *values: *Ts.values, *, sep: StringSpan[ImmStaticOrigin] = StringSpan(" "), end: StringSpan[ImmStaticOrigin] = StringSpan("\n"), location: Optional[SourceLocation] = None)
```

Logs an info message.

Parameters:

- `*Ts`: The types of values to log.

Args:

- `*values`: The values to log.
- `sep`: The separator to use between values (defaults to a space).
- `end`: The string to append to the end of the message (defaults to a newline).
- `location`: The location of the error (defaults to `call_location`).

#### `Logger.warning`

```mojo
def warning[*Ts: Writable](self, *values: *Ts.values, *, sep: StringSpan[ImmStaticOrigin] = StringSpan(" "), end: StringSpan[ImmStaticOrigin] = StringSpan("\n"), location: Optional[SourceLocation] = None)
```

Logs a warning message.

Parameters:

- `*Ts`: The types of values to log.

Args:

- `*values`: The values to log.
- `sep`: The separator to use between values (defaults to a space).
- `end`: The string to append to the end of the message (defaults to a newline).
- `location`: The location of the error (defaults to `call_location`).

#### `Logger.error`

```mojo
def error[*Ts: Writable](self, *values: *Ts.values, *, sep: StringSpan[ImmStaticOrigin] = StringSpan(" "), end: StringSpan[ImmStaticOrigin] = StringSpan("\n"), location: Optional[SourceLocation] = None)
```

Logs an error message.

Parameters:

- `*Ts`: The types of values to log.

Args:

- `*values`: The values to log.
- `sep`: The separator to use between values (defaults to a space).
- `end`: The string to append to the end of the message (defaults to a newline).
- `location`: The location of the error (defaults to `call_location`).

#### `Logger.critical`

```mojo
def critical[*Ts: Writable](self, *values: *Ts.values, *, sep: StringSpan[ImmStaticOrigin] = StringSpan(" "), end: StringSpan[ImmStaticOrigin] = StringSpan("\n"), location: Optional[SourceLocation] = None)
```

Logs a critical message and aborts execution.

Parameters:

- `*Ts`: The types of values to log.

Args:

- `*values`: The values to log.
- `sep`: The separator to use between values (defaults to a space).
- `end`: The string to append to the end of the message (defaults to a newline).
- `location`: The location of the error (defaults to `call_location`).
