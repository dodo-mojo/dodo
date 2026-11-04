"""Start programs, wait for them to end, and stop them.

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
"""

from std.ffi import c_int
from std.time import sleep

from .dylib import dl_sym, pinned_dodo_lib

comptime _NEW_GROUP: c_int = 1
# `wait` checks often at first, so a short program is collected within
# about 0.1 ms, then backs off to 10 ms for long ones.
comptime _FIRST_WAIT_SECONDS: Float64 = 0.0001
comptime _LONGEST_WAIT_SECONDS: Float64 = 0.01


@fieldwise_init
struct ExitStatus(Copyable, ImplicitlyCopyable, Movable, Writable):
    """How a child ended: an exit code, or the signal that killed it."""

    var code: Int
    """The exit code, or -1 when a signal killed the child."""
    var signal: Int
    """The signal that killed the child, or 0 when it exited."""

    def succeeded(self) -> Bool:
        """Whether the child exited with code 0."""
        return self.signal == 0 and self.code == 0

    def shell_code(self) -> Int:
        """The code a shell would report: the exit code, or 128 plus the
        signal number when a signal killed the child."""
        if self.signal != 0:
            return 128 + self.signal
        return self.code

    def write_to[W: Writer](self, mut writer: W):
        if self.signal != 0:
            writer.write("killed by signal ", self.signal)
        else:
            writer.write("exit code ", self.code)


struct Child(Movable):
    """A started program. Call `wait` (or `poll` until it returns a status)
    so the finished child does not linger in the process table."""

    var pid: Int
    """The child's process id."""
    var own_group: Bool
    """Whether the child leads a process group of its own."""
    var _status: Optional[ExitStatus]

    def __init__(out self, pid: Int, own_group: Bool):
        self.pid = pid
        self.own_group = own_group
        self._status = None

    def poll(mut self) raises -> Optional[ExitStatus]:
        """The exit status if the child has ended, without waiting."""
        if self._status:
            return self._status
        var ended = _wait(self.pid, nohang=True)
        if ended:
            self._status = ended
        return ended

    def wait(mut self) raises -> ExitStatus:
        """Wait for the child to end and return how it ended.

        Waits in short steps, so a signal handler that only records the
        signal (see `dodo.utils.signals`) never leaves this stuck.
        """
        var step = _FIRST_WAIT_SECONDS
        while True:
            var ended = self.poll()
            if ended:
                return ended.value()
            sleep(step)
            step = min(step * 2, _LONGEST_WAIT_SECONDS)

    def send_signal(self, signal: Int) raises:
        """Send `signal` to the child, or to its whole group when it has
        one of its own (so programs it started get it too)."""
        if self._status:
            return
        var send = dl_sym[def(Int64, c_int, c_int) thin abi("C") -> c_int](
            pinned_dodo_lib["proc"]()[], "dodo_proc_kill"
        )
        var whole_group = c_int(0)
        if self.own_group:
            whole_group = c_int(1)
        var failure = Int(send(Int64(self.pid), c_int(signal), whole_group))
        if failure != 0:
            raise Error(
                "cannot signal process ", self.pid, ": ", error_text(failure)
            )


def spawn(
    argv: List[String],
    env: List[String] = List[String](),
    stdout_path: String = "",
    stderr_path: String = "",
    new_group: Bool = False,
) raises -> Child:
    """Start a program and return without waiting for it.

    Args:
        argv: The program and its arguments. The program is looked up on
            `PATH` unless it contains a `/`.
        env: Extra `KEY=VALUE` entries; they replace inherited ones with
            the same key.
        stdout_path: A file for the child's output, or "" to share ours.
        stderr_path: A file for the child's errors, "&1" to join its
            output, or "" to share ours.
        new_group: Put the child in a process group of its own. A Ctrl-C
            in the terminal then reaches only us, and `send_signal` reaches
            everything the child started.

    Raises:
        Error: If `argv` is empty or the program cannot be started.
    """
    if len(argv) == 0:
        raise Error("spawn: argv is empty")
    _check_env(env)
    var start = dl_sym[
        def(Int, c_int, Int, c_int, Int, Int, c_int, Int) thin abi("C") -> c_int
    ](pinned_dodo_lib["proc"]()[], "dodo_proc_spawn")

    var packed_argv = _pack(argv)
    var packed_env = _pack(env)
    var out_path = _c_string(stdout_path)
    var err_path = _c_string(stderr_path)
    var flags = c_int(0)
    if new_group:
        flags = _NEW_GROUP
    var pid = List[Int64](length=1, fill=Int64(0))

    var failure = Int(
        start(
            Int(packed_argv.unsafe_ptr()),
            c_int(len(argv)),
            Int(packed_env.unsafe_ptr()),
            c_int(len(env)),
            Int(out_path.unsafe_ptr()),
            Int(err_path.unsafe_ptr()),
            flags,
            Int(pid.unsafe_ptr()),
        )
    )
    _ = packed_argv^
    _ = packed_env^
    _ = out_path^
    _ = err_path^
    if failure != 0:
        raise Error("cannot start ", argv[0], ": ", error_text(failure))
    return Child(Int(pid[0]), new_group)


def run(
    argv: List[String],
    env: List[String] = List[String](),
    stdout_path: String = "",
    stderr_path: String = "",
) raises -> ExitStatus:
    """Start a program, wait for it, and return how it ended."""
    var child = spawn(argv, env, stdout_path, stderr_path)
    return child.wait()


def exec_replace(
    argv: List[String], env: List[String] = List[String]()
) raises:
    """Replace this process with a program. Returns only by raising.

    Args:
        argv: The program and its arguments, looked up on `PATH`.
        env: Extra `KEY=VALUE` entries added to the environment.

    Raises:
        Error: If `argv` is empty or the program cannot be run.
    """
    if len(argv) == 0:
        raise Error("exec_replace: argv is empty")
    _check_env(env)
    var replace = dl_sym[def(Int, c_int, Int, c_int) thin abi("C") -> c_int](
        pinned_dodo_lib["proc"]()[], "dodo_proc_exec"
    )
    var packed_argv = _pack(argv)
    var packed_env = _pack(env)
    var failure = Int(
        replace(
            Int(packed_argv.unsafe_ptr()),
            c_int(len(argv)),
            Int(packed_env.unsafe_ptr()),
            c_int(len(env)),
        )
    )
    _ = packed_argv^
    _ = packed_env^
    raise Error("cannot run ", argv[0], ": ", error_text(failure))


def set_inherited(fd: Int, inherited: Bool) raises:
    """Choose whether programs started later get a copy of `fd`.

    Raises:
        Error: If `fd` is not open.
    """
    var set_flag = dl_sym[def(c_int, c_int) thin abi("C") -> c_int](
        pinned_dodo_lib["proc"]()[], "dodo_proc_set_inherit"
    )
    var inherit = c_int(0)
    if inherited:
        inherit = c_int(1)
    var failure = Int(set_flag(c_int(fd), inherit))
    if failure != 0:
        raise Error("cannot change fd ", fd, ": ", error_text(failure))


def error_text(code: Int) -> String:
    """The system's text for an errno value, such as "No such file or
    directory"."""
    try:
        var describe = dl_sym[def(c_int, Int, c_int) thin abi("C") -> None](
            pinned_dodo_lib["proc"]()[], "dodo_proc_error_text"
        )
        var buffer = List[UInt8](length=256, fill=UInt8(0))
        describe(c_int(code), Int(buffer.unsafe_ptr()), c_int(len(buffer)))
        var length = 0
        while length < len(buffer) and buffer[length] != 0:
            length += 1
        return String(from_utf8_lossy=Span(buffer)[:length])
    except:
        return String("errno ", code)


def _wait(pid: Int, nohang: Bool) raises -> Optional[ExitStatus]:
    var collect = dl_sym[def(Int64, c_int, Int, Int) thin abi("C") -> c_int](
        pinned_dodo_lib["proc"]()[], "dodo_proc_wait"
    )
    var no_hang = c_int(0)
    if nohang:
        no_hang = c_int(1)
    var results = List[c_int](length=2, fill=c_int(0))
    var outcome = Int(
        collect(
            Int64(pid),
            no_hang,
            Int(results.unsafe_ptr()),
            Int(results.unsafe_ptr()) + 4,
        )
    )
    if outcome < 0:
        raise Error(
            "cannot wait for process ", pid, ": ", error_text(Int(results[0]))
        )
    if outcome == 0:
        return None
    return ExitStatus(code=Int(results[0]), signal=Int(results[1]))


def _c_string(text: String) -> List[UInt8]:
    """`text` as bytes with a closing NUL, for C."""
    var bytes = text.as_bytes()
    var out = List[UInt8](capacity=len(bytes) + 1)
    for byte in bytes:
        out.append(byte)
    out.append(0)
    return out^


def _pack(strings: List[String]) raises -> List[UInt8]:
    """`strings` as NUL-terminated byte strings placed back to back.

    Raises:
        Error: If a string holds a NUL byte, which C would cut it at.
    """
    var out = List[UInt8]()
    for text in strings:
        for byte in text.as_bytes():
            if byte == 0:
                raise Error("argument holds a NUL byte: ", repr(text))
            out.append(byte)
        out.append(0)
    out.append(0)
    return out^


def _check_env(env: List[String]) raises:
    """Every entry must look like `KEY=VALUE` with a non-empty key."""
    for entry in env:
        var equals = entry.find("=")
        if equals < 1:
            raise Error("environment entry is not KEY=VALUE: ", repr(entry))
