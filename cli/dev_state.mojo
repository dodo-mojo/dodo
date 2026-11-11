"""What a running `dodo dev` leaves for the other commands.

`dodo dev` keeps its session in `.dodo/dev/` of the project:

- `state.json`: dodo's pid, the URL, the app's pid and the latest events.
  It is rewritten on every event by a rename, so a reader never sees half
  of it.
- `app.out` and `app.err`: what the app now running printed to stdout and
  stderr. Each start of the app begins them again.

`dodo logs`, `dodo request` and `dodo mcp` read them.
"""

from std.ffi import external_call
from std.os import makedirs
from std.os.path import join

from dodo.json import Value, dumps, loads

from .docs_folder import move_path
from .files import read_text, remove_if_there

comptime MAX_EVENTS = 50
"""How many of the latest events `state.json` keeps."""
comptime MAX_EVENT_LOG_BYTES = 65536
"""How much of a failed build's compiler output an event keeps."""


def dev_dir(root: String) -> String:
    return join(root, ".dodo", "dev")


def state_path(root: String) -> String:
    return join(dev_dir(root), "state.json")


def app_out_path(root: String) -> String:
    return join(dev_dir(root), "app.out")


def app_err_path(root: String) -> String:
    return join(dev_dir(root), "app.err")


def read_state(root: String) -> Optional[Value]:
    """The saved session, or None when there is none or it cannot be
    read."""
    var text = read_text(state_path(root))
    if text == "":
        return None
    try:
        var state = loads(text)
        if state.is_object():
            return state^
    except:
        pass
    return None


def write_state(root: String, state: Value) raises:
    """Save `state` as `state.json`, whole or not at all.

    Raises:
        Error: If the folder or the file cannot be written.
    """
    makedirs(dev_dir(root), exist_ok=True)
    var path = state_path(root)
    var temporary = String(path, ".", process_id(), ".tmp")
    try:
        with open(temporary, "w") as file:
            file.write(dumps(state))
        move_path(temporary, path)
    except e:
        remove_if_there(temporary)
        raise e^


def is_running(state: Value) -> Bool:
    """Whether the `dodo dev` that wrote `state` is still running. A dodo
    killed outright never marks its state stopped, so its pid is checked
    too."""
    try:
        if not state["running"].as_bool():
            return False
        return process_alive(Int(state["pid"].as_int()))
    except:
        return False


def process_alive(pid: Int) -> Bool:
    """`kill(pid, 0)`: whether a process with this pid exists."""
    if pid <= 0:
        return False
    var rc = external_call["kill", Int32](Int32(pid), Int32(0))
    return rc == 0


def process_id() -> Int:
    return Int(external_call["getpid", Int32]())


def unix_time() -> Int:
    """Seconds since 1970, from the wall clock."""
    return Int(external_call["time", Int64](Int(0)))
