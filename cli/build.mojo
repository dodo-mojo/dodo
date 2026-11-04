"""Building an app with `mojo build`, skipped when nothing changed.

Binaries go to `.dodo/build/` in the project. Next to each one a stamp
file records what it was built from: the newest change time of the
project's `.mojo` files (and how many there are) and of the toolchain (the `mojo` compiler and the
installed `.mojoc` packages, such as dodo). The build is skipped when the
stamp still matches, and redone when any of those change.
"""

from std.os import getenv, listdir, makedirs, remove
from std.os.path import isfile, join
from std.sys import stderr
from std.time import perf_counter_ns

from dodo.json import Value
from dodo.utils.process import run

from .files import mojo_files, newest_mtime_ns
from .project import drop_suffix, entry_file, find_root
from .report import (
    EXIT_BUILD_FAILED,
    EXIT_OK,
    EXIT_UNAVAILABLE,
    EXIT_USAGE,
    Report,
)

comptime _MAX_LOG_BYTES = 64 * 1024
"""How much of a failed build's output a report carries."""


struct Build(Movable):
    """What `build_app` did."""

    var binary: String
    var exit_code: Int
    """`EXIT_OK`, `EXIT_BUILD_FAILED`, or `EXIT_UNAVAILABLE` when `mojo`
    could not be started."""
    var skipped: Bool
    """The binary was already up to date."""
    var seconds: Float64
    var log: String
    """The compiler's output when the build failed (its end, when long)."""
    var message: String
    """Why it failed, in one line."""

    def __init__(out self, binary: String):
        self.binary = binary
        self.exit_code = EXIT_OK
        self.skipped = False
        self.seconds = 0.0
        self.log = ""
        self.message = ""

    def ok(self) -> Bool:
        return self.exit_code == EXIT_OK


def binary_name(root: String, entry: String) -> String:
    """`<root>/main.mojo` is `main`; `<root>/apps/api.mojo` is `apps__api`,
    so two files with the same name never share a binary."""
    var relative = entry
    var prefix = root + "/"
    if entry.startswith(prefix):
        relative = String(entry[byte = prefix.byte_length() :])
    return drop_suffix(relative, ".mojo").replace("/", "__")


def build_app(
    root: String, entry: String, out_dir: String, report: Report
) raises -> Build:
    """Build `entry` into `out_dir`, unless the last build is still current.
    Says "building ..." on `report` only when it does build."""
    makedirs(out_dir, exist_ok=True)
    var name = binary_name(root, entry)
    var result = Build(join(out_dir, name))
    var stamp_path = join(out_dir, name + ".stamp")
    var log_path = join(out_dir, name + ".log")

    var stamp = _stamp(root, entry)
    if isfile(result.binary) and _read_or_empty(stamp_path) == stamp:
        result.skipped = True
        return result^

    report.note(String("building ", entry, " ..."))
    var started = perf_counter_ns()
    var argv: List[String] = [
        "mojo",
        "build",
        "-I",
        root,
        entry,
        "-o",
        result.binary,
    ]
    var status: Int
    try:
        status = run(argv, stdout_path=log_path, stderr_path="&1").shell_code()
    except e:
        result.exit_code = EXIT_UNAVAILABLE
        result.message = String(e)
        return result^
    result.seconds = Float64(perf_counter_ns() - started) / 1e9

    if status != 0:
        _remove_if_there(stamp_path)
        result.exit_code = EXIT_BUILD_FAILED
        result.message = String(
            "mojo build failed on ", entry, " (exit ", status, ")"
        )
        result.log = _tail(_read_or_empty(log_path), _MAX_LOG_BYTES)
        return result^

    with open(stamp_path, "w") as file:
        file.write(stamp)
    return result^


def _stamp(root: String, entry: String) raises -> String:
    var files = mojo_files(root)
    var stamp = String(
        "sources ", newest_mtime_ns(files), " ", len(files), "\n"
    )
    stamp += String("toolchain ", _toolchain_mtime_ns(), "\n")
    stamp += String(entry, "\n")
    return stamp^


def _toolchain_mtime_ns() raises -> Int:
    """The newest change time of the compiler and installed packages."""
    var prefix = getenv("CONDA_PREFIX")
    if prefix == "":
        return 0
    var paths = List[String]()
    paths.append(join(prefix, "bin", "mojo"))
    var packages = join(prefix, "lib", "mojo")
    try:
        for name in listdir(packages):
            if name.endswith(".mojoc"):
                paths.append(join(packages, name))
    except:
        pass
    return newest_mtime_ns(paths)


def _read_or_empty(path: String) -> String:
    try:
        with open(path, "r") as file:
            return file.read()
    except:
        return ""


def _remove_if_there(path: String):
    try:
        remove(path)
    except:
        pass


def _tail(text: String, max_bytes: Int) -> String:
    """The last `max_bytes` of `text`, cut at a line start."""
    if text.byte_length() <= max_bytes:
        return text
    var start = text.byte_length() - max_bytes
    var newline = text.find("\n", start)
    if newline >= 0:
        start = newline + 1
    return String("[earlier output cut]\n", text[byte=start:])


def build_for_command(given_file: String, mut report: Report) raises -> Build:
    """Find the project and its app, build it, and put the result in
    `report`. A command goes on only when the returned build is `ok()`;
    otherwise `report` already holds the error and `exit_code` is the code
    to return."""
    var root = find_root(".")
    var entry: String
    try:
        entry = entry_file(root, given_file, report.command)
    except e:
        var failed = Build("")
        failed.exit_code = report.fail("not_found", String(e), EXIT_USAGE)
        return failed^

    var build = build_app(root, entry, join(root, ".dodo", "build"), report)
    report.set("built", Value(not build.skipped))
    report.set("build_seconds", Value(build.seconds))
    if build.ok():
        report.set("binary", Value(build.binary))
    if build.exit_code == EXIT_UNAVAILABLE:
        _ = report.fail(
            "mojo_missing",
            build.message,
            EXIT_UNAVAILABLE,
            hint="run dodo inside the project's environment: pixi run dodo ...",
        )
    elif build.exit_code == EXIT_BUILD_FAILED:
        report.set("build_log", Value(build.log))
        if not report.json_mode:
            print(build.log, end="", file=stderr, flush=True)
        _ = report.fail("build", build.message, EXIT_BUILD_FAILED)
    return build^
