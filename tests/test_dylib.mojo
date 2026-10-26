"""Tests for :func:`dodo.utils.dylib.find_dodo_lib`'s search order."""

from std.os import getenv, setenv, unsetenv
from std.testing import assert_equal, assert_false

from dodo.utils.dylib import find_dodo_lib


def test_never_resolves_against_the_working_directory() raises:
    """With no CONDA_PREFIX the resolver returned
    ``build/libdodo_<name>.so``, which dlopen reads relative to the
    working directory: a program started in a directory someone else
    could write to loaded their library."""
    var saved_prefix = getenv("CONDA_PREFIX", "")
    var saved_dir = getenv("DODO_LIB_DIR", "")
    _ = unsetenv("CONDA_PREFIX")
    _ = unsetenv("DODO_LIB_DIR")
    var bare = find_dodo_lib("tls")
    _ = setenv("DODO_LIB_DIR", "relative/dir")
    var relative = find_dodo_lib("tls")
    _ = setenv("DODO_LIB_DIR", "/opt/dodo/lib")
    var explicit = find_dodo_lib("tls")
    _ = setenv("CONDA_PREFIX", saved_prefix)
    if saved_dir != "":
        _ = setenv("DODO_LIB_DIR", saved_dir)
    else:
        _ = unsetenv("DODO_LIB_DIR")
    assert_equal(bare, "libdodo_tls.so")
    assert_false("/" in relative, "a relative DODO_LIB_DIR was used")
    assert_equal(explicit, "/opt/dodo/lib/libdodo_tls.so")


def main() raises:
    test_never_resolves_against_the_working_directory()
    print("test_dylib: 1 passed")
