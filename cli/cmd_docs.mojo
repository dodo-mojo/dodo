"""`dodo docs pull`: download the Mojo and dodo docs into `.dodo/docs/`.

Both come from the `dev` branch of dodo's GitHub repository as plain
files, saved there once per release:

    <source>/dev/mojo-docs/index.md          the saved Mojo versions
    <source>/dev/mojo-docs/<version>/        one Mojo release
    <source>/dev/dodo-docs/index.md          the saved dodo versions
    <source>/dev/dodo-docs/<version>/        one dodo release

`<source>` is `DODO_DOCS_URL` when set (tests point it at a local
server), else raw.githubusercontent.com. A server silent for 30 s
(`DODO_DOCS_READ_TIMEOUT_MS`) fails the pull. Each folder's `index.md`
lists its files. They download into a hidden folder that replaces the old
docs only once every file is in, so a failed pull keeps the docs you had.
"""

from std.os import getenv
from std.os.path import join
from std.time import perf_counter_ns

from dodo.http import HttpClient, Response, RetryPolicy
from dodo.json import Value

from cli.args import ParsedArgs
from cli.capture import capture
from cli.cmd_doctor import mojo_version_of
from cli.docs_folder import remove_tree, swap_in, write_file
from cli.docs_index import (
    index_links,
    is_safe_path,
    pick_version,
    saved_versions,
    version_parts,
)
from cli.project import find_root
from cli.report import (
    EXIT_OK,
    EXIT_UNAVAILABLE,
    EXIT_USAGE,
    Report,
    format_seconds,
)
from cli.version import DODO_VERSION

comptime DEFAULT_DOCS_URL = "https://raw.githubusercontent.com/dodo-mojo/dodo"
comptime _CONNECT_TIMEOUT_MS = 10_000
comptime _READ_TIMEOUT_MS = 30_000


struct DocsWanted(Movable):
    """The versions asked for; "" means the project's."""

    var mojo: String
    var dodo: String

    def __init__(out self):
        self.mojo = ""
        self.dodo = ""


def docs_wanted(parsed: ParsedArgs) raises -> DocsWanted:
    """The versions named by `--mojo`/`--dodo` or `mojo@`/`dodo@`.

    Raises:
        Error: If a word is not `NAME@VERSION`, a name is not mojo or
            dodo, a version is named twice, or a version is not one.
    """
    var wanted = DocsWanted()
    var mojo_given = parsed.given("mojo")
    var dodo_given = parsed.given("dodo")
    wanted.mojo = parsed.value("mojo")
    wanted.dodo = parsed.value("dodo")
    for word in parsed.positionals:
        var at = word.find("@")
        if at < 0:
            raise Error("`", word, "` is not mojo@VERSION or dodo@VERSION")
        var name = String(word[byte=:at])
        var version = String(word[byte = at + 1 :])
        if name == "mojo":
            if mojo_given:
                raise Error("the Mojo version is given twice")
            mojo_given = True
            wanted.mojo = version
        elif name == "dodo":
            if dodo_given:
                raise Error("the dodo version is given twice")
            dodo_given = True
            wanted.dodo = version
        else:
            raise Error("there are no `", name, "` docs; pull mojo or dodo")
    if mojo_given:
        _ = version_parts(wanted.mojo)
    if dodo_given:
        _ = version_parts(wanted.dodo)
    return wanted^


struct Pulled(Movable):
    """How pulling one set of docs went."""

    var name: String
    """"Mojo" or "dodo", as people read it."""
    var version: String
    var folder: String
    """Where the docs went, relative to the project root."""
    var files: Int
    var bytes: Int
    var seconds: Float64
    var error_kind: String
    """"" when it worked."""
    var error: String
    var hint: String

    def __init__(out self, name: String):
        self.name = name
        self.version = ""
        self.folder = ""
        self.files = 0
        self.bytes = 0
        self.seconds = 0.0
        self.error_kind = ""
        self.error = ""
        self.hint = ""

    def failed(self) -> Bool:
        return self.error_kind != ""

    def fail(mut self, kind: String, message: String, hint: String = ""):
        self.error_kind = kind
        self.error = message
        self.hint = hint

    def to_json(self) raises -> Value:
        var out = Value.object()
        out["version"] = Value(self.version)
        if self.failed():
            var error = Value.object()
            error["kind"] = Value(self.error_kind)
            error["message"] = Value(self.error)
            out["error"] = error^
            return out^
        out["folder"] = Value(self.folder)
        out["files"] = Value(self.files)
        out["bytes"] = Value(self.bytes)
        out["seconds"] = Value(self.seconds)
        return out^

    def summary(self) -> String:
        """`Mojo 1.2.0: 288 files (3.1 MB) in .dodo/docs/mojo-1.2.0, 4.20 s`"""
        return String(
            self.name,
            " ",
            self.version,
            ": ",
            self.files,
            " files (",
            format_megabytes(self.bytes),
            ") in ",
            self.folder,
            ", ",
            format_seconds(self.seconds),
        )


def cmd_docs_pull(parsed: ParsedArgs, mut report: Report) raises -> Int:
    var wanted: DocsWanted
    try:
        wanted = docs_wanted(parsed)
    except e:
        return report.fail(
            "usage", String(e), EXIT_USAGE, hint="run `dodo docs pull --help`"
        )
    var root = find_root(".")
    var source = docs_source()
    var client: HttpClient
    try:
        client = docs_client()
    except:
        return report.fail(
            "usage",
            "DODO_DOCS_READ_TIMEOUT_MS is not a whole number of milliseconds",
            EXIT_USAGE,
        )
    var mojo = pull_mojo(client, source, root, wanted.mojo, report)
    var dodo = pull_dodo(client, source, root, wanted.dodo, report)
    report.set("mojo", mojo.to_json())
    report.set("dodo", dodo.to_json())
    return finish_pull(mojo, dodo, report)


def docs_source() -> String:
    """`DODO_DOCS_URL` without a trailing `/`, or GitHub."""
    var source = getenv("DODO_DOCS_URL", DEFAULT_DOCS_URL)
    while source.endswith("/"):
        var shorter = String(source[byte = : source.byte_length() - 1])
        source = shorter^
    return source^


def docs_client() raises -> HttpClient:
    """One client for every file, so one connection serves them all.

    Raises:
        Error: If `DODO_DOCS_READ_TIMEOUT_MS` is not a whole number.
    """
    var client = HttpClient(
        timeout_ms=_CONNECT_TIMEOUT_MS,
        user_agent=String("dodo/", DODO_VERSION, " docs-pull"),
    )
    var read_timeout = _READ_TIMEOUT_MS
    var given = getenv("DODO_DOCS_READ_TIMEOUT_MS")
    if given != "":
        read_timeout = Int(given)
        if read_timeout <= 0:
            raise Error("DODO_DOCS_READ_TIMEOUT_MS must be above 0")
    var pooled = client^.with_pool()
    return pooled^.with_read_timeout(read_timeout).with_retry(RetryPolicy())


def pull_mojo(
    client: HttpClient,
    source: String,
    root: String,
    wanted: String,
    report: Report,
) -> Pulled:
    var version = wanted
    if version == "":
        version = project_mojo_version()
    if version == "":
        var pulled = Pulled("Mojo")
        pulled.fail(
            "not_found",
            (
                "cannot tell the project's Mojo version: `mojo --version`"
                " did not answer"
            ),
            hint="name one: dodo docs pull mojo@1.2",
        )
        return pulled^
    return pull_saved(client, source, root, "Mojo", "mojo", version, report)


def pull_dodo(
    client: HttpClient,
    source: String,
    root: String,
    wanted: String,
    report: Report,
) -> Pulled:
    var version = wanted
    if version == "":
        version = DODO_VERSION
    return pull_saved(client, source, root, "dodo", "dodo", version, report)


def pull_saved(
    client: HttpClient,
    source: String,
    root: String,
    label: String,
    name: String,
    version: String,
    report: Report,
) -> Pulled:
    """Pull `<name>-docs/<version>/` into `.dodo/docs/<name>-<version>/`.
    A short version (`1.2`) becomes the newest saved one it names."""
    var pulled = Pulled(label)
    pulled.version = version
    var archive = String(source, "/dev/", name, "-docs/")
    try:
        if len(version_parts(version)) < 3:
            var saved = saved_versions(fetch_text(client, archive + "index.md"))
            var full = pick_version(version, saved)
            if full == "":
                pulled.fail("not_found", _not_saved(label, version, saved))
                return pulled^
            pulled.version = full
    except e:
        pulled.fail("network", String(e))
        return pulled^
    report.note(String("pulling the ", label, " ", pulled.version, " docs..."))
    var folder = String(name, "-", pulled.version)
    pull_folder(
        client, String(archive, pulled.version, "/"), root, folder, pulled
    )
    if pulled.error_kind != "not_found":
        return pulled^
    pulled.error = String("no ", label, " ", pulled.version, " docs are saved")
    try:
        var saved = saved_versions(fetch_text(client, archive + "index.md"))
        pulled.error = _not_saved(label, pulled.version, saved)
    except:
        pass
    return pulled^


def _not_saved(label: String, version: String, saved: List[String]) -> String:
    return String(
        "no ", label, " ", version, " docs are saved; saved: ", _listed(saved)
    )


def pull_folder(
    client: HttpClient,
    base_url: String,
    root: String,
    name: String,
    mut pulled: Pulled,
):
    """Download `base_url`'s `index.md` and every file it lists into
    `.dodo/docs/<name>/`. On any failure the old folder is kept and
    `pulled` says what went wrong; "not_found" means there is no index."""
    var started = perf_counter_ns()
    var docs = join(root, ".dodo", "docs")
    var index_url = base_url + "index.md"
    var index_body = List[UInt8]()
    try:
        var reply = client.get(index_url)
        if reply.status == 404:
            pulled.fail("not_found", String(index_url, " is not there"))
            return
        if reply.status != 200:
            pulled.fail("network", _bad_status(index_url, reply.status))
            return
        swap(index_body, reply.body)
    except e:
        pulled.fail("network", _cannot_reach(index_url, e))
        return
    var index_text: String
    try:
        index_text = String(from_utf8=index_body)
    except:
        pulled.fail("bad_index", String(index_url, " is not UTF-8 text"))
        return
    var links = index_links(index_text)
    for link in links:
        if not is_safe_path(link):
            pulled.fail(
                "bad_index",
                String(index_url, " links outside its folder: `", link, "`"),
            )
            return
    var staging = join(docs, String(".", name, ".new"))
    var kind = String("disk")
    try:
        remove_tree(staging)
        write_file(join(staging, "index.md"), index_body)
        pulled.files = 1
        pulled.bytes = len(index_body)
        for link in links:
            if link == "index.md":
                continue
            var url = base_url + link
            kind = "network"
            var body = fetch_bytes(client, url)
            kind = "disk"
            write_file(join(staging, link), body)
            pulled.files += 1
            pulled.bytes += len(body)
        swap_in(staging, join(docs, name))
    except e:
        _remove_quietly(staging)
        pulled.fail(kind, String(e))
        return
    pulled.folder = join(".dodo", "docs", name)
    pulled.seconds = Float64(perf_counter_ns() - started) / 1e9


def fetch_bytes(client: HttpClient, url: String) raises -> List[UInt8]:
    """The body of `url`.

    Raises:
        Error: If it cannot be reached or does not answer 200.
    """
    var reply: Response
    try:
        reply = client.get(url)
    except e:
        raise Error(_cannot_reach(url, e))
    if reply.status != 200:
        raise Error(_bad_status(url, reply.status))
    var body = List[UInt8]()
    swap(body, reply.body)
    return body^


def fetch_text(client: HttpClient, url: String) raises -> String:
    """`fetch_bytes` as text."""
    var body = fetch_bytes(client, url)
    try:
        return String(from_utf8=body)
    except:
        raise Error(url, " is not UTF-8 text")


def project_mojo_version() -> String:
    """What `mojo --version` says, as `1.2.0`, or "" when it cannot run."""
    try:
        var result = capture(["mojo", "--version"])
        if not result.status.succeeded():
            return ""
        return mojo_version_of(result.output)
    except:
        return ""


def finish_pull(mojo: Pulled, dodo: Pulled, mut report: Report) -> Int:
    """Say what was pulled; a failed half makes the whole pull fail."""
    if not mojo.failed():
        report.say(mojo.summary())
    if not dodo.failed():
        report.say(dodo.summary())
    if mojo.failed() and dodo.failed():
        var kind = mojo.error_kind
        if kind != dodo.error_kind:
            kind = "several"
        return report.fail(
            kind,
            String(mojo.error, "; ", dodo.error),
            EXIT_UNAVAILABLE,
            hint=mojo.hint,
        )
    if mojo.failed():
        return report.fail(
            mojo.error_kind, mojo.error, EXIT_UNAVAILABLE, hint=mojo.hint
        )
    if dodo.failed():
        return report.fail(
            dodo.error_kind, dodo.error, EXIT_UNAVAILABLE, hint=dodo.hint
        )
    return EXIT_OK


def format_megabytes(bytes: Int) -> String:
    """`3_145_728` is "3.1 MB"; under 0.1 MB is "0.1 MB"."""
    var tenths = (bytes * 10 + 524_288) // 1_048_576
    if tenths < 1:
        tenths = 1
    return String(tenths // 10, ".", tenths % 10, " MB")


def _cannot_reach(url: String, error: Error) -> String:
    return String("cannot download ", url, ": ", error)


def _bad_status(url: String, status: Int) -> String:
    return String(url, " answered ", status)


def _listed(versions: List[String]) -> String:
    if len(versions) == 0:
        return "none"
    return String(", ").join(versions)


def _remove_quietly(path: String):
    try:
        remove_tree(path)
    except:
        pass
