"""Plant known mistakes in the code, one at a time, and check a test fails.

A test suite can pass while missing whole kinds of bugs. This script makes
small, deliberate mistakes (a flipped check, a skipped kill, a wrong exit
code), runs the tests after each one, and puts the file back. Every mistake
should make some test fail; one that does not is a gap to close with a new
test.

    pixi run check-mistakes            # every mistake
    pixi run check-mistakes 3 7        # only these
    pixi run check-mistakes --list     # what each number plants

Exit code: 0 when every mistake was caught, 1 when one was missed, 2 when a
mistake's text is no longer in its file (the code moved: update the list).

A planted file is copied to `.dodo/mistakes/` first, so a run that is
killed outright still leaves the original; the next run puts it back.
"""

import os
import shutil
import signal
import subprocess
import sys
import time
from dataclasses import dataclass
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
BACKUPS = ROOT / ".dodo" / "mistakes"
CAP_SECONDS = 300
"""A test file still running after this long counts as caught (it hung)."""

SCRATCH_DIRS = ["dodo_e2e_", "dodo_runner_", "dodo_cli_test_", "dodo_test_process_"]
"""Folder names the tests make in $TMPDIR. Programs still running from them
after a test file ends are killed, so a hung mistake cannot leak."""


@dataclass
class Mistake:
    what: str
    file: str
    find: str
    plant: str


MISTAKES = [
    Mistake(
        "stamp ignores the entry's own change time",
        "cli/build.mojo",
        '    stamp += String("entry ", mtime_ns(entry), "\\n")\n',
        "",
    ),
    Mistake(
        "build inputs leave out the entry itself",
        "cli/files.mojo",
        "if path == entry or not is_test_file(path):",
        "if not is_test_file(path):",
    ),
    Mistake(
        "other test files kept in a build's inputs",
        "cli/files.mojo",
        "if path == entry or not is_test_file(path):",
        "if True:",
    ),
    Mistake(
        "a failed build writes its stamp",
        "cli/build.mojo",
        "        result.log = tail_text(read_text(plan.log_path), _MAX_LOG_BYTES)\n"
        "        return result^\n",
        "        result.log = tail_text(read_text(plan.log_path), _MAX_LOG_BYTES)\n",
    ),
    Mistake(
        "a failed build keeps the old stamp",
        "cli/build.mojo",
        "        remove_if_there(plan.stamp_path)\n        result.exit_code",
        "        result.exit_code",
    ),
    Mistake(
        "stamp ignores the toolchain",
        "cli/build.mojo",
        '    stamp += String("toolchain ", _toolchain_mtime_ns(), "\\n")\n',
        "",
    ),
    Mistake(
        "dodo test ignores --timeout",
        "cli/cmd_test.mojo",
        "        if perf_counter_ns() > deadline:\n            timed_out = True",
        "        if False:\n            timed_out = True",
    ),
    Mistake(
        "leftover programs not killed",
        "cli/cmd_test.mojo",
        "    result.killed_leftovers = running.child.kill_group()",
        "    result.killed_leftovers = False",
    ),
    Mistake(
        "--only keeps the skipped tests",
        "cli/cmd_test.mojo",
        'if only != "" and test.name != only:',
        "if False:",
    ),
    Mistake(
        "build failure exits 1 instead of 2",
        "cli/cmd_test.mojo",
        "            EXIT_BUILD_FAILED,\n        )\n    if not_passing",
        "            EXIT_FAILED,\n        )\n    if not_passing",
    ),
    Mistake(
        "a crash is not reported as a crash",
        "cli/cmd_test.mojo",
        '    elif exit.signal != 0:\n        result.outcome = "crashed"',
        '    elif False:\n        result.outcome = "crashed"',
    ),
    Mistake(
        "--json lets text lines onto stdout",
        "cli/report.mojo",
        "        if not self.json_mode:\n            print(text, flush=True)",
        "        print(text, flush=True)",
    ),
    Mistake(
        "words after -- also read as dodo's flags",
        "cli/args.mojo",
        "                parsed.passthrough.append(words[i])\n            return parsed^",
        "                parsed.passthrough.append(words[i])\n            continue",
    ),
    Mistake(
        "failure messages not attached to their test",
        "cli/suite.mojo",
        "            _add_message_line(parsed.tests[len(parsed.tests) - 1], line)\n",
        "",
    ),
    Mistake(
        "dodo routes timeout never kills the app",
        "cli/cmd_routes.mojo",
        "            child.send_signal(_SIGKILL)\n            _ = child.wait()\n",
        "",
    ),
    Mistake(
        "kill_group kills only the child, not its group",
        "dodo/utils/process.mojo",
        "c_int(_SIGKILL), c_int(1)",
        "c_int(_SIGKILL), c_int(0)",
    ),
    Mistake(
        "kill_group says it killed something when nothing was left",
        "dodo/utils/process.mojo",
        "        if failure == _ESRCH:\n            return False",
        "        if failure == _ESRCH:\n            return True",
    ),
    Mistake(
        "--jobs 0 accepted",
        "cli/cmd_test.mojo",
        "if jobs < 1 or jobs > _MAX_JOBS:",
        "if jobs < 0 or jobs > _MAX_JOBS:",
    ),
    Mistake(
        "Ctrl-C during builds leaves builds running",
        "cli/cmd_test.mojo",
        "        if take_signal() != 0:\n            _kill_all(running)\n"
        "            return EXIT_INTERRUPTED",
        "        if take_signal() != 0:\n            return EXIT_INTERRUPTED",
    ),
    Mistake(
        "Ctrl-C while a test runs is ignored",
        "cli/cmd_test.mojo",
        "        if take_signal() != 0:\n            interrupted = True",
        "        if False:\n            interrupted = True",
    ),
    Mistake(
        "--only runs files that do not define the test",
        "cli/cmd_test.mojo",
        "            if String(line.strip()).startswith(wanted):",
        "            if True:",
    ),
    Mistake(
        "a file named twice runs twice",
        "cli/cmd_test.mojo",
        "        if existing == path:\n            return",
        "        if existing == path:\n            pass",
    ),
    Mistake(
        "summary never counts files that did not pass",
        "cli/cmd_test.mojo",
        '        if result.outcome != "passed":\n            bad_files += 1',
        "        if False:\n            bad_files += 1",
    ),
    Mistake(
        "a test importing another test is not rebuilt with it",
        "cli/files.mojo",
        '            if part.startswith("test_"):\n                return True',
        '            if part.startswith("test_"):\n                return False',
    ),
    Mistake(
        "an edit is reported again on every check",
        "cli/watch.mojo",
        "                self.file_times[i] = now\n",
        "",
    ),
    Mistake(
        "a file added to a folder is missed",
        "cli/watch.mojo",
        "                return True\n        return False",
        "                pass\n        return False",
    ),
    Mistake(
        "a file saved by renaming over the old one is missed",
        "cli/watch.mojo",
        "            return old_times != self.file_times",
        "            return False",
    ),
    Mistake(
        "dev does not hand the app its listening socket",
        "cli/cmd_dev.mojo",
        '    var env: List[String] = [String("DODO_LISTEN_FD=", session.listen_fd)]\n',
        "    var env = List[String]()\n",
    ),
    Mistake(
        "dev stops the old app when a build fails",
        "cli/cmd_dev.mojo",
        "        if built == _BUILD_FAILED:\n            return _GO_ON",
        "        if built == _BUILD_FAILED:\n            _ = _stop_app(session)\n            return _GO_ON",
    ),
    Mistake(
        "dev leaves the old app running on a restart",
        "cli/cmd_dev.mojo",
        "        var hurried = _stop_app(session)\n",
        "        var hurried = False\n",
    ),
    Mistake(
        "dev exits with 0 on Ctrl-C",
        "cli/cmd_dev.mojo",
        "    return EXIT_INTERRUPTED\n",
        "    return 0\n",
    ),
    Mistake(
        "dev leaves the app running after Ctrl-C",
        "cli/cmd_dev.mojo",
        "    _ = _stop_app(session)\n    if step == _NO_MOJO:",
        "    if step == _NO_MOJO:",
    ),
    Mistake(
        "dev never notices the app died",
        "cli/cmd_dev.mojo",
        "        _notice_exit(session)\n",
        "",
    ),
    Mistake(
        "dev leaves a build running after Ctrl-C",
        "cli/cmd_dev.mojo",
        "            _ = child.kill_group()\n            _ = child.wait()\n            return _SIGNALLED",
        "            return _SIGNALLED",
    ),
    Mistake(
        "dev takes one Ctrl-C delivered twice as a second press",
        "cli/cmd_dev.mojo",
        "        if signal != 0 and perf_counter_ns() > patient_until:",
        "        if signal != 0:",
    ),
    Mistake(
        "dev ignores a second Ctrl-C",
        "cli/cmd_dev.mojo",
        "        if signal != 0 and perf_counter_ns() > patient_until:",
        "        if False:",
    ),
    Mistake(
        "dev waits forever for an app that ignores SIGTERM",
        "cli/cmd_dev.mojo",
        "        if perf_counter_ns() > deadline:\n            break\n",
        "",
    ),
    Mistake(
        "dev restarts the app on a change the app is not built from",
        "cli/cmd_dev.mojo",
        "    if plan.up_to_date and session.app:",
        "    if False:",
    ),
    Mistake(
        "a plain handed-over listener gets per-worker siblings",
        "dodo/runtime/scheduler.mojo",
        "            prebind_per_worker = False\n",
        "            pass\n",
    ),
    Mistake(
        "allows_reuseport reads the flag backwards",
        "dodo/runtime/reuseport.mojo",
        "    return value.unsafe_load() != 0",
        "    return value.unsafe_load() == 0",
    ),
    Mistake(
        "a draining connection is kept alive after its response",
        "dodo/http/_reactor/conn_handle.mojo",
        "        if self.draining:\n            final = True\n",
        "",
    ),
    Mistake(
        "an HTTP/1.1 loop holds idle keep-alive connections through the grace",
        "dodo/http/_reactor/drain.mojo",
        "        if served_before or grace_over:",
        "        if grace_over:",
    ),
    Mistake(
        "an HTTP/1.1 loop closes new connections at once on a stop",
        "dodo/http/_reactor/drain.mojo",
        "        if served_before or grace_over:",
        "        if True:",
    ),
    Mistake(
        "a stop ends with connections still open",
        "dodo/http/_reactor/drain.mojo",
        "    if open_conns == 0:\n        return True\n    return now_ms >= clock.deadline_ms",
        "    return True",
    ),
    Mistake(
        "the unified loop holds idle keep-alive connections through the grace",
        "dodo/http/_unified_reactor_impl.mojo",
        "            if ch[].keepalive_count > 0 or grace_over:",
        "            if grace_over:",
    ),
    Mistake(
        "the unified loop closes connections choosing a protocol at once",
        "dodo/http/_unified_reactor_impl.mojo",
        "        elif kind == KIND_PENDING or kind == KIND_TLS:\n            if grace_over:",
        "        elif kind == KIND_PENDING or kind == KIND_TLS:\n            if True:",
    ),
    Mistake(
        "a connection that picks HTTP/1.1 during a stop is kept alive",
        "dodo/http/_unified_reactor_impl.mojo",
        "    if draining:\n        _mark_new_h1_draining(fd, conns)\n    var packed2",
        "    var packed2",
    ),
    Mistake(
        "a stop sends no GOAWAY to HTTP/2 connections",
        "dodo/http/_unified_reactor_impl.mojo",
        "            if not h2[].should_close:\n                var step = h2[].begin_close(config)",
        "            if False:\n                var step = h2[].begin_close(config)",
    ),
    Mistake(
        "a docs index counts links inside code blocks",
        "cli/docs_index.mojo",
        '        if fence != "":\n',
        '        if False:\n',
    ),
    Mistake(
        "a docs index may link to hidden or parent folders",
        "cli/docs_index.mojo",
        '        if String(part).startswith("."):\n',
        '        if String(part) == "never":\n',
    ),
    Mistake(
        "a short version picks the first match, not the newest",
        "cli/docs_index.mojo",
        'if best == "" or _newer(parts, best_parts):',
        'if best == "":',
    ),
    Mistake(
        "a failed docs swap does not put the old docs back",
        "cli/docs_folder.mojo",
        "            move_path(aside, target)\n",
        "            pass\n",
    ),
    Mistake(
        "removing a docs folder follows symlinks",
        "cli/docs_folder.mojo",
        "    if islink(path):\n",
        "    if False:\n",
    ),
    Mistake(
        "a failed docs pull leaves its half-done folder",
        "cli/cmd_docs.mojo",
        "        _remove_quietly(staging)\n",
        "",
    ),
    Mistake(
        "docs pull saves an error page as a file",
        "cli/cmd_docs.mojo",
        "        raise Error(_bad_status(url, reply.status))\n",
        "        pass\n",
    ),
    Mistake(
        "docs pull does not retry a server error",
        "cli/cmd_docs.mojo",
        ".with_read_timeout(read_timeout).with_retry(RetryPolicy())",
        ".with_read_timeout(read_timeout)",
    ),
    Mistake(
        "a missing dodo version does not fail the pull",
        "cli/cmd_docs.mojo",
        """    if dodo.failed():
        return report.fail(
            dodo.error_kind, dodo.error, EXIT_UNAVAILABLE, hint=dodo.hint
        )
""",
        "",
    ),
    Mistake(
        "docs pull takes the dodo version twice",
        "cli/cmd_docs.mojo",
        "            if dodo_given:\n",
        "            if False:\n",
    ),
    Mistake(
        "docs pull defaults to the wrong dodo version",
        "cli/cmd_docs.mojo",
        "        pulled.version = DODO_VERSION\n",
        '        pulled.version = "0.0.0"\n',
    ),
    Mistake(
        "docs pull fetches links that leave the docs folder",
        "cli/cmd_docs.mojo",
        "        if not is_safe_path(link):\n",
        "        if False:\n",
    ),
    Mistake(
        "docs pull ignores DODO_DOCS_READ_TIMEOUT_MS",
        "cli/cmd_docs.mojo",
        "        read_timeout = Int(given)\n",
        "        _ = Int(given)\n",
    ),
]


def tests_for(file: str) -> list[str]:
    """The test files to run for a mistake in `file`, quick ones first."""
    cli_tests = sorted(str(p.relative_to(ROOT)) for p in (ROOT / "tests" / "cli").glob("test_*.mojo"))
    end_to_end = "tests/cli/test_e2e.mojo"
    if end_to_end in cli_tests:
        cli_tests.remove(end_to_end)
        cli_tests.append(end_to_end)
    if file.startswith("dodo/utils/"):
        return ["tests/utils/test_process.mojo"] + cli_tests
    if file.startswith("dodo/http/"):
        return ["tests/http/test_offload.mojo"]
    if file.startswith("dodo/runtime/"):
        return ["tests/runtime/test_scheduler.mojo", end_to_end]
    return cli_tests


def backup_path(file: str) -> Path:
    return BACKUPS / file.replace("/", "__")


def restore_left_backups():
    """Put back any file a killed run left planted."""
    if not BACKUPS.is_dir():
        return
    for backup in sorted(BACKUPS.iterdir()):
        file = backup.name.replace("__", "/")
        shutil.copy2(backup, ROOT / file)
        backup.unlink()
        print(f"put back {file}, left planted by an earlier run")


def kill_leftovers():
    for name in SCRATCH_DIRS:
        subprocess.run(["pkill", "-9", "-f", name], capture_output=True)


def kill_group(child: subprocess.Popen):
    """Kill the test and everything it started. macOS has refused
    `killpg` with EPERM for a hung test; then kill the test itself, and
    `kill_leftovers` ends what it started."""
    try:
        os.killpg(child.pid, signal.SIGKILL)
    except OSError:
        child.kill()


def run_test(path: str) -> tuple[str, str]:
    """Run one test file. Returns ("passed" | "failed" | "hung", why)."""
    child = subprocess.Popen(
        ["pixi", "run", "mojo", "-I", ".", path],
        cwd=ROOT,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        text=True,
        start_new_session=True,
    )
    try:
        output, _ = child.communicate(timeout=CAP_SECONDS)
    except subprocess.TimeoutExpired:
        kill_group(child)
        child.wait()
        kill_leftovers()
        return "hung", f"still running after {CAP_SECONDS} s"
    except KeyboardInterrupt:
        # Stopped by Ctrl-C or SIGTERM: the test must not outlive us.
        kill_group(child)
        child.wait()
        kill_leftovers()
        raise
    kill_leftovers()
    if child.returncode == 0:
        return "passed", ""
    failed = []
    for line in output.splitlines():
        if line.strip().startswith("FAIL ["):
            failed.append(line.strip())
    if not failed:
        for line in output.splitlines():
            if "error:" in line:
                failed.append(line.strip())
    return "failed", "; ".join(failed[:3])


def check(number: int, mistake: Mistake) -> str:
    """Plant one mistake, run its tests, put the file back."""
    path = ROOT / mistake.file
    original = path.read_text()
    found = original.count(mistake.find)
    if found != 1:
        return f"#{number:<3} SETUP  {mistake.what}: its text is in {mistake.file} {found} times, not once"

    BACKUPS.mkdir(parents=True, exist_ok=True)
    shutil.copy2(path, backup_path(mistake.file))
    started = time.monotonic()
    try:
        path.write_text(original.replace(mistake.find, mistake.plant))
        for test in tests_for(mistake.file):
            outcome, why = run_test(test)
            if outcome != "passed":
                seconds = time.monotonic() - started
                return f"#{number:<3} caught {mistake.what}\n       {test} {outcome} ({seconds:.0f} s): {why}"
    finally:
        path.write_text(original)
        backup_path(mistake.file).unlink()
    seconds = time.monotonic() - started
    return f"#{number:<3} MISSED {mistake.what} ({seconds:.0f} s, every test passed)"


def stop_on_sigterm(signum, frame):
    raise KeyboardInterrupt


def main() -> int:
    if "--list" in sys.argv:
        for number, mistake in enumerate(MISTAKES, start=1):
            print(f"#{number:<3} {mistake.file:26} {mistake.what}")
        return 0

    picked = []
    for word in sys.argv[1:]:
        if not word.isdigit() or not 1 <= int(word) <= len(MISTAKES):
            print(f"not a mistake number: {word} (1 to {len(MISTAKES)}, or --list)")
            return 2
        picked.append(int(word))
    if not picked:
        picked = list(range(1, len(MISTAKES) + 1))

    signal.signal(signal.SIGTERM, stop_on_sigterm)
    restore_left_backups()
    lines = []
    try:
        for number in picked:
            line = check(number, MISTAKES[number - 1])
            print(line, flush=True)
            lines.append(line)
    except KeyboardInterrupt:
        print("stopped; the planted file was put back")
        return 130

    missed = sum(1 for line in lines if " MISSED " in line)
    setup = sum(1 for line in lines if " SETUP " in line)
    caught = len(lines) - missed - setup
    print(f"\n{caught} caught, {missed} missed, {setup} out of date, of {len(lines)}")
    if setup > 0:
        return 2
    if missed > 0:
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
