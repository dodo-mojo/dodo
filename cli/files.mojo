"""A project's `.mojo` files and when they last changed."""

from std.os import listdir, remove, stat
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


def is_test_file(path: String) -> Bool:
    """`test_*.mojo`, the files `dodo test` runs."""
    var name = path
    var slash = path.rfind("/")
    if slash >= 0:
        name = String(path[byte = slash + 1 :])
    return name.startswith("test_") and name.endswith(".mojo")


def imports_a_test_file(source: String) -> Bool:
    """Whether `source` imports a `test_*` module, as in
    `from test_helpers import ...` or `import tests.test_x`."""
    for line in source.splitlines():
        var words = String(line.strip()).split(" ")
        if len(words) < 2:
            continue
        var keyword = String(words[0])
        if keyword != "from" and keyword != "import":
            continue
        for part in String(words[1]).split("."):
            if part.startswith("test_"):
                return True
    return False


def build_inputs(root: String, entry: String) raises -> List[String]:
    """The project files a build of `entry` may read: every `.mojo` file,
    except other test files when `entry` imports none of them. So editing
    one test rebuilds that test alone."""
    var files = mojo_files(root)
    var source: String
    with open(entry, "r") as file:
        source = file.read()
    if imports_a_test_file(source):
        return files^
    var inputs = List[String]()
    for path in files:
        if path == entry or not is_test_file(path):
            inputs.append(path)
    return inputs^


def read_text(path: String) -> String:
    """The file's text, or "" when it cannot be read."""
    try:
        with open(path, "r") as file:
            return file.read()
    except:
        return ""


def remove_if_there(path: String):
    """Delete `path`; a file that is already gone is fine."""
    try:
        remove(path)
    except:
        pass


def tail_text(text: String, max_bytes: Int) -> String:
    """The last `max_bytes` of `text`, cut at a line start."""
    if text.byte_length() <= max_bytes:
        return text
    var start = text.byte_length() - max_bytes
    var newline = text.find("\n", start)
    if newline >= 0:
        start = newline + 1
    return String("[earlier output cut]\n", text[byte=start:])
