"""Tests for cli.report: the JSON object scripts read, and the exit codes."""

from std.testing import TestSuite, assert_equal, assert_false, assert_true

from dodo.json import Value, loads

from cli.report import (
    EXIT_BUILD_FAILED,
    EXIT_FAILED,
    EXIT_INTERNAL,
    EXIT_OK,
    EXIT_UNAVAILABLE,
    EXIT_USAGE,
    Report,
)


def test_exit_codes_are_stable() raises:
    assert_equal(EXIT_OK, 0)
    assert_equal(EXIT_FAILED, 1)
    assert_equal(EXIT_BUILD_FAILED, 2)
    assert_equal(EXIT_USAGE, 64)
    assert_equal(EXIT_UNAVAILABLE, 69)
    assert_equal(EXIT_INTERNAL, 70)


def test_ok_report() raises:
    var report = Report("routes", True)
    var out = loads(report.to_json(EXIT_OK))
    assert_true(out["ok"].as_bool())
    assert_equal(out["command"].as_string(), "routes")
    assert_equal(out["exit_code"].as_int(), 0)
    assert_false("error" in out)


def test_fields_are_copied_in() raises:
    var report = Report("doctor", True)
    report.set("checks", Value(3))
    report.set("name", Value(String("dodo")))
    var out = loads(report.to_json(EXIT_OK))
    assert_equal(out["checks"].as_int(), 3)
    assert_equal(out["name"].as_string(), "dodo")


def test_fail_returns_its_code() raises:
    var report = Report("test", True)
    var code = report.fail("tests", "2 tests failed", EXIT_FAILED)
    assert_equal(code, EXIT_FAILED)
    assert_true(report.failed())


def test_error_object() raises:
    var report = Report("docs pull", True)
    var code = report.fail(
        "usage", "bad version `abc`", EXIT_USAGE, hint="use mojo@1.2"
    )
    var out = loads(report.to_json(code))
    assert_false(out["ok"].as_bool())
    assert_equal(out["exit_code"].as_int(), 64)
    var error = out["error"]
    assert_equal(error["kind"].as_string(), "usage")
    assert_equal(error["message"].as_string(), "bad version `abc`")
    assert_equal(error["hint"].as_string(), "use mojo@1.2")


def test_error_without_hint_has_no_hint_key() raises:
    var report = Report("doctor", True)
    var code = report.fail("internal", "oops", EXIT_INTERNAL)
    var out = loads(report.to_json(code))
    assert_false("hint" in out["error"])


def test_nonzero_exit_is_not_ok() raises:
    var report = Report("run", True)
    var out = loads(report.to_json(3))
    assert_false(out["ok"].as_bool())
    assert_equal(out["exit_code"].as_int(), 3)


def test_message_with_quotes_and_unicode() raises:
    var report = Report("new", True)
    var message = String('name "ünï\\cødé" is taken\n')
    var code = report.fail("exists", message, EXIT_FAILED)
    var out = loads(report.to_json(code))
    assert_equal(out["error"]["message"].as_string(), message)


def test_finish_returns_code_unchanged() raises:
    var report = Report("doctor", True)
    assert_equal(report.finish(EXIT_UNAVAILABLE), EXIT_UNAVAILABLE)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
