"""Tests for `dodo dev`'s pieces: the file watcher and the flag parsers.
The whole command is tested end to end in `test_e2e.mojo`."""

from std.os import getenv, makedirs, remove
from std.os.path import join, realpath
from std.testing import (
    TestSuite,
    assert_equal,
    assert_false,
    assert_raises,
    assert_true,
)
from std.time import sleep

from dodo.net import IpAddr
from dodo.utils.process import run

from cli.cmd_dev import parse_host, parse_port, url_of
from cli.files import ProjectTree
from cli.watch import Watcher


def _scratch(name: String) raises -> String:
    var dir = join(getenv("TMPDIR", "/tmp"), String("dodo_cli_test_", name))
    _ = run(["rm", "-rf", dir])
    makedirs(dir, exist_ok=True)
    return realpath(dir)


def _write(path: String, text: String) raises:
    """Write `path` a little later, so its change time moves."""
    sleep(0.01)
    with open(path, "w") as file:
        file.write(text)


def _project(name: String) raises -> String:
    var dir = _scratch(name)
    makedirs(join(dir, "src"), exist_ok=True)
    _write(join(dir, "main.mojo"), "def main():\n    pass\n")
    _write(join(dir, "src", "lib.mojo"), "def f():\n    pass\n")
    return dir


# ── watcher ──


def test_nothing_changed() raises:
    var dir = _project("watch_still")
    var watcher = Watcher(dir)
    assert_false(watcher.changed())
    assert_false(watcher.changed())


def test_edit_is_seen_once() raises:
    var dir = _project("watch_edit")
    var watcher = Watcher(dir)
    _write(join(dir, "src", "lib.mojo"), "def f():\n    print(1)\n")
    assert_true(watcher.changed())
    assert_false(watcher.changed())


def test_new_file_is_seen() raises:
    var dir = _project("watch_new")
    var watcher = Watcher(dir)
    _write(join(dir, "src", "more.mojo"), "def g():\n    pass\n")
    assert_true(watcher.changed())
    assert_equal(len(watcher.files), 3)
    assert_false(watcher.changed())


def test_removed_file_is_seen() raises:
    var dir = _project("watch_removed")
    var watcher = Watcher(dir)
    remove(join(dir, "src", "lib.mojo"))
    assert_true(watcher.changed())
    assert_equal(len(watcher.files), 1)


def test_save_by_rename_is_seen() raises:
    # Many editors write a new file and rename it over the old one.
    var dir = _project("watch_rename")
    var watcher = Watcher(dir)
    var temp = join(dir, "src", "lib.mojo.tmp")
    _write(temp, "def f():\n    print(2)\n")
    assert_false(watcher.changed(), "a .tmp file is not a .mojo file")
    _ = run(["mv", temp, join(dir, "src", "lib.mojo")])
    assert_true(watcher.changed())


def test_new_folder_with_a_file_is_seen() raises:
    var dir = _project("watch_folder")
    var watcher = Watcher(dir)
    makedirs(join(dir, "src", "deep"), exist_ok=True)
    assert_false(watcher.changed(), "an empty folder holds no .mojo file")
    _write(join(dir, "src", "deep", "x.mojo"), "def x():\n    pass\n")
    assert_true(watcher.changed())


def test_other_files_and_skipped_folders_are_ignored() raises:
    var dir = _project("watch_ignored")
    makedirs(join(dir, ".dodo"), exist_ok=True)
    makedirs(join(dir, "build"), exist_ok=True)
    var watcher = Watcher(dir)
    _write(join(dir, "notes.md"), "notes")
    _write(join(dir, ".dodo", "x.mojo"), "def x():\n    pass\n")
    _write(join(dir, "build", "x.mojo"), "def x():\n    pass\n")
    assert_false(watcher.changed())


def test_missing_root_raises() raises:
    var dir = _project("watch_gone")
    var watcher = Watcher(dir)
    _ = run(["rm", "-rf", dir])
    with assert_raises():
        _ = watcher.changed()


def test_tree_lists_folders_with_times() raises:
    var dir = _project("watch_tree")
    var tree = ProjectTree(dir)
    assert_equal(len(tree.dirs), 2)
    assert_equal(tree.dirs[0], dir)
    assert_equal(tree.dirs[1], join(dir, "src"))
    assert_true(tree.dir_times[0] > 0)
    assert_equal(len(tree.files), 2)


# ── flags ──


def test_parse_port() raises:
    assert_equal(parse_port("8000"), 8000)
    assert_equal(parse_port("0"), 0)
    assert_equal(parse_port("65535"), 65535)
    assert_equal(parse_port("00080"), 80)
    for bad in ["", "65536", "-1", "80a", "123456", " 80", "+80", "1e3"]:
        with assert_raises(contains="--port"):
            _ = parse_port(bad)


def test_parse_host() raises:
    assert_equal(String(parse_host("127.0.0.1")), "127.0.0.1")
    assert_equal(String(parse_host("localhost")), "127.0.0.1")
    assert_equal(String(parse_host("0.0.0.0")), "0.0.0.0")
    assert_true(parse_host("::1").is_v6())
    for bad in ["", "example.com", "1.2.3", "127.0.0.1:80", "[::1]"]:
        with assert_raises(contains="--host"):
            _ = parse_host(bad)


def test_url_of() raises:
    assert_equal(
        url_of(IpAddr.parse("127.0.0.1"), 8000), "http://127.0.0.1:8000"
    )
    assert_equal(url_of(IpAddr.parse("::1"), 80), "http://[::1]:80")


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
