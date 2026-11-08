# `std.testing`

Unit testing: Assertions (equal, true, raises) and test suites.

The `testing` package provides a unit testing framework for Mojo code. It
includes assertion functions for validating conditions and values, plus
infrastructure for organizing and running test suites The framework follows 
familiar patterns from other testing libraries, making it straightforward to
write and maintain tests.

Use this package to write unit tests for your Mojo code, validate correctness,
and catch regressions during development.

## Packages

- [`std.testing.prop`](prop/index.md): A property testing package.

## Modules

- [`std.testing.assert_aborts`](assert_aborts.md): Asserts that code aborts the process, without losing the rest of the test suite.
- [`std.testing.suite`](suite.md): Implements test suite infrastructure for organizing and running tests.
- [`std.testing.testing`](testing.md): Implements various testing utils.
