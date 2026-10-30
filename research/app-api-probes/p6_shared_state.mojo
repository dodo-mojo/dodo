"""P6d: the App state is boxed once; handlers borrow it, and threads share the App.

Run: pixi run mojo -I . -I research/app-api-probes research/app-api-probes/p6_shared_state.mojo

AppState below is Movable only, not Copyable: if a request copied it, this
file would not compile. The handler returns the address of the state it was
given, and every request, on every thread, must report the App's box address.
Threads are raw pthreads, each holding its own ArcPointer copy of the App.
"""

from std.ffi import external_call, c_int
from std.memory import ArcPointer
from p6_lib import *

comptime OpaquePtr = Pointer[UInt8, MutUntrackedOrigin]


@fieldwise_init
struct AppState(State):
    var db_name: String
    var weights: List[Int]


@fieldwise_init
struct Where(Movable):
    var address: Int
    var db: String
    var total: Int


def where_is_state(req: Request, state: AppState) raises -> Where:
    var total = 0
    for w in state.weights:
        total += w
    return Where(Int(Pointer(to=state)), state.db_name, total)


struct WorkerArg(Movable):
    var app: ArcPointer[App[AppState]]
    var expected: String
    var mismatches: Int

    def __init__(out self, var app: ArcPointer[App[AppState]], expected: String):
        self.app = app^
        self.expected = expected
        self.mismatches = 0


def worker(raw: OpaquePtr) -> OpaquePtr:
    var arg = box_ptr[WorkerArg](Int(raw))
    for _ in range(2000):
        var resp = arg[].app[].dispatch(Request("GET", "/where", "", ""))
        if resp.body != arg[].expected:
            arg[].mismatches += 1
    return raw


def start_thread(arg_addr: Int) raises -> UInt64:
    var tid = UInt64(0)
    var tid_ptr = Pointer[UInt64, MutUntrackedOrigin](unsafe_from_address=Int(Pointer(to=tid)))
    var zero = 0
    var no_attr = OpaquePtr(unsafe_from_address=zero)
    var arg = OpaquePtr(unsafe_from_address=arg_addr)
    var rc = external_call[
        "pthread_create",
        c_int,
        Pointer[UInt64, MutUntrackedOrigin],
        OpaquePtr,
        def(OpaquePtr) thin -> OpaquePtr,
        OpaquePtr,
    ](tid_ptr, no_attr, worker, arg)
    if rc != c_int(0):
        raise Error("pthread_create failed")
    return tid


def join_thread(tid: UInt64):
    var zero = 0
    var no_result = OpaquePtr(unsafe_from_address=zero)
    _ = external_call["pthread_join", c_int, UInt64, OpaquePtr](tid, no_result)


def main() raises:
    var weights = List[Int]()
    for i in range(1000):
        weights.append(i)
    var app = App(state=AppState("model-db", weights^))
    app.get["/where"](where_is_state)

    var first = app.dispatch(Request("GET", "/where", "", ""))
    print("app state box address:", app.state_addr)
    print("first response:", first.body)

    var same = True
    for _ in range(1000):
        var resp = app.dispatch(Request("GET", "/where", "", ""))
        if resp.body != first.body:
            same = False
    print("1000 sequential requests saw the same state:", same)

    var shared = ArcPointer(app^)
    var worker_count = 8
    var args = List[Int]()
    var threads = List[UInt64]()
    for _ in range(worker_count):
        args.append(box_move(WorkerArg(shared.copy(), first.body)))
    print("ArcPointer[App] strong count with 8 workers holding a copy:", shared.count())
    for addr in args:
        threads.append(start_thread(addr))
    for tid in threads:
        join_thread(tid)

    var mismatches = 0
    for addr in args:
        var arg = box_ptr[WorkerArg](addr)
        mismatches += arg[].mismatches
        arg.unsafe_deinit_pointee()
    print("8 threads x 2000 requests through one ArcPointer[App], mismatches:", mismatches)
    print("strong count after workers dropped their copies:", shared.count())
