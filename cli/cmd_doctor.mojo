"""`dodo doctor`: check the toolchain, the project and the machine.

Every check is `ok`, `warn` (works, but worth fixing) or `fail` (something
dodo needs is missing). The command exits 1 when any check fails.
"""

from std.ffi import OwnedDLHandle, external_call
from std.os import getenv, listdir
from std.os.path import exists, isdir, isfile, join
from std.sys.info import CompilationTarget

from dodo.json import Value
from dodo.runtime._thread import num_cpus
from dodo.utils.dylib import find_dodo_lib

from .args import ParsedArgs
from .capture import capture
from .project import find_root
from .report import EXIT_FAILED, EXIT_OK, Report

comptime NATIVE_LIBS: List[String] = [
    "tls",
    "zlib",
    "brotli",
    "fs",
    "simdjson",
    "proc",
]
"""Every `libdodo_<name>.so` dodo loads. `tools/check_recipe.py` checks
this list against the code."""

comptime _OK = "ok"
comptime _WARN = "warn"
comptime _FAIL = "fail"
comptime _MIN_OPEN_FILES = 4096


@fieldwise_init
struct Check(Copyable, Movable):
    var name: String
    var status: String
    var detail: String
    var hint: String
    """How to fix it; "" when it passed."""


def cmd_doctor(parsed: ParsedArgs, mut report: Report) raises -> Int:
    var checks = List[Check]()
    checks.append(check_machine())
    checks.append(check_environment())
    var mojo = check_mojo()
    var mojo_version = mojo.detail
    checks.append(mojo^)
    var root = find_root(".")
    var in_project = exists(join(root, "pixi.toml"))
    checks.append(check_project(root))
    if in_project:
        checks.append(check_app(root))
    checks.append(check_dodo_package(root))
    checks.append(check_native_libs())
    if in_project:
        checks.append(check_docs(root, mojo_version))
    checks.append(check_open_files())
    checks.append(check_git())

    report.say(format_checks(checks))
    var list = Value.array()
    var failed = 0
    for check in checks:
        var entry = Value.object()
        entry["name"] = Value(check.name)
        entry["status"] = Value(check.status)
        entry["detail"] = Value(check.detail)
        if check.hint != "":
            entry["hint"] = Value(check.hint)
        list.append(entry^)
        if check.status == _FAIL:
            failed += 1
    report.set("checks", list^)
    if failed > 0:
        return report.fail(
            "checks_failed", String(failed, " check(s) failed"), EXIT_FAILED
        )
    return EXIT_OK


def format_checks(checks: List[Check]) -> String:
    var width = 0
    for check in checks:
        width = max(width, check.name.byte_length())
    var text = String("")
    for check in checks:
        var line = String(check.status)
        while line.byte_length() < 6:
            line += " "
        var name = check.name
        while name.byte_length() < width:
            name += " "
        text += String(line, name, "  ", check.detail, "\n")
        if check.hint != "":
            var indent = String("")
            while indent.byte_length() < 6 + width + 2:
                indent += " "
            text += String(indent, "fix: ", check.hint, "\n")
    return String(text.rstrip("\n"))


def check_machine() -> Check:
    var os = String("linux")
    comptime if CompilationTarget.is_macos():
        os = "macOS"
    var arch = String("x86_64")
    comptime if CompilationTarget.is_apple_silicon() or CompilationTarget.has_neon():
        arch = "arm64"
    return Check(
        "machine", _OK, String(os, " ", arch, ", ", num_cpus(), " cores"), ""
    )


def check_environment() -> Check:
    var prefix = getenv("CONDA_PREFIX")
    if prefix == "":
        return Check(
            "environment",
            _FAIL,
            "not inside a pixi environment",
            "run it as `pixi run dodo ...`, or inside `pixi shell`",
        )
    return Check("environment", _OK, prefix, "")


def check_mojo() -> Check:
    """`detail` is the bare version ("1.2.0") when it passes."""
    var output: String
    try:
        var result = capture(["mojo", "--version"])
        if not result.status.succeeded():
            return Check(
                "mojo",
                _FAIL,
                "`mojo --version` failed",
                "reinstall: pixi install",
            )
        output = result.output
    except:
        return Check(
            "mojo", _FAIL, "mojo is not on PATH", "add it: pixi add mojo"
        )
    var version = mojo_version_of(output)
    if version == "":
        return Check(
            "mojo",
            _FAIL,
            String("cannot read the version in `", output.strip(), "`"),
            "",
        )
    if not supported_mojo(version):
        return Check(
            "mojo",
            _FAIL,
            String("Mojo ", version, " is not supported (need >=1.2.0, <2)"),
            'pin it in pixi.toml: mojo = ">=1.2.0,<2.0.0"',
        )
    return Check("mojo", _OK, version, "")


def mojo_version_of(output: String) -> String:
    """`Mojo 1.2.0 (2016d0cd)` is `1.2.0`; "" when there is no version."""
    var words = String(output.strip()).split(" ")
    if len(words) < 2 or String(words[0]) != "Mojo":
        return ""
    var version = String(words[1])
    var parts = version.split(".")
    if len(parts) != 3:
        return ""
    for part in parts:
        if part.byte_length() == 0 or not String(part).is_ascii_digit():
            return ""
    return version


def supported_mojo(version: String) -> Bool:
    """At least 1.2.0 and below 2."""
    var parts = version.split(".")
    try:
        var major = Int(String(parts[0]))
        var minor = Int(String(parts[1]))
        if major != 1:
            return False
        return minor >= 2
    except:
        return False


def check_project(root: String) -> Check:
    if not exists(join(root, "pixi.toml")):
        return Check(
            "project",
            _WARN,
            "no pixi.toml here or above",
            "make a project: dodo new NAME",
        )
    return Check("project", _OK, root, "")


def check_app(root: String) -> Check:
    if isfile(join(root, "main.mojo")):
        return Check("app", _OK, "main.mojo", "")
    return Check(
        "app",
        _WARN,
        "no main.mojo in the project root",
        "name the file instead: dodo run app.mojo",
    )


def check_dodo_package(root: String) -> Check:
    var prefix = getenv("CONDA_PREFIX")
    if prefix != "" and isfile(join(prefix, "lib", "mojo", "dodo.mojoc")):
        return Check("dodo package", _OK, "installed", "")
    if isfile(join(root, "dodo", "__init__.mojo")):
        return Check(
            "dodo package", _OK, "from source (the dodo repository)", ""
        )
    return Check(
        "dodo package",
        _FAIL,
        "dodo is not installed in this environment",
        "pixi add dodo (with the modular-community channel)",
    )


def check_native_libs() -> Check:
    var missing = List[String]()
    for name in materialize[NATIVE_LIBS]():
        try:
            var lib = OwnedDLHandle(find_dodo_lib(name))
            _ = lib^
        except:
            missing.append(String("libdodo_", name, ".so"))
    var total = len(materialize[NATIVE_LIBS]())
    if len(missing) > 0:
        return Check(
            "native libraries",
            _FAIL,
            String("missing: ", String(", ").join(missing)),
            "pixi install (they are built when the environment activates)",
        )
    return Check("native libraries", _OK, String("all ", total, " load"), "")


def check_docs(root: String, mojo_version: String) -> Check:
    var docs = join(root, ".dodo", "docs")
    if mojo_version != "" and isdir(join(docs, String("mojo-", mojo_version))):
        return Check(
            "docs", _OK, String(".dodo/docs has Mojo ", mojo_version), ""
        )
    return Check(
        "docs",
        _WARN,
        "no Mojo docs for this toolchain in .dodo/docs",
        "dodo docs pull",
    )


def check_open_files() -> Check:
    var limit = open_files_limit()
    if limit < 0:
        return Check("open files", _WARN, "cannot read the limit", "")
    if limit < _MIN_OPEN_FILES:
        return Check(
            "open files",
            _WARN,
            String("limit is ", limit, "; a busy server needs more"),
            "ulimit -n 65536",
        )
    return Check("open files", _OK, String("limit ", limit), "")


def open_files_limit() -> Int:
    """The soft `RLIMIT_NOFILE`, or -1 when it cannot be read."""
    var resource = 7
    comptime if CompilationTarget.is_macos():
        resource = 8
    var limits = List[UInt64](length=2, fill=0)
    var rc = external_call["getrlimit", Int32](
        Int32(resource), limits.unsafe_ptr()
    )
    if rc != 0:
        return -1
    var soft = limits[0]
    if soft > UInt64(Int.MAX):
        return Int.MAX
    return Int(soft)


def check_git() -> Check:
    try:
        var result = capture(["git", "--version"])
        if result.status.succeeded():
            return Check("git", _OK, String(result.output.strip()), "")
    except:
        pass
    return Check(
        "git", _WARN, "git is not on PATH", "install git; dodo new uses it"
    )
