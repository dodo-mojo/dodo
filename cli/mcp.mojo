"""The MCP server behind `dodo mcp`: messages in, answers out.

`McpServer.handle` takes one JSON-RPC message and returns the answer line,
or "" when there is nothing to answer (a notification). It speaks both
eras of the protocol:

- 2026-07-28: no handshake. A client may ask `server/discover` first, and
  every request names its version in `_meta`.
- 2025-11-25 and earlier: `initialize` first, then plain requests.

Each tool runs a `dodo` command with `--json` as a child process and hands
back its JSON object, so the tools do exactly what the commands do, and a
crash in one cannot take the server down.
"""

from std.os import getenv, remove
from std.os.path import join
from std.time import perf_counter_ns

from dodo.json import Value, dumps, loads
from dodo.utils.process import run

from .dev_state import process_id
from .files import read_text
from .version import DODO_VERSION

comptime MODERN_VERSION = "2026-07-28"
comptime LEGACY_VERSIONS: List[String] = [
    "2025-11-25",
    "2025-06-18",
    "2025-03-26",
    "2024-11-05",
]
"""The `initialize` versions, newest first."""
comptime VERSION_KEY = "io.modelcontextprotocol/protocolVersion"

comptime PARSE_ERROR = -32700
comptime INVALID_REQUEST = -32600
comptime METHOD_NOT_FOUND = -32601
comptime INVALID_PARAMS = -32602
comptime INTERNAL_ERROR = -32603
comptime UNSUPPORTED_VERSION = -32022

comptime INSTRUCTIONS = (
    "Tools for the dodo web app in this folder. request_send and logs_tail"
    " need the app running under `pixi run dodo dev` (start it in a"
    " terminal). docs_search needs `pixi run dodo docs pull` once."
    " Check Mojo and dodo APIs with docs_search instead of from memory."
)


struct McpServer(Movable):
    var binary: String
    """The `dodo` program the tools run."""

    def __init__(out self, binary: String):
        self.binary = binary

    def handle(self, line: String) -> String:
        """The answer to one message, or "" for none."""
        var message: Value
        try:
            message = loads(line)
        except:
            return _error_line(Value(None), PARSE_ERROR, "not JSON")
        if not message.is_object():
            return _error_line(
                Value(None), INVALID_REQUEST, "a message is one JSON object"
            )
        try:
            return self._handle(message)
        except e:
            var id = Value(None)
            try:
                id = message.get("id", Value(None))
            except:
                pass
            return _error_line(id, INTERNAL_ERROR, String(e))

    def _handle(self, message: Value) raises -> String:
        var found_id = message.get("id")
        var found_method = message.get("method")
        if not found_method:
            # An answer to a request of ours; this server sends none.
            return ""
        if not found_id:
            # A notification (initialized, cancelled): no answer.
            return ""
        var id = found_id.value().copy()
        var method = found_method.value().string_or("")
        var params = message.get("params", Value.object())
        if not params.is_object():
            return _error_line(id, INVALID_PARAMS, "params must be an object")

        var modern = False
        var meta = params.get("_meta", Value.object())
        if meta.is_object() and VERSION_KEY in meta:
            modern = True
            var asked = meta[VERSION_KEY].string_or("")
            if asked != MODERN_VERSION:
                return _unsupported(id, asked)

        if method == "initialize":
            return _result_line(id, _initialize(params))
        if method == "server/discover":
            return _result_line(id, _discover())
        if method == "ping":
            return _result_line(id, _complete(Value.object(), modern))
        if method == "tools/list":
            var listed = Value.object()
            listed["tools"] = tool_list()
            return _result_line(id, _complete(listed^, modern))
        if method == "tools/call":
            var name = params.get("name", Value("")).string_or("")
            if not is_tool(name):
                return _error_line(
                    id, INVALID_PARAMS, String("Unknown tool: ", name)
                )
            var arguments = params.get("arguments", Value.object())
            var called = self.call_tool(name, arguments)
            return _result_line(id, _complete(called^, modern))
        return _error_line(
            id, METHOD_NOT_FOUND, String("no method `", method, "`")
        )

    def call_tool(self, name: String, arguments: Value) -> Value:
        """Run tool `name`. Bad arguments and failed commands come back as
        a result with `isError`, so the agent can read why and retry."""
        var words: List[String]
        try:
            words = tool_command(name, arguments)
        except e:
            return tool_error(String(e))
        try:
            return self._run_dodo(words)
        except e:
            return tool_error(String("could not run dodo: ", e))

    def _run_dodo(self, words: List[String]) raises -> Value:
        var argv: List[String] = [self.binary]
        for word in words:
            argv.append(word)
        argv.append("--json")
        var base = join(
            getenv("TMPDIR", "/tmp"),
            String("dodo-mcp-", process_id(), "-", perf_counter_ns()),
        )
        var out_path = base + ".out"
        var err_path = base + ".err"
        _ = run(argv, stdout_path=out_path, stderr_path=err_path)
        var out = read_text(out_path)
        var err = read_text(err_path)
        _remove_quietly(out_path)
        _remove_quietly(err_path)
        var answer: Value
        try:
            answer = loads(out)
        except:
            return tool_error(
                String("dodo printed no JSON result:\n", out, err)
            )
        var ok = answer.get("ok", Value(False)).bool_or(False)
        var result = Value.object()
        var content = Value.array()
        var text = Value.object()
        text["type"] = Value("text")
        text["text"] = Value(dumps(answer))
        content.append(text^)
        result["content"] = content^
        result["structuredContent"] = answer^
        result["isError"] = Value(not ok)
        return result^


def tool_error(message: String) -> Value:
    """A tool result that says what went wrong."""
    var result = Value.object()
    try:
        var content = Value.array()
        var text = Value.object()
        text["type"] = Value("text")
        text["text"] = Value(message)
        content.append(text^)
        result["content"] = content^
        result["isError"] = Value(True)
    except:
        pass
    return result^


# ── the tools ──


comptime TOOL_NAMES: List[String] = [
    "routes_list",
    "request_send",
    "test_run",
    "logs_tail",
    "docs_search",
    "doctor",
]


def is_tool(name: String) -> Bool:
    for known in materialize[TOOL_NAMES]():
        if known == name:
            return True
    return False


def tool_list() raises -> Value:
    """What `tools/list` answers: each tool with its input schema."""
    var tools = Value.array()
    tools.append(
        _tool(
            "routes_list",
            "List routes",
            "Build the app and list its routes (method and path).",
            _schema_routes(),
            read_only=True,
        )
    )
    tools.append(
        _tool(
            "request_send",
            "Send a request",
            (
                "Send one HTTP request to the app running under `dodo dev`"
                " and return the status, headers and body. Redirects are"
                " returned, not followed."
            ),
            _schema_request(),
            read_only=False,
        )
    )
    tools.append(
        _tool(
            "test_run",
            "Run tests",
            (
                "Build and run the project's tests (tests/**/test_*.mojo) and"
                " return each file's result with any failure output."
            ),
            _schema_test(),
            read_only=False,
        )
    )
    tools.append(
        _tool(
            "logs_tail",
            "Read dev logs",
            (
                "What the running `dodo dev` and its app printed: recent"
                " events (starts, failed builds with compiler errors, app"
                " exits) and the app's last stdout and stderr lines."
            ),
            _schema_logs(),
            read_only=True,
        )
    )
    tools.append(
        _tool(
            "docs_search",
            "Search docs",
            (
                "Search the pulled Mojo and dodo docs in .dodo/docs/. Returns"
                " pages with their best matching lines and line numbers."
            ),
            _schema_docs(),
            read_only=True,
        )
    )
    tools.append(
        _tool(
            "doctor",
            "Check setup",
            "Check the toolchain, the project and the machine.",
            _object_schema(Value.object(), List[String]()),
            read_only=True,
        )
    )
    return tools^


def tool_command(name: String, arguments: Value) raises -> List[String]:
    """The `dodo` command line tool `name` runs for `arguments`.

    Raises:
        Error: If the arguments are wrong, saying how.
    """
    if not arguments.is_object():
        raise Error("arguments must be an object")
    if name == "routes_list":
        _only_keys(arguments, ["file"])
        var words: List[String] = ["routes"]
        var file = _optional_string(arguments, "file")
        if file != "":
            words.append(_plain_word(file, "file"))
        return words^
    if name == "request_send":
        return _request_command(arguments)
    if name == "test_run":
        _only_keys(arguments, ["paths", "only"])
        var words: List[String] = ["test"]
        for path in _optional_strings(arguments, "paths"):
            words.append(_plain_word(path, "paths"))
        var only = _optional_string(arguments, "only")
        if only != "":
            words.append(String("--only=", only))
        return words^
    if name == "logs_tail":
        _only_keys(arguments, ["lines"])
        var words: List[String] = ["logs"]
        var lines = _optional_int(arguments, "lines")
        if lines:
            words.append(String("--lines=", lines.value()))
        return words^
    if name == "docs_search":
        _only_keys(arguments, ["query", "limit"])
        var query = _required_string(arguments, "query")
        var words: List[String] = ["docs", "search"]
        for word in query.split():
            # A word that looks like a flag would be read as one.
            var plain = String(String(word).lstrip("-"))
            if plain != "":
                words.append(plain)
        if len(words) == 2:
            raise Error("`query` has no words to search for")
        var limit = _optional_int(arguments, "limit")
        if limit:
            words.append(String("--limit=", limit.value()))
        return words^
    if name == "doctor":
        _only_keys(arguments, List[String]())
        return ["doctor"]
    raise Error("Unknown tool: ", name)


def _request_command(arguments: Value) raises -> List[String]:
    _only_keys(arguments, ["method", "path", "headers", "body"])
    var method = _required_string(arguments, "method")
    var path = _required_string(arguments, "path")
    if not path.startswith("/"):
        raise Error("`path` must start with /, such as /users/1")
    var words: List[String] = ["request", _plain_word(method, "method"), path]
    var found = arguments.get("headers")
    if found:
        var headers = found.value().copy()
        if not headers.is_object():
            raise Error("`headers` must be an object of names to values")
        for key in headers.keys():
            var name = String(key)
            if name.startswith("-"):
                raise Error("`", name, "` is not a header name")
            var value = headers[name]
            if not value.is_string():
                raise Error("the value of header `", name, "` must be text")
            words.append(String(name, ":", value.as_string()))
    var body = _optional_string(arguments, "body")
    if body != "":
        words.append(String("--body=", body))
    return words^


# ── schemas ──


def _tool(
    name: String,
    title: String,
    description: String,
    var schema: Value,
    read_only: Bool,
) raises -> Value:
    var tool = Value.object()
    tool["name"] = Value(name)
    tool["title"] = Value(title)
    tool["description"] = Value(description)
    tool["inputSchema"] = schema^
    var hints = Value.object()
    hints["readOnlyHint"] = Value(read_only)
    hints["destructiveHint"] = Value(False)
    hints["openWorldHint"] = Value(False)
    tool["annotations"] = hints^
    return tool^


def _object_schema(
    var properties: Value, required: List[String]
) raises -> Value:
    var schema = Value.object()
    schema["type"] = Value("object")
    schema["properties"] = properties^
    if len(required) > 0:
        var names = Value.array()
        for name in required:
            names.append(Value(name))
        schema["required"] = names^
    schema["additionalProperties"] = Value(False)
    return schema^


def _property(kind: String, description: String) raises -> Value:
    var property = Value.object()
    property["type"] = Value(kind)
    property["description"] = Value(description)
    return property^


def _schema_routes() raises -> Value:
    var properties = Value.object()
    properties["file"] = _property(
        "string", "The app's main file (default: main.mojo)"
    )
    return _object_schema(properties^, List[String]())


def _schema_request() raises -> Value:
    var properties = Value.object()
    properties["method"] = _property("string", "GET, POST, PUT, ...")
    properties["path"] = _property(
        "string", "Path and query, starting with /, such as /users?page=2"
    )
    var headers = _property("object", "Header names to values")
    var values = Value.object()
    values["type"] = Value("string")
    headers["additionalProperties"] = values^
    properties["headers"] = headers^
    properties["body"] = _property("string", "The request body")
    return _object_schema(properties^, ["method", "path"])


def _schema_test() raises -> Value:
    var properties = Value.object()
    var paths = _property(
        "array", "Test files or folders to run (default: all of tests/)"
    )
    var item = Value.object()
    item["type"] = Value("string")
    paths["items"] = item^
    properties["paths"] = paths^
    properties["only"] = _property("string", "Run only the test with this name")
    return _object_schema(properties^, List[String]())


def _schema_logs() raises -> Value:
    var properties = Value.object()
    var lines = _property(
        "integer", "How many of the app's last lines (1 to 10000, default 100)"
    )
    lines["minimum"] = Value(1)
    lines["maximum"] = Value(10000)
    properties["lines"] = lines^
    return _object_schema(properties^, List[String]())


def _schema_docs() raises -> Value:
    var properties = Value.object()
    properties["query"] = _property(
        "string", "Words to look for, such as `PathParams` or `json body`"
    )
    var limit = _property(
        "integer", "Most pages to return (1 to 100, default 10)"
    )
    limit["minimum"] = Value(1)
    limit["maximum"] = Value(100)
    properties["limit"] = limit^
    return _object_schema(properties^, ["query"])


# ── reading arguments ──


def _only_keys(arguments: Value, allowed: List[String]) raises:
    for key in arguments.keys():
        var name = String(key)
        var known = False
        for allowed_name in allowed:
            if allowed_name == name:
                known = True
        if not known:
            raise Error("unknown argument `", name, "`")


def _required_string(arguments: Value, key: String) raises -> String:
    var found = arguments.get(key)
    if not found or not found.value().is_string():
        raise Error("`", key, "` is required and must be text")
    var text = found.value().as_string()
    if String(text.strip()) == "":
        raise Error("`", key, "` is empty")
    return text


def _optional_string(arguments: Value, key: String) raises -> String:
    var found = arguments.get(key)
    if not found:
        return ""
    if not found.value().is_string():
        raise Error("`", key, "` must be text")
    return found.value().as_string()


def _optional_strings(arguments: Value, key: String) raises -> List[String]:
    var texts = List[String]()
    var found = arguments.get(key)
    if not found:
        return texts^
    var items = found.value().copy()
    if not items.is_array():
        raise Error("`", key, "` must be a list of text")
    for i in range(len(items)):
        if not items[i].is_string():
            raise Error("`", key, "` must be a list of text")
        texts.append(items[i].as_string())
    return texts^


def _optional_int(arguments: Value, key: String) raises -> Optional[Int]:
    var found = arguments.get(key)
    if not found:
        return None
    if not found.value().is_int():
        raise Error("`", key, "` must be a whole number")
    return Int(found.value().as_int())


def _plain_word(text: String, key: String) raises -> String:
    """`text` as one command-line word that cannot be taken for a flag."""
    if text.startswith("-"):
        raise Error("`", key, "` cannot start with -")
    return text


# ── answers ──


def _initialize(params: Value) raises -> Value:
    var asked = params.get("protocolVersion", Value("")).string_or("")
    var version = materialize[LEGACY_VERSIONS]()[0]
    for known in materialize[LEGACY_VERSIONS]():
        if known == asked:
            version = asked
    var result = Value.object()
    result["protocolVersion"] = Value(version)
    result["capabilities"] = _capabilities()
    result["serverInfo"] = _server_info()
    result["instructions"] = Value(INSTRUCTIONS)
    return result^


def _discover() raises -> Value:
    var result = Value.object()
    result["resultType"] = Value("complete")
    var versions = Value.array()
    versions.append(Value(MODERN_VERSION))
    result["supportedVersions"] = versions^
    result["capabilities"] = _capabilities()
    result["instructions"] = Value(INSTRUCTIONS)
    var meta = Value.object()
    meta["io.modelcontextprotocol/serverInfo"] = _server_info()
    result["_meta"] = meta^
    return result^


def _capabilities() raises -> Value:
    var tools = Value.object()
    tools["listChanged"] = Value(False)
    var capabilities = Value.object()
    capabilities["tools"] = tools^
    return capabilities^


def _server_info() raises -> Value:
    var info = Value.object()
    info["name"] = Value("dodo")
    info["title"] = Value("dodo")
    info["version"] = Value(String(DODO_VERSION))
    return info^


def _complete(var result: Value, modern: Bool) raises -> Value:
    """A 2026-07-28 result says it is complete; older ones have no such
    field."""
    if modern:
        result["resultType"] = Value("complete")
    return result^


def _unsupported(id: Value, asked: String) raises -> String:
    var data = Value.object()
    var supported = Value.array()
    # Only versions a request may name in `_meta`; the older ones are
    # reached through `initialize`.
    supported.append(Value(MODERN_VERSION))
    data["supported"] = supported^
    data["requested"] = Value(asked)
    return _error_line(
        id, UNSUPPORTED_VERSION, "Unsupported protocol version", data^
    )


def _result_line(id: Value, var result: Value) raises -> String:
    var answer = Value.object()
    answer["jsonrpc"] = Value("2.0")
    answer["id"] = id.copy()
    answer["result"] = result^
    return dumps(answer)


def _error_line(
    id: Value, code: Int, message: String, var data: Value = Value(None)
) -> String:
    try:
        var error = Value.object()
        error["code"] = Value(code)
        error["message"] = Value(message)
        if not data.is_null():
            error["data"] = data^
        var answer = Value.object()
        answer["jsonrpc"] = Value("2.0")
        answer["id"] = id.copy()
        answer["error"] = error^
        return dumps(answer)
    except:
        return (
            '{"jsonrpc":"2.0","id":null,"error":{"code":-32603,"message":"internal'
            ' error"}}'
        )


def _remove_quietly(path: String):
    try:
        remove(path)
    except:
        pass
