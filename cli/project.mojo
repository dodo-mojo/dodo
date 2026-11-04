"""Where the project is and which file is its app."""

from std.os.path import dirname, exists, isfile, join, realpath


def find_root(start: String) raises -> String:
    """The nearest folder at or above `start` that holds a `pixi.toml`, or
    `start` itself when there is none (a loose file outside a project)."""
    var dir = realpath(start)
    while True:
        if exists(join(dir, "pixi.toml")):
            return dir
        var parent = dirname(dir)
        if parent == dir or parent == "":
            return realpath(start)
        dir = parent


def entry_file(root: String, given: String, command: String) raises -> String:
    """The app's main file: `given` when the user named one, otherwise
    `main.mojo` in the project root.

    Raises:
        Error: If the file does not exist or is not a `.mojo` file.
    """
    var path = given
    if path == "":
        path = join(root, "main.mojo")
        if not isfile(path):
            raise Error(
                "no main.mojo in ",
                root,
                "; name the app's file: dodo ",
                command,
                " app.mojo",
            )
        return path
    if not path.endswith(".mojo"):
        raise Error("`", path, "` is not a .mojo file")
    if not isfile(path):
        raise Error("no file `", path, "`")
    return realpath(path)


def stem(path: String) -> String:
    """`apps/main.mojo` is `main`."""
    var name = path
    var slash = path.rfind("/")
    if slash >= 0:
        name = String(path[byte = slash + 1 :])
    return drop_suffix(name, ".mojo")


def drop_suffix(text: String, suffix: String) -> String:
    """`text` without `suffix` at its end, when it has one."""
    if not text.endswith(suffix):
        return text
    var keep = text.byte_length() - suffix.byte_length()
    return String(text[byte=:keep])
