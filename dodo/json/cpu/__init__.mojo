"""The CPU parser: a two-pass stage 1 + stage 2 walker.

Stage 1 finds the structural positions (SIMD by default, scalar with
``force_scalar=True``; both give the same index). Stage 2 walks that
index and emits a ``Document`` tape, whose root comes back wrapped as a
``Value`` view.
"""

from std.memory import ArcPointer

from ..value import Value
from ..value.value import make_view_value
from ..document import Document
from .stage2 import parse_two_pass_tape


def parse_cpu_native_tape[
    force_scalar: Bool = False
](var s: String) raises -> Value:
    """Parse ``s`` into a tape-backed ``Value`` view of the document root.

    Reads (``is_*``, ``*_value``, ``__getitem__``, ...) hit the tape
    directly; a mutation materialises an owned tree and rebuilds the
    document.

    Parameters:
        force_scalar: Use the scalar stage 1 instead of the SIMD one.

    Args:
        s: JSON input. The returned ``Value``'s document owns it.

    Returns:
        A ``Value`` view of the document root.
    """
    var doc = parse_two_pass_tape[force_scalar=force_scalar](s^)
    var root_idx = doc.root()
    var arc = ArcPointer[Document](doc^)
    return make_view_value(arc, root_idx)
