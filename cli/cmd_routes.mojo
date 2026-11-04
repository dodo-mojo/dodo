"""`dodo routes [FILE]`: list the app's routes.

dodo builds the app and runs it with `DODO_ROUTES=json`. `main` runs as
usual up to `app.serve(...)`, which prints the route list as one JSON line
and returns without binding a port. Anything else `main` prints is
ignored. A `main` that never reaches `serve` (it waits for a database,
say) is stopped after `--timeout` seconds.
"""

from std.os import remove
from std.time import perf_counter_ns, sleep

from dodo.json import Value, loads
from dodo.utils.process import spawn

from .args import ParsedArgs
from .build import build_for_command
from .report import EXIT_FAILED, EXIT_OK, EXIT_USAGE, Report

comptime _MARKER = '{"dodo_routes":'
comptime _SIGKILL = 9


def cmd_routes(parsed: ParsedArgs, mut report: Report) raises -> Int:
    var timeout: Float64
    try:
        timeout = parse_timeout(parsed.value("timeout", "60"))
    except e:
        return report.fail("usage", String(e), EXIT_USAGE)

    var given = String("")
    if len(parsed.positionals) > 0:
        given = parsed.positionals[0]
    var build = build_for_command(given, report)
    if not build.ok():
        return build.exit_code

    var out_path = build.binary + ".routes.out"
    var err_path = build.binary + ".routes.err"
    var child = spawn(
        [build.binary],
        env=["DODO_ROUTES=json"],
        stdout_path=out_path,
        stderr_path=err_path,
        new_group=True,
    )
    var deadline = perf_counter_ns() + Int(timeout * 1e9)
    var status = child.poll()
    while not status:
        if perf_counter_ns() > deadline:
            child.send_signal(_SIGKILL)
            _ = child.wait()
            return report.fail(
                "timeout",
                String("the app did not reach serve() within ", timeout, " s"),
                EXIT_FAILED,
                hint="main() may be waiting on a database; raise --timeout",
            )
        sleep(0.005)
        status = child.poll()

    var exit = status.value()
    var output = _read(out_path)
    var errors = _read(err_path)
    _remove(out_path)
    _remove(err_path)
    if not exit.succeeded():
        report.set("app_stderr", Value(errors))
        return report.fail(
            "app_failed",
            String("the app exited with ", exit, " before listing its routes"),
            EXIT_FAILED,
            hint=_last_line(errors),
        )

    var routes = _find_routes(output)
    if not routes:
        return report.fail(
            "no_routes",
            "the app exited without calling serve() on an App or Router",
            EXIT_FAILED,
            hint=(
                "dodo routes reads the list App.serve() and dodo.serve() print"
            ),
        )
    var list = routes.take()
    report.say(format_routes(list))
    report.set("routes", list^)
    return EXIT_OK


def parse_timeout(text: String) raises -> Float64:
    """Seconds, more than 0 and at most an hour."""
    var seconds: Float64
    try:
        seconds = Float64(text)
    except:
        raise Error("--timeout must be a number of seconds, got `", text, "`")
    if not (seconds > 0.0 and seconds <= 3600.0):
        raise Error(
            "--timeout must be more than 0 and at most 3600, got `", text, "`"
        )
    return seconds


def format_routes(routes: Value) raises -> String:
    """One route per line: method, path, and `blocking` when it is."""
    if len(routes) == 0:
        return "no routes"
    var width = 0
    for i in range(len(routes)):
        width = max(width, routes[i]["method"].as_string().byte_length())
    var text = String("")
    for i in range(len(routes)):
        var route = routes[i]
        var method = route["method"].as_string()
        var line = method
        while line.byte_length() < width:
            line += " "
        line += String("  ", route["path"].as_string())
        if route["blocking"].as_bool():
            line += "  (blocking)"
        var kind = route["kind"].as_string()
        if kind != "route":
            line += String("  (", kind, ")")
        if i > 0:
            text += "\n"
        text += line
    return text^


def _find_routes(output: String) raises -> Optional[Value]:
    """The route list from the last marker line `serve` printed."""
    var found = Optional[Value]()
    for line in output.splitlines():
        if line.startswith(_MARKER):
            var parsed = loads(String(line))
            found = parsed["dodo_routes"].copy()
    return found^


def _last_line(text: String) -> String:
    var lines = text.strip().splitlines()
    if len(lines) == 0:
        return ""
    return String(lines[len(lines) - 1])


def _read(path: String) -> String:
    try:
        with open(path, "r") as file:
            return file.read()
    except:
        return ""


def _remove(path: String):
    try:
        remove(path)
    except:
        pass
