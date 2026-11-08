"""End-to-end tests of `dodo docs pull` against a local stand-in for
GitHub (`fixtures/docs_server.py`)."""

from std.os import listdir, makedirs
from std.os.path import exists, isfile, join, realpath
from std.testing import TestSuite, assert_equal, assert_false, assert_true
from std.time import perf_counter_ns, sleep

from dodo.json import Value
from dodo.utils.process import Child, ExitStatus, run, spawn

from cli.docs_folder import write_file
from cli.docs_index import index_links
from cli.report import EXIT_INTERRUPTED, EXIT_OK, EXIT_UNAVAILABLE, EXIT_USAGE
from cli.version import DODO_VERSION

from dodo_cli import Ran, dodo_binary, dodo_run, read_or_empty, scratch

comptime _SERVER = "tests/cli/fixtures/docs_server.py"
comptime _NOWHERE = "http://127.0.0.1:1"
"""A port nothing listens on."""


struct DocsServer(Movable):
    """`docs_server.py` serving one folder, stopped when this is dropped."""

    var child: Child
    var url: String
    var log_path: String

    def __init__(out self, folder: String) raises:
        self.log_path = folder + ".log"
        self.child = spawn(
            ["python3", _SERVER, folder],
            stdout_path=self.log_path,
            stderr_path="&1",
        )
        self.url = ""
        var tries = 0
        while tries < 1000:
            var log = read_or_empty(self.log_path)
            if log.startswith("port "):
                var port = String(log.splitlines()[0])[byte=5:]
                self.url = String("http://127.0.0.1:", port)
                return
            sleep(0.01)
            tries += 1
        raise Error(
            "the docs server did not start: ", read_or_empty(self.log_path)
        )

    def requests_for(self, path: String) -> Int:
        """How many times `path` was asked for."""
        var count = 0
        for line in read_or_empty(self.log_path).splitlines():
            if line == String("GET ", path):
                count += 1
        return count

    def asked_for(self, path: String) -> Bool:
        return self.requests_for(path) > 0

    def __deinit__(deinit self):
        try:
            self.child.send_signal(15)
            _ = self.child.wait()
        except:
            pass


def _write(path: String, text: String) raises:
    write_file(path, text.as_bytes())


def _docs_folder(dir: String, title: String, extra_links: String = "") raises:
    """A small docs folder: an index and three files, one in a subfolder."""
    _write(
        join(dir, "index.md"),
        String(
            "# ",
            title,
            "\n\n> Test docs.\n\n",
            "- [Guide](guide.md): The guide.\n",
            "- [List](std/collections/list.md#append): `[not](a_link.md)`\n",
            "- [License](LICENSE.txt)\n",
            "- [Home](https://example.com/)\n",
            extra_links,
        ),
    )
    _write(join(dir, "guide.md"), String("guide of ", title, "\n"))
    _write(
        join(dir, "std", "collections", "list.md"), String("list of ", title)
    )
    _write(join(dir, "LICENSE.txt"), String("license of ", title))


def _site(name: String) raises -> String:
    """A copy of what GitHub serves on `dev`: three saved Mojo versions,
    and two saved dodo versions besides the one under test."""
    var site = scratch(name)
    var mojo = join(site, "dev", "mojo-docs")
    _write(
        join(mojo, "index.md"),
        String(
            "# Mojo docs saved by dodo\n\n",
            "- [Mojo 1.3.1](1.3.1/index.md)\n",
            "- [Mojo 1.3.0](1.3.0/index.md)\n",
            "- [Mojo 1.2.0](1.2.0/index.md)\n",
        ),
    )
    _docs_folder(join(mojo, "1.3.1"), "Mojo 1.3.1")
    _docs_folder(join(mojo, "1.3.0"), "Mojo 1.3.0")
    _docs_folder(join(mojo, "1.2.0"), "Mojo 1.2.0")
    var dodo = join(site, "dev", "dodo-docs")
    _write(
        join(dodo, "index.md"),
        String(
            "# dodo docs\n\n",
            "- [dodo 9.9.9](9.9.9/index.md)\n",
            "- [dodo 9.8.0](9.8.0/index.md)\n",
            "- [dodo ",
            DODO_VERSION,
            "](",
            DODO_VERSION,
            "/index.md)\n",
        ),
    )
    _docs_folder(join(dodo, "9.9.9"), "dodo 9.9.9")
    _docs_folder(join(dodo, "9.8.0"), "dodo 9.8.0")
    _docs_folder(join(dodo, DODO_VERSION), "dodo now")
    return site^


def _project(name: String) raises -> String:
    var dir = scratch(String(name, "_project"))
    _write(join(dir, "pixi.toml"), "[workspace]\n")
    makedirs(join(dir, "src"))
    return dir^


def _pull(
    project: String,
    url: String,
    words: List[String],
    env: List[String] = List[String](),
) raises -> Ran:
    var all_words: List[String] = ["docs", "pull"]
    for word in words:
        all_words.append(word)
    var all_env: List[String] = [String("DODO_DOCS_URL=", url)]
    for entry in env:
        all_env.append(entry)
    return dodo_run(all_words, env=all_env, cwd=project)


def _docs_dir(project: String) -> String:
    return join(project, ".dodo", "docs")


def _listing(dir: String) raises -> String:
    """The names in `dir`, sorted, joined by spaces."""
    var names = listdir(dir)
    sort(names)
    return String(" ").join(names)


def _error_of(ran: Ran) raises -> Value:
    var result = ran.json()
    assert_false(result["ok"].as_bool(), ran.out)
    return result["error"].copy()


# ── pulls that work ──


def test_named_versions_are_pulled() raises:
    var site = _site("named")
    var server = DocsServer(site)
    var project = _project("named")
    var ran = _pull(project, server.url, ["mojo@1.3", "dodo@9.9.9", "--json"])
    assert_equal(ran.code, EXIT_OK, String(ran.out, ran.err))
    var result = ran.json()
    assert_true(result["ok"].as_bool())
    var mojo = result["mojo"].copy()
    assert_equal(mojo["version"].as_string(), "1.3.1")
    assert_equal(mojo["folder"].as_string(), ".dodo/docs/mojo-1.3.1")
    assert_equal(mojo["files"].as_int(), 4)
    assert_true(mojo["bytes"].as_int() > 100)
    assert_equal(result["dodo"]["version"].as_string(), "9.9.9")
    assert_equal(result["dodo"]["files"].as_int(), 4)

    var docs = _docs_dir(project)
    assert_equal(_listing(docs), "dodo-9.9.9 mojo-1.3.1")
    var mojo_docs = join(docs, "mojo-1.3.1")
    assert_equal(_listing(mojo_docs), "LICENSE.txt guide.md index.md std")
    assert_equal(
        read_or_empty(join(mojo_docs, "guide.md")), "guide of Mojo 1.3.1\n"
    )
    assert_equal(
        read_or_empty(join(mojo_docs, "std", "collections", "list.md")),
        "list of Mojo 1.3.1",
    )
    assert_equal(
        read_or_empty(join(docs, "dodo-9.9.9", "LICENSE.txt")),
        "license of dodo 9.9.9",
    )
    # A link inside code is not a file.
    assert_false(server.asked_for("/dev/mojo-docs/1.3.1/a_link.md"))


def test_flags_name_versions_and_text_says_what_came() raises:
    var site = _site("flags")
    var server = DocsServer(site)
    var project = _project("flags")
    var ran = _pull(project, server.url, ["--mojo", "1.3.0", "--dodo=9.9.9"])
    assert_equal(ran.code, EXIT_OK, String(ran.out, ran.err))
    var lines = ran.out.strip().splitlines()
    assert_equal(len(lines), 2, ran.out)
    assert_true(
        String(lines[0]).startswith(
            "Mojo 1.3.0: 4 files (0.1 MB) in .dodo/docs/mojo-1.3.0, "
        ),
        ran.out,
    )
    assert_true(String(lines[1]).startswith("dodo 9.9.9: 4 files"), ran.out)
    assert_true("pulling the Mojo 1.3.0 docs" in ran.err, ran.err)
    assert_true(isfile(join(_docs_dir(project), "mojo-1.3.0", "guide.md")))


def test_the_project_versions_by_default_from_the_real_archive() raises:
    # The Mojo version is what `mojo --version` says (the tests run inside
    # pixi), and the archive is the one this repository saves.
    var site = _site("default")
    var archive = join(site, "dev", "mojo-docs")
    _ = run(["rm", "-rf", archive])
    _ = run(["ln", "-s", realpath("mojo-docs"), archive])
    var server = DocsServer(site)
    var project = _project("default")
    var ran = _pull(project, server.url, ["--json"])
    assert_equal(ran.code, EXIT_OK, String(ran.out, ran.err))
    var result = ran.json()
    assert_equal(result["mojo"]["version"].as_string(), "1.2.0")
    assert_equal(result["dodo"]["version"].as_string(), DODO_VERSION)

    var saved: String
    with open("mojo-docs/1.2.0/index.md", "r") as file:
        saved = file.read()
    var expected = Int64(len(index_links(saved)) + 1)
    assert_equal(result["mojo"]["files"].as_int(), expected)
    var pulled = join(_docs_dir(project), "mojo-1.2.0")
    var same = run(["diff", "-r", "mojo-docs/1.2.0", pulled])
    assert_true(same.succeeded(), "the pulled docs differ from the archive")
    assert_equal(
        read_or_empty(
            join(_docs_dir(project), String("dodo-", DODO_VERSION), "guide.md")
        ),
        "guide of dodo now\n",
    )


def test_short_versions_pick_the_newest_saved_one() raises:
    var site = _site("short")
    var server = DocsServer(site)
    var project = _project("short")
    var ran = _pull(project, server.url, ["mojo@1", "dodo@9", "--json"])
    assert_equal(ran.code, EXIT_OK, String(ran.out, ran.err))
    var result = ran.json()
    assert_equal(result["mojo"]["version"].as_string(), "1.3.1")
    assert_equal(result["dodo"]["version"].as_string(), "9.9.9")
    var older = _pull(project, server.url, ["mojo@1.2", "dodo@9.8", "--json"])
    assert_equal(older.json()["dodo"]["version"].as_string(), "9.8.0")
    assert_equal(
        _listing(_docs_dir(project)),
        "dodo-9.8.0 dodo-9.9.9 mojo-1.2.0 mojo-1.3.1",
    )


def test_a_pull_from_a_subfolder_lands_in_the_project_root() raises:
    var site = _site("subfolder")
    var server = DocsServer(site)
    var project = _project("subfolder")
    var ran = _pull(
        join(project, "src"), server.url, ["mojo@1.3.1", "dodo@9.9.9"]
    )
    assert_equal(ran.code, EXIT_OK, String(ran.out, ran.err))
    assert_true(isfile(join(_docs_dir(project), "mojo-1.3.1", "guide.md")))
    assert_false(exists(join(project, "src", ".dodo")))


def test_a_new_pull_replaces_the_old_docs() raises:
    var site = _site("replace")
    var server = DocsServer(site)
    var project = _project("replace")
    var old = join(_docs_dir(project), "mojo-1.3.1")
    _write(join(old, "stale.md"), "gone from the archive")
    _write(join(old, "guide.md"), "old guide")
    var ran = _pull(project, server.url, ["mojo@1.3.1", "dodo@9.9.9"])
    assert_equal(ran.code, EXIT_OK, String(ran.out, ran.err))
    assert_false(exists(join(old, "stale.md")), "a stale file stayed")
    assert_equal(read_or_empty(join(old, "guide.md")), "guide of Mojo 1.3.1\n")
    assert_equal(_listing(_docs_dir(project)), "dodo-9.9.9 mojo-1.3.1")


# ── pulls that fail keep the old docs ──


def _old_docs(project: String) raises -> String:
    var old = join(_docs_dir(project), "mojo-1.3.1")
    _write(join(old, "guide.md"), "old guide")
    return old^


def _assert_old_docs_kept(project: String) raises:
    var docs = _docs_dir(project)
    assert_equal(
        read_or_empty(join(docs, "mojo-1.3.1", "guide.md")), "old guide"
    )
    assert_equal(_listing(join(docs, "mojo-1.3.1")), "guide.md")
    for name in listdir(docs):
        assert_false(name.startswith("."), String("left behind: ", name))


def test_a_missing_file_keeps_the_old_docs() raises:
    var site = _site("missing")
    _docs_folder(
        join(site, "dev", "mojo-docs", "1.3.1"),
        "Mojo 1.3.1",
        "- [Gone](gone.md)\n",
    )
    var server = DocsServer(site)
    var project = _project("missing")
    _ = _old_docs(project)
    var ran = _pull(project, server.url, ["mojo@1.3.1", "dodo@9.9.9", "--json"])
    assert_equal(ran.code, EXIT_UNAVAILABLE, String(ran.out, ran.err))
    var error = _error_of(ran)
    assert_equal(error["kind"].as_string(), "network")
    assert_true(
        "1.3.1/gone.md answered 404" in error["message"].as_string(), ran.out
    )
    _assert_old_docs_kept(project)
    # The other half still comes.
    var result = ran.json()
    assert_equal(result["dodo"]["files"].as_int(), 4)
    assert_true(isfile(join(_docs_dir(project), "dodo-9.9.9", "guide.md")))


def test_a_server_error_is_retried_then_reported() raises:
    var site = _site("broken")
    _docs_folder(
        join(site, "dev", "mojo-docs", "1.3.1"),
        "Mojo 1.3.1",
        "- [Broken](broken.md)\n",
    )
    var server = DocsServer(site)
    var project = _project("broken")
    _ = _old_docs(project)
    var ran = _pull(project, server.url, ["mojo@1.3.1", "dodo@9.9.9", "--json"])
    assert_equal(ran.code, EXIT_UNAVAILABLE, String(ran.out, ran.err))
    var error = _error_of(ran)
    assert_true(
        "broken.md answered 500" in error["message"].as_string(), ran.out
    )
    assert_equal(server.requests_for("/dev/mojo-docs/1.3.1/broken.md"), 3)
    _assert_old_docs_kept(project)


def test_an_index_that_leaves_its_folder_is_refused() raises:
    var site = _site("escape")
    _write(join(site, "dev", "secret.md"), "secret")
    _docs_folder(
        join(site, "dev", "mojo-docs", "1.3.1"),
        "Mojo 1.3.1",
        "- [Secret](../../secret.md)\n",
    )
    var server = DocsServer(site)
    var project = _project("escape")
    _ = _old_docs(project)
    var ran = _pull(project, server.url, ["mojo@1.3.1", "dodo@9.9.9", "--json"])
    assert_equal(ran.code, EXIT_UNAVAILABLE, String(ran.out, ran.err))
    var error = _error_of(ran)
    assert_equal(error["kind"].as_string(), "bad_index")
    assert_true("`../../secret.md`" in error["message"].as_string(), ran.out)
    assert_false(server.asked_for("/dev/mojo-docs/1.3.1/guide.md"))
    assert_false(server.asked_for("/dev/secret.md"))
    _assert_old_docs_kept(project)


def test_an_index_that_is_not_text_is_refused() raises:
    var site = _site("binary")
    var bytes: List[UInt8] = [0x2D, 0x20, 0xFF, 0xFE, 0x0A]
    write_file(join(site, "dev", "mojo-docs", "1.3.1", "index.md"), bytes)
    var server = DocsServer(site)
    var project = _project("binary")
    _ = _old_docs(project)
    var ran = _pull(project, server.url, ["mojo@1.3.1", "dodo@9.9.9", "--json"])
    assert_equal(ran.code, EXIT_UNAVAILABLE, String(ran.out, ran.err))
    assert_equal(_error_of(ran)["kind"].as_string(), "bad_index")
    _assert_old_docs_kept(project)


def test_a_silent_server_times_out() raises:
    var site = _site("silent")
    _docs_folder(
        join(site, "dev", "mojo-docs", "1.3.1"),
        "Mojo 1.3.1",
        "- [Slow](hang.md)\n",
    )
    var server = DocsServer(site)
    var project = _project("silent")
    _ = _old_docs(project)
    var started = perf_counter_ns()
    var ran = _pull(
        project,
        server.url,
        ["mojo@1.3.1", "dodo@9.9.9", "--json"],
        env=["DODO_DOCS_READ_TIMEOUT_MS=300"],
    )
    var seconds = Float64(perf_counter_ns() - started) / 1e9
    assert_equal(ran.code, EXIT_UNAVAILABLE, String(ran.out, ran.err))
    assert_true("hang.md" in _error_of(ran)["message"].as_string(), ran.out)
    assert_true(seconds < 20.0, String("took ", seconds, " s"))
    _assert_old_docs_kept(project)


def test_ctrl_c_keeps_the_old_docs_and_the_next_pull_cleans_up() raises:
    var site = _site("ctrl_c")
    var folder = join(site, "dev", "mojo-docs", "1.3.1")
    _docs_folder(folder, "Mojo 1.3.1", "- [Slow](hang.md)\n")
    var server = DocsServer(site)
    var project = _project("ctrl_c")
    _ = _old_docs(project)
    var out_path = join(project, "pull.out")
    var dodo = spawn(
        [
            "sh",
            "-c",
            'cd "$1" && shift && exec "$@"',
            "sh",
            project,
            dodo_binary(),
            "docs",
            "pull",
            "mojo@1.3.1",
            "dodo@9.9.9",
        ],
        env=[String("DODO_DOCS_URL=", server.url)],
        stdout_path=out_path,
        stderr_path="&1",
    )
    var tries = 0
    while not server.asked_for("/dev/mojo-docs/1.3.1/hang.md"):
        assert_true(
            tries < 2000,
            String("never asked for hang.md: ", read_or_empty(out_path)),
        )
        sleep(0.01)
        tries += 1
    dodo.send_signal(2)
    var status = dodo.wait()
    assert_equal(status.shell_code(), EXIT_INTERRUPTED)
    var docs = _docs_dir(project)
    assert_equal(
        read_or_empty(join(docs, "mojo-1.3.1", "guide.md")), "old guide"
    )
    _ = run(["rm", "-f", out_path])

    # The fixed archive pulls, and the half-done folder is gone.
    _docs_folder(folder, "Mojo 1.3.1")
    var ran = _pull(project, server.url, ["mojo@1.3.1", "dodo@9.9.9"])
    assert_equal(ran.code, EXIT_OK, String(ran.out, ran.err))
    assert_equal(_listing(docs), "dodo-9.9.9 mojo-1.3.1")


# ── versions that are not there ──


def test_an_unsaved_short_version_lists_the_saved_ones() raises:
    var site = _site("unsaved_short")
    var server = DocsServer(site)
    var project = _project("unsaved_short")
    var ran = _pull(project, server.url, ["mojo@1.4", "dodo@9.9.9", "--json"])
    assert_equal(ran.code, EXIT_UNAVAILABLE, String(ran.out, ran.err))
    var error = _error_of(ran)
    assert_equal(error["kind"].as_string(), "not_found")
    assert_equal(
        error["message"].as_string(),
        "no Mojo 1.4 docs are saved; saved: 1.3.1, 1.3.0, 1.2.0",
    )
    assert_false(exists(join(_docs_dir(project), "mojo-1.4")))


def test_an_unsaved_full_version_lists_the_saved_ones() raises:
    var site = _site("unsaved_full")
    var server = DocsServer(site)
    var project = _project("unsaved_full")
    var ran = _pull(project, server.url, ["mojo@1.2.9", "dodo@8.0.0", "--json"])
    assert_equal(ran.code, EXIT_UNAVAILABLE, String(ran.out, ran.err))
    var result = ran.json()
    assert_equal(
        result["mojo"]["error"]["message"].as_string(),
        "no Mojo 1.2.9 docs are saved; saved: 1.3.1, 1.3.0, 1.2.0",
    )
    assert_equal(
        result["dodo"]["error"]["message"].as_string(),
        String(
            "no dodo 8.0.0 docs are saved; saved: 9.9.9, 9.8.0, ", DODO_VERSION
        ),
    )
    assert_equal(result["error"]["kind"].as_string(), "not_found")
    assert_false(exists(_docs_dir(project)))


def test_a_missing_dodo_version_fails_the_pull_but_keeps_mojo() raises:
    var site = _site("dodo_missing")
    var server = DocsServer(site)
    var project = _project("dodo_missing")
    var ran = _pull(project, server.url, ["mojo@1.3.1", "dodo@8.0.0"])
    assert_equal(ran.code, EXIT_UNAVAILABLE, String(ran.out, ran.err))
    assert_true(ran.out.startswith("Mojo 1.3.1: 4 files"), ran.out)
    assert_true(
        "dodo docs pull: no dodo 8.0.0 docs are saved" in ran.err, ran.err
    )
    assert_equal(_listing(_docs_dir(project)), "mojo-1.3.1")


def test_no_mojo_on_path_and_no_version_named() raises:
    var site = _site("no_mojo")
    var server = DocsServer(site)
    var project = _project("no_mojo")
    var ran = _pull(
        project,
        server.url,
        ["dodo@9.9.9", "--json"],
        env=["PATH=/usr/bin:/bin"],
    )
    assert_equal(ran.code, EXIT_UNAVAILABLE, String(ran.out, ran.err))
    var error = _error_of(ran)
    assert_true(
        "cannot tell the project's Mojo version" in error["message"].as_string()
    )
    assert_true("mojo@" in error["hint"].as_string())
    assert_true(isfile(join(_docs_dir(project), "dodo-9.9.9", "guide.md")))


def test_an_unreachable_server() raises:
    var project = _project("unreachable")
    var ran = _pull(project, _NOWHERE, ["mojo@1.3.1", "dodo@9.9.9", "--json"])
    assert_equal(ran.code, EXIT_UNAVAILABLE, String(ran.out, ran.err))
    var error = _error_of(ran)
    assert_equal(error["kind"].as_string(), "network")
    assert_true("cannot download" in error["message"].as_string(), ran.out)
    assert_false(exists(_docs_dir(project)))


# ── command lines that are wrong ──


def test_wrong_command_lines() raises:
    var project = _project("usage")
    var wrong: List[List[String]] = [
        ["foo@1"],
        ["mojo@"],
        ["mojo1.2"],
        ["mojo@v1.2"],
        ["mojo@1.2.x"],
        ["mojo@1.2.3.4"],
        ["mojo@1.2", "--mojo", "1.3"],
        ["mojo@1", "mojo@2"],
        ["dodo@1", "--dodo=2"],
        ["--dodo="],
        ["--mojo"],
        ["mojo@1", "dodo@1", "dodo@2"],
    ]
    for words in wrong:
        var with_json = words.copy()
        with_json.append("--json")
        var ran = _pull(project, _NOWHERE, with_json)
        var said = String(" ").join(words)
        assert_equal(ran.code, EXIT_USAGE, String(said, ": ", ran.out, ran.err))
        assert_equal(_error_of(ran)["kind"].as_string(), "usage", said)
    assert_false(exists(_docs_dir(project)))


def test_a_bad_timeout_setting() raises:
    var project = _project("timeout_setting")
    for setting in ["abc", "0", "-5", ""]:
        var ran = _pull(
            project,
            _NOWHERE,
            ["mojo@1.3.1", "--json"],
            env=[String("DODO_DOCS_READ_TIMEOUT_MS=", setting)],
        )
        if setting == "":
            # Empty is the same as not set.
            assert_equal(ran.code, EXIT_UNAVAILABLE, ran.out)
            continue
        assert_equal(ran.code, EXIT_USAGE, String(setting, ": ", ran.out))


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
