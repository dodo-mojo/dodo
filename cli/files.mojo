"""A project's `.mojo` files and when they last changed."""

from std.os import listdir, stat
from std.os.path import isdir, islink, join


def mojo_files(root: String) raises -> List[String]:
    """Every `.mojo` file under `root`, sorted.

    Skips hidden folders (`.git`, `.pixi`, `.dodo`), `build/`, and folders
    reached through a symlink, so a link loop cannot hang the walk.
    """
    var found = List[String]()
    _collect(root, found)
    sort(found)
    return found^


def _collect(dir: String, mut found: List[String]) raises:
    for name in listdir(dir):
        if name.startswith("."):
            continue
        var path = join(dir, name)
        if isdir(path):
            if name == "build" or islink(path):
                continue
            _collect(path, found)
        elif name.endswith(".mojo"):
            found.append(path)


def mtime_ns(path: String) raises -> Int:
    """When `path` last changed, in nanoseconds."""
    return stat(path).st_mtimespec.as_nanoseconds()


def newest_mtime_ns(paths: List[String]) -> Int:
    """The newest change time among `paths`, or 0 for none."""
    var newest = 0
    for path in paths:
        var changed: Int
        try:
            changed = mtime_ns(path)
        except:
            # Deleted since the walk listed it.
            continue
        if changed > newest:
            newest = changed
    return newest
