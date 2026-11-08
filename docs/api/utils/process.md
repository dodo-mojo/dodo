# `dodo.utils.process`

Start programs, wait for them to end, and stop them.

`spawn` starts a program and returns a `Child`. `Child.wait` returns its
`ExitStatus`, which keeps the exit code (the stdlib's `subprocess.run`
drops it). `exec_replace` runs a program in place of this process, so the
program gets this process's signals and its exit code is the final one.
The work is done in `libdodo_proc.so` (`ffi/proc_wrapper.c`).

```mojo
from dodo.utils.process import spawn

def main() raises:
    var child = spawn(["mojo", "--version"], stdout_path="version.txt")
    var status = child.wait()
    print(status.succeeded())
```

## Structs

### `ExitStatus`

```mojo
struct ExitStatus
```

How a child ended: an exit code, or the signal that killed it.

Fields:

- `code` (`Int`): The exit code, or -1 when a signal killed the child.
- `signal` (`Int`): The signal that killed the child, or 0 when it exited.

Implemented traits: `AnyType`, `Copyable`, `Deinitable`, `ImplicitlyCopyable`, `Movable`, `Writable`

#### `ExitStatus.succeeded`

```mojo
def succeeded(self) -> Bool
```

Whether the child exited with code 0.

#### `ExitStatus.shell_code`

```mojo
def shell_code(self) -> Int
```

The code a shell would report: the exit code, or 128 plus the signal number when a signal killed the child.

#### `ExitStatus.write_to`

```mojo
def write_to[W: Writer](self, mut writer: W)
```

### `Child`

```mojo
struct Child
```

A started program. Call `wait` (or `poll` until it returns a status) so the finished child does not linger in the process table.

Fields:

- `pid` (`Int`): The child's process id.
- `own_group` (`Bool`): Whether the child leads a process group of its own.

Implemented traits: `AnyType`, `Deinitable`, `Movable`

#### `Child.__init__`

```mojo
def __init__(out self, pid: Int, own_group: Bool)
```

#### `Child.poll`

```mojo
def poll(mut self) raises -> Optional[ExitStatus]
```

The exit status if the child has ended, without waiting.

#### `Child.wait`

```mojo
def wait(mut self) raises -> ExitStatus
```

Wait for the child to end and return how it ended.

Waits in short steps, so a signal handler that only records the
signal (see `dodo.utils.signals`) never leaves this stuck.

#### `Child.send_signal`

```mojo
def send_signal(self, signal: Int) raises
```

Send `signal` to the child, or to its whole group when it has one of its own (so programs it started get it too).

#### `Child.kill_group`

```mojo
def kill_group(self) raises -> Bool
```

Kill (SIGKILL) everything still in the child's process group, even after the child itself ended: programs it started and left running. Returns whether anything was left to kill.

Raises: Error: If the child was not started with `new_group=True`.

## Functions

### `spawn`

```mojo
def spawn(argv: List[String], env: List[String] = List(), stdout_path: String = "", stderr_path: String = "", new_group: Bool = False) raises -> Child
```

Start a program and return without waiting for it.

Args:

- `argv`: The program and its arguments. The program is looked up on `PATH` unless it contains a `/`.
- `env`: Extra `KEY=VALUE` entries; they replace inherited ones with the same key.
- `stdout_path`: A file for the child's output, or "" to share ours.
- `stderr_path`: A file for the child's errors, "&1" to join its output, or "" to share ours.
- `new_group`: Put the child in a process group of its own. A Ctrl-C in the terminal then reaches only us, and `send_signal` reaches everything the child started.

Raises: Error: If `argv` is empty or the program cannot be started.

### `run`

```mojo
def run(argv: List[String], env: List[String] = List(), stdout_path: String = "", stderr_path: String = "") raises -> ExitStatus
```

Start a program, wait for it, and return how it ended.

### `exec_replace`

```mojo
def exec_replace(argv: List[String], env: List[String] = List()) raises
```

Replace this process with a program. Returns only by raising.

Args:

- `argv`: The program and its arguments, looked up on `PATH`.
- `env`: Extra `KEY=VALUE` entries added to the environment.

Raises: Error: If `argv` is empty or the program cannot be run.

### `set_inherited`

```mojo
def set_inherited(fd: Int, inherited: Bool) raises
```

Choose whether programs started later get a copy of `fd`.

Raises: Error: If `fd` is not open.

### `error_text`

```mojo
def error_text(code: Int) -> String
```

The system's text for an errno value, such as "No such file or directory".
