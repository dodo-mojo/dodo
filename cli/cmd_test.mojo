"""`dodo test [PATH...]`: build and run every `test_*.mojo` file.

Each file is a `TestSuite` program. dodo builds each one into its own
binary in `.dodo/build/tests/`, several at a time, and skips files whose
build is still current. Then it runs them one by one from the project
root, each in a process group of its own, so a test that hangs is stopped
after `--timeout` and programs a test leaves running are killed.

A file ends as one of: passed, failed (a test failed), crashed (killed by
a signal), timed_out, no_report (exited without a `TestSuite` report) or
build_failed. Exit code: 0 when every file passed, 2 when any build
failed, 1 otherwise.
"""

from std.os import chdir
from std.os.path import dirname, isdir, isfile, join, realpath
from std.time import perf_counter_ns, sleep

from dodo.json import Value
from dodo.runtime._thread import num_cpus
from dodo.utils.process import Child, ExitStatus, spawn
from dodo.utils.signals import stop_watching_signals, take_signal, watch_signals

from .args import ParsedArgs
from .build import BuildPlan, finish_build, start_build
from .cmd_routes import parse_timeout
from .files import (
    is_test_file,
    mojo_files,
    read_text,
    remove_if_there,
    tail_text,
)
from .project import find_root
from .report import (
    EXIT_BUILD_FAILED,
    EXIT_FAILED,
    EXIT_INTERRUPTED,
    EXIT_OK,
    EXIT_UNAVAILABLE,
    EXIT_USAGE,
    Report,
    format_seconds,
)
from .suite import TestCase, parse_suite_output

comptime _MAX_JOBS = 64
comptime _MAX_DETAIL_BYTES = 8 * 1024
"""How much of a crashed or silent file's output the report keeps."""
comptime _LABEL_WIDTH = 8
comptime _POLL_SECONDS = 0.005


struct FileResult(Copyable, Movable):
    """How one test file did."""

    var path: String
    var shown: String
    """`path` relative to the project root, for the report."""
    var outcome: String
    var built: Bool
    var build_seconds: Float64
    var seconds: Float64
    var tests: List[TestCase]
    var detail: String
    """The build log, or the end of the output when there is no report."""
    var exit: String
    """How the binary ended, such as "exit code 3"."""
    var killed_leftovers: Bool
    """Programs the tests started were still running and were killed."""

    def __init__(out self, path: String, shown: String):
        self.path = path
        self.shown = shown
        self.outcome = ""
        self.built = False
        self.build_seconds = 0.0
        self.seconds = 0.0
        self.tests = List[TestCase]()
        self.detail = ""
        self.exit = ""
        self.killed_leftovers = False


struct _Running(Movable):
    """A build or a test binary that has not ended yet."""

    var index: Int
    var child: Child
    var started_ns: Int

    def __init__(out self, index: Int, var child: Child):
        self.index = index
        self.child = child^
        self.started_ns = perf_counter_ns()

    def seconds(self) -> Float64:
        return Float64(perf_counter_ns() - self.started_ns) / 1e9


def cmd_test(parsed: ParsedArgs, mut report: Report) raises -> Int:
    var jobs: Int
    var timeout: Float64
    try:
        jobs = default_jobs()
        if parsed.given("jobs"):
            jobs = parse_jobs(parsed.value("jobs"))
        timeout = parse_timeout(parsed.value("timeout", "600"))
    except e:
        return report.fail("usage", String(e), EXIT_USAGE)
    var only = parsed.value("only", "")
    if parsed.given("only") and only == "":
        return report.fail("usage", "--only needs a test name", EXIT_USAGE)

    var root = find_root(".")
    var files: List[String]
    try:
        files = find_test_files(root, parsed.positionals)
    except e:
        return report.fail("not_found", String(e), EXIT_USAGE)
    if only != "":
        files = _defining(files, only)
    if len(files) == 0:
        var message = String("no test_*.mojo files to run")
        if only != "":
            message = String("no test file defines `", only, "`")
        return report.fail(
            "no_tests",
            message,
            EXIT_FAILED,
            hint="a test file is tests/test_<name>.mojo with a TestSuite main",
        )

    var results = List[FileResult]()
    for path in files:
        results.append(FileResult(path, _relative(root, path)))

    # Tests run from the project root, as they would under `pixi run`.
    chdir(root)
    watch_signals()
    var code: Int
    try:
        code = _build_and_run(root, results, jobs, timeout, only, report)
    except e:
        stop_watching_signals()
        raise e^
    stop_watching_signals()
    return code


def _build_and_run(
    root: String,
    mut results: List[FileResult],
    jobs: Int,
    timeout: Float64,
    only: String,
    mut report: Report,
) raises -> Int:
    var started = perf_counter_ns()
    var plans = List[BuildPlan]()
    var out_dir = join(root, ".dodo", "build", "tests")
    for result in results:
        plans.append(BuildPlan(root, result.path, out_dir))

    var stopped = _build_all(root, plans, results, jobs, report)
    if stopped == EXIT_UNAVAILABLE:
        return report.fail(
            "mojo_missing",
            "cannot start mojo",
            EXIT_UNAVAILABLE,
            hint="run dodo inside the project's environment: pixi run dodo ...",
        )
    if stopped == EXIT_INTERRUPTED:
        return report.fail(
            "interrupted", "stopped while building", EXIT_INTERRUPTED
        )

    for i in range(len(results)):
        if results[i].outcome != "build_failed":
            var interrupted = _run_file(
                plans[i].binary, only, timeout, results[i]
            )
            if interrupted:
                report.say(format_file(results[i]))
                return report.fail(
                    "interrupted",
                    String("stopped while running ", results[i].shown),
                    EXIT_INTERRUPTED,
                )
        report.say(format_file(results[i]))

    var seconds = Float64(perf_counter_ns() - started) / 1e9
    report.say(format_summary(results, seconds))
    _record(results, seconds, report)
    return _verdict(results, report)


def _build_all(
    root: String,
    plans: List[BuildPlan],
    mut results: List[FileResult],
    jobs: Int,
    report: Report,
) raises -> Int:
    """Build every file whose build is not current, `jobs` at a time.
    Returns `EXIT_OK`, `EXIT_UNAVAILABLE` (no `mojo`) or `EXIT_INTERRUPTED`."""
    var needed = 0
    for plan in plans:
        if not plan.up_to_date:
            needed += 1
    if needed == 0:
        return EXIT_OK
    report.note(
        String(
            "building ",
            needed,
            " test file(s), ",
            min(jobs, needed),
            " at a time ...",
        )
    )

    var running = List[_Running]()
    var next = 0
    while next < len(plans) or len(running) > 0:
        if take_signal() != 0:
            _kill_all(running)
            return EXIT_INTERRUPTED
        while next < len(plans) and len(running) < jobs:
            if not plans[next].up_to_date:
                var includes: List[String] = [root, dirname(plans[next].entry)]
                var child: Child
                try:
                    child = start_build(plans[next], includes, new_group=True)
                except:
                    _kill_all(running)
                    return EXIT_UNAVAILABLE
                running.append(_Running(next, child^))
            next += 1
        var i = 0
        while i < len(running):
            var status = running[i].child.poll()
            if not status:
                i += 1
                continue
            var done = running.pop(i)
            var build = finish_build(
                plans[done.index], status.value(), done.seconds()
            )
            results[done.index].built = True
            results[done.index].build_seconds = build.seconds
            if not build.ok():
                results[done.index].outcome = "build_failed"
                results[done.index].detail = build.log
                results[done.index].exit = "mojo build failed"
        sleep(_POLL_SECONDS)
    return EXIT_OK


def _run_file(
    binary: String, only: String, timeout: Float64, mut result: FileResult
) raises -> Bool:
    """Run one test binary and fill in `result`. Returns True when a signal
    to dodo stopped it."""
    var out_path = binary + ".out"
    var argv: List[String] = [binary]
    if only != "":
        argv.append("--only")
        argv.append(only)
    var running = _Running(
        0, spawn(argv, stdout_path=out_path, stderr_path="&1", new_group=True)
    )
    var deadline = perf_counter_ns() + Int(timeout * 1e9)
    var interrupted = False
    var timed_out = False
    var status = running.child.poll()
    while not status:
        if take_signal() != 0:
            interrupted = True
            break
        if perf_counter_ns() > deadline:
            timed_out = True
            break
        sleep(_POLL_SECONDS)
        status = running.child.poll()
    var exit: ExitStatus
    if status:
        exit = status.value()
    else:
        _ = running.child.kill_group()
        exit = running.child.wait()
    result.killed_leftovers = running.child.kill_group()
    result.seconds = running.seconds()
    result.exit = String(exit)

    var output = read_text(out_path)
    remove_if_there(out_path)
    var suite = parse_suite_output(output)
    for test in suite.tests:
        # With --only, TestSuite marks every other test as skipped.
        if only != "" and test.name != only:
            continue
        result.tests.append(test.copy())

    if interrupted:
        result.outcome = "interrupted"
    elif timed_out:
        result.outcome = "timed_out"
        result.exit = String("still running after ", format_seconds(timeout))
    elif exit.signal != 0:
        result.outcome = "crashed"
    elif exit.code == 0 and suite.finished:
        result.outcome = "passed"
    elif suite.count("fail") > 0:
        result.outcome = "failed"
    else:
        result.outcome = "no_report"
    if result.outcome != "passed" and result.outcome != "failed":
        result.detail = tail_text(output, _MAX_DETAIL_BYTES)
    return interrupted


def _kill_all(mut running: List[_Running]) raises:
    for i in range(len(running)):
        _ = running[i].child.kill_group()
        _ = running[i].child.wait()


def default_jobs() -> Int:
    """The number of cores, at most 4: each build takes several GB."""
    return max(1, min(num_cpus(), 4))


def parse_jobs(text: String) raises -> Int:
    """`--jobs`: a whole number from 1 to 64."""
    var jobs: Int
    try:
        jobs = Int(text)
    except:
        raise Error("--jobs must be a whole number, got `", text, "`")
    if jobs < 1 or jobs > _MAX_JOBS:
        raise Error(
            "--jobs must be from 1 to ", _MAX_JOBS, ", got `", text, "`"
        )
    return jobs


def find_test_files(root: String, given: List[String]) raises -> List[String]:
    """The test files to run, sorted: every `test_*.mojo` under each given
    folder, and each given file. With nothing given, the `tests` folder.

    Raises:
        Error: If a given path does not exist or is not a `.mojo` file.
    """
    var paths = List[String]()
    for path in given:
        paths.append(path)
    if len(paths) == 0:
        var tests = join(root, "tests")
        if not isdir(tests):
            return List[String]()
        paths.append(tests)

    var found = List[String]()
    for path in paths:
        if isdir(path):
            for file in mojo_files(realpath(path)):
                if is_test_file(file):
                    _add_once(found, file)
        elif isfile(path):
            if not path.endswith(".mojo"):
                raise Error("`", path, "` is not a .mojo file")
            _add_once(found, realpath(path))
        else:
            raise Error("no file or folder `", path, "`")
    sort(found)
    return found^


def _add_once(mut found: List[String], path: String):
    for existing in found:
        if existing == path:
            return
    found.append(path)


def _defining(files: List[String], name: String) raises -> List[String]:
    """The files with a `def <name>(` in them."""
    var wanted = String("def ", name, "(")
    var kept = List[String]()
    for path in files:
        var source = read_text(path)
        for line in source.splitlines():
            if String(line.strip()).startswith(wanted):
                kept.append(path)
                break
    return kept^


def format_file(result: FileResult) -> String:
    """One line for a file, then the failures under it."""
    var label = _label(result.outcome)
    var line = String(label)
    while line.byte_length() < _LABEL_WIDTH:
        line += " "
    line += String(result.shown, "  ", _file_summary(result))
    if result.killed_leftovers:
        line += "\n        warning: killed programs the tests left running"
    for test in result.tests:
        if test.outcome == "fail":
            line += String("\n        ", test.name)
            for message_line in test.message.splitlines():
                line += String("\n          ", message_line)
    if result.detail != "":
        for detail_line in result.detail.strip().splitlines():
            line += String("\n        ", detail_line)
    return line^


def _label(outcome: String) -> String:
    if outcome == "passed":
        return "PASS"
    if outcome == "failed":
        return "FAIL"
    if outcome == "crashed":
        return "CRASH"
    if outcome == "timed_out":
        return "TIMEOUT"
    if outcome == "build_failed":
        return "BUILD"
    if outcome == "interrupted":
        return "STOPPED"
    return "ERROR"


def _file_summary(result: FileResult) -> String:
    var count = len(result.tests)
    if result.outcome == "build_failed":
        return result.exit
    if result.outcome == "passed":
        return String(_tests(count), ", ", format_seconds(result.seconds))
    if result.outcome == "failed":
        var failed = 0
        for test in result.tests:
            if test.outcome == "fail":
                failed += 1
        return String(failed, " of ", _tests(count), " failed")
    if result.outcome == "no_report":
        return String(result.exit, " without a test report")
    return result.exit


def _tests(count: Int) -> String:
    if count == 1:
        return "1 test"
    return String(count, " tests")


def format_summary(results: List[FileResult], seconds: Float64) -> String:
    """`7 passed, 1 failed, 0 skipped; 3 file(s), 1 built; 4.20 s`."""
    var passed = 0
    var failed = 0
    var skipped = 0
    var built = 0
    var bad_files = 0
    for result in results:
        if result.built:
            built += 1
        if result.outcome != "passed":
            bad_files += 1
        for test in result.tests:
            if test.outcome == "pass":
                passed += 1
            elif test.outcome == "fail":
                failed += 1
            else:
                skipped += 1
    var text = String(
        passed, " passed, ", failed, " failed, ", skipped, " skipped; "
    )
    text += String(len(results), " file(s), ", built, " built")
    if bad_files > 0:
        text += String(", ", bad_files, " not passing")
    text += String("; ", format_seconds(seconds))
    return text^


def _record(
    results: List[FileResult], seconds: Float64, mut report: Report
) raises:
    var files = Value.array()
    var passed = 0
    var failed = 0
    var skipped = 0
    for result in results:
        var entry = Value.object()
        entry["path"] = Value(result.shown)
        entry["outcome"] = Value(result.outcome)
        entry["built"] = Value(result.built)
        entry["build_seconds"] = Value(result.build_seconds)
        entry["seconds"] = Value(result.seconds)
        entry["exit"] = Value(result.exit)
        entry["killed_leftovers"] = Value(result.killed_leftovers)
        var tests = Value.array()
        for test in result.tests:
            var one = Value.object()
            one["name"] = Value(test.name)
            one["outcome"] = Value(test.outcome)
            one["ms"] = Value(test.ms)
            if test.message != "":
                one["message"] = Value(test.message)
            tests.append(one^)
            if test.outcome == "pass":
                passed += 1
            elif test.outcome == "fail":
                failed += 1
            else:
                skipped += 1
        entry["tests"] = tests^
        if result.detail != "":
            entry["detail"] = Value(result.detail)
        files.append(entry^)
    report.set("files", files^)
    report.set("passed", Value(passed))
    report.set("failed", Value(failed))
    report.set("skipped", Value(skipped))
    report.set("seconds", Value(seconds))


def _verdict(results: List[FileResult], mut report: Report) -> Int:
    var build_failures = 0
    var not_passing = 0
    for result in results:
        if result.outcome == "build_failed":
            build_failures += 1
        elif result.outcome != "passed":
            not_passing += 1
    if build_failures > 0:
        return report.fail(
            "build",
            String(build_failures, " test file(s) did not build"),
            EXIT_BUILD_FAILED,
        )
    if not_passing > 0:
        return report.fail(
            "tests_failed",
            String(not_passing, " test file(s) did not pass"),
            EXIT_FAILED,
        )
    return EXIT_OK


def _relative(root: String, path: String) -> String:
    var prefix = root + "/"
    if path.startswith(prefix):
        return String(path[byte = prefix.byte_length() :])
    return path
