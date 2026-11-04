"""Run a program and keep what it printed."""

from std.ffi import external_call
from std.os import getenv, remove
from std.os.path import join
from std.time import perf_counter_ns

from dodo.utils.process import ExitStatus, run


struct Captured(Movable):
    var status: ExitStatus
    var output: String
    """stdout and stderr together."""

    def __init__(out self, status: ExitStatus, var output: String):
        self.status = status
        self.output = output^


def capture(argv: List[String]) raises -> Captured:
    """Run `argv` to the end and return its exit status and output.

    Raises:
        Error: If the program cannot be started (not on `PATH`, say).
    """
    var path = _scratch_path()
    var status = run(argv, stdout_path=path, stderr_path="&1")
    var output = String("")
    try:
        with open(path, "r") as file:
            output = file.read()
        remove(path)
    except:
        pass
    return Captured(status, output^)


def _scratch_path() -> String:
    var dir = getenv("TMPDIR", "/tmp")
    var pid = Int(external_call["getpid", Int32]())
    return join(dir, String("dodo-", pid, "-", perf_counter_ns(), ".out"))
