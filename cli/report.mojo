"""What a `dodo` command says, as text for people or one JSON object.

A command writes its result into a `Report` and returns the report's
exit code. With `--json`, nothing but one JSON object reaches stdout:

    {"ok": true, "command": "routes", ...the command's fields...}
    {"ok": false, "command": "docs pull", "error": {"kind": "usage",
     "message": "...", "hint": "..."}}

Without it, `say` lines go to stdout and errors to stderr.
"""

from std.sys import stderr

from dodo.json import Value, dumps

comptime EXIT_OK = 0
"""The command did what was asked."""
comptime EXIT_FAILED = 1
"""The command ran and found a failure: a failing test, a doctor check."""
comptime EXIT_BUILD_FAILED = 2
"""`mojo build` failed on the project's code."""
comptime EXIT_USAGE = 64
"""The command line was wrong: unknown flag, bad version, missing value."""
comptime EXIT_UNAVAILABLE = 69
"""Something outside dodo was missing: the network, `mojo`, `git`."""
comptime EXIT_INTERNAL = 70
"""A bug in dodo or an error it did not expect."""


struct Report(Movable):
    """The result of one command."""

    var command: String
    var json_mode: Bool
    var fields: Value
    var _error_kind: String
    var _error_message: String
    var _error_hint: String

    def __init__(out self, command: String, json_mode: Bool):
        self.command = command
        self.json_mode = json_mode
        self.fields = Value.object()
        self._error_kind = ""
        self._error_message = ""
        self._error_hint = ""

    def say(self, text: String):
        """A line for people. Left out of `--json` output."""
        if not self.json_mode:
            print(text, flush=True)

    def note(self, text: String):
        """Progress for people, such as "building...". Goes to stderr so it
        never mixes with output a script reads."""
        if not self.json_mode:
            print(text, file=stderr, flush=True)

    def set(mut self, key: String, var value: Value) raises:
        """A field of the JSON result."""
        self.fields[key] = value^

    def fail(
        mut self,
        kind: String,
        message: String,
        exit_code: Int,
        hint: String = "",
    ) -> Int:
        """Record an error and return `exit_code`, for `return report.fail(...)`.

        `kind` is a stable word scripts can match: "usage", "not_found",
        "network", "build", "internal" and so on.
        """
        self._error_kind = kind
        self._error_message = message
        self._error_hint = hint
        return exit_code

    def failed(self) -> Bool:
        return self._error_kind != ""

    def finish(self, exit_code: Int) -> Int:
        """Print the error (text) or the whole result (JSON) and return
        `exit_code` unchanged."""
        if self.json_mode:
            print(self.to_json(exit_code), flush=True)
            return exit_code
        if self.failed():
            var prefix = String("dodo")
            if self.command != "":
                prefix = String("dodo ", self.command)
            print(String(prefix, ": ", self._error_message), file=stderr)
            if self._error_hint != "":
                print(String("  hint: ", self._error_hint), file=stderr)
        return exit_code

    def to_json(self, exit_code: Int) -> String:
        """The JSON object `finish` prints in `--json` mode."""
        try:
            var out = Value.object()
            out["ok"] = Value(exit_code == EXIT_OK and not self.failed())
            out["command"] = Value(self.command)
            out["exit_code"] = Value(exit_code)
            for key in self.fields.keys():
                out[String(key)] = self.fields[String(key)].copy()
            if self.failed():
                var error = Value.object()
                error["kind"] = Value(self._error_kind)
                error["message"] = Value(self._error_message)
                if self._error_hint != "":
                    error["hint"] = Value(self._error_hint)
                out["error"] = error^
            return dumps(out)
        except e:
            return String(
                '{"ok":false,"command":"',
                self.command,
                '","exit_code":',
                exit_code,
                ',"error":{"kind":"internal","message":"cannot write JSON"}}',
            )
