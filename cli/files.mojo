"""A project's `.mojo` files and when they last changed."""

from std.os import listdir, remove, stat
from std.os.path import isdir, islink, join


def mojo_files(root: String) raises -> List[String]:
    """Every `.mojo` file under `root`, sorted. `ProjectTree` says which
    folders are skipped."""
    var tree = ProjectTree(root)
    return tree.files.copy()


struct ProjectTree(Movable):
    """The `.mojo` files under a root (sorted), and the folders walked to
    find them with each folder's change time, read before it was listed.

    Skips hidden folders (`.git`, `.pixi`, `.dodo`), `build/`, and folders
    reached through a symlink, so a link loop cannot hang the walk. A
    folder removed during the walk is left out.
    """

    var files: List[String]
    var dirs: List[String]
    var dir_times: List[Int]

    def __init__(out self, root: String) raises:
        """Raises: Error: If `root` cannot be listed."""
        self.files = List[String]()
        self.dirs = List[String]()
        self.dir_times = List[Int]()
        var changed = time_or_zero(root)
        var names = listdir(root)
        self.dirs.append(root)
        self.dir_times.append(changed)
        self._collect(root, names)
        sort(self.files)

    def _collect(mut self, dir: String, names: List[String]):
        for name in names:
            if name.startswith("."):
                continue
            var path = join(dir, name)
            if isdir(path):
                if name == "build" or islink(path):
                    continue
                var changed = time_or_zero(path)
                var inner: List[String]
                try:
                    inner = listdir(path)
                except:
                    continue
                self.dirs.append(path)
                self.dir_times.append(changed)
                self._collect(path, inner)
            elif name.endswith(".mojo"):
                self.files.append(path)


def time_or_zero(path: String) -> Int:
    """`mtime_ns(path)`, or 0 when `path` is gone."""
    try:
        return mtime_ns(path)
    except:
        return 0


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
