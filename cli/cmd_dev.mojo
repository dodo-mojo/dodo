"""`dodo dev [FILE] [-- ARGS...]`: run the app and restart it on every save.

dodo binds the port itself and holds it for the whole session. Each app
it starts gets the listening socket as `DODO_LISTEN_FD` and serves on it
instead of binding (`App.serve` does this), so a request sent during a
restart waits in the socket's queue and is answered by the new app.

Every 200 ms dodo checks the project's `.mojo` files (`Watcher`). When
one changed and the build is out of date, it builds while the old app
keeps serving. Only a good build replaces the app: the old one gets
SIGTERM and finishes its in-flight requests, then the new one starts. A
failed build prints the compiler's errors and leaves the old app running.
An app that exits by itself starts again on the next change.

The app writes to `.dodo/dev/app.out` and `app.err`; dodo copies each new
line to its own stdout and stderr, and keeps the session (URL, pids, the
latest events) in `.dodo/dev/state.json` for `dodo logs`, `dodo request`
and `dodo mcp`. One project runs one `dodo dev` at a time.

The app and each build run in a process group of their own, so Ctrl-C
reaches only dodo, which stops the app the same way and exits with 130.
A second Ctrl-C, half a second or more after the first, kills the app at
once. With `--json`, each event is one
line on stdout, `{"dodo_dev": {"event": ...}}`, among whatever the app
prints, and the usual result object ends the session.
"""

from std.os import makedirs
from std.os.path import join
from std.sys import stderr
from std.time import perf_counter_ns, sleep

from dodo.json import Value, dumps
from dodo.net import IpAddr, SocketAddr
from dodo.tcp import TcpListener
from dodo.utils.process import Child, ExitStatus, set_inherited, spawn
from dodo.utils.signals import stop_watching_signals, take_signal, watch_signals

from .app_output import OutputCopy
from .args import ParsedArgs
from .build import BuildPlan, finish_build, start_build
from .dev_state import (
    MAX_EVENTS,
    MAX_EVENT_LOG_BYTES,
    app_err_path,
    app_out_path,
    dev_dir,
    is_running,
    process_id,
    read_state,
    unix_time,
    write_state,
)
from .files import tail_text
from .project import entry_file, find_root
from .report import (
    EXIT_INTERRUPTED,
    EXIT_UNAVAILABLE,
    EXIT_USAGE,
    Report,
    format_seconds,
)
from .watch import Watcher

comptime _WATCH_NS = 200_000_000
"""How often the project's files are checked (0.2 s)."""
comptime _COPY_SECONDS = 0.02
"""How often the app's new output is copied to the terminal."""
comptime _STEP_SECONDS = 0.005
"""How often a running build or a stopping app is checked."""
comptime _STOP_GRACE_NS = 10_000_000_000
"""How long a stopping app may drain (10 s) before it is killed.
`App.serve` drains for up to 5 s by default."""
comptime _SAME_SIGNAL_NS = 500_000_000
"""Signals within 0.5 s of a stop are the same Ctrl-C arriving twice
(`pixi run` passes it on as well), not a second press."""
comptime _SIGTERM = 15

# What a step of the session ended with.
comptime _GO_ON = 0
comptime _SIGNALLED = 1
comptime _NO_MOJO = 2
comptime _BUILD_FAILED = 3


struct _Session(Movable):
    """What one `dodo dev` run works with."""

    var root: String
    var entry: String
    var out_dir: String
    var listen_fd: Int
    var app_args: List[String]
    var json_mode: Bool
    var app: Optional[Child]
    """The app now running, if any."""
    var state: Value
    """What `.dodo/dev/state.json` holds."""
    var out_copy: OutputCopy
    var err_copy: OutputCopy

    def __init__(
        out self,
        root: String,
        entry: String,
        listen_fd: Int,
        var app_args: List[String],
        json_mode: Bool,
        url: String,
    ) raises:
        self.root = root
        self.entry = entry
        self.out_dir = join(root, ".dodo", "build")
        self.listen_fd = listen_fd
        self.app_args = app_args^
        self.json_mode = json_mode
        self.app = None
        self.state = Value.object()
        self.state["running"] = Value(True)
        self.state["pid"] = Value(process_id())
        self.state["url"] = Value(url)
        self.state["file"] = Value(entry)
        self.state["started"] = Value(unix_time())
        self.state["app_pid"] = Value(0)
        self.state["events"] = Value.array()
        self.out_copy = OutputCopy(app_out_path(root), 1)
        self.err_copy = OutputCopy(app_err_path(root), 2)


def cmd_dev(parsed: ParsedArgs, mut report: Report) raises -> Int:
    var port: Int
    var ip: IpAddr
    try:
        port = parse_port(parsed.value("port", "8000"))
        ip = parse_host(parsed.value("host", "127.0.0.1"))
    except e:
        return report.fail("usage", String(e), EXIT_USAGE)

    var root = find_root(".")
    var given = String("")
    if len(parsed.positionals) > 0:
        given = parsed.positionals[0]
    var entry: String
    try:
        entry = entry_file(root, given, "dev")
    except e:
        return report.fail("not_found", String(e), EXIT_USAGE)

    var previous = read_state(root)
    if previous and is_running(previous.value()):
        var other = previous.value().copy()
        return report.fail(
            "busy",
            String(
                "`dodo dev` already runs for this project (pid ",
                other.get("pid", Value(0)).int_or(0),
                ", ",
                other.get("url", Value("?")).string_or("?"),
                ")",
            ),
            EXIT_UNAVAILABLE,
            hint="stop it first; `dodo logs` shows what it printed",
        )

    var listener: TcpListener
    try:
        listener = TcpListener.bind(SocketAddr(ip, UInt16(port)))
    except e:
        return report.fail(
            "listen",
            String("cannot listen on ", url_of(ip, port), ": ", e),
            EXIT_UNAVAILABLE,
            hint="pick another port with --port",
        )
    var fd = Int(listener.as_raw_fd())
    set_inherited(fd, True)
    var url = url_of(ip, Int(listener.local_addr().port))
    report.set("url", Value(url))

    makedirs(dev_dir(root), exist_ok=True)
    var session = _Session(
        root, entry, fd, parsed.passthrough.copy(), report.json_mode, url
    )
    var fields = Value.object()
    fields["url"] = Value(url)
    fields["file"] = Value(entry)
    _event(
        session,
        "listening",
        fields^,
        String("dodo dev: serving ", entry, " on ", url, " (Ctrl-C to stop)"),
    )

    watch_signals()
    var code: Int
    try:
        code = _run_session(session, report)
    except e:
        _ = _stop_app(session)
        _mark_stopped(session)
        stop_watching_signals()
        raise e^
    _mark_stopped(session)
    stop_watching_signals()
    # Held open until here: every app served on it.
    _ = listener^
    return code


def _run_session(mut session: _Session, mut report: Report) raises -> Int:
    """Build, start and restart until a signal. Returns the exit code."""
    # Made before the first build, so a save during it is noticed.
    var watcher = Watcher(session.root)
    var step = _build_and_restart(session)
    var next_watch = perf_counter_ns() + _WATCH_NS
    while step == _GO_ON:
        sleep(_COPY_SECONDS)
        _copy_output(session)
        if take_signal() != 0:
            step = _SIGNALLED
            break
        _notice_exit(session)
        if perf_counter_ns() < next_watch:
            continue
        next_watch = perf_counter_ns() + _WATCH_NS
        if watcher.changed():
            step = _build_and_restart(session)

    _ = _stop_app(session)
    if step == _NO_MOJO:
        return report.fail(
            "mojo_missing",
            "cannot start mojo",
            EXIT_UNAVAILABLE,
            hint="run dodo inside the project's environment: pixi run dodo ...",
        )
    session.state["running"] = Value(False)
    _event(session, "stopped", Value.object(), "dodo dev: stopped")
    return EXIT_INTERRUPTED


def _build_and_restart(mut session: _Session) raises -> Int:
    """Build when the build is out of date, then swap the app for the new
    build. Returns `_GO_ON`, `_SIGNALLED` or `_NO_MOJO`."""
    var started = perf_counter_ns()
    var plan = BuildPlan(session.root, session.entry, session.out_dir)
    if plan.up_to_date and session.app:
        # The change did not reach the app, such as an edit to a test.
        return _GO_ON

    if not plan.up_to_date:
        var built = _build(session, plan)
        if built == _BUILD_FAILED:
            return _GO_ON
        if built != _GO_ON:
            return built

    var restart = Bool(session.app)
    if restart:
        var hurried = _stop_app(session)
        if hurried:
            return _SIGNALLED
    var argv: List[String] = [plan.binary]
    for word in session.app_args:
        argv.append(word)
    var env: List[String] = [String("DODO_LISTEN_FD=", session.listen_fd)]
    session.app = spawn(
        argv,
        env=env,
        stdout_path=app_out_path(session.root),
        stderr_path=app_err_path(session.root),
        new_group=True,
    )
    # `spawn` started both files again.
    session.out_copy.restart()
    session.err_copy.restart()
    session.state["app_pid"] = Value(session.app.value().pid)

    var seconds = Float64(perf_counter_ns() - started) / 1e9
    var fields = Value.object()
    fields["pid"] = Value(session.app.value().pid)
    fields["restart"] = Value(restart)
    fields["seconds"] = Value(seconds)
    var text = String("started in ", format_seconds(seconds))
    if restart:
        text = String("restarted in ", format_seconds(seconds))
    _event(session, "started", fields^, text)
    return _GO_ON


def _build(mut session: _Session, plan: BuildPlan) raises -> Int:
    """Run `mojo build` for `plan`, watching for signals. Returns `_GO_ON`
    when it built, `_BUILD_FAILED`, `_SIGNALLED` or `_NO_MOJO`."""
    var fields = Value.object()
    fields["file"] = Value(plan.entry)
    _event(
        session, "building", fields^, String("building ", plan.entry, " ...")
    )
    var started = perf_counter_ns()
    var child: Child
    try:
        child = start_build(plan, [session.root], new_group=True)
    except:
        return _NO_MOJO
    var status = child.poll()
    while not status:
        if take_signal() != 0:
            _ = child.kill_group()
            _ = child.wait()
            return _SIGNALLED
        sleep(_STEP_SECONDS)
        # The old app keeps serving, and printing, during the build.
        _copy_output(session)
        status = child.poll()
    var seconds = Float64(perf_counter_ns() - started) / 1e9
    var build = finish_build(plan, status.value(), seconds)
    if build.ok():
        return _GO_ON

    if not session.json_mode:
        print(build.log, end="", file=stderr, flush=True)
    var failed = Value.object()
    failed["message"] = Value(build.message)
    failed["log"] = Value(build.log)
    var text = String("build failed; save a fix to try again")
    if session.app:
        text = String("build failed; the last good build is still serving")
    _event(session, "build_failed", failed^, text)
    return _BUILD_FAILED


def _notice_exit(mut session: _Session) raises:
    """Forget the app when it exited by itself, and say how it ended."""
    if not session.app:
        return
    var status = session.app.value().poll()
    if not status:
        return
    var exit = status.value()
    _ = session.app.value().kill_group()
    session.app = None
    _copy_output(session, whole=True)
    session.state["app_pid"] = Value(0)
    var fields = Value.object()
    fields["exit"] = Value(String(exit))
    fields["exit_code"] = Value(exit.shell_code())
    _event(
        session,
        "app_exited",
        fields^,
        String("the app exited (", exit, "); save a file to start it again"),
    )


def _stop_app(mut session: _Session) raises -> Bool:
    """Stop the app, if one runs: SIGTERM, so it drains, and SIGKILL to
    its whole group after `_STOP_GRACE_NS` or on another signal.
    Returns whether a signal came while it stopped."""
    if not session.app:
        return False
    var child = session.app.take()
    session.app = None
    try:
        child.send_signal(_SIGTERM)
    except:
        # It already exited; `poll` below collects it.
        pass
    var now = perf_counter_ns()
    var deadline = now + _STOP_GRACE_NS
    var patient_until = now + _SAME_SIGNAL_NS
    var hurried = False
    var status = child.poll()
    while not status:
        var signal = take_signal()
        if signal != 0 and perf_counter_ns() > patient_until:
            hurried = True
            break
        if perf_counter_ns() > deadline:
            break
        sleep(_STEP_SECONDS)
        _copy_output(session)
        status = child.poll()
    # Also ends whatever the app started and left running.
    _ = child.kill_group()
    _ = child.wait()
    _copy_output(session, whole=True)
    session.state["app_pid"] = Value(0)
    return hurried


def _copy_output(mut session: _Session, whole: Bool = False):
    """Copy what the app printed since the last call to the terminal."""
    session.out_copy.copy_new(whole)
    session.err_copy.copy_new(whole)


def _mark_stopped(mut session: _Session):
    """Save that this session is over, so `dodo logs` says so."""
    try:
        session.state["running"] = Value(False)
        session.state["app_pid"] = Value(0)
    except:
        pass
    _save_state(session)


def _save_state(session: _Session):
    """Write `state.json`. A failure only costs `dodo logs` its view, so
    the session goes on."""
    try:
        write_state(session.root, session.state)
    except:
        pass


def _event(
    mut session: _Session, name: String, var fields: Value, text: String
):
    """Tell what happened: `text` on stderr, or with `--json` one tagged
    line on stdout. Either way it is saved in `state.json`."""
    _remember(session, name, fields, text)
    if not session.json_mode:
        print(text, file=stderr, flush=True)
        return
    try:
        fields["event"] = Value(name)
        var line = Value.object()
        line["dodo_dev"] = fields^
        print(dumps(line), flush=True)
    except:
        pass


def _remember(mut session: _Session, name: String, fields: Value, text: String):
    """Add the event to the state's latest events and save the state."""
    try:
        var saved = fields.copy()
        saved["event"] = Value(name)
        saved["text"] = Value(text)
        saved["time"] = Value(unix_time())
        if "log" in saved:
            var log = saved["log"].as_string()
            saved["log"] = Value(tail_text(log, MAX_EVENT_LOG_BYTES))
        var events = session.state["events"].copy()
        events.append(saved^)
        while len(events) > MAX_EVENTS:
            events.remove(0)
        session.state["events"] = events^
    except:
        pass
    _save_state(session)


def parse_port(text: String) raises -> Int:
    """A port number from 0 to 65535; 0 lets the system pick a free one.

    Raises:
        Error: If `text` is not such a number.
    """
    if text.byte_length() == 0 or text.byte_length() > 5:
        raise _bad_port(text)
    for byte in text.as_bytes():
        var code = Int(byte)
        if code < ord("0") or code > ord("9"):
            raise _bad_port(text)
    var port = Int(text)
    if port > 65535:
        raise _bad_port(text)
    return port


def _bad_port(text: String) -> Error:
    return Error("--port must be a number from 0 to 65535, got `", text, "`")


def parse_host(text: String) raises -> IpAddr:
    """An IP address to listen on; `localhost` is 127.0.0.1.

    Raises:
        Error: If `text` is not an IPv4 or IPv6 address.
    """
    if text == "localhost":
        return IpAddr.parse("127.0.0.1")
    try:
        return IpAddr.parse(text)
    except:
        raise Error(
            "--host must be an IP address such as 127.0.0.1 or ::1, got `",
            text,
            "`",
        )


def url_of(ip: IpAddr, port: Int) -> String:
    """`http://127.0.0.1:8000`, or `http://[::1]:8000` for IPv6."""
    if ip.is_v6():
        return String("http://[", ip, "]:", port)
    return String("http://", ip, ":", port)
