"""Tests for cli.args: every way a command line can be right or wrong."""

from std.testing import TestSuite, assert_equal, assert_false, assert_true

from cli.args import ParsedArgs, parse_args
from cli.commands import command_specs


def _parse(var words: List[String]) -> ParsedArgs:
    return parse_args(words, command_specs())


def test_no_words_is_no_command() raises:
    var parsed = _parse(List[String]())
    assert_equal(parsed.command, "")
    assert_equal(parsed.error, "")


def test_simple_command() raises:
    var parsed = _parse(["doctor"])
    assert_equal(parsed.command, "doctor")
    assert_equal(parsed.error, "")
    assert_false(parsed.json)


def test_two_word_command() raises:
    var parsed = _parse(["docs", "pull", "mojo@1.2"])
    assert_equal(parsed.command, "docs pull")
    assert_equal(len(parsed.positionals), 1)
    assert_equal(parsed.positionals[0], "mojo@1.2")


def test_group_without_subcommand() raises:
    var parsed = _parse(["docs"])
    assert_equal(parsed.command, "")
    assert_equal(parsed.error, "`docs` needs a subcommand: pull, search")


def test_group_with_unknown_subcommand() raises:
    var parsed = _parse(["docs", "push"])
    assert_equal(parsed.error, "`docs` needs a subcommand: pull, search")


def test_unknown_command() raises:
    var parsed = _parse(["serve"])
    assert_equal(parsed.error, "unknown command `serve`")


def test_unicode_command_is_unknown() raises:
    var parsed = _parse(["dévéloppe"])
    assert_equal(parsed.error, "unknown command `dévéloppe`")


def test_empty_word_is_unknown_command() raises:
    var parsed = _parse([""])
    assert_equal(parsed.error, "unknown command ``")


def test_json_anywhere() raises:
    var before = _parse(["--json", "doctor"])
    assert_equal(before.command, "doctor")
    assert_true(before.json)
    var after = _parse(["doctor", "--json"])
    assert_true(after.json)


def test_json_kept_on_parse_error() raises:
    var parsed = _parse(["routes", "--nope", "--json"])
    assert_true(parsed.json)
    assert_equal(parsed.error, "unknown flag --nope")


def test_json_after_double_dash_is_passed_on() raises:
    var parsed = _parse(["run", "app.mojo", "--", "--json"])
    assert_false(parsed.json)
    assert_equal(len(parsed.passthrough), 1)
    assert_equal(parsed.passthrough[0], "--json")


def test_help_flags() raises:
    assert_true(_parse(["--help"]).help)
    assert_true(_parse(["-h"]).help)
    var parsed = _parse(["test", "--help"])
    assert_equal(parsed.command, "test")
    assert_true(parsed.help)


def test_help_skips_argument_count() raises:
    var parsed = _parse(["doctor", "extra", "--help"])
    assert_equal(parsed.error, "")
    assert_true(parsed.help)


def test_version_flags() raises:
    assert_true(_parse(["--version"]).version)
    assert_true(_parse(["-V"]).version)


def test_global_flags_before_two_word_command() raises:
    var parsed = _parse(["--json", "-h", "docs", "pull"])
    assert_equal(parsed.command, "docs pull")
    assert_true(parsed.json)
    assert_true(parsed.help)


def test_global_flags_alone() raises:
    var parsed = _parse(["--json", "--version"])
    assert_equal(parsed.command, "")
    assert_equal(parsed.error, "")
    assert_true(parsed.version)


def test_unknown_command_after_global_flag() raises:
    var parsed = _parse(["--json", "serve"])
    assert_equal(parsed.error, "unknown command `serve`")


def test_flag_with_separate_value() raises:
    var parsed = _parse(["dev", "--port", "9000"])
    assert_equal(parsed.value("port"), "9000")
    assert_true(parsed.given("port"))


def test_flag_with_inline_value() raises:
    var parsed = _parse(["dev", "--port=9000"])
    assert_equal(parsed.value("port"), "9000")


def test_flag_with_empty_inline_value() raises:
    var parsed = _parse(["dev", "--host="])
    assert_equal(parsed.error, "")
    assert_true(parsed.given("host"))
    assert_equal(parsed.value("host", "x"), "")


def test_inline_value_keeps_later_equals() raises:
    var parsed = _parse(["test", "--only=a=b"])
    assert_equal(parsed.value("only"), "a=b")


def test_flag_default_when_missing() raises:
    var parsed = _parse(["dev"])
    assert_false(parsed.given("port"))
    assert_equal(parsed.value("port", "8000"), "8000")


def test_flag_missing_value_at_end() raises:
    var parsed = _parse(["dev", "--port"])
    assert_equal(parsed.error, "--port needs a value: --port PORT")


def test_flag_value_cannot_be_another_flag() raises:
    var parsed = _parse(["dev", "--port", "--host", "x"])
    assert_equal(parsed.error, "--port needs a value: --port PORT")


def test_flag_value_may_start_with_one_dash() raises:
    var parsed = _parse(["test", "--only", "-x"])
    assert_equal(parsed.error, "")
    assert_equal(parsed.value("only"), "-x")


def test_flag_given_twice() raises:
    var parsed = _parse(["dev", "--port", "1", "--port", "2"])
    assert_equal(parsed.error, "--port is given twice")


def test_switch() raises:
    var parsed = _parse(["new", "app", "--no-git"])
    assert_true(parsed.has("no-git"))
    assert_equal(parsed.positionals[0], "app")


def test_switch_given_twice() raises:
    var parsed = _parse(["new", "app", "--no-git", "--no-git"])
    assert_equal(parsed.error, "--no-git is given twice")


def test_switch_with_value() raises:
    var parsed = _parse(["new", "app", "--no-git=yes"])
    assert_equal(parsed.error, "--no-git takes no value")


def test_unknown_long_flag() raises:
    var parsed = _parse(["doctor", "--fix"])
    assert_equal(parsed.error, "unknown flag --fix")


def test_flag_of_another_command() raises:
    var parsed = _parse(["doctor", "--port", "1"])
    assert_equal(parsed.error, "unknown flag --port")


def test_unknown_flag_before_command() raises:
    var parsed = _parse(["--port", "1", "dev"])
    assert_equal(parsed.error, "unknown flag --port")


def test_short_flag_rejected() raises:
    var parsed = _parse(["test", "-v"])
    assert_equal(
        parsed.error, "unknown flag -v (dodo uses long flags such as --json)"
    )


def test_single_dash_is_positional() raises:
    var parsed = _parse(["run", "-"])
    assert_equal(parsed.error, "")
    assert_equal(parsed.positionals[0], "-")


def test_too_many_for_no_argument_command() raises:
    var parsed = _parse(["doctor", "now"])
    assert_equal(parsed.error, "takes no arguments (got `now`)")


def test_too_many_for_one_argument_command() raises:
    var parsed = _parse(["new", "a", "b"])
    assert_equal(parsed.error, "takes at most 1 argument(s) (got `b` too)")


def test_any_number_of_paths() raises:
    var parsed = _parse(["test", "a", "b", "c", "d"])
    assert_equal(parsed.error, "")
    assert_equal(len(parsed.positionals), 4)


def test_double_dash_passes_everything_on() raises:
    var parsed = _parse(["run", "app.mojo", "--", "--port", "1", "x"])
    assert_equal(parsed.error, "")
    assert_equal(parsed.positionals[0], "app.mojo")
    assert_equal(len(parsed.passthrough), 3)
    assert_equal(parsed.passthrough[0], "--port")


def test_double_dash_with_nothing_after() raises:
    var parsed = _parse(["run", "--"])
    assert_equal(parsed.error, "")
    assert_equal(len(parsed.passthrough), 0)


def test_double_dash_not_allowed() raises:
    var parsed = _parse(["doctor", "--", "x"])
    assert_equal(
        parsed.error, "unexpected `--`: this command passes nothing on"
    )


def test_double_dash_without_command() raises:
    var parsed = _parse(["--", "x"])
    assert_equal(
        parsed.error, "unexpected `--`: this command passes nothing on"
    )


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
