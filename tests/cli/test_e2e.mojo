"""End-to-end tests: build the real `dodo` binary and run it as a user would.

The binary is built with the CLI's own build cache (into `.dodo/build/` of
this repository), so only the first test of a run pays for the build. The
apps it builds are the fixtures in `tests/cli/fixtures/`. Run from the
repository root, as `tests/tools/run_tests.sh` does.
"""

from std.os import getenv, makedirs, remove
from std.os.path import exists, join, realpath
from std.testing import TestSuite, assert_equal, assert_false, assert_true
from std.time import perf_counter_ns

from dodo.json import Value, loads
from dodo.utils.process import run

from cli.build import build_app
from cli.report import (
    EXIT_BUILD_FAILED,
    EXIT_FAILED,
    EXIT_OK,
    EXIT_USAGE,
    Report,
)
from cli.version import DODO_VERSION

comptime _APP = "tests/cli/fixtures/cli_app.mojo"
comptime _BROKEN = "tests/cli/fixtures/broken_app.mojo"


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


def _dodo() raises -> String:
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


def _scratch(name: String) raises -> String:
    var dir = join(getenv("TMPDIR", "/tmp"), String("dodo_e2e_", name))
    _ = run(["rm", "-rf", dir])
    makedirs(dir, exist_ok=True)
    return realpath(dir)


def _read(path: String) -> String:
    try:
        with open(path, "r") as file:
            return file.read()
    except:
        return ""


def _dodo_run(
    words: List[String],
    env: List[String] = List[String](),
    cwd: String = "",
) raises -> Ran:
    """Run `dodo WORDS...` (in `cwd` when given) and keep what it printed."""
    var argv = List[String]()
    if cwd != "":
        # `sh -c` changes directory, then becomes dodo.
        argv = ["sh", "-c", 'cd "$1" && shift && exec "$@"', "sh", cwd]
    argv.append(_dodo())
    for word in words:
        argv.append(word)
    var base = join(
        getenv("TMPDIR", "/tmp"), String("dodo_e2e_", perf_counter_ns())
    )
    var out_path = base + ".out"
    var err_path = base + ".err"
    var status = run(argv, env=env, stdout_path=out_path, stderr_path=err_path)
    var ran = Ran(status.shell_code(), _read(out_path), _read(err_path))
    remove(out_path)
    remove(err_path)
    return ran^


# ── version and help ──


def test_version() raises:
    var ran = _dodo_run(["--version"])
    assert_equal(ran.code, EXIT_OK)
    assert_equal(ran.out, String("dodo ", DODO_VERSION, "\n"))
    assert_equal(ran.err, "")


def test_version_json() raises:
    var ran = _dodo_run(["--version", "--json"])
    assert_equal(ran.code, EXIT_OK)
    var result = ran.json()
    assert_true(result["ok"].as_bool())
    assert_equal(result["version"].as_string(), DODO_VERSION)
    assert_equal(Int(result["exit_code"].as_int()), 0)


def test_help_lists_commands() raises:
    var ran = _dodo_run(List[String]())
    assert_equal(ran.code, EXIT_OK)
    for name in ["new", "run", "dev", "test", "routes", "doctor", "docs pull"]:
        assert_true(name in ran.out, String("help misses ", name))


def test_unknown_command() raises:
    var ran = _dodo_run(["serve"])
    assert_equal(ran.code, EXIT_USAGE)
    assert_equal(ran.out, "")
    assert_true("serve" in ran.err)
    assert_true("hint: run `dodo --help`" in ran.err)


def test_unknown_command_json() raises:
    var ran = _dodo_run(["serve", "--json"])
    assert_equal(ran.code, EXIT_USAGE)
    assert_equal(ran.err, "")
    var result = ran.json()
    assert_false(result["ok"].as_bool())
    assert_equal(Int(result["exit_code"].as_int()), EXIT_USAGE)
    assert_equal(result["error"]["kind"].as_string(), "usage")


def test_unknown_flag() raises:
    var ran = _dodo_run(["routes", "--colour"])
    assert_equal(ran.code, EXIT_USAGE)
    assert_true("--colour" in ran.err)
    assert_true("dodo routes --help" in ran.err)


# ── routes ──


def test_routes_lists_the_app() raises:
    var ran = _dodo_run(["routes", _APP])
    assert_equal(ran.code, EXIT_OK, ran.err)
    assert_equal(ran.out, "GET  /\nGET  /slow  (blocking)\n")


def test_routes_json() raises:
    var ran = _dodo_run(["--json", "routes", _APP])
    assert_equal(ran.code, EXIT_OK, ran.out)
    assert_equal(ran.err, "")
    var result = ran.json()
    assert_true(result["ok"].as_bool())
    assert_equal(result["command"].as_string(), "routes")
    var routes = result["routes"].copy()
    assert_equal(len(routes), 2)
    assert_equal(routes[0]["path"].as_string(), "/")
    assert_false(routes[0]["blocking"].as_bool())
    assert_equal(routes[1]["path"].as_string(), "/slow")
    assert_true(routes[1]["blocking"].as_bool())
    assert_true(
        result["binary"].as_string().endswith("tests__cli__fixtures__cli_app")
    )


def test_routes_second_run_skips_the_build() raises:
    _ = _dodo_run(["routes", _APP])
    var result = _dodo_run(["routes", _APP, "--json"]).json()
    assert_false(result["built"].as_bool())


def test_routes_app_crashes() raises:
    var ran = _dodo_run(["routes", _APP, "--json"], env=["CLI_APP_MODE=crash"])
    assert_equal(ran.code, EXIT_FAILED)
    var result = ran.json()
    assert_equal(result["error"]["kind"].as_string(), "app_failed")
    assert_true("database is down" in result["error"]["hint"].as_string())
    assert_true("database is down" in result["app_stderr"].as_string())


def test_routes_app_never_serves() raises:
    var ran = _dodo_run(["routes", _APP], env=["CLI_APP_MODE=no_serve"])
    assert_equal(ran.code, EXIT_FAILED)
    assert_equal(ran.out, "")
    assert_true("without calling serve()" in ran.err)


def test_routes_timeout() raises:
    var started = perf_counter_ns()
    var ran = _dodo_run(
        ["routes", _APP, "--timeout", "0.5", "--json"],
        env=["CLI_APP_MODE=hang"],
    )
    var seconds = Float64(perf_counter_ns() - started) / 1e9
    assert_equal(ran.code, EXIT_FAILED)
    assert_equal(ran.json()["error"]["kind"].as_string(), "timeout")
    assert_true(seconds < 10.0, String("took ", seconds, " s"))


def test_routes_bad_timeout() raises:
    for bad in ["abc", "0", "-2", "99999"]:
        var ran = _dodo_run(["routes", _APP, "--timeout", bad])
        assert_equal(ran.code, EXIT_USAGE, String(bad))
        assert_true("--timeout" in ran.err)


def test_routes_build_failure() raises:
    var ran = _dodo_run(["routes", _BROKEN])
    assert_equal(ran.code, EXIT_BUILD_FAILED)
    assert_equal(ran.out, "")
    assert_true("cannot implicitly convert" in ran.err)
    assert_true("mojo build failed" in ran.err)


def test_routes_build_failure_json() raises:
    var ran = _dodo_run(["routes", _BROKEN, "--json"])
    assert_equal(ran.code, EXIT_BUILD_FAILED)
    assert_equal(ran.err, "")
    var result = ran.json()
    assert_equal(result["error"]["kind"].as_string(), "build")
    assert_true("cannot implicitly convert" in result["build_log"].as_string())
    assert_false("binary" in result)


def test_routes_missing_or_wrong_file() raises:
    var missing = _dodo_run(["routes", "nope.mojo", "--json"])
    assert_equal(missing.code, EXIT_USAGE)
    assert_equal(missing.json()["error"]["kind"].as_string(), "not_found")
    var not_mojo = _dodo_run(["routes", "README.md"])
    assert_equal(not_mojo.code, EXIT_USAGE)
    assert_true("is not a .mojo file" in not_mojo.err)


def test_routes_without_main_mojo() raises:
    var dir = _scratch("no_main")
    var ran = _dodo_run(["routes"], cwd=dir)
    assert_equal(ran.code, EXIT_USAGE)
    assert_true("no main.mojo" in ran.err)


# ── run ──


def test_run_passes_arguments_and_exit_code() raises:
    var ran = _dodo_run(
        ["run", _APP, "--", "3", "hello world", "--json"],
        env=["CLI_APP_MODE=args"],
    )
    assert_equal(ran.code, 3)
    assert_equal(ran.out, "cli_app starting\n3\nhello world\n--json\n")


def test_run_json_reports_before_the_app() raises:
    var ran = _dodo_run(
        ["run", "--json", _APP, "--", "0"], env=["CLI_APP_MODE=args"]
    )
    assert_equal(ran.code, EXIT_OK)
    var lines = ran.out.splitlines()
    assert_equal(len(lines), 3)
    var result = loads(String(lines[0]))
    assert_true(result["ok"].as_bool())
    assert_equal(result["command"].as_string(), "run")
    assert_equal(String(lines[1]), "cli_app starting")
    assert_equal(String(lines[2]), "0")


def test_run_app_error_is_its_exit_code() raises:
    var ran = _dodo_run(["run", _APP], env=["CLI_APP_MODE=crash"])
    assert_equal(ran.code, 1)
    assert_true("database is down" in ran.err)


def test_run_build_failure() raises:
    var ran = _dodo_run(["run", _BROKEN, "--", "x"])
    assert_equal(ran.code, EXIT_BUILD_FAILED)
    assert_true("cannot implicitly convert" in ran.err)


# ── doctor ──


def test_doctor_in_the_repository() raises:
    var ran = _dodo_run(["doctor", "--json"])
    var result = ran.json()
    assert_equal(Int(result["exit_code"].as_int()), ran.code)
    var names = List[String]()
    var failed = 0
    var checks = result["checks"].copy()
    for i in range(len(checks)):
        names.append(checks[i]["name"].as_string())
        var status = checks[i]["status"].as_string()
        assert_true(status == "ok" or status == "warn" or status == "fail")
        if status == "fail":
            failed += 1
    assert_true("app" in names)
    assert_true("docs" in names)
    assert_true("native libraries" in names)
    if failed == 0:
        assert_equal(ran.code, EXIT_OK)
    else:
        assert_equal(ran.code, EXIT_FAILED)


def test_doctor_outside_a_project() raises:
    var dir = _scratch("doctor")
    var result = _dodo_run(["doctor", "--json"], cwd=dir).json()
    var checks = result["checks"].copy()
    for i in range(len(checks)):
        var name = checks[i]["name"].as_string()
        assert_true(name != "app" and name != "docs", name)
        if name == "project":
            assert_equal(checks[i]["status"].as_string(), "warn")


def test_doctor_text() raises:
    var ran = _dodo_run(["doctor"])
    assert_true(ran.out.startswith("ok    machine"), ran.out)
    assert_true("native libraries" in ran.out)


def test_doctor_takes_no_arguments() raises:
    var ran = _dodo_run(["doctor", "now"])
    assert_equal(ran.code, EXIT_USAGE)
    assert_true("takes no arguments" in ran.err)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
