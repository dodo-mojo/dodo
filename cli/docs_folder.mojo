"""Putting a freshly downloaded docs folder in place of the old one, so a
pull that fails half way never leaves the docs half deleted."""

from std.ffi import external_call
from std.os import listdir, makedirs, remove, rmdir
from std.os.path import basename, dirname, exists, isdir, islink, join


def remove_tree(path: String) raises:
    """Delete `path` and everything under it. A symlink is deleted, never
    followed. A path that is not there is fine.

    Raises:
        Error: If something under `path` cannot be deleted.
    """
    if islink(path):
        remove(path)
        return
    if not exists(path):
        return
    if not isdir(path):
        remove(path)
        return
    for name in listdir(path):
        remove_tree(join(path, name))
    rmdir(path)


def move_path(old: String, new: String) raises:
    """Rename `old` to `new` in one step (`rename(2)`). Both must be on the
    same disk; `new` must not be a folder that has files in it.

    Raises:
        Error: If the rename fails.
    """
    var from_path = old
    var to_path = new
    var rc = external_call["rename", Int32](
        from_path.as_c_string_span(), to_path.as_c_string_span()
    )
    if rc != 0:
        raise Error("cannot move ", old, " to ", new)


def swap_in(staging: String, target: String) raises:
    """Put the finished folder `staging` at `target`.

    The old `target` is moved aside first (to a hidden `.NAME.old` next
    to it) and deleted only once the new one is in place. If the new one
    cannot be moved in, the old one is moved back.

    Raises:
        Error: If the folders cannot be moved.
    """
    var aside = join(dirname(target), String(".", basename(target), ".old"))
    remove_tree(aside)
    var had_old = exists(target) or islink(target)
    if had_old:
        move_path(target, aside)
    try:
        move_path(staging, target)
    except e:
        if had_old:
            move_path(aside, target)
        raise e^
    remove_tree(aside)


def write_file(path: String, data: Span[UInt8, _]) raises:
    """Write `data` to `path`, making its folders first.

    Raises:
        Error: If the folders or the file cannot be written.
    """
    var folder = dirname(path)
    if folder != "":
        makedirs(folder, exist_ok=True)
    with open(path, "w") as file:
        file.write_all(data)
