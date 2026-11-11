"""The commands that work with a `dodo dev` session (`logs`, `request`),
`docs search`, and copying the app's output to the terminal."""

from std.ffi import c_int, external_call
from std.os import makedirs
from std.os.path import join
from std.testing import TestSuite, assert_equal, assert_false, assert_true

from dodo.json import Value

from cli.app_output import OutputCopy
from cli.cmd_docs_search import (
    markdown_files,
    page_title,
    query_terms,
    score_page,
    search,
)
from cli.cmd_logs import last_lines, parse_lines
from cli.cmd_request import method_problem, parse_header, target_problem
from cli.dev_state import is_running, process_id, read_state, write_state
from cli.report import EXIT_OK, EXIT_UNAVAILABLE, EXIT_USAGE

from dodo_cli import dodo_run, read_or_empty, scratch


# ── logs ──


def test_last_lines() raises:
    assert_equal(last_lines("", 3), "")
    assert_equal(last_lines("a\nb\nc\n", 2), "b\nc\n")
    assert_equal(last_lines("a\nb\nc", 2), "b\nc")
    assert_equal(last_lines("a\nb\n", 5), "a\nb\n")
    assert_equal(last_lines("only", 1), "only")


def test_parse_lines() raises:
    assert_equal(parse_lines("1"), 1)
    assert_equal(parse_lines("10000"), 10000)
    for bad in ["", "0", "-1", "10001", "1.5", "x", "999999"]:
        var refused = False
        try:
            _ = parse_lines(bad)
        except:
            refused = True
        assert_true(refused, bad)


def test_state_round_trip_and_liveness() raises:
    var dir = scratch("dev_state")
    assert_false(Bool(read_state(dir)))
    var state = Value.object()
    state["running"] = Value(True)
    state["pid"] = Value(process_id())
    write_state(dir, state)
    var read = read_state(dir).value().copy()
    assert_true(is_running(read))
    # A dodo that was killed outright never marked itself stopped.
    read["pid"] = Value(999_999_999)
    assert_false(is_running(read))
    read["pid"] = Value(process_id())
    read["running"] = Value(False)
    assert_false(is_running(read))
    # A half-written or broken file reads as no state.
    with open(join(dir, ".dodo", "dev", "state.json"), "w") as file:
        file.write('{"running": tr')
    assert_false(Bool(read_state(dir)))


def test_logs_and_request_without_a_session() raises:
    var dir = scratch("dev_tools_none")
    with open(join(dir, "pixi.toml"), "w") as file:
        file.write("")
    var logs = dodo_run(["logs", "--json"], cwd=dir)
    assert_equal(logs.code, EXIT_UNAVAILABLE)
    assert_equal(logs.json()["error"]["kind"].as_string(), "not_running")
    var request = dodo_run(["request", "GET", "/", "--json"], cwd=dir)
    assert_equal(request.code, EXIT_UNAVAILABLE)
    assert_equal(request.json()["error"]["kind"].as_string(), "not_running")


def test_logs_of_a_stopped_session() raises:
    var dir = scratch("dev_tools_stopped")
    with open(join(dir, "pixi.toml"), "w") as file:
        file.write("")
    var state = Value.object()
    state["running"] = Value(False)
    state["pid"] = Value(process_id())
    state["url"] = Value("http://127.0.0.1:1")
    var events = Value.array()
    var failed = Value.object()
    failed["event"] = Value("build_failed")
    failed["text"] = Value("build failed")
    failed["log"] = Value("main.mojo:1: error: nope\n")
    events.append(failed^)
    state["events"] = events^
    write_state(dir, state)
    with open(join(dir, ".dodo", "dev", "app.out"), "w") as file:
        file.write("one\ntwo\nthree\n")
    var ran = dodo_run(["logs", "--lines", "2", "--json"], cwd=dir)
    assert_equal(ran.code, EXIT_OK, ran.err)
    var result = ran.json()
    assert_false(result["running"].as_bool())
    assert_equal(result["stdout"].as_string(), "two\nthree\n")
    assert_equal(result["stderr"].as_string(), "")
    assert_true("nope" in result["events"][0]["log"].as_string())
    var text = dodo_run(["logs"], cwd=dir)
    assert_true("dodo dev: stopped" in text.out, text.out)
    assert_true("main.mojo:1: error: nope" in text.out, text.out)


# ── request ──


def test_request_words() raises:
    assert_equal(method_problem("GET"), "")
    assert_equal(method_problem("PROPFIND"), "")
    assert_true(method_problem("") != "")
    assert_true(method_problem("G T") != "")
    assert_true(method_problem("get") != "", "the command uppercases first")
    assert_equal(target_problem("/"), "")
    assert_equal(target_problem("https://example.com/x"), "")
    assert_true(target_problem("users") != "")
    assert_true(target_problem("ftp://x") != "")

    var header = parse_header("Content-Type:  application/json ")
    assert_equal(header.name, "Content-Type")
    assert_equal(header.value, "application/json")
    assert_equal(parse_header("X-Empty:").value, "")
    assert_equal(parse_header("A:b:c").value, "b:c")
    for bad in ["nocolon", ":value", "Bad Name:x", "A\r:x", "Ä:x"]:
        var refused = False
        try:
            _ = parse_header(bad)
        except:
            refused = True
        assert_true(refused, bad)


def test_request_refuses_bad_command_lines() raises:
    var dir = scratch("request_usage")
    var lines: List[List[String]] = [
        ["request"],
        ["request", "GET"],
        ["request", "G T", "/"],
        ["request", "GET", "users"],
        ["request", "GET", "/", "nocolon"],
        ["request", "GET", "/", "--body", "a", "--body-file", "b"],
        ["request", "GET", "/", "--timeout", "0"],
        ["request", "GET", "/", "--body-file", "/nonexistent/body"],
    ]
    for words in lines:
        var ran = dodo_run(words, cwd=dir)
        assert_equal(ran.code, EXIT_USAGE, String(" ").join(words))


def test_request_to_a_closed_port() raises:
    var ran = dodo_run(["request", "GET", "http://127.0.0.1:1/", "--json"])
    assert_equal(ran.code, EXIT_UNAVAILABLE, ran.out)
    assert_equal(ran.json()["error"]["kind"].as_string(), "connect")


# ── docs search ──


def _docs_folder(name: String) raises -> String:
    var dir = scratch(name)
    with open(join(dir, "pixi.toml"), "w") as file:
        file.write("")
    var docs = join(dir, ".dodo", "docs")
    makedirs(join(docs, "dodo-0.0.1", "http"))
    makedirs(join(docs, "mojo-1.2.0"))
    with open(join(docs, "dodo-0.0.1", "http", "routes.md"), "w") as file:
        file.write(
            "# Routes and path params\n\nUse PathParams for `{id}`.\n"
            "Path params are typed.\n"
        )
    with open(join(docs, "dodo-0.0.1", "index.md"), "w") as file:
        file.write("# dodo\n\nSee routes. Params everywhere: params params.\n")
    with open(join(docs, "mojo-1.2.0", "strings.md"), "w") as file:
        file.write("# Strings\n\nNothing about the query here.\n")
    with open(join(docs, "mojo-1.2.0", "notes.txt"), "w") as file:
        file.write("path params path params\n")
    return dir


def test_query_terms() raises:
    var terms = query_terms("  Path  PARAMS path\t")
    assert_equal(len(terms), 2)
    assert_equal(terms[0], "path")
    assert_equal(terms[1], "params")
    assert_equal(len(query_terms("   ")), 0)


def test_page_title() raises:
    assert_equal(
        page_title("intro\n# Real title \n## Sub", "a.md"), "Real title"
    )
    assert_equal(page_title("no heading", "a/b.md"), "a/b.md")


def test_search_ranks_pages() raises:
    var dir = _docs_folder("docs_search_rank")
    var docs = join(dir, ".dodo", "docs")
    var files = markdown_files(docs, "")
    assert_equal(len(files), 3, "only .md files")
    var hits = search(docs, query_terms("path params"), 10)
    assert_equal(len(hits), 2)
    # Both words in the title beat one word said many times.
    assert_equal(hits[0].path, "dodo-0.0.1/http/routes.md")
    assert_equal(hits[0].title, "Routes and path params")
    assert_equal(hits[0].lines[0].number, 1)
    assert_equal(hits[1].path, "dodo-0.0.1/index.md")
    assert_equal(len(search(docs, query_terms("path params"), 1)), 1)
    assert_equal(len(search(docs, query_terms("zebra"), 10)), 0)


def test_search_ranks_words_matched_before_count() raises:
    var docs = scratch("docs_search_words")
    with open(join(docs, "both.md"), "w") as file:
        file.write("# One\n\npath params\n")
    with open(join(docs, "many.md"), "w") as file:
        file.write("# Two\n\nparams params params params params params\n")
    var hits = search(docs, query_terms("path params"), 10)
    assert_equal(len(hits), 2)
    assert_equal(hits[0].path, "both.md")
    assert_equal(hits[1].path, "many.md")


def test_score_page_keeps_the_best_lines() raises:
    var text = String("a\nb x\nx y\nc\nx y z\nx\n")
    var hit = score_page("p.md", text, query_terms("x y z")).value().copy()
    assert_equal(len(hit.lines), 3)
    assert_equal(hit.lines[0].number, 5)
    assert_equal(hit.lines[1].number, 3)
    assert_equal(hit.lines[2].number, 2)


def test_docs_search_command() raises:
    var dir = _docs_folder("docs_search_cmd")
    var ran = dodo_run(["docs", "search", "path", "params", "--json"], cwd=dir)
    assert_equal(ran.code, EXIT_OK, ran.err)
    var results = ran.json()["results"].copy()
    assert_equal(len(results), 2)
    assert_equal(
        results[0]["path"].as_string(), ".dodo/docs/dodo-0.0.1/http/routes.md"
    )
    var none = dodo_run(["docs", "search", "zebra"], cwd=dir)
    assert_equal(none.code, EXIT_OK)
    assert_true("nothing in .dodo/docs/ matches" in none.out, none.out)
    assert_equal(dodo_run(["docs", "search"], cwd=dir).code, EXIT_USAGE)
    var bad_limit = dodo_run(["docs", "search", "x", "--limit", "0"], cwd=dir)
    assert_equal(bad_limit.code, EXIT_USAGE)
    var empty = scratch("docs_search_empty")
    var missing = dodo_run(["docs", "search", "x", "--json"], cwd=empty)
    assert_equal(missing.code, EXIT_UNAVAILABLE)
    assert_equal(missing.json()["error"]["kind"].as_string(), "not_found")


# ── copying the app's output ──


def _copy_into(dir: String) raises -> OutputCopy:
    """An `OutputCopy` of `dir/app.out` that writes to `dir/terminal`."""
    var fd: Int
    with open(join(dir, "terminal"), "w") as terminal:
        # A copy of the descriptor stays open after the file closes.
        fd = Int(external_call["dup", c_int](c_int(terminal.handle)))
    return OutputCopy(join(dir, "app.out"), fd)


def _append(path: String, text: String) raises:
    with open(path, "a") as file:
        file.write(text)


def test_output_copy_waits_for_whole_lines() raises:
    var dir = scratch("output_copy")
    var app = join(dir, "app.out")
    var copy = _copy_into(dir)
    copy.copy_new()  # no file yet: nothing happens
    _append(app, "one\ntw")
    copy.copy_new()
    assert_equal(read_or_empty(join(dir, "terminal")), "one\n")
    _append(app, "o\nthr")
    copy.copy_new()
    assert_equal(read_or_empty(join(dir, "terminal")), "one\ntwo\n")
    copy.copy_new(whole=True)
    assert_equal(read_or_empty(join(dir, "terminal")), "one\ntwo\nthr")

    # A restart begins the file again.
    with open(app, "w") as file:
        file.write("new\n")
    copy.restart()
    copy.copy_new()
    assert_equal(read_or_empty(join(dir, "terminal")), "one\ntwo\nthrnew\n")


def test_output_copy_does_not_wait_forever_on_a_long_line() raises:
    var dir = scratch("output_copy_long")
    var copy = _copy_into(dir)
    _append(join(dir, "app.out"), "x" * 70000)
    copy.copy_new()
    assert_equal(read_or_empty(join(dir, "terminal")).byte_length(), 70000)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
