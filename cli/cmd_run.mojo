"""`dodo run [FILE] [-- ARGS...]`: build the app, then become it.

dodo replaces itself with the app (`exec`), so the app gets Ctrl-C and
SIGTERM directly, owns the terminal, and its exit code is the command's.
With `--json`, the build report is printed on one line before the app
starts.
"""

from dodo.utils.process import exec_replace

from .args import ParsedArgs
from .build import build_for_command
from .report import EXIT_OK, Report


def cmd_run(parsed: ParsedArgs, mut report: Report) raises -> Int:
    var given = String("")
    if len(parsed.positionals) > 0:
        given = parsed.positionals[0]
    var build = build_for_command(given, report)
    if not build.ok():
        return build.exit_code

    if report.json_mode:
        _ = report.finish(EXIT_OK)
    var argv: List[String] = [build.binary]
    for word in parsed.passthrough:
        argv.append(word)
    exec_replace(argv)
    return EXIT_OK
