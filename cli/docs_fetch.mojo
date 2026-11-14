"""Download the files of one docs folder, several at a time.

Every file is one round trip to the docs server, about 0.3 s to
raw.githubusercontent.com even on a kept-alive connection, and one
connection carries one request at a time. `fetch_files` splits the files
among `FETCH_THREADS` threads, each with its own client and connection,
so a folder of 288 files takes about 288 / 8 round trips instead of 288.
"""

from std.atomic import Atomic, Ordering
from std.os import getenv, makedirs
from std.os.path import dirname, join

from dodo.http import HttpClient, Response, RetryPolicy
from dodo.runtime._thread import ThreadHandle, _OpaquePtr
from dodo.runtime.pool import Pool

from cli.docs_folder import write_file
from cli.version import DODO_VERSION

comptime FETCH_THREADS = 8
"""How many files download at once."""
comptime _CONNECT_TIMEOUT_MS = 10_000
comptime _READ_TIMEOUT_MS = 30_000


def docs_client() raises -> HttpClient:
    """A client that keeps its connection open between files.

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


def fetch_bytes(client: HttpClient, url: String) raises -> List[UInt8]:
    """The body of `url`.

    Raises:
        Error: If it cannot be reached or does not answer 200.
    """
    var reply: Response
    try:
        reply = client.get(url)
    except e:
        raise Error(cannot_reach(url, e))
    if reply.status != 200:
        raise Error(bad_status(url, reply.status))
    var body = List[UInt8]()
    swap(body, reply.body)
    return body^


def cannot_reach(url: String, error: Error) -> String:
    return String("cannot download ", url, ": ", error)


def bad_status(url: String, status: Int) -> String:
    return String(url, " answered ", status)


struct Fetched(Movable):
    """What `fetch_files` saved, or what went wrong first."""

    var files: Int
    var bytes: Int
    var error: String
    """"" when every file was saved."""
    var error_kind: String
    """"network" or "disk"."""
    var failed_at: Int
    """The failing file's place in the list, or -1."""

    def __init__(out self):
        self.files = 0
        self.bytes = 0
        self.error = ""
        self.error_kind = ""
        self.failed_at = -1

    def failed(self) -> Bool:
        return self.error != ""


struct _Job(Movable):
    """One thread's share of the files. The thread fills `fetched`; the
    join is what makes that visible to the caller."""

    var base_url: String
    var staging: String
    var links: List[String]
    var places: List[Int]
    """Each link's place in the whole list."""
    var stop_addr: Int
    """A heap `Int` that turns 1 once any thread fails."""
    var fetched: Fetched

    def __init__(out self, base_url: String, staging: String, stop_addr: Int):
        self.base_url = base_url
        self.staging = staging
        self.links = List[String]()
        self.places = List[Int]()
        self.stop_addr = stop_addr
        self.fetched = Fetched()


def fetch_files(
    base_url: String,
    links: List[String],
    staging: String,
    threads: Int = FETCH_THREADS,
) raises -> Fetched:
    """Download `base_url + link` into `join(staging, link)` for every
    link, `threads` at a time. Once one file fails the others stop after
    the file they are on; the failure with the lowest place is returned.

    Raises:
        Error: If a folder cannot be made or a thread cannot start.
    """
    var fetched = Fetched()
    var count = min(threads, len(links))
    if count == 0:
        return fetched^
    # Made here, so two threads never race to make the same folder.
    for link in links:
        var folder = dirname(join(staging, link))
        if folder != "":
            makedirs(folder, exist_ok=True)
    var stop_addr = Pool[Int].alloc_move(0)
    var jobs = List[Int]()
    var handles = List[ThreadHandle]()
    var spawn_error = String("")
    try:
        for _ in range(count):
            jobs.append(
                Pool[_Job].alloc_move(_Job(base_url, staging, stop_addr))
            )
        for i in range(len(links)):
            var job = Pool[_Job].get_ptr(jobs[i % count])
            job[].links.append(links[i])
            job[].places.append(i)
        for addr in jobs:
            var arg = _OpaquePtr(unsafe_from_address=addr)
            handles.append(ThreadHandle.spawn_os[_fetch_start](arg))
    except e:
        spawn_error = String(e)
        _stop(stop_addr)
    for i in range(len(handles)):
        try:
            handles[i].join()
        except e:
            if spawn_error == "":
                spawn_error = String(e)
    # A job whose thread never started is still freed here.
    for addr in jobs:
        ref done = Pool[_Job].get_ptr(addr)[].fetched
        fetched.files += done.files
        fetched.bytes += done.bytes
        if done.failed() and (
            not fetched.failed() or done.failed_at < fetched.failed_at
        ):
            fetched.error = done.error
            fetched.error_kind = done.error_kind
            fetched.failed_at = done.failed_at
        Pool[_Job].free(addr)
    Pool[Int].free(stop_addr)
    if spawn_error != "":
        raise Error(spawn_error)
    return fetched^


def _fetch_start(arg: _OpaquePtr) -> _OpaquePtr:
    """Thread body: download this job's files until done or stopped."""
    var job = Pool[_Job].get_ptr(Int(arg))
    var kind = String("network")
    var place = -1
    try:
        var client = docs_client()
        for i in range(len(job[].links)):
            if _stopped(job[].stop_addr):
                break
            place = job[].places[i]
            ref link = job[].links[i]
            kind = "network"
            var body = fetch_bytes(client, job[].base_url + link)
            kind = "disk"
            write_file(join(job[].staging, link), body)
            job[].fetched.files += 1
            job[].fetched.bytes += len(body)
    except e:
        job[].fetched.error = String(e)
        job[].fetched.error_kind = kind
        job[].fetched.failed_at = place
        _stop(job[].stop_addr)
    return arg


def _stop(addr: Int):
    var p = Pool[Int].get_ptr(addr).unsafe_bitcast[Scalar[DType.int64]]()
    Atomic[Int64].store[ordering=Ordering.RELEASE](p, Int64(1))


def _stopped(addr: Int) -> Bool:
    var p = Pool[Int].get_ptr(addr).unsafe_bitcast[Scalar[DType.int64]]()
    return Atomic[Int64].load[ordering=Ordering.ACQUIRE](p) != Int64(0)
