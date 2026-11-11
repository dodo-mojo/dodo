"""`dodo mcp`: the protocol answers, each tool's command line and argument
checks, and the real server over stdio."""

from std.os import makedirs
from std.os.path import join
from std.testing import TestSuite, assert_equal, assert_false, assert_true

from dodo.json import Value, dumps, loads
from dodo.utils.process import run

from cli.mcp import (
    INVALID_PARAMS,
    INVALID_REQUEST,
    METHOD_NOT_FOUND,
    MODERN_VERSION,
    PARSE_ERROR,
    TOOL_NAMES,
    UNSUPPORTED_VERSION,
    McpServer,
    tool_command,
)

from dodo_cli import dodo_binary, read_or_empty, scratch


def _server() -> McpServer:
    # Never run: the protocol tests call no tool.
    return McpServer("/nonexistent/dodo")


def _answer(line: String) raises -> Value:
    return loads(_server().handle(line))


def _request(id: Int, method: String, params: String = "{}") -> String:
    return String(
        '{"jsonrpc":"2.0","id":',
        id,
        ',"method":"',
        method,
        '","params":',
        params,
        "}",
    )


def _modern(params: String = "") -> String:
    """`params` with the 2026-07-28 `_meta` in front."""
    var meta = String(
        '"_meta":{"io.modelcontextprotocol/protocolVersion":"',
        MODERN_VERSION,
        '","io.modelcontextprotocol/clientCapabilities":{}}',
    )
    if params == "":
        return String("{", meta, "}")
    return String("{", meta, ",", params, "}")


def _error_code(answer: Value) raises -> Int:
    return Int(answer["error"]["code"].as_int())


# ── the protocol ──


def test_initialize_answers_the_asked_version() raises:
    var answer = _answer(
        _request(1, "initialize", '{"protocolVersion":"2025-06-18"}')
    )
    assert_equal(Int(answer["id"].as_int()), 1)
    var result = answer["result"].copy()
    assert_equal(result["protocolVersion"].as_string(), "2025-06-18")
    assert_equal(result["serverInfo"]["name"].as_string(), "dodo")
    assert_true("tools" in result["capabilities"])


def test_initialize_with_an_unknown_version_offers_the_newest() raises:
    var answer = _answer(
        _request(1, "initialize", '{"protocolVersion":"1999-01-01"}')
    )
    assert_equal(answer["result"]["protocolVersion"].as_string(), "2025-11-25")


def test_discover() raises:
    var answer = _answer(_request(7, "server/discover", _modern()))
    var result = answer["result"].copy()
    assert_equal(result["resultType"].as_string(), "complete")
    assert_equal(result["supportedVersions"][0].as_string(), MODERN_VERSION)
    var info = result["_meta"]["io.modelcontextprotocol/serverInfo"].copy()
    assert_equal(info["name"].as_string(), "dodo")


def test_modern_requests_say_complete_and_old_ones_do_not() raises:
    var modern = _answer(_request(2, "ping", _modern()))
    assert_equal(modern["result"]["resultType"].as_string(), "complete")
    var old = _answer(_request(2, "ping"))
    assert_false("resultType" in old["result"])


def test_unsupported_version() raises:
    var params = (
        '{"_meta":{"io.modelcontextprotocol/protocolVersion":"2099-01-01"}}'
    )
    var answer = _answer(_request(3, "tools/list", params))
    assert_equal(_error_code(answer), UNSUPPORTED_VERSION)
    var data = answer["error"]["data"].copy()
    assert_equal(data["requested"].as_string(), "2099-01-01")
    assert_equal(len(data["supported"]), 1)
    assert_equal(data["supported"][0].as_string(), MODERN_VERSION)


def test_tools_list_names_every_tool_once() raises:
    var tools = _answer(_request(4, "tools/list"))["result"]["tools"].copy()
    var names = materialize[TOOL_NAMES]()
    assert_equal(len(tools), len(names))
    for i in range(len(tools)):
        var tool = tools[i].copy()
        assert_equal(tool["name"].as_string(), names[i])
        assert_equal(tool["inputSchema"]["type"].as_string(), "object")
        assert_true(tool["description"].as_string() != "")
        # Only lowercase letters and `_`, which every client accepts
        # (Claude Code 2.1.306 called these names in a real session).
        for byte in names[i].as_bytes():
            var plain = byte >= UInt8(ord("a")) and byte <= UInt8(ord("z"))
            assert_true(plain or byte == UInt8(ord("_")), names[i])


def test_notifications_and_answers_get_no_answer() raises:
    var server = _server()
    assert_equal(
        server.handle('{"jsonrpc":"2.0","method":"notifications/initialized"}'),
        "",
    )
    assert_equal(server.handle('{"jsonrpc":"2.0","id":9,"result":{}}'), "")


def test_bad_messages() raises:
    var not_json = _answer("{nope")
    assert_equal(_error_code(not_json), PARSE_ERROR)
    assert_true(not_json["id"].is_null())
    assert_equal(_error_code(_answer("[1,2]")), INVALID_REQUEST)
    assert_equal(_error_code(_answer(_request(5, "bogus"))), METHOD_NOT_FOUND)
    assert_equal(
        _error_code(_answer(_request(5, "tools/list", "[]"))), INVALID_PARAMS
    )
    var unknown = _answer(_request(6, "tools/call", '{"name":"rm_rf"}'))
    assert_equal(_error_code(unknown), INVALID_PARAMS)
    assert_equal(Int(unknown["id"].as_int()), 6)


def test_string_ids_come_back_as_they_were() raises:
    var answer = _answer('{"jsonrpc":"2.0","id":"abc","method":"ping"}')
    assert_equal(answer["id"].as_string(), "abc")


def test_bad_arguments_are_a_tool_error() raises:
    var call = _request(
        8, "tools/call", '{"name":"logs_tail","arguments":{"lines":"ten"}}'
    )
    var result = _answer(call)["result"].copy()
    assert_true(result["isError"].as_bool())
    assert_true("whole number" in result["content"][0]["text"].as_string())


# ── each tool's command line ──


def _words(name: String, arguments: String) raises -> String:
    return String(" ").join(tool_command(name, loads(arguments)))


def _refused(name: String, arguments: String) raises -> String:
    try:
        _ = tool_command(name, loads(arguments))
    except e:
        return String(e)
    return ""


def test_tool_commands() raises:
    assert_equal(_words("routes_list", "{}"), "routes")
    assert_equal(
        _words("routes_list", '{"file":"app.mojo"}'), "routes app.mojo"
    )
    assert_equal(
        _words(
            "request_send",
            (
                '{"method":"post","path":"/u?x=1","headers":{"X-A":"1"},'
                '"body":"--json"}'
            ),
        ),
        "request post /u?x=1 X-A:1 --body=--json",
    )
    assert_equal(_words("test_run", "{}"), "test")
    assert_equal(
        _words("test_run", '{"paths":["tests/a"],"only":"test_x"}'),
        "test tests/a --only=test_x",
    )
    assert_equal(_words("logs_tail", '{"lines":5}'), "logs --lines=5")
    assert_equal(
        _words("docs_search", '{"query":"--json  path params","limit":3}'),
        "docs search json path params --limit=3",
    )
    assert_equal(_words("doctor", "{}"), "doctor")


def test_tool_arguments_are_checked() raises:
    var cases: List[List[String]] = [
        ["routes_list", '{"extra":1}'],
        ["routes_list", '{"file":"--json"}'],
        ["request_send", '{"method":"GET"}'],
        ["request_send", '{"method":"GET","path":"http://evil.example/"}'],
        ["request_send", '{"method":"GET","path":"/","headers":[]}'],
        ["request_send", '{"method":"GET","path":"/","headers":{"A":1}}'],
        ["request_send", '{"method":"GET","path":"/","headers":{"-x":"1"}}'],
        ["request_send", '{"method":"-X","path":"/"}'],
        ["test_run", '{"paths":"tests"}'],
        ["test_run", '{"paths":["--only=x"]}'],
        ["logs_tail", '{"lines":1.5}'],
        ["docs_search", "{}"],
        ["docs_search", '{"query":"  "}'],
        ["docs_search", '{"query":"-- ---"}'],
        ["doctor", '{"x":1}'],
        ["doctor", "[]"],
    ]
    for check in cases:
        var why = _refused(check[0], check[1])
        assert_true(why != "", String(check[0], " took ", check[1]))


# ── the server over stdio ──


def test_stdio_session() raises:
    """Every request gets one answer line, in order; a tool's child
    process cannot eat the messages after it; stdin closing ends it."""
    var dir = scratch("mcp_stdio")
    with open(join(dir, "pixi.toml"), "w") as file:
        file.write("")
    var messages: List[String] = [
        _request(1, "initialize", '{"protocolVersion":"2025-11-25"}'),
        '{"jsonrpc":"2.0","method":"notifications/initialized"}',
        "",
        _request(2, "tools/call", '{"name":"doctor","arguments":{}}') + "\r",
        "not json",
        _request(3, "tools/call", '{"name":"logs_tail","arguments":{}}'),
        _request(4, "ping"),
    ]
    var input = join(dir, "in.jsonl")
    with open(input, "w") as file:
        file.write(String("\n").join(messages))
        # The last message has no newline: the end of input ends it.
    var output = join(dir, "out.jsonl")
    var status = run(
        [
            "sh",
            "-c",
            'cd "$1" && exec "$2" mcp < "$3" > "$4"',
            "sh",
            dir,
            dodo_binary(),
            input,
            output,
        ],
        stderr_path=join(dir, "err.txt"),
    )
    assert_true(status.succeeded(), read_or_empty(join(dir, "err.txt")))
    var lines = read_or_empty(output).splitlines()
    assert_equal(len(lines), 5, read_or_empty(output))

    assert_equal(Int(loads(String(lines[0]))["id"].as_int()), 1)
    var doctor = loads(String(lines[1]))
    assert_equal(Int(doctor["id"].as_int()), 2)
    var checks = doctor["result"]["structuredContent"]["checks"].copy()
    assert_true(len(checks) > 0)
    assert_equal(_error_code(loads(String(lines[2]))), PARSE_ERROR)
    var logs = loads(String(lines[3]))["result"].copy()
    assert_true(logs["isError"].as_bool())
    var error = logs["structuredContent"]["error"]["kind"].as_string()
    assert_equal(error, "not_running")
    assert_equal(Int(loads(String(lines[4]))["id"].as_int()), 4)


comptime _READS_STDIN = "tests/cli/fixtures/reads_stdin.mojo"
"""A user's test that reads stdin."""


def test_a_tool_cannot_read_the_messages() raises:
    """A user's test that reads stdin runs while the next message waits
    in the pipe. It must not get that message."""
    var dir = scratch("mcp_stdin")
    with open(join(dir, "pixi.toml"), "w") as file:
        file.write("")
    makedirs(join(dir, "tests"))
    var program: String
    with open(_READS_STDIN, "r") as file:
        program = file.read()
    with open(join(dir, "tests", "test_stdin.mojo"), "w") as file:
        file.write(program)
    var call = _request(1, "tools/call", '{"name":"test_run","arguments":{}}')
    var output = join(dir, "out.jsonl")
    var status = run(
        [
            "sh",
            "-c",
            (
                'cd "$1" && { printf "%s\\n" "$3"; sleep 1; printf "%s\\n"'
                ' "$4"; } | "$2" mcp > "$5"'
            ),
            "sh",
            dir,
            dodo_binary(),
            call,
            _request(2, "ping"),
            output,
        ],
    )
    assert_true(status.succeeded())
    var lines = read_or_empty(output).splitlines()
    assert_equal(len(lines), 2, read_or_empty(output))
    var tested = loads(String(lines[0]))["result"].copy()
    assert_false(tested["isError"].as_bool(), String(lines[0]))
    assert_equal(Int(loads(String(lines[1]))["id"].as_int()), 2)


def test_stdio_skips_a_message_that_is_too_long() raises:
    var dir = scratch("mcp_long")
    var input = join(dir, "in.jsonl")
    with open(input, "w") as file:
        file.write('{"jsonrpc":"2.0","id":1,"method":"ping","x":"')
        file.write("a" * (17 * 1024 * 1024))
        file.write('"}\n')
        file.write(_request(2, "ping") + "\n")
    var output = join(dir, "out.jsonl")
    var status = run(
        [
            "sh",
            "-c",
            'exec "$1" mcp < "$2" > "$3"',
            "sh",
            dodo_binary(),
            input,
            output,
        ]
    )
    assert_true(status.succeeded())
    var lines = read_or_empty(output).splitlines()
    assert_equal(len(lines), 2, read_or_empty(output))
    assert_equal(_error_code(loads(String(lines[0]))), PARSE_ERROR)
    assert_equal(Int(loads(String(lines[1]))["id"].as_int()), 2)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
