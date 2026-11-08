"""Running the real `dodo` binary from the end-to-end tests.

The binary is built with the CLI's own build cache (into `.dodo/build/` of
this repository), so only the first test of a run pays for the build. Run
from the repository root, as `tests/tools/run_tests.sh` does.
"""

from std.os import getenv, makedirs, remove
from std.os.path import join, realpath
from std.testing import assert_equal
from std.time import perf_counter_ns

from dodo.json import Value, loads
from dodo.utils.process import run

from cli.build import build_app
from cli.report import EXIT_OK, Report


struct Ran(Movable):
    """How one `dodo` command line ended."""

    var code: Int
    var out: String
    var err: String

    def __init__(out self, code: Int, var out: String, var err: String):
        self.code = code
        self.out = out^
        self.err = err^

    def json(self) raises -> Value:
        """The stdout as the one JSON object `--json` promises."""
        var lines = self.out.strip().splitlines()
        assert_equal(
            len(lines), 1, String("stdout is not one line: ", self.out)
        )
        return loads(String(lines[0]))


def dodo_binary() raises -> String:
    """The `dodo` binary, built from `cli/main.mojo` when it changed."""
    var root = realpath(".")
    var report = Report("test", True)
    var build = build_app(
        root,
        join(root, "cli", "main.mojo"),
        join(root, ".dodo", "build"),
        report,
    )
    assert_equal(build.exit_code, EXIT_OK, build.log)
    return build.binary


def dodo_run(
    words: List[String],
    env: List[String] = List[String](),
    cwd: String = "",
) raises -> Ran:
    """Run `dodo WORDS...` (in `cwd` when given) and keep what it printed."""
    var argv = List[String]()
    if cwd != "":
        # `sh -c` changes directory, then becomes dodo.
        argv = ["sh", "-c", 'cd "$1" && shift && exec "$@"', "sh", cwd]
    argv.append(dodo_binary())
    for word in words:
        argv.append(word)
    var base = join(
        getenv("TMPDIR", "/tmp"), String("dodo_e2e_", perf_counter_ns())
    )
    var out_path = base + ".out"
    var err_path = base + ".err"
    var status = run(argv, env=env, stdout_path=out_path, stderr_path=err_path)
    var ran = Ran(
        status.shell_code(), read_or_empty(out_path), read_or_empty(err_path)
    )
    remove(out_path)
    remove(err_path)
    return ran^


def scratch(name: String) raises -> String:
    """An empty folder for one test, made fresh each run."""
    var dir = join(getenv("TMPDIR", "/tmp"), String("dodo_e2e_", name))
    _ = run(["rm", "-rf", dir])
    makedirs(dir, exist_ok=True)
    return realpath(dir)


def read_or_empty(path: String) -> String:
    try:
        with open(path, "r") as file:
            return file.read()
    except:
        return ""
