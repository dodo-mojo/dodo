# `std.logger`

Logging with configurable severity levels.

The `logger` package provides a flexible logging system with multiple severity
levels for debugging and monitoring applications. It supports configurable log
levels (`TRACE`, `DEBUG`, `INFO`, `WARNING`, `ERROR`, `CRITICAL`), colored output,
customizable formatting, and environment-based configuration. The logging level
can be set via the LOGGING_LEVEL environment variable to control message
verbosity.

Use this package for debugging, monitoring application behavior, error
reporting, or adding instrumentation to track program execution. Configure the
logging level in development for detailed output, then reduce verbosity in
production for performance.

## Modules

- [`std.logger.logger`](logger.md): Provides logging functionality with different severity levels.
