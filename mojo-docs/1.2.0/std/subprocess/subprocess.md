# `std.subprocess.subprocess`

Provides utilities for executing shell commands and capturing output.

This module offers functions for running shell commands in subprocesses and
retrieving their output, similar to Python's `subprocess` module. It handles
process creation, output capture, and resource cleanup automatically.

## Functions

### `run`

```mojo
def run(cmd: String) raises -> String
```

Runs the specified command and returns the output as a string.

This function executes the given command in a subprocess, captures its
standard output, and returns it as a string. It automatically handles
opening and closing the subprocess.

Args:

- `cmd`: The command to execute as a string.

Returns: The standard output of the command as a string, with trailing whitespace removed.

Raises: This function raises if: * The command cannot be executed. * There is an IO error reading from the subprocess. * The data written by the subprocess is not valid UTF-8.
