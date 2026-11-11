"""`dodo request METHOD PATH [NAME:VALUE...]`: send one request to the app.

PATH is resolved against the URL of the project's running `dodo dev`, or
against `--url`; a full `http://` or `https://` address is sent as it is.
Words such as `Content-Type:application/json` after PATH are headers.
Redirects are shown, not followed. Any answer, a 500 included, exits 0:
the command worked, and the status is in the result.
"""

from std.time import perf_counter_ns

from dodo.crypto.base64 import base64_encode
from dodo.http import HttpClient, Request, Response
from dodo.http.redirect_policy import RedirectPolicy
from dodo.json import Value

from .args import ParsedArgs
from .cmd_routes import parse_timeout
from .dev_state import is_running, read_state
from .files import read_text
from .project import find_root
from .report import EXIT_OK, EXIT_UNAVAILABLE, EXIT_USAGE, Report

comptime MAX_BODY_BYTES = 1_048_576
"""The most of a response body the result shows (1 MiB)."""


@fieldwise_init
struct Header(Copyable, Movable):
    var name: String
    var value: String


def cmd_request(parsed: ParsedArgs, mut report: Report) raises -> Int:
    if len(parsed.positionals) < 2:
        return report.fail(
            "usage",
            "name the method and the path",
            EXIT_USAGE,
            hint="dodo request GET /",
        )
    var method = String(parsed.positionals[0]).upper()
    var target = String(parsed.positionals[1])
    var problem = method_problem(method)
    if problem == "":
        problem = target_problem(target)
    var headers = List[Header]()
    for i in range(2, len(parsed.positionals)):
        if problem != "":
            break
        try:
            headers.append(parse_header(parsed.positionals[i]))
        except e:
            problem = String(e)
    if problem == "" and parsed.given("body") and parsed.given("body-file"):
        problem = "give --body or --body-file, not both"
    var timeout = Float64(30)
    if problem == "":
        try:
            timeout = parse_timeout(parsed.value("timeout", "30"))
        except e:
            problem = String(e)
    if problem != "":
        return report.fail("usage", problem, EXIT_USAGE)

    var body = List[UInt8]()
    if parsed.given("body"):
        body = List[UInt8](parsed.value("body").as_bytes())
    if parsed.given("body-file"):
        var path = parsed.value("body-file")
        try:
            with open(path, "r") as file:
                body = file.read_bytes()
        except:
            return report.fail(
                "not_found", String("cannot read `", path, "`"), EXIT_USAGE
            )

    var url = target
    if target.startswith("/"):
        var base = parsed.value("url")
        if base == "":
            base = running_dev_url()
        if base == "":
            return report.fail(
                "not_running",
                "no `dodo dev` runs in this project to send it to",
                EXIT_UNAVAILABLE,
                hint="start one with `dodo dev`, or pass --url",
            )
        url = String(base.rstrip("/"), target)

    var request = Request(method=method, url=url, body=body)
    for header in headers:
        request.headers.append(header.name, header.value)
    var client = HttpClient().with_redirect_policy(RedirectPolicy.deny())
    client = client^.with_read_timeout(Int(timeout * 1000.0))
    var started = perf_counter_ns()
    var answer: Response
    try:
        answer = client.send(request)
    except e:
        return report.fail(
            "connect",
            String("no answer from ", url, ": ", e),
            EXIT_UNAVAILABLE,
            hint="is the app running? `dodo logs` shows what it printed",
        )
    var milliseconds = Float64(perf_counter_ns() - started) / 1e6
    _report_answer(report, method, url, answer, milliseconds)
    return EXIT_OK


def _report_answer(
    mut report: Report,
    method: String,
    url: String,
    answer: Response,
    milliseconds: Float64,
) raises:
    var shown = Span(answer.body)
    var truncated = len(shown) > MAX_BODY_BYTES
    if truncated:
        shown = shown[:MAX_BODY_BYTES]
    var encoding = String("text")
    var body_text: String
    try:
        body_text = String(from_utf8=shown)
    except:
        encoding = "base64"
        body_text = base64_encode(shown)

    var headers = Value.object()
    var lines = String("")
    for i in range(answer.headers.len()):
        var name = answer.headers.name_at(i).lower()
        var value = String(answer.headers.value_at(i))
        lines += String(name, ": ", value, "\n")
        if name in headers:
            value = String(headers[name].as_string(), ", ", value)
        headers[name] = Value(value)

    report.set("method", Value(method))
    report.set("url", Value(url))
    report.set("status", Value(answer.status))
    report.set("reason", Value(answer.reason))
    report.set("headers", headers^)
    report.set("body", Value(body_text))
    report.set("body_encoding", Value(encoding))
    report.set("body_bytes", Value(len(answer.body)))
    report.set("truncated", Value(truncated))
    report.set("ms", Value(milliseconds))

    var text = String(answer.status, " ", answer.reason, "\n", lines, "\n")
    if encoding == "base64":
        text += String("(", len(answer.body), " bytes that are not text)")
    else:
        text += body_text
    if truncated:
        text += String("\n(cut at ", MAX_BODY_BYTES, " bytes)")
    report.say(text)


def running_dev_url() -> String:
    """The URL of this project's running `dodo dev`, or ""."""
    try:
        var found = read_state(find_root("."))
        if found and is_running(found.value()):
            return found.value().get("url", Value("")).string_or("")
    except:
        pass
    return ""


def method_problem(method: String) -> String:
    """Why `method` cannot be an HTTP method, or "" when it can."""
    if method == "" or method.byte_length() > 32:
        return String("`", method, "` is not an HTTP method")
    for byte in method.as_bytes():
        if byte < UInt8(ord("A")) or byte > UInt8(ord("Z")):
            return String("`", method, "` is not an HTTP method")
    return ""


def target_problem(target: String) -> String:
    """Why `target` cannot be sent, or "" when it can."""
    if target.startswith("/"):
        return ""
    if target.startswith("http://") or target.startswith("https://"):
        return ""
    return String(
        "`", target, "` must be a path such as /users, or a full http:// URL"
    )


def parse_header(word: String) raises -> Header:
    """`Name:value` or `Name: value` as a header.

    Raises:
        Error: If `word` has no `:` or its name is not a header name.
    """
    var colon = word.find(":")
    if colon <= 0:
        raise Error("`", word, "` is not a header; write it as Name:value")
    var name = String(word[byte=:colon])
    for byte in name.as_bytes():
        if not _is_token_byte(byte):
            raise Error("`", name, "` is not a header name")
    var value = String(String(word[byte = colon + 1 :]).strip())
    for byte in value.as_bytes():
        if byte == UInt8(ord("\r")) or byte == UInt8(ord("\n")):
            raise Error("the value of `", name, "` has a line break")
    return Header(name, value)


def _is_token_byte(byte: UInt8) -> Bool:
    """A byte allowed in a header name (RFC 9110 `tchar`)."""
    if byte >= UInt8(ord("a")) and byte <= UInt8(ord("z")):
        return True
    if byte >= UInt8(ord("A")) and byte <= UInt8(ord("Z")):
        return True
    if byte >= UInt8(ord("0")) and byte <= UInt8(ord("9")):
        return True
    for allowed in "!#$%&'*+-.^_`|~".as_bytes():
        if byte == allowed:
            return True
    return False
