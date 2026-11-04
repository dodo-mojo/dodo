"""Tests for the pieces of `dodo test`: reading TestSuite output, finding
test files, what a test build depends on, and the report text."""

from std.os import getenv, makedirs
from std.os.path import join, realpath
from std.testing import (
    TestSuite,
    assert_equal,
    assert_false,
    assert_raises,
    assert_true,
)

from cli.cmd_test import (
    FileResult,
    default_jobs,
    find_test_files,
    format_file,
    format_summary,
    parse_jobs,
)
from cli.files import build_inputs, imports_a_test_file, is_test_file
from cli.report import format_seconds
from cli.suite import TestCase, parse_suite_output
from dodo.utils.process import run


def _scratch(name: String) raises -> String:
    var dir = join(getenv("TMPDIR", "/tmp"), String("dodo_runner_", name))
    _ = run(["rm", "-rf", dir])
    makedirs(dir, exist_ok=True)
    return realpath(dir)


def _touch(path: String, text: String = "") raises:
    with open(path, "w") as file:
        file.write(text)


# ── TestSuite output ──

comptime _FAILED_RUN = """Unhandled exception caught during execution:
Running 3 tests for /p/test_x.mojo
    PASS [ 0.001 ] test_ok
    FAIL [ 0.051 ] test_bad
      At /p/test_x.mojo:7:17: AssertionError: failed:
         left: 1
        right: 2
    FAIL [ 0.002 ] test_raises
      boom
    SKIP [ 0.001 ] test_later
--------
Summary [ 0.053 ] 4 tests run: 1 passed , 2 failed , 1 skipped
Test suite' /p/test_x.mojo 'failed!
"""


def test_parse_failed_run() raises:
    var suite = parse_suite_output(_FAILED_RUN)
    assert_true(suite.finished)
    assert_equal(len(suite.tests), 4)
    assert_equal(suite.tests[0].name, "test_ok")
    assert_equal(suite.tests[0].outcome, "pass")
    assert_equal(suite.tests[0].ms, 0.001)
    assert_equal(suite.tests[0].message, "")
    assert_equal(suite.tests[1].outcome, "fail")
    assert_equal(
        suite.tests[1].message,
        (
            "At /p/test_x.mojo:7:17: AssertionError: failed:\n   left: 1\n "
            " right: 2"
        ),
    )
    assert_equal(suite.tests[2].message, "boom")
    assert_equal(suite.tests[3].outcome, "skip")
    assert_equal(suite.count("fail"), 2)


def test_parse_ignores_printed_lines() raises:
    var text = String(
        "hello from a test\n",
        "    not a result line\n",
        "    PASS [ 1.5 ] test_a\n",
        "      indented print after a pass\n",
        "    PASS [ abc ] test_bad_time\n",
        "    PASS [ 1.0 ] \n",
        "Summary [ 1.5 ] 1 tests run\n",
    )
    var suite = parse_suite_output(text)
    assert_equal(len(suite.tests), 1)
    assert_equal(suite.tests[0].message, "")
    assert_true(suite.finished)


def test_parse_cut_off_run() raises:
    var suite = parse_suite_output("Running 2 tests\n    PASS [ 0.1 ] test_a\n")
    assert_false(suite.finished)
    assert_equal(len(suite.tests), 1)
    var empty = parse_suite_output("")
    assert_false(empty.finished)
    assert_equal(len(empty.tests), 0)


# ── which files ──


def test_is_test_file() raises:
    assert_true(is_test_file("tests/test_a.mojo"))
    assert_true(is_test_file("test_a.mojo"))
    assert_false(is_test_file("tests/helpers.mojo"))
    assert_false(is_test_file("tests/test_a.py"))
    assert_false(is_test_file("test_dir/a.mojo"))
    assert_false(is_test_file("tests/mytest_a.mojo"))


def test_imports_a_test_file() raises:
    assert_true(imports_a_test_file("from test_helpers import x\n"))
    assert_true(imports_a_test_file("  import tests.test_util\n"))
    assert_false(imports_a_test_file("from std.testing import TestSuite\n"))
    assert_false(imports_a_test_file("# from test_x import y is old\n"))
    assert_false(imports_a_test_file("var test_x = 1\n"))
    assert_false(imports_a_test_file(""))


def test_build_inputs_leave_out_other_tests() raises:
    var dir = _scratch("inputs")
    makedirs(join(dir, "tests"), exist_ok=True)
    var a = join(dir, "tests", "test_a.mojo")
    var b = join(dir, "tests", "test_b.mojo")
    var helper = join(dir, "tests", "helpers.mojo")
    _touch(a, "from helpers import x\n")
    _touch(b, "from test_a import y\n")
    _touch(helper)
    _touch(join(dir, "main.mojo"))

    var for_a = build_inputs(dir, a)
    assert_equal(len(for_a), 3)
    assert_false(b in for_a)
    assert_true(a in for_a)
    assert_true(helper in for_a)
    # b imports a test file, so every file is an input.
    assert_equal(len(build_inputs(dir, b)), 4)


def test_find_test_files() raises:
    var dir = _scratch("find")
    makedirs(join(dir, "tests", "deep"), exist_ok=True)
    _touch(join(dir, "tests", "test_b.mojo"))
    _touch(join(dir, "tests", "deep", "test_a.mojo"))
    _touch(join(dir, "tests", "helpers.mojo"))
    _touch(join(dir, "check.mojo"))
    _touch(join(dir, "notes.md"))

    var all = find_test_files(dir, List[String]())
    assert_equal(len(all), 2)
    assert_equal(all[0], join(dir, "tests", "deep", "test_a.mojo"))

    # A file named on the command line runs even without the test_ prefix,
    # and naming a file twice runs it once.
    var given: List[String] = [
        join(dir, "check.mojo"),
        join(dir, "tests"),
        join(dir, "tests", "test_b.mojo"),
    ]
    assert_equal(len(find_test_files(dir, given)), 3)

    with assert_raises(contains="is not a .mojo file"):
        _ = find_test_files(dir, [join(dir, "notes.md")])
    with assert_raises(contains="no file or folder"):
        _ = find_test_files(dir, [join(dir, "missing")])


def test_find_without_tests_folder() raises:
    var dir = _scratch("no_tests")
    assert_equal(len(find_test_files(dir, List[String]())), 0)


# ── flags ──


def test_parse_jobs() raises:
    assert_equal(parse_jobs("1"), 1)
    assert_equal(parse_jobs("64"), 64)
    for bad in ["0", "65", "-1", "two", "1.5", ""]:
        with assert_raises(contains="--jobs"):
            _ = parse_jobs(bad)
    var default = default_jobs()
    assert_true(default >= 1 and default <= 4)


# ── report text ──


def test_format_seconds() raises:
    assert_equal(format_seconds(0.0), "0.00 s")
    assert_equal(format_seconds(0.004), "0.00 s")
    assert_equal(format_seconds(0.005), "0.01 s")
    assert_equal(format_seconds(1.234), "1.23 s")
    assert_equal(format_seconds(12.5), "12.50 s")


def test_format_file() raises:
    var passed = FileResult("/p/tests/test_a.mojo", "tests/test_a.mojo")
    passed.outcome = "passed"
    passed.seconds = 0.5
    passed.tests.append(TestCase("test_x", "pass", 1.0, ""))
    assert_equal(
        format_file(passed), "PASS    tests/test_a.mojo  1 test, 0.50 s"
    )

    var failed = FileResult("/p/tests/test_b.mojo", "tests/test_b.mojo")
    failed.outcome = "failed"
    failed.tests.append(TestCase("test_x", "pass", 1.0, ""))
    failed.tests.append(TestCase("test_y", "fail", 1.0, "line one\nline two"))
    assert_equal(
        format_file(failed),
        String(
            "FAIL    tests/test_b.mojo  1 of 2 tests failed\n",
            "        test_y\n",
            "          line one\n",
            "          line two",
        ),
    )

    var crashed = FileResult("/p/t.mojo", "t.mojo")
    crashed.outcome = "crashed"
    crashed.exit = "killed by signal 11"
    crashed.detail = "last words\n"
    crashed.killed_leftovers = True
    assert_equal(
        format_file(crashed),
        String(
            "CRASH   t.mojo  killed by signal 11\n",
            "        warning: killed programs the tests left running\n",
            "        last words",
        ),
    )


def test_format_summary() raises:
    var results = List[FileResult]()
    var a = FileResult("/p/a", "a")
    a.outcome = "passed"
    a.built = True
    a.tests.append(TestCase("t1", "pass", 1.0, ""))
    a.tests.append(TestCase("t2", "skip", 1.0, ""))
    results.append(a^)
    var b = FileResult("/p/b", "b")
    b.outcome = "build_failed"
    results.append(b^)
    assert_equal(
        format_summary(results, 1.5),
        (
            "1 passed, 0 failed, 1 skipped; 2 file(s), 1 built, 1 not passing;"
            " 1.50 s"
        ),
    )


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
