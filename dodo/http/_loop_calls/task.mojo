"""``CallTask``: one parked request and its outgoing calls, and the steps
that run its handler's ``start`` and ``finish`` on the worker (ADR-0006).

A connection that parks a request hands its ``CallTask`` to the worker's
:class:`LoopClient`. The client fills one reply slot per call; once
every slot is full the task is ready, and the loop runs ``finish``.
"""

from std.collections import List, Optional

from dodo.errors import log_handler_error, map_handler_error
from dodo.http.calls import CallReply, Calls, no_response_and_no_calls
from dodo.http.handler import Handler
from dodo.http.request import Request
from dodo.http.response import Response
from dodo.runtime.pool import Pool


struct CallTask(Movable):
    """One parked request: what the handler needs for its next step, and
    the replies of the round in flight."""

    var req: Request
    """The incoming request, kept for ``finish``."""
    var calls: Calls
    """The calls and replies so far, and the middleware notes."""
    var fd: Int
    """The incoming connection."""
    var sid: Int
    """The HTTP/2 stream id, or 0 on HTTP/1.1."""
    var slots: List[Optional[CallReply]]
    """This round's replies, in the order the calls were asked for."""
    var left: Int
    """Slots still empty."""
    var running: List[Int]
    """The client's exchange for each slot, or 0 once its reply is in."""
    var abandoned: Bool
    """The connection stopped waiting; the client frees the task."""

    def __init__(
        out self, var req: Request, var calls: Calls, fd: Int, sid: Int
    ):
        self.req = req^
        self.calls = calls^
        self.fd = fd
        self.sid = sid
        self.slots = List[Optional[CallReply]]()
        self.left = 0
        self.running = List[Int]()
        self.abandoned = False

    def fill(mut self, slot: Int, var reply: CallReply) -> Bool:
        """Put ``reply`` in ``slot``. True when that was the last empty
        slot. A slot already filled keeps its first reply."""
        if self.slots[slot]:
            return False
        self.slots[slot] = Optional[CallReply](reply^)
        self.left -= 1
        return self.left == 0

    def end_round(mut self) raises:
        """Hand the round's replies to ``calls`` in order and count the
        round. Raises once the request made ``MAX_ROUNDS`` rounds."""
        for i in range(len(self.slots)):
            self.calls.add_reply(self.slots[i].take())
        self.slots = List[Optional[CallReply]]()
        self.calls.end_round()


def task_new(var task: CallTask) raises -> Int:
    """Put ``task`` on the heap. Its address is what the loop passes
    around; free it with :func:`task_free`."""
    return Pool[CallTask].alloc_move(task^)


def task_ptr(addr: Int) -> Pointer[CallTask, MutUntrackedOrigin]:
    """The task at ``addr``."""
    return Pool[CallTask].get_ptr(addr)


def task_free(addr: Int):
    """Free the task at ``addr``."""
    Pool[CallTask].free(addr)


struct StepAnswer(Movable):
    """What one step of a calling handler came to: a response, an error
    status for a step that raised, or a round of calls to make."""

    var resp: Optional[Response]
    var err_status: Int
    var err_reason: String

    def __init__(out self):
        """The step asked for calls."""
        self.resp = Optional[Response]()
        self.err_status = 0
        self.err_reason = String()

    def __init__(out self, var resp: Response):
        """The step returned ``resp``."""
        self.resp = Optional[Response](resp^)
        self.err_status = 0
        self.err_reason = String()

    def __init__(out self, *, err_status: Int, err_reason: String):
        """The step raised; ``err_status`` is what the client gets."""
        self.resp = Optional[Response]()
        self.err_status = err_status
        self.err_reason = err_reason

    def waiting(self) -> Bool:
        """Whether the step asked for calls instead of answering."""
        if self.resp:
            return False
        return self.err_status == 0


def wants_calls[H: Handler](ref handler: H, req: Request) -> Bool:
    """Whether ``handler`` serves ``req`` in steps. A ``calling`` that
    raises keeps the request on ``serve``."""
    if not handler.may_call():
        return False
    try:
        return handler.calling(req)
    except:
        return False


def first_step[
    H: Handler
](ref handler: H, req: Request, mut calls: Calls) -> StepAnswer:
    """Run ``handler.start``. A raise, or no answer and no calls, becomes
    the error status the inline path would send."""
    try:
        var answer = handler.start(req, calls)
        if answer:
            return StepAnswer(answer.take())
        if calls.waiting() == 0:
            raise no_response_and_no_calls()
        return StepAnswer()
    except e:
        return _failed(req, String(e))


def next_step[H: Handler](ref handler: H, mut task: CallTask) -> StepAnswer:
    """Hand the round's replies over and run ``handler.finish``. A raise,
    too many rounds, or no answer and no calls becomes an error status."""
    try:
        task.end_round()
        var answer = handler.finish(task.req, task.calls)
        if answer:
            return StepAnswer(answer.take())
        if task.calls.waiting() == 0:
            raise no_response_and_no_calls()
        return StepAnswer()
    except e:
        return _failed(task.req, String(e))


def _failed(req: Request, message: String) -> StepAnswer:
    log_handler_error(req.headers.get("x-request-id"), message)
    var mapped = map_handler_error(message, req.expose_errors)
    return StepAnswer(err_status=mapped.status, err_reason=mapped.reason)
