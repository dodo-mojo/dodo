"""The `dodo` command line. Build with `pixi run cli-build`."""

from std.sys import argv, exit

from dodo.json import Value

from cli.args import ParsedArgs, parse_args
from cli.commands import command_specs, find_spec
from cli.help import command_help, overview
from cli.report import EXIT_INTERNAL, EXIT_OK, EXIT_USAGE, Report
from cli.version import DODO_VERSION


def main():
    var words = List[String]()
    var all_words = argv()
    for i in range(1, len(all_words)):
        words.append(String(all_words[i]))
    exit(run_cli(words))


def run_cli(words: List[String]) -> Int:
    """Run one command line and return its exit code."""
    var specs = command_specs()
    var parsed = parse_args(words, specs)
    var report = Report(parsed.command, parsed.json)

    if parsed.error != "":
        var hint = String("run `dodo --help`")
        if parsed.command != "":
            hint = String("run `dodo ", parsed.command, " --help`")
        var code = report.fail("usage", parsed.error, EXIT_USAGE, hint=hint)
        return report.finish(code)

    if parsed.version and parsed.command == "":
        return _version(report)

    if parsed.command == "" or parsed.command == "help":
        return _help(parsed, report)

    if parsed.help:
        report.say(command_help(specs[find_spec(specs, parsed.command)]))
        return report.finish(EXIT_OK)

    try:
        return report.finish(_dispatch(parsed, report))
    except e:
        var code = report.fail("internal", String(e), EXIT_INTERNAL)
        return report.finish(code)


def _dispatch(parsed: ParsedArgs, mut report: Report) raises -> Int:
    return report.fail("internal", "not built yet", EXIT_INTERNAL)


def _version(mut report: Report) -> Int:
    report.say(String("dodo ", DODO_VERSION))
    try:
        report.set("version", Value(String(DODO_VERSION)))
    except:
        pass
    return report.finish(EXIT_OK)


def _help(parsed: ParsedArgs, mut report: Report) -> Int:
    var specs = command_specs()
    if len(parsed.positionals) == 0:
        report.say(overview(specs))
        return report.finish(EXIT_OK)
    var name = String(" ").join(parsed.positionals)
    var index = find_spec(specs, name)
    if index < 0:
        var code = report.fail(
            "usage",
            String("no command called `", name, "`"),
            EXIT_USAGE,
            hint="run `dodo help` for the list",
        )
        return report.finish(code)
    report.say(command_help(specs[index]))
    return report.finish(EXIT_OK)
