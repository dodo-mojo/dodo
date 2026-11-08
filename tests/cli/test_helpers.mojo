"""Tests for the CLI's small helpers: files, project, build names, doctor
parsing, routes formatting."""

from std.os import getenv, makedirs, remove, rmdir, setenv, symlink
from std.os.path import exists, join, realpath
from std.testing import (
    TestSuite,
    assert_equal,
    assert_false,
    assert_raises,
    assert_true,
)
from std.time import sleep

from dodo.json import loads
from dodo.utils.process import ExitStatus

from cli.build import BuildPlan, binary_name, build_app, finish_build
from cli.cmd_doctor import (
    Check,
    format_checks,
    mojo_version_of,
    open_files_limit,
    supported_mojo,
)
from cli.cmd_routes import format_routes, parse_timeout
from cli.files import mojo_files, newest_mtime_ns
from cli.project import drop_suffix, entry_file, find_root, stem
from cli.report import EXIT_BUILD_FAILED, EXIT_OK, Report
from dodo.utils.process import run


def _scratch(name: String) raises -> String:
    var dir = join(getenv("TMPDIR", "/tmp"), String("dodo_cli_test_", name))
    _ = run(["rm", "-rf", dir])
    makedirs(dir, exist_ok=True)
    return realpath(dir)


def _touch(path: String, text: String = "") raises:
    with open(path, "w") as file:
        file.write(text)


# ── files ──


def test_mojo_files_walk() raises:
    var dir = _scratch("walk")
    makedirs(join(dir, "a", "b"), exist_ok=True)
    makedirs(join(dir, ".hidden"), exist_ok=True)
    makedirs(join(dir, "build"), exist_ok=True)
    _touch(join(dir, "main.mojo"))
    _touch(join(dir, "a", "b", "deep.mojo"))
    _touch(join(dir, "a", "notes.md"))
    _touch(join(dir, ".hidden", "skip.mojo"))
    _touch(join(dir, "build", "skip.mojo"))
    _touch(join(dir, ".dot.mojo"))
    var files = mojo_files(dir)
    assert_equal(len(files), 2)
    assert_equal(files[0], join(dir, "a", "b", "deep.mojo"))
    assert_equal(files[1], join(dir, "main.mojo"))


def test_mojo_files_ignores_symlink_loop() raises:
    var dir = _scratch("loop")
    makedirs(join(dir, "src"), exist_ok=True)
    _touch(join(dir, "src", "x.mojo"))
    symlink(dir, join(dir, "src", "back"))
    var files = mojo_files(dir)
    assert_equal(len(files), 1)


def test_mojo_files_empty_and_missing() raises:
    var dir = _scratch("empty")
    assert_equal(len(mojo_files(dir)), 0)
    with assert_raises():
        _ = mojo_files(join(dir, "nope"))


def test_newest_mtime_skips_deleted() raises:
    var dir = _scratch("mtime")
    _touch(join(dir, "a.mojo"))
    var paths: List[String] = [join(dir, "a.mojo"), join(dir, "gone.mojo")]
    assert_true(newest_mtime_ns(paths) > 0)
    assert_equal(newest_mtime_ns(List[String]()), 0)


# ── project ──


def test_find_root_walks_up() raises:
    var dir = _scratch("root")
    _touch(join(dir, "pixi.toml"))
    makedirs(join(dir, "src", "deep"), exist_ok=True)
    assert_equal(find_root(join(dir, "src", "deep")), dir)


def test_find_root_without_project() raises:
    var dir = _scratch("noroot")
    makedirs(join(dir, "x"), exist_ok=True)
    assert_equal(find_root(join(dir, "x")), join(dir, "x"))


def test_entry_file() raises:
    var dir = _scratch("entry")
    with assert_raises(contains="dodo dev app.mojo"):
        _ = entry_file(dir, "", "dev")
    _touch(join(dir, "main.mojo"))
    assert_equal(entry_file(dir, "", "run"), join(dir, "main.mojo"))
    with assert_raises(contains="is not a .mojo file"):
        _ = entry_file(dir, join(dir, "main.py"), "run")
    with assert_raises(contains="no file"):
        _ = entry_file(dir, join(dir, "other.mojo"), "run")
    with assert_raises(contains="no file"):
        _ = entry_file(dir, dir + "/.mojo", "run")


def test_stem_and_drop_suffix() raises:
    assert_equal(stem("apps/main.mojo"), "main")
    assert_equal(stem("main.mojo"), "main")
    assert_equal(stem("x"), "x")
    assert_equal(drop_suffix("a.mojo", ".mojo"), "a")
    assert_equal(drop_suffix("a.md", ".mojo"), "a.md")
    assert_equal(drop_suffix(".mojo", ".mojo"), "")


def test_binary_name() raises:
    assert_equal(binary_name("/p", "/p/main.mojo"), "main")
    assert_equal(binary_name("/p", "/p/apps/api.mojo"), "apps__api")
    assert_equal(binary_name("/p", "/elsewhere/x.mojo"), "__elsewhere__x")


# ── build ──


def test_build_failure_then_stamp_logic() raises:
    var dir = _scratch("build")
    var entry = join(dir, "main.mojo")
    _touch(entry, 'def main():\n    var x: Int = "no"\n')
    var report = Report("run", True)
    var out_dir = join(dir, ".dodo", "build")
    var failed = build_app(dir, entry, out_dir, report)
    assert_equal(failed.exit_code, EXIT_BUILD_FAILED)
    assert_true("cannot implicitly convert" in failed.log)
    assert_false(exists(join(out_dir, "main.stamp")))

    _touch(entry, 'def main():\n    print("hi")\n')
    var first = build_app(dir, entry, out_dir, report)
    assert_equal(first.exit_code, EXIT_OK)
    assert_false(first.skipped)
    assert_true(exists(first.binary))

    var second = build_app(dir, entry, out_dir, report)
    assert_true(second.skipped)

    # A new file (even one main does not import) means a rebuild.
    _touch(join(dir, "extra.mojo"), "def unused():\n    pass\n")
    var third = build_app(dir, entry, out_dir, report)
    assert_false(third.skipped)
    remove(join(dir, "extra.mojo"))
    var fourth = build_app(dir, entry, out_dir, report)
    assert_false(fourth.skipped)

    # A missing binary is rebuilt even when the stamp matches.
    remove(first.binary)
    var fifth = build_app(dir, entry, out_dir, report)
    assert_false(fifth.skipped)
    assert_true(exists(first.binary))


def _built(plan: BuildPlan) raises:
    """Pretend `plan` was built: a binary and its stamp are there."""
    _touch(plan.binary, "binary")
    _ = finish_build(plan, ExitStatus(code=0, signal=0), 0.0)


def _rewrite(path: String, text: String) raises:
    """Change `path`, a little later so its change time moves."""
    sleep(0.01)
    _touch(path, text)


def test_failed_build_drops_the_old_stamp() raises:
    # Otherwise a later run could trust the binary the failed build left.
    var dir = _scratch("drop_stamp")
    var entry = join(dir, "main.mojo")
    _touch(entry, "def main():\n    pass\n")
    var out_dir = join(dir, ".dodo", "build")
    var plan = BuildPlan(dir, entry, out_dir)
    _built(plan)
    assert_true(BuildPlan(dir, entry, out_dir).up_to_date)

    _ = finish_build(plan, ExitStatus(code=1, signal=0), 0.0)
    assert_false(exists(plan.stamp_path))
    assert_false(BuildPlan(dir, entry, out_dir).up_to_date)


def test_stamp_follows_an_entry_outside_the_project() raises:
    # `dodo test /elsewhere/test_x.mojo`: the walk of the project never
    # sees the file, so the stamp must watch it on its own.
    var dir = _scratch("near")
    var elsewhere = _scratch("far")
    var entry = join(elsewhere, "test_far.mojo")
    _touch(entry, "def main():\n    pass\n")
    var out_dir = join(dir, ".dodo", "build")
    _built(BuildPlan(dir, entry, out_dir))
    assert_true(BuildPlan(dir, entry, out_dir).up_to_date)

    _rewrite(entry, "def main():\n    print(1)\n")
    assert_false(BuildPlan(dir, entry, out_dir).up_to_date)


def test_stamp_follows_the_toolchain() raises:
    var dir = _scratch("toolchain")
    var entry = join(dir, "main.mojo")
    _touch(entry, "def main():\n    pass\n")
    var prefix = _scratch("toolchain_prefix")
    makedirs(join(prefix, "bin"), exist_ok=True)
    makedirs(join(prefix, "lib", "mojo"), exist_ok=True)
    var compiler = join(prefix, "bin", "mojo")
    var package = join(prefix, "lib", "mojo", "dodo.mojoc")
    _touch(compiler)
    _touch(package)
    var out_dir = join(dir, ".dodo", "build")

    var saved = getenv("CONDA_PREFIX")
    _ = setenv("CONDA_PREFIX", prefix)
    var at_start = BuildPlan(dir, entry, out_dir).stamp
    _rewrite(package, "a new dodo")
    var new_package = BuildPlan(dir, entry, out_dir).stamp
    _rewrite(compiler, "a new mojo")
    var new_compiler = BuildPlan(dir, entry, out_dir).stamp
    _ = setenv("CONDA_PREFIX", saved)

    assert_true(at_start != new_package)
    assert_true(new_package != new_compiler)


# ── doctor ──


def test_mojo_version_of() raises:
    assert_equal(mojo_version_of("Mojo 1.2.0 (2016d0cd)\n"), "1.2.0")
    assert_equal(mojo_version_of("Mojo 1.10.3"), "1.10.3")
    assert_equal(mojo_version_of(""), "")
    assert_equal(mojo_version_of("mojo 1.2.0"), "")
    assert_equal(mojo_version_of("Mojo 1.2"), "")
    assert_equal(mojo_version_of("Mojo 1.x.0"), "")
    assert_equal(mojo_version_of("Mojo 1..0"), "")


def test_supported_mojo() raises:
    assert_true(supported_mojo("1.2.0"))
    assert_true(supported_mojo("1.10.0"))
    assert_false(supported_mojo("1.1.9"))
    assert_false(supported_mojo("2.0.0"))
    assert_false(supported_mojo("0.26.1"))


def test_format_checks() raises:
    var checks: List[Check] = [
        Check("mojo", "ok", "1.2.0", ""),
        Check("docs", "warn", "missing", "dodo docs pull"),
    ]
    var text = format_checks(checks)
    assert_equal(
        text,
        (
            "ok    mojo  1.2.0\nwarn  docs  missing\n            fix: dodo docs"
            " pull"
        ),
    )


def test_open_files_limit_reads() raises:
    assert_true(open_files_limit() > 0)


# ── routes ──


def test_parse_timeout() raises:
    assert_equal(parse_timeout("60"), 60.0)
    assert_equal(parse_timeout("0.5"), 0.5)
    assert_equal(parse_timeout("3600"), 3600.0)
    for bad in ["0", "-1", "3601", "abc", "", "nan", "inf"]:
        with assert_raises(contains="--timeout"):
            _ = parse_timeout(bad)


def test_format_routes() raises:
    var routes = loads(
        '[{"method":"GET","path":"/","blocking":false,"kind":"route"},'
        '{"method":"DELETE","path":"/u/{id}","blocking":true,"kind":"route"},'
        '{"method":"*","path":"/{*path}","blocking":false,"kind":"fallback"}]'
    )
    assert_equal(
        format_routes(routes),
        "GET     /\nDELETE  /u/{id}  (blocking)\n*       /{*path}  (fallback)",
    )
    assert_equal(format_routes(loads("[]")), "no routes")


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
