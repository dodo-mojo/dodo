"""Tests for cli.help and cli.commands: help is built from the specs."""

from std.testing import TestSuite, assert_equal, assert_false, assert_true

from cli.commands import command_specs, find_spec
from cli.help import command_help, exit_codes, overview
from cli.version import DODO_VERSION


def test_every_command_is_in_overview() raises:
    var specs = command_specs()
    var text = overview(specs)
    for spec in specs:
        assert_true(spec.name in text, String("missing: ", spec.name))
    assert_true(DODO_VERSION in text)


def test_overview_lists_exit_codes() raises:
    var text = overview(command_specs())
    assert_true(exit_codes() in text)


def test_command_help_names_flags() raises:
    var specs = command_specs()
    var text = command_help(specs[find_spec(specs, "dev")])
    assert_true("Usage: dodo dev [FILE] [-- ARGS...] [--json]" in text)
    assert_true("--port PORT" in text)
    assert_true("--host HOST" in text)


def test_command_help_without_flags() raises:
    var specs = command_specs()
    var text = command_help(specs[find_spec(specs, "doctor")])
    assert_true("Usage: dodo doctor [--json]" in text)
    assert_false("Flags:" in text)


def test_switch_shows_without_placeholder() raises:
    var specs = command_specs()
    var text = command_help(specs[find_spec(specs, "new")])
    assert_true("--no-git  " in text)


def test_find_spec() raises:
    var specs = command_specs()
    assert_true(find_spec(specs, "docs pull") >= 0)
    assert_equal(find_spec(specs, "docs"), -1)
    assert_equal(find_spec(specs, ""), -1)


def test_command_names_are_unique() raises:
    var specs = command_specs()
    for i in range(len(specs)):
        for j in range(i + 1, len(specs)):
            assert_true(specs[i].name != specs[j].name)


def test_flag_names_are_unique_and_not_reserved() raises:
    for spec in command_specs():
        for i in range(len(spec.flags)):
            var name = spec.flags[i].name
            assert_true(name != "json" and name != "help" and name != "version")
            for j in range(i + 1, len(spec.flags)):
                assert_true(name != spec.flags[j].name)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
