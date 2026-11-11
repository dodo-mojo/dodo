"""`dodo new NAME`: make a new project folder.

It only writes files; it never downloads. The files go into a hidden
folder next to the target first and are moved into place at the end, so
a failure leaves nothing behind. A folder that already has files in it
is refused.
"""

from std.ffi import external_call
from std.os import listdir
from std.os.path import (
    basename,
    dirname,
    exists,
    isdir,
    islink,
    join,
    realpath,
)

from dodo.json import Value

from .args import ParsedArgs
from .capture import capture
from .docs_folder import move_path, remove_tree, write_file
from .new_files import package_channel, project_files
from .report import EXIT_OK, EXIT_UNAVAILABLE, EXIT_USAGE, Report

comptime MAX_NAME_BYTES = 64

comptime GIT_CREATED = "created"
comptime GIT_INSIDE_REPO = "inside_repo"
"""The folder is inside a git repository already, so none was made."""
comptime GIT_OFF = "off"
"""`--no-git`."""


def cmd_new(parsed: ParsedArgs, mut report: Report) raises -> Int:
    if len(parsed.positionals) == 0:
        return report.fail(
            "usage",
            "name the project",
            EXIT_USAGE,
            hint="dodo new NAME",
        )
    var given = String(parsed.positionals[0])
    var target = String(given.rstrip("/"))
    var name = basename(target)
    var problem = name_problem(name)
    if problem != "":
        return report.fail("usage", problem, EXIT_USAGE)

    var parent = dirname(target)
    if parent == "":
        parent = "."
    if not isdir(parent):
        return report.fail(
            "not_found",
            String("no folder `", parent, "` to put `", name, "` in"),
            EXIT_USAGE,
        )
    parent = realpath(parent)
    if not can_write(parent):
        return report.fail(
            "disk",
            String("cannot write in `", parent, "`"),
            EXIT_UNAVAILABLE,
            hint="check the folder's permissions",
        )
    var path = join(parent, name)
    if has_content(path):
        return report.fail(
            "exists",
            String("`", path, "` already exists"),
            EXIT_USAGE,
            hint="pick another name, or empty the folder",
        )

    var git = GIT_OFF
    if not parsed.has("no-git"):
        if not git_installed():
            return report.fail(
                "unavailable",
                "git is not on PATH",
                EXIT_UNAVAILABLE,
                hint="install git, or pass --no-git",
            )
        git = GIT_CREATED
        if inside_git_repo(parent):
            git = GIT_INSIDE_REPO

    var files = project_files(name, package_channel())
    var staging = join(parent, String(".", name, ".new.", _pid()))
    try:
        remove_tree(staging)
        for file in files:
            write_file(join(staging, file.path), file.text.as_bytes())
        if git == GIT_CREATED:
            git_init(staging)
        move_path(staging, path)
    except e:
        _remove_quietly(staging)
        if has_content(path):
            return report.fail(
                "exists",
                String("`", path, "` was made by something else meanwhile"),
                EXIT_USAGE,
            )
        return report.fail(
            "disk",
            String("cannot write in `", parent, "`: ", first_line(String(e))),
            EXIT_UNAVAILABLE,
        )

    report.say(created_message(name, given, git))
    report.set("name", Value(name))
    report.set("path", Value(path))
    report.set("git", Value(git))
    var listed = Value.array()
    for file in files:
        listed.append(Value(file.path))
    report.set("files", listed^)
    return EXIT_OK


def name_problem(name: String) -> String:
    """Why `name` cannot be a project name, or "" when it can. A name
    starts with a letter and has only ASCII letters, digits, `-` and `_`.
    """
    if name == "" or name == "." or name == "..":
        return "name the project"
    if name.byte_length() > MAX_NAME_BYTES:
        return String("`", name, "` is longer than ", MAX_NAME_BYTES, " bytes")
    var bytes = name.as_bytes()
    if not _is_letter(bytes[0]):
        return String("`", name, "` must start with a letter")
    for byte in bytes:
        if _is_letter(byte) or _is_digit(byte):
            continue
        if byte == UInt8(ord("-")) or byte == UInt8(ord("_")):
            continue
        return String("`", name, "` may have only letters, digits, `-` and `_`")
    return ""


def has_content(path: String) -> Bool:
    """Whether `path` is there and is not an empty folder. A symlink
    counts as there, even one that points nowhere."""
    if islink(path):
        return True
    if not exists(path):
        return False
    if not isdir(path):
        return True
    try:
        return len(listdir(path)) > 0
    except:
        return True


def can_write(folder: String) -> Bool:
    """`access(2)` with `W_OK`."""
    comptime W_OK = 2
    var path = folder
    var rc = external_call["access", Int32](
        path.as_c_string_span(), Int32(W_OK)
    )
    return rc == 0


def git_installed() -> Bool:
    try:
        return capture(["git", "--version"]).status.succeeded()
    except:
        return False


def inside_git_repo(folder: String) -> Bool:
    try:
        var result = capture(
            ["git", "-C", folder, "rev-parse", "--is-inside-work-tree"]
        )
        if not result.status.succeeded():
            return False
        return String(result.output.strip()) == "true"
    except:
        return False


def git_init(folder: String) raises:
    """Raises: Error: If `git init` fails."""
    var result = capture(["git", "init", "-q", folder])
    if not result.status.succeeded():
        raise Error("git init failed: ", result.output.strip())


def created_message(name: String, given: String, git: String) -> String:
    var text = String("Created ", name, " in ", given)
    if git == GIT_INSIDE_REPO:
        text += " (inside a git repository, so no new one)"
    text += "\n\nNext:\n"
    text += String("  cd ", shell_quote(given), "\n")
    text += "  pixi run dodo docs pull\n"
    text += "  pixi run dodo dev"
    return text^


def shell_quote(word: String) -> String:
    """`word` as one shell word: as it is when it is plain, otherwise in
    single quotes."""
    var plain = True
    for byte in word.as_bytes():
        if not _is_plain_shell_byte(byte):
            plain = False
            break
    if plain and word != "":
        return word
    return String("'", word.replace("'", "'\\''"), "'")


def first_line(text: String) -> String:
    var newline = text.find("\n")
    if newline < 0:
        return text
    return String(text[byte=:newline])


def _is_plain_shell_byte(byte: UInt8) -> Bool:
    if _is_letter(byte) or _is_digit(byte):
        return True
    for allowed in "-_./".as_bytes():
        if byte == allowed:
            return True
    return False


def _is_letter(byte: UInt8) -> Bool:
    if byte >= UInt8(ord("a")) and byte <= UInt8(ord("z")):
        return True
    return byte >= UInt8(ord("A")) and byte <= UInt8(ord("Z"))


def _is_digit(byte: UInt8) -> Bool:
    return byte >= UInt8(ord("0")) and byte <= UInt8(ord("9"))


def _pid() -> Int:
    return Int(external_call["getpid", Int32]())


def _remove_quietly(path: String):
    try:
        remove_tree(path)
    except:
        pass
