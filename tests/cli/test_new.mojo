"""`dodo new`: the name rules, the files it writes, every refusal, and
that the project it makes builds and passes its own tests."""

from std.os import listdir, makedirs, symlink
from std.os.path import exists, isdir, isfile, join, realpath
from std.testing import TestSuite, assert_equal, assert_false, assert_true

from dodo.utils.process import run

from cli.cmd_new import has_content, name_problem, shell_quote
from cli.new_files import COMMUNITY_CHANNEL, fill, project_files
from cli.report import EXIT_OK, EXIT_UNAVAILABLE, EXIT_USAGE
from cli.version import DODO_VERSION

from dodo_cli import dodo_run, read_or_empty, scratch

comptime _FILES: List[String] = [
    "pixi.toml",
    "main.mojo",
    "app.mojo",
    "tests/test_app.mojo",
    "AGENTS.md",
    "CLAUDE.md",
    ".mcp.json",
    ".gitignore",
    ".gitattributes",
]


# ── names ──


def test_good_names() raises:
    for name in ["a", "myapp", "my-app", "my_app", "App2", "x" * 64]:
        assert_equal(name_problem(name), "", name)


def test_bad_names() raises:
    var bad: List[String] = [
        "",
        ".",
        "..",
        "1app",
        "-app",
        "_app",
        "my app",
        "my.app",
        "héllo",
        "a/b",
        "a\tb",
        "x" * 65,
    ]
    for name in bad:
        assert_true(name_problem(name) != "", String("accepted `", name, "`"))


def test_shell_quote() raises:
    assert_equal(shell_quote("myapp"), "myapp")
    assert_equal(shell_quote("../a/b-c_d.e"), "../a/b-c_d.e")
    assert_equal(shell_quote("with space/app"), "'with space/app'")
    assert_equal(shell_quote("it's"), "'it'\\''s'")
    assert_equal(shell_quote("$HOME"), "'$HOME'")
    assert_equal(shell_quote(""), "''")


# ── files ──


def test_fill_puts_every_value_in() raises:
    var text = fill("__NAME__ __DODO_VERSION__ __CHANNEL__", "app", "chan")
    assert_equal(text, String("app ", DODO_VERSION, " chan"))


def test_project_files_are_filled() raises:
    var files = project_files("shop", COMMUNITY_CHANNEL)
    assert_equal(len(files), len(materialize[_FILES]()))
    for file in files:
        for token in ["__NAME__", "__DODO_VERSION__", "__CHANNEL__"]:
            assert_false(token in file.text, String(file.path, " has ", token))
    var toml = files[0].text.copy()
    assert_true('name = "shop"' in toml)
    assert_true(String('dodo = "==', DODO_VERSION, '"') in toml)
    assert_true(COMMUNITY_CHANNEL in toml)


def test_claude_md_imports_agents_md() raises:
    var files = project_files("shop", COMMUNITY_CHANNEL)
    for file in files:
        if file.path == "CLAUDE.md":
            assert_equal(file.text, "@AGENTS.md\n")


def test_has_content() raises:
    var dir = scratch("new_has_content")
    assert_false(has_content(join(dir, "missing")))
    makedirs(join(dir, "empty"))
    assert_false(has_content(join(dir, "empty")))
    makedirs(join(dir, "full", "inner"))
    assert_true(has_content(join(dir, "full")))
    with open(join(dir, "file"), "w") as file:
        file.write("x")
    assert_true(has_content(join(dir, "file")))
    symlink(join(dir, "empty"), join(dir, "link"))
    assert_true(has_content(join(dir, "link")))
    symlink(join(dir, "nowhere"), join(dir, "dangling"))
    assert_true(has_content(join(dir, "dangling")))


# ── the command ──


def _assert_project(path: String) raises:
    for name in materialize[_FILES]():
        assert_true(isfile(join(path, name)), String("missing ", name))


def _assert_nothing_left(dir: String) raises:
    """No hidden `.NAME.new.PID` folder stayed behind."""
    for name in listdir(dir):
        assert_false(".new." in name, String("left behind: ", name))


def test_new_makes_the_project() raises:
    var dir = scratch("new_basic")
    var ran = dodo_run(["new", "shop"], cwd=dir)
    assert_equal(ran.code, EXIT_OK, ran.err)
    assert_true("Created shop in shop" in ran.out)
    assert_true("cd shop\n" in ran.out)
    assert_true("pixi run dodo docs pull" in ran.out)
    _assert_project(join(dir, "shop"))
    assert_true(isdir(join(dir, "shop", ".git")))
    _assert_nothing_left(dir)


def test_new_json() raises:
    var dir = scratch("new_json")
    var ran = dodo_run(["new", "shop", "--json"], cwd=dir)
    assert_equal(ran.code, EXIT_OK, ran.err)
    var result = ran.json()
    assert_true(result["ok"].as_bool())
    assert_equal(result["name"].as_string(), "shop")
    assert_equal(result["path"].as_string(), join(dir, "shop"))
    assert_equal(result["git"].as_string(), "created")
    assert_equal(len(result["files"]), len(materialize[_FILES]()))


def test_new_no_git() raises:
    var dir = scratch("new_no_git")
    var ran = dodo_run(["new", "shop", "--no-git", "--json"], cwd=dir)
    assert_equal(ran.code, EXIT_OK, ran.err)
    assert_equal(ran.json()["git"].as_string(), "off")
    _assert_project(join(dir, "shop"))
    assert_false(exists(join(dir, "shop", ".git")))


def test_new_inside_a_repository_makes_no_repository() raises:
    var dir = scratch("new_in_repo")
    assert_true(run(["git", "init", "-q", dir]).succeeded())
    var ran = dodo_run(["new", "shop", "--json"], cwd=dir)
    assert_equal(ran.code, EXIT_OK, ran.err)
    assert_equal(ran.json()["git"].as_string(), "inside_repo")
    assert_false(exists(join(dir, "shop", ".git")))


def test_new_into_a_nested_and_absolute_path() raises:
    var dir = scratch("new_nested")
    makedirs(join(dir, "apps", "with space"))
    var target = join(dir, "apps", "with space", "shop")
    var ran = dodo_run(["new", target])
    assert_equal(ran.code, EXIT_OK, ran.err)
    _assert_project(target)
    assert_true(String("cd '", target, "'") in ran.out)


def test_new_into_an_empty_folder() raises:
    var dir = scratch("new_empty")
    makedirs(join(dir, "shop"))
    var ran = dodo_run(["new", "shop/"], cwd=dir)
    assert_equal(ran.code, EXIT_OK, ran.err)
    _assert_project(join(dir, "shop"))


def test_new_refuses_what_is_there() raises:
    var dir = scratch("new_exists")
    makedirs(join(dir, "full"))
    with open(join(dir, "full", "keep.txt"), "w") as file:
        file.write("mine")
    with open(join(dir, "afile"), "w") as file:
        file.write("mine")
    symlink(join(dir, "full"), join(dir, "link"))
    symlink(join(dir, "nowhere"), join(dir, "dangling"))
    for name in ["full", "afile", "link", "dangling"]:
        var ran = dodo_run(["new", name, "--json"], cwd=dir)
        assert_equal(ran.code, EXIT_USAGE, name)
        assert_equal(ran.json()["error"]["kind"].as_string(), "exists", name)
    assert_equal(read_or_empty(join(dir, "full", "keep.txt")), "mine")
    assert_equal(read_or_empty(join(dir, "afile")), "mine")
    assert_equal(len(listdir(join(dir, "full"))), 1)
    _assert_nothing_left(dir)


def test_new_refuses_bad_command_lines() raises:
    var dir = scratch("new_usage")
    var lines: List[List[String]] = [
        ["new"],
        ["new", ""],
        ["new", "1app"],
        ["new", "my app"],
        ["new", ".."],
        ["new", "a", "b"],
        ["new", "a", "--bogus"],
        ["new", "missing/folder/app"],
    ]
    for words in lines:
        var ran = dodo_run(words, cwd=dir)
        assert_equal(ran.code, EXIT_USAGE, String(" ").join(words))
        assert_true(ran.err != "")
    assert_equal(len(listdir(dir)), 0)


def test_new_in_a_read_only_folder() raises:
    var dir = scratch("new_read_only")
    makedirs(join(dir, "locked"))
    assert_true(run(["chmod", "555", join(dir, "locked")]).succeeded())
    var ran = dodo_run(["new", "locked/shop", "--json"], cwd=dir)
    _ = run(["chmod", "755", join(dir, "locked")])
    assert_equal(ran.code, EXIT_UNAVAILABLE)
    var error = ran.json()["error"].copy()
    assert_equal(error["kind"].as_string(), "disk")
    assert_false(
        ".new." in error["message"].as_string(), "names the hidden folder"
    )
    assert_equal(len(listdir(join(dir, "locked"))), 0)


def test_new_that_fails_half_way_leaves_nothing() raises:
    """A `git` whose `init` fails stops the command after the files are
    written; the hidden folder must go and no project must appear."""
    var dir = scratch("new_half_way")
    makedirs(join(dir, "bin"))
    var fake_git = join(dir, "bin", "git")
    with open(fake_git, "w") as file:
        file.write(_FAILING_GIT)
    assert_true(run(["chmod", "755", fake_git]).succeeded())
    var path = String("PATH=", join(dir, "bin"), ":/usr/bin:/bin")
    makedirs(join(dir, "work"))
    var ran = dodo_run(
        ["new", "shop", "--json"], env=[path], cwd=join(dir, "work")
    )
    assert_equal(ran.code, EXIT_UNAVAILABLE, ran.out)
    assert_equal(ran.json()["error"]["kind"].as_string(), "disk")
    assert_equal(len(listdir(join(dir, "work"))), 0)


comptime _FAILING_GIT = """#!/bin/sh
case "$1" in
    --version) echo "git version 0.0.0"; exit 0 ;;
    init) echo "init refused" >&2; exit 1 ;;
    *) exit 1 ;;
esac
"""


def test_new_without_git_on_path() raises:
    var dir = scratch("new_no_git_on_path")
    var ran = dodo_run(
        ["new", "shop", "--json"], env=["PATH=/nonexistent"], cwd=dir
    )
    assert_equal(ran.code, EXIT_UNAVAILABLE)
    assert_equal(ran.json()["error"]["kind"].as_string(), "unavailable")
    assert_false(exists(join(dir, "shop")))
    var no_git = dodo_run(
        ["new", "shop", "--no-git"], env=["PATH=/nonexistent"], cwd=dir
    )
    assert_equal(no_git.code, EXIT_OK, no_git.err)


def test_package_channel_can_be_swapped() raises:
    var dir = scratch("new_channel")
    var ran = dodo_run(
        ["new", "shop"],
        env=["DODO_PACKAGE_CHANNEL=file:///local/conda"],
        cwd=dir,
    )
    assert_equal(ran.code, EXIT_OK, ran.err)
    var toml = read_or_empty(join(dir, "shop", "pixi.toml"))
    assert_true('"file:///local/conda"' in toml)
    assert_false(COMMUNITY_CHANNEL in toml)


# ── the project it makes ──


def test_new_project_builds_and_passes_its_tests() raises:
    """Builds against this checkout's `dodo`, so a change to dodo's API
    that breaks the templates fails here."""
    var dir = scratch("new_builds")
    var ran = dodo_run(["new", "shop", "--no-git"], cwd=dir)
    assert_equal(ran.code, EXIT_OK, ran.err)
    var project = join(dir, "shop")
    var repo = realpath(".")
    for entry in ["tests/test_app.mojo", "main.mojo"]:
        var binary = join(dir, String(entry).replace("/", "_") + ".bin")
        var log = join(dir, "build.log")
        var built = run(
            [
                "mojo",
                "build",
                "-I",
                repo,
                "-I",
                project,
                join(project, entry),
                "-o",
                binary,
            ],
            stdout_path=log,
            stderr_path="&1",
        )
        assert_true(built.succeeded(), read_or_empty(log))
    var log = join(dir, "test.log")
    var tested = run(
        [join(dir, "tests_test_app.mojo.bin")],
        stdout_path=log,
        stderr_path="&1",
    )
    assert_true(tested.succeeded(), read_or_empty(log))
    assert_true("3 passed" in read_or_empty(log), read_or_empty(log))


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
