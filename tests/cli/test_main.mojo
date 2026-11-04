"""Tests for cli.main.run_cli: the exit code of each kind of command line."""

from std.testing import TestSuite, assert_equal

from cli.main import run_cli
from cli.report import EXIT_INTERNAL, EXIT_OK, EXIT_USAGE


def test_no_arguments_shows_help() raises:
    assert_equal(run_cli(List[String]()), EXIT_OK)


def test_help_command() raises:
    assert_equal(run_cli(["help"]), EXIT_OK)
    assert_equal(run_cli(["help", "docs", "pull"]), EXIT_OK)
    assert_equal(run_cli(["--help"]), EXIT_OK)


def test_help_for_unknown_command() raises:
    assert_equal(run_cli(["help", "serve"]), EXIT_USAGE)


def test_command_help() raises:
    assert_equal(run_cli(["routes", "--help"]), EXIT_OK)
    assert_equal(run_cli(["docs", "pull", "-h", "--json"]), EXIT_OK)


def test_version() raises:
    assert_equal(run_cli(["--version"]), EXIT_OK)
    assert_equal(run_cli(["--version", "--json"]), EXIT_OK)


def test_usage_errors() raises:
    assert_equal(run_cli(["serve"]), EXIT_USAGE)
    assert_equal(run_cli(["docs"]), EXIT_USAGE)
    assert_equal(run_cli(["doctor", "now", "--json"]), EXIT_USAGE)
    assert_equal(run_cli(["dev", "--port"]), EXIT_USAGE)


def test_unbuilt_command_is_internal() raises:
    assert_equal(run_cli(["doctor"]), EXIT_INTERNAL)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
