"""End-to-end tests: build the real `dodo` binary and run it as a user would.

The apps it builds are the fixtures in `tests/cli/fixtures/`; how the
binary is built and run is in `dodo_cli.mojo`.
"""

from std.os import getenv, makedirs, remove
from std.os.path import exists, join, realpath
from std.testing import TestSuite, assert_equal, assert_false, assert_true
from std.time import perf_counter_ns, sleep

from dodo.json import Value, loads
from dodo.net import SocketAddr
from dodo.tcp import TcpListener
from dodo.utils.process import Child, ExitStatus, run, spawn

from cli.build import build_app
from cli.report import (
    EXIT_BUILD_FAILED,
    EXIT_FAILED,
    EXIT_INTERRUPTED,
    EXIT_OK,
    EXIT_UNAVAILABLE,
    EXIT_USAGE,
    Report,
)
from cli.version import DODO_VERSION

from dodo_cli import Ran, dodo_binary, dodo_run, read_or_empty, scratch

comptime _APP = "tests/cli/fixtures/cli_app.mojo"
comptime _BROKEN = "tests/cli/fixtures/broken_app.mojo"
comptime _SUITES = "tests/cli/fixtures/suites"


# ── version and help ──


def test_version() raises:
    var ran = dodo_run(["--version"])
    assert_equal(ran.code, EXIT_OK)
    assert_equal(ran.out, String("dodo ", DODO_VERSION, "\n"))
    assert_equal(ran.err, "")


def test_version_json() raises:
    var ran = dodo_run(["--version", "--json"])
    assert_equal(ran.code, EXIT_OK)
    var result = ran.json()
    assert_true(result["ok"].as_bool())
    assert_equal(result["version"].as_string(), DODO_VERSION)
    assert_equal(Int(result["exit_code"].as_int()), 0)


def test_help_lists_commands() raises:
    var ran = dodo_run(List[String]())
    assert_equal(ran.code, EXIT_OK)
    for name in ["new", "run", "dev", "test", "routes", "doctor", "docs pull"]:
        assert_true(name in ran.out, String("help misses ", name))


def test_unknown_command() raises:
    var ran = dodo_run(["serve"])
    assert_equal(ran.code, EXIT_USAGE)
    assert_equal(ran.out, "")
    assert_true("serve" in ran.err)
    assert_true("hint: run `dodo --help`" in ran.err)


def test_unknown_command_json() raises:
    var ran = dodo_run(["serve", "--json"])
    assert_equal(ran.code, EXIT_USAGE)
    assert_equal(ran.err, "")
    var result = ran.json()
    assert_false(result["ok"].as_bool())
    assert_equal(Int(result["exit_code"].as_int()), EXIT_USAGE)
    assert_equal(result["error"]["kind"].as_string(), "usage")


def test_unknown_flag() raises:
    var ran = dodo_run(["routes", "--colour"])
    assert_equal(ran.code, EXIT_USAGE)
    assert_true("--colour" in ran.err)
    assert_true("dodo routes --help" in ran.err)


# ── routes ──


def test_routes_lists_the_app() raises:
    var ran = dodo_run(["routes", _APP])
    assert_equal(ran.code, EXIT_OK, ran.err)
    assert_equal(ran.out, "GET  /\nGET  /slow  (blocking)\n")


def test_routes_json() raises:
    var ran = dodo_run(["--json", "routes", _APP])
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
    _ = dodo_run(["routes", _APP])
    var result = dodo_run(["routes", _APP, "--json"]).json()
    assert_false(result["built"].as_bool())


def test_routes_app_crashes() raises:
    var ran = dodo_run(["routes", _APP, "--json"], env=["CLI_APP_MODE=crash"])
    assert_equal(ran.code, EXIT_FAILED)
    var result = ran.json()
    assert_equal(result["error"]["kind"].as_string(), "app_failed")
    assert_true("database is down" in result["error"]["hint"].as_string())
    assert_true("database is down" in result["app_stderr"].as_string())


def test_routes_app_never_serves() raises:
    var ran = dodo_run(["routes", _APP], env=["CLI_APP_MODE=no_serve"])
    assert_equal(ran.code, EXIT_FAILED)
    assert_equal(ran.out, "")
    assert_true("without calling serve()" in ran.err)


def test_routes_timeout() raises:
    var started = perf_counter_ns()
    var ran = dodo_run(
        ["routes", _APP, "--timeout", "0.5", "--json"],
        env=["CLI_APP_MODE=hang"],
    )
    var seconds = Float64(perf_counter_ns() - started) / 1e9
    assert_equal(ran.code, EXIT_FAILED)
    assert_equal(ran.json()["error"]["kind"].as_string(), "timeout")
    assert_true(seconds < 10.0, String("took ", seconds, " s"))


def test_routes_bad_timeout() raises:
    for bad in ["abc", "0", "-2", "99999"]:
        var ran = dodo_run(["routes", _APP, "--timeout", bad])
        assert_equal(ran.code, EXIT_USAGE, String(bad))
        assert_true("--timeout" in ran.err)


def test_routes_build_failure() raises:
    var ran = dodo_run(["routes", _BROKEN])
    assert_equal(ran.code, EXIT_BUILD_FAILED)
    assert_equal(ran.out, "")
    assert_true("cannot implicitly convert" in ran.err)
    assert_true("mojo build failed" in ran.err)


def test_routes_build_failure_json() raises:
    var ran = dodo_run(["routes", _BROKEN, "--json"])
    assert_equal(ran.code, EXIT_BUILD_FAILED)
    assert_equal(ran.err, "")
    var result = ran.json()
    assert_equal(result["error"]["kind"].as_string(), "build")
    assert_true("cannot implicitly convert" in result["build_log"].as_string())
    assert_false("binary" in result)


def test_routes_missing_or_wrong_file() raises:
    var missing = dodo_run(["routes", "nope.mojo", "--json"])
    assert_equal(missing.code, EXIT_USAGE)
    assert_equal(missing.json()["error"]["kind"].as_string(), "not_found")
    var not_mojo = dodo_run(["routes", "README.md"])
    assert_equal(not_mojo.code, EXIT_USAGE)
    assert_true("is not a .mojo file" in not_mojo.err)


def test_routes_without_main_mojo() raises:
    var dir = scratch("no_main")
    var ran = dodo_run(["routes"], cwd=dir)
    assert_equal(ran.code, EXIT_USAGE)
    assert_true("no main.mojo" in ran.err)


# ── run ──


def test_run_passes_arguments_and_exit_code() raises:
    var ran = dodo_run(
        ["run", _APP, "--", "3", "hello world", "--json"],
        env=["CLI_APP_MODE=args"],
    )
    assert_equal(ran.code, 3)
    assert_equal(ran.out, "cli_app starting\n3\nhello world\n--json\n")


def test_run_json_reports_before_the_app() raises:
    var ran = dodo_run(
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
    var ran = dodo_run(["run", _APP], env=["CLI_APP_MODE=crash"])
    assert_equal(ran.code, 1)
    assert_true("database is down" in ran.err)


def test_run_build_failure() raises:
    var ran = dodo_run(["run", _BROKEN, "--", "x"])
    assert_equal(ran.code, EXIT_BUILD_FAILED)
    assert_true("cannot implicitly convert" in ran.err)


# ── doctor ──


def test_doctor_in_the_repository() raises:
    var ran = dodo_run(["doctor", "--json"])
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
    var dir = scratch("doctor")
    var result = dodo_run(["doctor", "--json"], cwd=dir).json()
    var checks = result["checks"].copy()
    for i in range(len(checks)):
        var name = checks[i]["name"].as_string()
        assert_true(name != "app" and name != "docs", name)
        if name == "project":
            assert_equal(checks[i]["status"].as_string(), "warn")


def test_doctor_text() raises:
    var ran = dodo_run(["doctor"])
    assert_true(ran.out.startswith("ok    machine"), ran.out)
    assert_true("native libraries" in ran.out)


def test_doctor_takes_no_arguments() raises:
    var ran = dodo_run(["doctor", "now"])
    assert_equal(ran.code, EXIT_USAGE)
    assert_true("takes no arguments" in ran.err)


# ── test ──


def _suites_project() raises -> String:
    """A project whose tests/ is a copy of the suites fixture. It is kept
    between runs and copied with times kept (`cp -p`), so its builds stay
    cached until a fixture changes."""
    var dir = join(getenv("TMPDIR", "/tmp"), "dodo_e2e_suites")
    makedirs(join(dir, "tests"), exist_ok=True)
    var copied = run(["cp", "-Rp", _SUITES + "/.", join(dir, "tests")])
    assert_true(copied.succeeded())
    with open(join(dir, "pixi.toml"), "w") as file:
        file.write("")
    return realpath(dir)


def _outcome_of(result: Value, path: String) raises -> String:
    var files = result["files"].copy()
    for i in range(len(files)):
        if files[i]["path"].as_string() == path:
            return files[i]["outcome"].as_string()
    return "missing"


def _is_running(pid: String) raises -> Bool:
    return run(["kill", "-0", pid], stderr_path="/dev/null").succeeded()


def test_test_every_outcome() raises:
    # Every fixture but the hanging one, which has its own test: a short
    # --timeout here could also stop a slow first launch of a new binary.
    var dir = _suites_project()
    var ran = dodo_run(
        [
            "test",
            "tests/passing",
            "tests/failing",
            "tests/crash",
            "tests/broken",
            "tests/no_report",
            "tests/leftover",
            "--json",
        ],
        cwd=dir,
    )
    assert_equal(ran.code, EXIT_BUILD_FAILED, ran.out)
    var result = ran.json()
    assert_equal(len(result["files"]), 7)
    assert_equal(_outcome_of(result, "tests/passing/test_math.mojo"), "passed")
    assert_equal(_outcome_of(result, "tests/passing/test_words.mojo"), "passed")
    assert_equal(_outcome_of(result, "tests/failing/test_mixed.mojo"), "failed")
    assert_equal(_outcome_of(result, "tests/crash/test_crash.mojo"), "crashed")
    assert_equal(
        _outcome_of(result, "tests/broken/test_broken.mojo"), "build_failed"
    )
    assert_equal(
        _outcome_of(result, "tests/no_report/test_exit.mojo"), "no_report"
    )
    assert_equal(
        _outcome_of(result, "tests/leftover/test_leftover.mojo"), "passed"
    )
    assert_equal(result["error"]["kind"].as_string(), "build")
    assert_equal(Int(result["passed"].as_int()), 5)
    assert_equal(Int(result["failed"].as_int()), 1)

    # The test ran from the project root and its background program was
    # killed once the test file ended.
    var pid = String(read_or_empty(join(dir, "leftover.pid")).strip())
    assert_true(pid != "")
    assert_false(_is_running(pid))


def test_test_timeout() raises:
    var dir = _suites_project()
    var ran = dodo_run(
        ["test", "tests/hang", "--timeout", "0.5", "--json"], cwd=dir
    )
    assert_equal(ran.code, EXIT_FAILED, ran.out)
    var result = ran.json()
    assert_equal(_outcome_of(result, "tests/hang/test_hang.mojo"), "timed_out")
    assert_equal(
        result["files"][0]["exit"].as_string(), "still running after 0.50 s"
    )
    var left = run(
        ["pgrep", "-f", "tests__hang__test_hang"], stdout_path="/dev/null"
    )
    assert_false(left.succeeded())


def test_test_text_report() raises:
    var dir = _suites_project()
    var ran = dodo_run(["test", "tests/passing", "tests/failing"], cwd=dir)
    assert_equal(ran.code, EXIT_FAILED)
    var lines = ran.out.strip().splitlines()
    assert_true(
        String(lines[0]).startswith(
            "FAIL    tests/failing/test_mixed.mojo  1 of 2 tests failed"
        )
    )
    assert_equal(String(lines[1]), "        test_wrong")
    assert_true(
        String(lines[2]).endswith(
            "AssertionError: `left == right` comparison failed:"
        )
    )
    assert_true(
        String(lines[len(lines) - 1]).startswith(
            "4 passed, 1 failed, 0 skipped; 3 file(s)"
        )
    )
    assert_true("dodo test: 1 test file(s) did not pass" in ran.err)


def test_test_second_run_builds_nothing() raises:
    var dir = _suites_project()
    _ = dodo_run(["test", "tests/passing"], cwd=dir)
    var ran = dodo_run(["test", "tests/passing", "--json"], cwd=dir)
    assert_equal(ran.code, EXIT_OK)
    var files = ran.json()["files"].copy()
    assert_equal(len(files), 2)
    for i in range(len(files)):
        assert_false(files[i]["built"].as_bool())


def test_test_only_one_test() raises:
    var dir = _suites_project()
    var ran = dodo_run(["test", "--only", "test_double", "--json"], cwd=dir)
    assert_equal(ran.code, EXIT_OK, ran.out)
    var result = ran.json()
    assert_equal(len(result["files"]), 1)
    var tests = result["files"][0]["tests"].copy()
    assert_equal(len(tests), 1)
    assert_equal(tests[0]["name"].as_string(), "test_double")
    assert_equal(Int(result["skipped"].as_int()), 0)


def test_test_only_unknown_name() raises:
    var dir = _suites_project()
    var ran = dodo_run(["test", "--only", "test_nothing"], cwd=dir)
    assert_equal(ran.code, EXIT_FAILED)
    assert_true("no test file defines `test_nothing`" in ran.err)


def test_test_from_a_subfolder() raises:
    var dir = _suites_project()
    var ran = dodo_run(
        ["test", "--only", "test_add", "--json"],
        cwd=join(dir, "tests", "passing"),
    )
    assert_equal(ran.code, EXIT_OK, ran.out)
    var result = ran.json()
    assert_equal(
        result["files"][0]["path"].as_string(), "tests/passing/test_math.mojo"
    )


def test_test_bad_flags_and_paths() raises:
    var dir = _suites_project()
    # tests/passing keeps a wrongly accepted flag from running the slow files.
    for flag in ["--jobs", "--timeout", "--only"]:
        for bad in ["0", "x", ""]:
            if String(flag) == "--only" and String(bad) != "":
                continue
            var ran = dodo_run(
                ["test", String(flag), String(bad), "tests/passing"], cwd=dir
            )
            assert_equal(ran.code, EXIT_USAGE, String(flag, " ", bad))
    var missing = dodo_run(["test", "tests/nope", "--json"], cwd=dir)
    assert_equal(missing.code, EXIT_USAGE)
    assert_equal(missing.json()["error"]["kind"].as_string(), "not_found")
    var not_mojo = dodo_run(["test", "tests/README.md"], cwd=dir)
    assert_equal(not_mojo.code, EXIT_USAGE)


def test_test_without_tests_folder() raises:
    var dir = scratch("empty_project")
    with open(join(dir, "pixi.toml"), "w") as file:
        file.write("")
    var ran = dodo_run(["test", "--json"], cwd=dir)
    assert_equal(ran.code, EXIT_FAILED)
    assert_equal(ran.json()["error"]["kind"].as_string(), "no_tests")


def test_test_interrupted() raises:
    var dir = _suites_project()
    # Build the hanging test first, so the interrupt lands while it runs.
    _ = dodo_run(["test", "tests/hang", "--timeout", "0.5"], cwd=dir)
    var out_path = join(dir, "interrupted.out")
    var child = spawn(
        [
            "sh",
            "-c",
            'cd "$1" && shift && exec "$@"',
            "sh",
            dir,
            dodo_binary(),
            "test",
            "tests/hang",
        ],
        stdout_path=out_path,
        stderr_path="&1",
    )
    sleep(1.0)
    child.send_signal(2)
    var status = child.wait()
    assert_equal(status.shell_code(), EXIT_INTERRUPTED)
    var output = read_or_empty(out_path)
    assert_true("STOPPED tests/hang/test_hang.mojo" in output, output)
    var left = run(
        ["pgrep", "-f", "tests__hang__test_hang"], stdout_path="/dev/null"
    )
    assert_false(left.succeeded())


def test_test_interrupted_while_building() raises:
    # A fresh project, so dodo has to build; the builds run in process
    # groups of their own, so only dodo can stop them.
    var dir = scratch("interrupt_build")
    makedirs(join(dir, "tests"), exist_ok=True)
    _ = run(["cp", "-R", _SUITES + "/passing/.", join(dir, "tests")])
    with open(join(dir, "pixi.toml"), "w") as file:
        file.write("")
    var builds = join(dir, ".dodo", "build", "tests")
    var out_path = join(dir, "interrupted.out")
    var child = spawn(
        [
            "sh",
            "-c",
            'cd "$1" && shift && exec "$@"',
            "sh",
            dir,
            dodo_binary(),
            "test",
        ],
        stdout_path=out_path,
        stderr_path="&1",
    )

    var building = False
    var tries = 0
    while not building and tries < 3000:
        sleep(0.01)
        tries += 1
        var found = run(["pgrep", "-f", builds], stdout_path="/dev/null")
        building = found.succeeded()
    assert_true(building, read_or_empty(out_path))

    child.send_signal(2)
    var status = child.wait()
    assert_equal(status.shell_code(), EXIT_INTERRUPTED)
    assert_true("stopped while building" in read_or_empty(out_path))
    sleep(0.1)
    var left = run(["pgrep", "-f", builds], stdout_path="/dev/null")
    assert_false(left.succeeded())


# ── dev ──

comptime _DEV_APP = """from dodo import App, Request
from std.time import sleep


def home(req: Request) raises -> String:
    return "VERSION"


def slow(req: Request) raises -> String:
    sleep(1.5)
    return "slow done"


def main() raises:
    var app = App()
    app.get["/"](home)
    app.get["/slow"](slow, blocking=True)
    # Port 1 cannot be bound by a test; `dodo dev` hands its own socket down.
    app.serve(port=1, num_workers=2)
"""


def _dev_project(name: String, main: String) raises -> String:
    """A project whose `main.mojo` is `main` and imports dodo through a
    link to this repository's package (the watcher does not follow
    links)."""
    var dir = scratch(name)
    _ = run(["ln", "-s", realpath("dodo"), join(dir, "dodo")])
    with open(join(dir, "pixi.toml"), "w") as file:
        file.write("")
    _save_main(dir, main)
    return dir


def _save_main(dir: String, text: String) raises:
    """Save `main.mojo` a little later, so its change time moves."""
    sleep(0.01)
    with open(join(dir, "main.mojo"), "w") as file:
        file.write(text)


def _save_version(dir: String, version: String) raises:
    _save_main(dir, String(_DEV_APP).replace("VERSION", version))


def _get(url: String) raises -> String:
    """The body of `url`, or `refused` when nothing answered."""
    var path = join(
        getenv("TMPDIR", "/tmp"), String("dodo_e2e_get_", perf_counter_ns())
    )
    var status = run(
        ["curl", "-s", "-m", "5", "-o", path, url], stderr_path="/dev/null"
    )
    var body = read_or_empty(path)
    _ = run(["rm", "-f", path])
    if not status.succeeded():
        return String("refused (curl ", status, ")")
    return body


def _dev_events(out_path: String, name: String) raises -> List[Value]:
    """Every `dodo dev` event called `name` printed so far."""
    var found = List[Value]()
    for line in read_or_empty(out_path).splitlines():
        if not line.startswith('{"dodo_dev"'):
            continue
        var event = loads(String(line))["dodo_dev"].copy()
        if event["event"].as_string() == name:
            found.append(event^)
    return found^


def _wait_for_event(out_path: String, name: String, count: Int) raises:
    """Wait (up to 2 minutes, for builds) until `name` was printed `count`
    times."""
    var tries = 0
    while len(_dev_events(out_path, name)) < count:
        var why = String("no ", name, ":\n", read_or_empty(out_path))
        assert_true(tries < 12000, why)
        sleep(0.01)
        tries += 1


def _wait_for_body(url: String, want: String, out_path: String) raises:
    """Ask `url` until it answers `want`. Every answer on the way must be a
    real answer: the port stays open while the app restarts."""
    var tries = 0
    var body = _get(url)
    while body != want:
        if body.startswith("refused"):
            raise Error(body, " during a restart:\n", read_or_empty(out_path))
        var why = String(
            "never `", want, "`, last `", body, "`:\n", read_or_empty(out_path)
        )
        assert_true(tries < 1200, why)
        sleep(0.1)
        tries += 1
        body = _get(url)


def _start_dev(dir: String, json: Bool) raises -> Child:
    """Start `dodo dev --port 0` in `dir`, printing to `dev.out` and
    `dev.err` there."""
    var argv: List[String] = [
        "sh",
        "-c",
        'cd "$1" && shift && exec "$@"',
        "sh",
        dir,
        dodo_binary(),
        "dev",
        "--port",
        "0",
    ]
    if json:
        argv.append("--json")
    return spawn(
        argv,
        stdout_path=join(dir, "dev.out"),
        stderr_path=join(dir, "dev.err"),
    )


def _stop_dev(mut dodo: Child) raises -> ExitStatus:
    """Ctrl-C, as a user would; dodo stops its app before it exits."""
    var status = dodo.poll()
    if status:
        return status.value()
    dodo.send_signal(2)
    return dodo.wait()


def test_dev_session() raises:
    var dir = _dev_project(
        "dev_session", String(_DEV_APP).replace("VERSION", "v1")
    )
    var dodo = _start_dev(dir, json=True)
    try:
        _dev_session_steps(dir, dodo)
    except e:
        # Never leave a server running behind a failed test.
        _ = _stop_dev(dodo)
        raise e^


def _dev_session_steps(dir: String, mut dodo: Child) raises:
    var out_path = join(dir, "dev.out")
    var err_path = join(dir, "dev.err")
    _wait_for_event(out_path, "listening", 1)
    var url = _dev_events(out_path, "listening")[0]["url"].as_string()
    assert_true(url.startswith("http://127.0.0.1:"), url)

    # First start. Until the first build is done, a request waits unanswered.
    _wait_for_event(out_path, "started", 1)
    _wait_for_body(url, '"v1"', out_path)
    var started = _dev_events(out_path, "started")
    assert_false(started[0]["restart"].as_bool())

    # A save restarts it; a request in flight is finished by the old app.
    var slow_path = join(dir, "slow.out")
    var slow = spawn(
        ["curl", "-s", "-m", "60", "-o", slow_path, url + "/slow"],
        stderr_path="/dev/null",
    )
    sleep(0.3)
    _save_version(dir, "v2")
    _wait_for_body(url, '"v2"', out_path)
    assert_true(slow.wait().succeeded())
    assert_equal(read_or_empty(slow_path), '"slow done"')
    assert_true(_dev_events(out_path, "started")[1]["restart"].as_bool())

    # A broken save keeps the last good build serving.
    sleep(0.01)
    with open(join(dir, "main.mojo"), "w") as file:
        file.write("def main(:\n")
    _wait_for_event(out_path, "build_failed", 1)
    var failed = _dev_events(out_path, "build_failed")[0].copy()
    var log = failed["log"].as_string()
    assert_true("error" in log, log)
    assert_equal(_get(url), '"v2"')
    _save_version(dir, "v3")
    _wait_for_body(url, '"v3"', out_path)

    # An app that dies is reported, and the next save starts it again.
    var pid = _dev_events(out_path, "started")[2]["pid"].as_int()
    _ = run(["kill", "-9", String(pid)])
    _wait_for_event(out_path, "app_exited", 1)
    var exited = _dev_events(out_path, "app_exited")[0].copy()
    assert_equal(Int(exited["exit_code"].as_int()), 137)
    _save_version(dir, "v4")
    _wait_for_event(out_path, "started", 4)
    _wait_for_body(url, '"v4"', out_path)
    assert_false(_dev_events(out_path, "started")[3]["restart"].as_bool())

    # Ctrl-C stops the app and closes the port.
    var app_pid = _dev_events(out_path, "started")[3]["pid"].as_int()
    var status = _stop_dev(dodo)
    assert_equal(status.shell_code(), EXIT_INTERRUPTED, read_or_empty(err_path))
    assert_equal(len(_dev_events(out_path, "stopped")), 1)
    assert_false(_is_running(String(app_pid)), "the app outlived dodo")
    assert_true(_get(url).startswith("refused"))
    var lines = read_or_empty(out_path).strip().splitlines()
    var result = loads(String(lines[len(lines) - 1]))
    assert_equal(result["command"].as_string(), "dev")
    assert_equal(result["url"].as_string(), url)


def test_dev_text_output() raises:
    # Without --json, events go to stderr as plain lines; stdout is the
    # app's.
    var dir = _dev_project(
        "dev_text", String(_DEV_APP).replace("VERSION", "v1")
    )
    var err_path = join(dir, "dev.err")
    var dodo = _start_dev(dir, json=False)
    var tries = 0
    while "started in" not in read_or_empty(err_path) and tries < 12000:
        sleep(0.01)
        tries += 1
    var status = _stop_dev(dodo)
    assert_equal(status.shell_code(), EXIT_INTERRUPTED)
    var err = read_or_empty(err_path)
    assert_true("started in" in err, err)
    assert_true("dodo dev: serving " in err, err)
    assert_true("(Ctrl-C to stop)" in err, err)
    assert_true("dodo dev: stopped" in err, err)
    assert_equal(read_or_empty(join(dir, "dev.out")), "")


def test_dev_port_in_use() raises:
    var taken = TcpListener.bind(SocketAddr.localhost(0))
    var port = String(Int(taken.local_addr().port))
    var ran = dodo_run(["dev", _APP, "--port", port, "--json"])
    assert_equal(ran.code, EXIT_UNAVAILABLE)
    var error = ran.json()["error"].copy()
    assert_equal(error["kind"].as_string(), "listen")
    assert_true(port in error["message"].as_string())
    _ = taken^


def test_dev_bad_flags_and_files() raises:
    for port in ["", "-1", "65536", "abc"]:
        var ran = dodo_run(["dev", _APP, "--port", port, "--json"])
        assert_equal(ran.code, EXIT_USAGE, port)
        assert_equal(ran.json()["error"]["kind"].as_string(), "usage")
    var bad_host = dodo_run(["dev", _APP, "--host", "example.com"])
    assert_equal(bad_host.code, EXIT_USAGE)
    assert_true("--host" in bad_host.err, bad_host.err)
    var missing = dodo_run(["dev", "nope.mojo", "--json"])
    assert_equal(missing.code, EXIT_USAGE)
    assert_equal(missing.json()["error"]["kind"].as_string(), "not_found")
    var too_many = dodo_run(["dev", _APP, _APP])
    assert_equal(too_many.code, EXIT_USAGE)


comptime _STUBBORN_APP = """from std.ffi import c_int, external_call
from std.time import sleep


def main() raises:
    # Ignore SIGTERM (SIG_IGN is 1), as a hung app would.
    _ = external_call["signal", Int](c_int(15), Int(1))
    print("VERSION ignores SIGTERM", flush=True)
    sleep(600.0)
"""


def _seconds_since(started_ns: Int) -> Float64:
    return Float64(perf_counter_ns() - started_ns) / 1e9


def _wait_for_exit(mut dodo: Child, seconds: Float64) raises -> ExitStatus:
    """Wait up to `seconds` for dodo to exit; fail if it does not."""
    var started = perf_counter_ns()
    var status = dodo.poll()
    while not status:
        if _seconds_since(started) > seconds:
            dodo.send_signal(9)
            _ = dodo.wait()
            raise Error("dodo still running after ", seconds, " s")
        sleep(0.01)
        status = dodo.poll()
    return status.value()


def test_dev_first_build_fails_then_a_fix_starts_it() raises:
    var dir = _dev_project("dev_first_fails", "def main(:\n")
    var dodo = _start_dev(dir, json=True)
    try:
        var out_path = join(dir, "dev.out")
        _wait_for_event(out_path, "build_failed", 1)
        assert_equal(len(_dev_events(out_path, "started")), 0)
        var url = _dev_events(out_path, "listening")[0]["url"].as_string()
        _save_version(dir, "v1")
        _wait_for_event(out_path, "started", 1)
        assert_false(_dev_events(out_path, "started")[0]["restart"].as_bool())
        _wait_for_body(url, '"v1"', out_path)

        # A new test file and a non-Mojo file change nothing the app is
        # built from, so nothing is built or restarted.
        makedirs(join(dir, "tests"), exist_ok=True)
        with open(join(dir, "tests", "test_more.mojo"), "w") as file:
            file.write("def main():\n    pass\n")
        with open(join(dir, "notes.md"), "w") as file:
            file.write("notes")
        sleep(1.0)
        assert_equal(len(_dev_events(out_path, "building")), 2)
        assert_equal(len(_dev_events(out_path, "started")), 1)

        # SIGTERM stops dodo the way Ctrl-C does.
        dodo.send_signal(15)
        var status = _wait_for_exit(dodo, 15.0)
        assert_equal(status.shell_code(), EXIT_INTERRUPTED)
        assert_equal(len(_dev_events(out_path, "stopped")), 1)
    except e:
        _ = _stop_dev(dodo)
        raise e^


def test_dev_ctrl_c_during_the_first_build() raises:
    var dir = _dev_project(
        "dev_ctrl_c_build", String(_DEV_APP).replace("VERSION", "v1")
    )
    var dodo = _start_dev(dir, json=True)
    var out_path = join(dir, "dev.out")
    _wait_for_event(out_path, "building", 1)
    sleep(0.2)
    var started = perf_counter_ns()
    dodo.send_signal(2)
    var status = _wait_for_exit(dodo, 5.0)
    assert_true(_seconds_since(started) < 2.0, "the build was not stopped")
    assert_equal(status.shell_code(), EXIT_INTERRUPTED)
    assert_equal(len(_dev_events(out_path, "started")), 0)
    assert_equal(len(_dev_events(out_path, "stopped")), 1)
    var left = run(
        ["pgrep", "-f", join(dir, "main.mojo")], stdout_path="/dev/null"
    )
    assert_false(left.succeeded(), "the build outlived dodo")


def test_dev_kills_an_app_that_ignores_sigterm() raises:
    var dir = _dev_project(
        "dev_stubborn", String(_STUBBORN_APP).replace("VERSION", "v1")
    )
    var dodo = _start_dev(dir, json=True)
    try:
        _dev_stubborn_steps(dir, dodo)
    except e:
        _ = _stop_dev(dodo)
        raise e^


def _wait_for_text(path: String, text: String) raises:
    """Wait up to 30 s until the file at `path` holds `text`."""
    var tries = 0
    while text not in read_or_empty(path):
        assert_true(
            tries < 3000, String("no `", text, "`:\n", read_or_empty(path))
        )
        sleep(0.01)
        tries += 1


def _dev_stubborn_steps(dir: String, mut dodo: Child) raises:
    var out_path = join(dir, "dev.out")
    _wait_for_event(out_path, "started", 1)
    _wait_for_text(out_path, "v1 ignores SIGTERM")
    var first_pid = _dev_events(out_path, "started")[0]["pid"].as_int()

    # A restart waits 10 s for the old app to stop, then kills it.
    _save_main(dir, String(_STUBBORN_APP).replace("VERSION", "v2"))
    _wait_for_event(out_path, "building", 2)
    _wait_for_event(out_path, "started", 2)
    var restart = _dev_events(out_path, "started")[1].copy()
    assert_true(restart["restart"].as_bool())
    var seconds = restart["seconds"].as_float()
    assert_true(seconds >= 10.0, String("killed after ", seconds, " s"))
    assert_true(seconds < 60.0, String("killed after ", seconds, " s"))
    assert_false(_is_running(String(first_pid)), "the old app still runs")

    # Two signals 0.1 s apart are one Ctrl-C (pixi passes it on too), so
    # dodo keeps waiting for the app to drain.
    var second_pid = _dev_events(out_path, "started")[1]["pid"].as_int()
    _wait_for_text(out_path, "v2 ignores SIGTERM")
    dodo.send_signal(2)
    sleep(0.1)
    dodo.send_signal(2)
    sleep(1.5)
    assert_false(Bool(dodo.poll()), "one Ctrl-C did not wait for the app")
    assert_true(_is_running(String(second_pid)))

    # A second Ctrl-C kills the app at once.
    var started = perf_counter_ns()
    dodo.send_signal(2)
    var status = _wait_for_exit(dodo, 5.0)
    assert_true(_seconds_since(started) < 1.0, "the second Ctrl-C waited")
    assert_equal(status.shell_code(), EXIT_INTERRUPTED)
    assert_false(_is_running(String(second_pid)), "the app outlived dodo")


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
