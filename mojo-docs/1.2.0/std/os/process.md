# `std.os.process`

Implements os methods for dealing with processes.

Example:

```mojo
from std.os import Process
from std.collections import List
_ = Process.run("echo", ["== TEST_ECHO"])
```

## Structs

### `ProcessStatus`

```mojo
struct ProcessStatus
```

Represents the termination status of a process.

This struct is returned by `poll()` and `wait()`.

Fields:

- `exit_code` (`Optional[Int]`): The exit code if the process terminated normally.
- `term_signal` (`Optional[Int]`): The signal number that terminated the process.

Implemented traits: `AnyType`, `Copyable`, `Deinitable`, `ImplicitlyCopyable`, `Movable`

#### `ProcessStatus.__init__`

```mojo
def __init__(out self, exit_code: Optional[Int] = None, term_signal: Optional[Int] = None)
```

Initializes a new `ProcessStatus`.

Args:

- `exit_code`: The exit code if the process terminated normally.
- `term_signal`: The signal number that terminated the process.

#### `ProcessStatus.running`

```mojo
def running() -> Self
```

Creates a status for a running process.

Returns: A `ProcessStatus` for a running process.

#### `ProcessStatus.has_exited`

```mojo
def has_exited(self) -> Bool
```

Checks if the process has terminated.

Returns: True if the process has terminated, either normally or by a signal.

### `Pipe`

```mojo
struct Pipe
```

Create a pipe for interprocess communication.

Example usage:
```mojo
from std.os.process import Pipe

def main() raises:
    var pipe = Pipe()
    pipe.write_bytes("TEST".as_bytes())
```

Fields:

- `fd_in` (`Optional[RawFileDescriptor]`): File descriptor for pipe input.
- `fd_out` (`Optional[RawFileDescriptor]`): File descriptor for pipe output.

Implemented traits: `AnyType`, `Deinitable`, `Movable`

#### `Pipe.__init__`

```mojo
def __init__(out self, in_close_on_exec: Bool = True, out_close_on_exec: Bool = True) raises
```

Initializes a new `Pipe`.

Args:

- `in_close_on_exec`: Close the read side of pipe if an `exec` syscall is issued in the process.
- `out_close_on_exec`: Close the write side of pipe if an `exec` syscall is issued in the process.

Raises: Error: If the pipe could not be created or configured.

#### `Pipe.__deinit__`

```mojo
def __deinit__(deinit self)
```

Ensures pipes input and output file descriptors are closed, when the object is destroyed.

#### `Pipe.set_input_only`

```mojo
def set_input_only(mut self)
```

Close the output descriptor/ channel for this side of the pipe.

#### `Pipe.set_output_only`

```mojo
def set_output_only(mut self)
```

Close the input descriptor/ channel for this side of the pipe.

#### `Pipe.write_bytes`

```mojo
def write_bytes(mut self, bytes: Span[UInt8]) raises
```

Writes a span of bytes to the pipe.

Args:

- `bytes`: The byte span to write to this pipe.

Raises: Error: If called on a read-only pipe.

#### `Pipe.read_bytes`

```mojo
def read_bytes(mut self, buffer: Span[UInt8]) raises -> Int
```

Read a number of bytes from this pipe.

Args:

- `buffer`: Span[Byte] of length n where to store read bytes. n = number of bytes to read.

Returns: Actual number of bytes read.

Raises: Error: If the pipe is in write-only mode.

### `Process`

```mojo
struct Process
```

Create and manage child processes from file executables.

Example usage:
```mojo
from std.os.process import Process

def main() raises:
    var child_process = Process.run("ls", ["-lha"])
    if child_process.interrupt():
        print("Successfully interrupted.")
```

Fields:

- `child_pid` (`c_pid_t`): Child process id.
- `status` (`Optional[ProcessStatus]`): Cached status of the process. `None` if the process has not been waited on yet.

Implemented traits: `AnyType`, `Deinitable`, `Movable`

#### `Process.__init__`

```mojo
def __init__(out self, child_pid: Int)
```

Struct to manage metadata about child process. Use the `run` static method to create new process.

Args:

- `child_pid`: The pid of child process returned by `posix_spawnp` that the struct will manage.

#### `Process.__deinit__`

```mojo
def __deinit__(deinit self)
```

Waits for the process to exit when the `Process` object is destroyed.

#### `Process.hangup`

```mojo
def hangup(mut self) -> Bool
```

Send the Hang up signal to the managed child process.

Returns: Upon successful completion, True is returned else False.

#### `Process.interrupt`

```mojo
def interrupt(mut self) -> Bool
```

Send the Interrupt signal to the managed child process.

Returns: Upon successful completion, True is returned else False.

#### `Process.kill`

```mojo
def kill(mut self) -> Bool
```

Send the Kill signal to the managed child process.

Returns: Upon successful completion, True is returned else False.

#### `Process.poll`

```mojo
def poll(mut self) raises -> ProcessStatus
```

Check if the child process has terminated in a non-blocking way.

This method updates the internal state of the `Process` object.
If the process has terminated, the status is cached.

Returns: A `ProcessStatus` indicating the status of the process.

Raises: Error: If `waitpid` fails.

#### `Process.wait`

```mojo
def wait(mut self) raises -> ProcessStatus
```

Wait for the child process to terminate (blocking).

This method updates the internal state of the `Process` object.
If the process has terminated, the status is cached.

Returns: A `ProcessStatus` indicating the process has exited and its status.

Raises: Error: If `waitpid` fails or the process does not exit.

#### `Process.run`

```mojo
def run(var path: String, argv: List[String]) raises -> Self
```

Spawn new process from file executable.

Args:

- `path`: The path to the file.
- `argv`: A list of string arguments to be passed to executable.

Returns: An instance of `Process` struct.

Raises: Error: If the process fails to spawn.
