"""`dodo logs`: what the project's `dodo dev` session printed.

It reads `.dodo/dev/` (see `dev_state.mojo`): whether the session runs,
its latest events (starts, failed builds with the compiler's errors, app
exits) and the last lines the app wrote to stdout and stderr. A session
that has stopped still shows what it left.
"""

from dodo.json import Value

from .args import ParsedArgs
from .dev_state import app_err_path, app_out_path, is_running, read_state
from .files import read_text
from .project import find_root
from .report import EXIT_OK, EXIT_UNAVAILABLE, EXIT_USAGE, Report

comptime DEFAULT_LINES = 100
comptime MAX_LINES = 10000
comptime SHOWN_EVENTS = 10
"""How many of the latest events are shown."""


def cmd_logs(parsed: ParsedArgs, mut report: Report) raises -> Int:
    var lines: Int
    try:
        lines = parse_lines(parsed.value("lines", String(DEFAULT_LINES)))
    except e:
        return report.fail("usage", String(e), EXIT_USAGE)

    var root = find_root(".")
    var found = read_state(root)
    if not found:
        return report.fail(
            "not_running",
            "no `dodo dev` has run in this project",
            EXIT_UNAVAILABLE,
            hint="start one: dodo dev",
        )
    var state = found.value().copy()
    var running = is_running(state)
    var stdout_text = last_lines(read_text(app_out_path(root)), lines)
    var stderr_text = last_lines(read_text(app_err_path(root)), lines)
    var events = latest(state.get("events", Value.array()), SHOWN_EVENTS)

    report.set("running", Value(running))
    report.set("url", Value(state.get("url", Value("")).string_or("")))
    report.set("file", Value(state.get("file", Value("")).string_or("")))
    var app_pid = Int(state.get("app_pid", Value(0)).int_or(0))
    if not running:
        app_pid = 0
    report.set("app_pid", Value(app_pid))
    report.set("events", events.copy())
    report.set("stdout", Value(stdout_text))
    report.set("stderr", Value(stderr_text))
    report.say(_as_text(state, running, events, stdout_text, stderr_text))
    return EXIT_OK


def parse_lines(text: String) raises -> Int:
    """`--lines`: a whole number from 1 to `MAX_LINES`.

    Raises:
        Error: If `text` is not such a number.
    """
    var bad = Error("--lines must be a number from 1 to ", MAX_LINES)
    if text.byte_length() == 0 or text.byte_length() > 5:
        raise bad^
    for byte in text.as_bytes():
        if byte < UInt8(ord("0")) or byte > UInt8(ord("9")):
            raise bad^
    var count = Int(text)
    if count < 1 or count > MAX_LINES:
        raise bad^
    return count


def last_lines(text: String, count: Int) -> String:
    """The last `count` lines of `text`, with their newlines."""
    var newlines = 0
    var i = text.byte_length()
    var bytes = text.as_bytes()
    # A final newline ends the last line; it does not start another.
    if i > 0 and bytes[i - 1] == UInt8(ord("\n")):
        i -= 1
    while i > 0:
        if bytes[i - 1] == UInt8(ord("\n")):
            newlines += 1
            if newlines == count:
                break
        i -= 1
    return String(text[byte=i:])


def latest(events: Value, count: Int) raises -> Value:
    """The last `count` items of the array `events`."""
    var kept = Value.array()
    if not events.is_array():
        return kept^
    var start = len(events) - count
    if start < 0:
        start = 0
    for i in range(start, len(events)):
        kept.append(events[i].copy())
    return kept^


def _as_text(
    state: Value,
    running: Bool,
    events: Value,
    stdout_text: String,
    stderr_text: String,
) raises -> String:
    var text = String("dodo dev: stopped")
    if running:
        text = String(
            "dodo dev: running on ", state.get("url", Value("")).string_or("")
        )
    text += "\n\n── events ──\n"
    for i in range(len(events)):
        var event = events[i].copy()
        text += event.get("text", Value("")).string_or("") + "\n"
        var log = event.get("log")
        if log:
            text += log.value().string_or("")
    text += "\n── stdout ──\n" + stdout_text
    text += "\n── stderr ──\n" + stderr_text
    return String(text.rstrip("\n"))
