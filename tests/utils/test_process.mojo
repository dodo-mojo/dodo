"""Tests for dodo.utils.process: real programs, real exit codes."""

from std.os import getenv, remove
from std.os.path import exists
from std.testing import (
    TestSuite,
    assert_equal,
    assert_false,
    assert_raises,
    assert_true,
)
from std.time import sleep

from dodo.utils.process import (
    ExitStatus,
    error_text,
    exec_replace,
    run,
    set_inherited,
    spawn,
)


def _scratch(name: String) -> String:
    var dir = getenv("TMPDIR", "/tmp")
    if not dir.endswith("/"):
        dir += "/"
    return String(dir, "dodo_test_process_", name)


def _read(path: String) raises -> String:
    with open(path, "r") as file:
        return file.read()


def _sh(script: String) -> List[String]:
    return [String("sh"), String("-c"), script]


def test_exit_code_zero() raises:
    var status = run(["true"])
    assert_true(status.succeeded())
    assert_equal(status.code, 0)
    assert_equal(status.signal, 0)


def test_exit_code_kept() raises:
    var status = run(_sh("exit 3"))
    assert_false(status.succeeded())
    assert_equal(status.code, 3)
    assert_equal(status.shell_code(), 3)


def test_exit_code_255() raises:
    var status = run(_sh("exit 255"))
    assert_equal(status.code, 255)


def test_killed_by_signal() raises:
    var status = run(_sh("kill -TERM $$"))
    assert_false(status.succeeded())
    assert_equal(status.signal, 15)
    assert_equal(status.code, -1)
    assert_equal(status.shell_code(), 143)
    assert_equal(String(status), "killed by signal 15")


def test_stdout_to_file_keeps_spaces() raises:
    var path = _scratch("stdout.txt")
    var status = run(
        ["printf", "%s|%s", "two words", "  edge  "], stdout_path=path
    )
    assert_true(status.succeeded())
    assert_equal(_read(path), "two words|  edge  ")
    remove(path)


def test_stdout_file_is_truncated() raises:
    var path = _scratch("truncate.txt")
    _ = run(["printf", "a long first line"], stdout_path=path)
    _ = run(["printf", "short"], stdout_path=path)
    assert_equal(_read(path), "short")
    remove(path)


def test_stderr_joins_stdout() raises:
    var path = _scratch("joined.txt")
    _ = run(
        _sh("printf out; printf err 1>&2"), stdout_path=path, stderr_path="&1"
    )
    assert_equal(_read(path), "outerr")
    remove(path)


def test_stderr_to_its_own_file() raises:
    var out = _scratch("out_only.txt")
    var err = _scratch("err_only.txt")
    _ = run(
        _sh("printf out; printf err 1>&2"), stdout_path=out, stderr_path=err
    )
    assert_equal(_read(out), "out")
    assert_equal(_read(err), "err")
    remove(out)
    remove(err)


def test_unicode_arguments() raises:
    var path = _scratch("unicode.txt")
    _ = run(["printf", "%s", "héllo 🦤 \"quoted\" $HOME"], stdout_path=path)
    assert_equal(_read(path), "héllo 🦤 \"quoted\" $HOME")
    remove(path)


def test_extra_env_added() raises:
    var path = _scratch("env_added.txt")
    _ = run(
        _sh('printf %s "$DODO_TEST_VALUE"'),
        env=["DODO_TEST_VALUE=a=b c"],
        stdout_path=path,
    )
    assert_equal(_read(path), "a=b c")
    remove(path)


def test_extra_env_replaces_inherited() raises:
    var path = _scratch("env_replaced.txt")
    _ = run(_sh('printf %s "$HOME"'), env=["HOME=/nowhere"], stdout_path=path)
    assert_equal(_read(path), "/nowhere")
    remove(path)


def test_inherited_env_kept() raises:
    var path = _scratch("env_kept.txt")
    _ = run(_sh('printf %s "$PATH"'), env=["OTHER=1"], stdout_path=path)
    assert_equal(_read(path), getenv("PATH"))
    remove(path)


def test_empty_env_value() raises:
    var path = _scratch("env_empty.txt")
    _ = run(
        _sh('printf "[%s]" "${DODO_EMPTY-unset}"'),
        env=["DODO_EMPTY="],
        stdout_path=path,
    )
    assert_equal(_read(path), "[]")
    remove(path)


def test_missing_program_raises() raises:
    with assert_raises(contains="No such file or directory"):
        _ = spawn(["dodo-no-such-program-xyz"])


def test_empty_argv_raises() raises:
    with assert_raises(contains="argv is empty"):
        _ = spawn(List[String]())


def test_nul_in_argument_raises() raises:
    var bad = String("a")
    bad += String(from_utf8_lossy=[UInt8(0)])
    bad += "b"
    with assert_raises(contains="NUL byte"):
        _ = spawn(["printf", bad])


def test_env_without_equals_raises() raises:
    with assert_raises(contains="not KEY=VALUE"):
        _ = spawn(["true"], env=["NOEQUALS"])


def test_env_with_empty_key_raises() raises:
    with assert_raises(contains="not KEY=VALUE"):
        _ = spawn(["true"], env=["=value"])


def test_poll_while_running_then_signal() raises:
    var child = spawn(["sleep", "30"])
    assert_false(Bool(child.poll()))
    child.send_signal(15)
    var status = child.wait()
    assert_equal(status.signal, 15)


def test_wait_twice_returns_same_status() raises:
    var child = spawn(_sh("exit 7"))
    var first = child.wait()
    var second = child.wait()
    assert_equal(first.code, 7)
    assert_equal(second.code, 7)


def test_signal_after_exit_is_ignored() raises:
    var child = spawn(["true"])
    _ = child.wait()
    child.send_signal(15)


def test_group_signal_reaches_grandchild() raises:
    var pid_file = _scratch("grandchild.pid")
    var child = spawn(
        _sh(String("sleep 30 & echo $! > ", pid_file, "; wait")),
        new_group=True,
    )
    var tries = 0
    while not exists(pid_file) and tries < 400:
        sleep(0.005)
        tries += 1
    sleep(0.05)
    var grandchild = _read(pid_file).strip()
    child.send_signal(15)
    _ = child.wait()
    sleep(0.05)
    var alive = run(["kill", "-0", String(grandchild)], stderr_path="/dev/null")
    assert_false(alive.succeeded())
    remove(pid_file)


def test_many_children_in_a_row() raises:
    for _ in range(50):
        var status = run(["true"])
        assert_true(status.succeeded())


def test_set_inherited_on_bad_fd_raises() raises:
    with assert_raises(contains="cannot change fd"):
        set_inherited(987654, True)


def test_set_inherited_round_trip() raises:
    set_inherited(1, False)
    set_inherited(1, True)


def test_error_text() raises:
    assert_equal(error_text(2), "No such file or directory")


def test_exec_replace_missing_program_raises() raises:
    with assert_raises(contains="cannot run"):
        exec_replace(["dodo-no-such-program-xyz"])


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
