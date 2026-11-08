"""Swapping a downloaded docs folder in place of the old one."""

from std.os import getenv, listdir, makedirs, symlink
from std.os.path import exists, isfile, join, realpath
from std.testing import (
    TestSuite,
    assert_equal,
    assert_false,
    assert_raises,
    assert_true,
)

from dodo.utils.process import run

from cli.docs_folder import move_path, remove_tree, swap_in, write_file


def _scratch(name: String) raises -> String:
    var dir = join(getenv("TMPDIR", "/tmp"), String("dodo_docs_folder_", name))
    _ = run(["rm", "-rf", dir])
    makedirs(dir, exist_ok=True)
    return realpath(dir)


def _write(path: String, text: String) raises:
    write_file(path, text.as_bytes())


def _read(path: String) raises -> String:
    with open(path, "r") as file:
        return file.read()


def test_write_file_makes_its_folders() raises:
    var dir = _scratch("write")
    var path = join(dir, "a", "b", "c.md")
    _write(path, "hello")
    assert_equal(_read(path), "hello")
    _write(path, "again")
    assert_equal(_read(path), "again")


def test_remove_tree_deletes_everything_under_it() raises:
    var dir = _scratch("tree")
    _write(join(dir, "top", "a.md"), "a")
    _write(join(dir, "top", "deep", "er", "b.md"), "b")
    _write(join(dir, "top", ".hidden"), "c")
    makedirs(join(dir, "top", "empty"))
    remove_tree(join(dir, "top"))
    assert_false(exists(join(dir, "top")))


def test_remove_tree_deletes_a_link_but_not_what_it_points_to() raises:
    var dir = _scratch("link")
    _write(join(dir, "keep", "precious.md"), "keep me")
    _write(join(dir, "top", "a.md"), "a")
    symlink(join(dir, "keep"), join(dir, "top", "to_keep"))
    symlink(join(dir, "keep"), join(dir, "link_itself"))
    remove_tree(join(dir, "top"))
    remove_tree(join(dir, "link_itself"))
    assert_false(exists(join(dir, "top")))
    assert_false(exists(join(dir, "link_itself")))
    assert_equal(_read(join(dir, "keep", "precious.md")), "keep me")


def test_remove_tree_of_nothing_or_a_file() raises:
    var dir = _scratch("nothing")
    remove_tree(join(dir, "not_there"))
    _write(join(dir, "file.md"), "x")
    remove_tree(join(dir, "file.md"))
    assert_false(exists(join(dir, "file.md")))


def test_move_path_fails_loudly() raises:
    var dir = _scratch("move")
    with assert_raises(contains="cannot move"):
        move_path(join(dir, "missing"), join(dir, "elsewhere"))


def test_swap_in_replaces_the_old_folder() raises:
    var dir = _scratch("swap")
    _write(join(dir, "docs", "old.md"), "old")
    _write(join(dir, "docs", "both.md"), "old")
    _write(join(dir, ".new", "both.md"), "new")
    _write(join(dir, ".new", "sub", "fresh.md"), "new")
    swap_in(join(dir, ".new"), join(dir, "docs"))
    assert_false(exists(join(dir, "docs", "old.md")), "an old file stayed")
    assert_equal(_read(join(dir, "docs", "both.md")), "new")
    assert_equal(_read(join(dir, "docs", "sub", "fresh.md")), "new")
    assert_false(exists(join(dir, ".new")))
    assert_equal(len(listdir(dir)), 1, "something was left next to it")


def test_swap_in_with_no_old_folder() raises:
    var dir = _scratch("first")
    _write(join(dir, ".new", "a.md"), "a")
    swap_in(join(dir, ".new"), join(dir, "docs"))
    assert_equal(_read(join(dir, "docs", "a.md")), "a")


def test_swap_in_clears_a_leftover_from_a_crash() raises:
    var dir = _scratch("leftover")
    _write(join(dir, ".docs.old", "stale.md"), "stale")
    _write(join(dir, "docs", "old.md"), "old")
    _write(join(dir, ".new", "a.md"), "a")
    swap_in(join(dir, ".new"), join(dir, "docs"))
    assert_false(exists(join(dir, ".docs.old")))
    assert_true(isfile(join(dir, "docs", "a.md")))


def test_a_failed_swap_keeps_the_old_folder() raises:
    var dir = _scratch("failed")
    _write(join(dir, "docs", "old.md"), "old")
    with assert_raises(contains="cannot move"):
        swap_in(join(dir, "never_made"), join(dir, "docs"))
    assert_equal(_read(join(dir, "docs", "old.md")), "old")
    assert_false(exists(join(dir, ".docs.old")))


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
