"""Building an app with `mojo build`, skipped when nothing changed.

Binaries go to `.dodo/build/` in the project. Next to each one a stamp
file records what it was built from: the newest change time of the
project's `.mojo` files and how many there are (other test files are left
out, see `build_inputs`), the entry file's own change time, and the
toolchain's (the `mojo` compiler and the installed `.mojoc` packages,
such as dodo). The build is skipped when the stamp still matches, and
redone when any of those change.
"""

from std.os import getenv, listdir, makedirs
from std.os.path import isfile, join
from std.sys import stderr
from std.time import perf_counter_ns

from dodo.json import Value
from dodo.utils.process import Child, ExitStatus, spawn

from .files import (
    build_inputs,
    mtime_ns,
    newest_mtime_ns,
    read_text,
    remove_if_there,
    tail_text,
)
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


struct BuildPlan(Copyable, Movable):
    """Where one build goes and whether it is needed."""

    var entry: String
    var binary: String
    var stamp_path: String
    var log_path: String
    var stamp: String
    var up_to_date: Bool

    def __init__(out self, root: String, entry: String, out_dir: String) raises:
        makedirs(out_dir, exist_ok=True)
        var name = binary_name(root, entry)
        self.entry = entry
        self.binary = join(out_dir, name)
        self.stamp_path = join(out_dir, name + ".stamp")
        self.log_path = join(out_dir, name + ".log")
        self.stamp = _stamp(root, entry)
        self.up_to_date = (
            isfile(self.binary) and read_text(self.stamp_path) == self.stamp
        )


def start_build(
    plan: BuildPlan, includes: List[String], new_group: Bool = False
) raises -> Child:
    """Start `mojo build` for `plan`, with `-I` for each of `includes`.

    Raises:
        Error: If `mojo` cannot be started.
    """
    var argv: List[String] = ["mojo", "build"]
    for dir in includes:
        argv.append("-I")
        argv.append(dir)
    argv.append(plan.entry)
    argv.append("-o")
    argv.append(plan.binary)
    return spawn(
        argv,
        stdout_path=plan.log_path,
        stderr_path="&1",
        new_group=new_group,
    )


def finish_build(
    plan: BuildPlan, status: ExitStatus, seconds: Float64
) raises -> Build:
    """Record how the build ended: write the stamp, or keep the log."""
    var result = Build(plan.binary)
    result.seconds = seconds
    if not status.succeeded():
        remove_if_there(plan.stamp_path)
        result.exit_code = EXIT_BUILD_FAILED
        result.message = String(
            "mojo build failed on ", plan.entry, " (", status, ")"
        )
        result.log = tail_text(read_text(plan.log_path), _MAX_LOG_BYTES)
        return result^
    with open(plan.stamp_path, "w") as file:
        file.write(plan.stamp)
    return result^


def build_app(
    root: String, entry: String, out_dir: String, report: Report
) raises -> Build:
    """Build `entry` into `out_dir`, unless the last build is still current.
    Says "building ..." on `report` only when it does build."""
    var plan = BuildPlan(root, entry, out_dir)
    if plan.up_to_date:
        var skipped = Build(plan.binary)
        skipped.skipped = True
        return skipped^

    report.note(String("building ", entry, " ..."))
    var started = perf_counter_ns()
    var child: Child
    try:
        child = start_build(plan, [root])
    except e:
        var missing = Build(plan.binary)
        missing.exit_code = EXIT_UNAVAILABLE
        missing.message = String(e)
        return missing^
    var status = child.wait()
    var seconds = Float64(perf_counter_ns() - started) / 1e9
    return finish_build(plan, status, seconds)


def _stamp(root: String, entry: String) raises -> String:
    var files = build_inputs(root, entry)
    var stamp = String(
        "sources ", newest_mtime_ns(files), " ", len(files), "\n"
    )
    stamp += String("entry ", mtime_ns(entry), "\n")
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
