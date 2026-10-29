"""``loads``: JSON text to a ``Value``.

Parsing goes through simdjson (``dodo/json/ffi``) when its library is
available, and through the pure-Mojo parser otherwise. When simdjson
rejects an input, the pure-Mojo parser decides: it returns the value for
the few inputs simdjson refuses but JSON allows (integers wider than 64
bits become floats, a lone surrogate escape becomes U+FFFD), and it raises
the error for everything else. So both paths give the same result for
every input.
"""

from std.memory import ArcPointer

from .cpu import parse_cpu_native_tape
from .cpu.validate import is_valid_utf8
from .document import Document
from .ffi.simdjson import SIMDJSON_OK, SimdjsonTape, simdjson_available
from .value import Value
from .value.value import make_view_value


def loads(var s: String) raises -> Value:
    """Parse JSON text into a ``Value``.

    Args:
        s: The JSON text. The returned ``Value`` owns it.

    Returns:
        A ``Value`` view over the parsed document.

    Raises:
        Error: If ``s`` is not valid JSON.
    """
    if simdjson_available():
        return parse_simdjson_string(s^)
    return parse_mojo_string(s^)


def loads(bytes: Span[UInt8, _]) raises -> Value:
    """Parse JSON bytes into a ``Value``.

    The bytes are checked for well-formed UTF-8, because a ``String`` built
    from ill-formed bytes is undefined behaviour.

    Args:
        bytes: The JSON text.

    Returns:
        A ``Value`` view over the parsed document.

    Raises:
        Error: If ``bytes`` is not UTF-8 or not valid JSON.
    """
    if simdjson_available():
        return parse_simdjson_bytes(bytes)
    return parse_mojo_bytes(bytes)


def parse_mojo_string(var s: String) raises -> Value:
    """Parse ``s`` with the pure-Mojo parser.

    Args:
        s: The JSON text. The returned ``Value`` owns it.

    Returns:
        A ``Value`` view over the parsed document.

    Raises:
        Error: If ``s`` is not valid JSON.
    """
    return parse_cpu_native_tape(s^)


def parse_mojo_bytes(bytes: Span[UInt8, _]) raises -> Value:
    """Parse ``bytes`` with the pure-Mojo parser, after a UTF-8 check.

    Args:
        bytes: The JSON text.

    Returns:
        A ``Value`` view over the parsed document.

    Raises:
        Error: If ``bytes`` is not UTF-8 or not valid JSON.
    """
    if not is_valid_utf8(bytes):
        raise Error("invalid UTF-8 in input")
    return parse_cpu_native_tape(String(unsafe_from_utf8=bytes))


def parse_simdjson_string(var s: String) raises -> Value:
    """Parse ``s`` with simdjson, falling back to the Mojo parser when
    simdjson rejects it.

    Args:
        s: The JSON text.

    Returns:
        A ``Value`` view over the parsed document.

    Raises:
        Error: If the library is not loaded or ``s`` is not valid JSON.
    """
    var tape = SimdjsonTape()
    var code = tape.parse(s.as_bytes())
    if code != SIMDJSON_OK:
        return parse_mojo_string(s^)
    return _view_of(tape.take_document())


def parse_simdjson_bytes(bytes: Span[UInt8, _]) raises -> Value:
    """Parse ``bytes`` with simdjson, falling back to the Mojo parser when
    simdjson rejects them.

    Args:
        bytes: The JSON text.

    Returns:
        A ``Value`` view over the parsed document.

    Raises:
        Error: If the library is not loaded, or ``bytes`` is not UTF-8 or
            not valid JSON.
    """
    var tape = SimdjsonTape()
    var code = tape.parse(bytes)
    if code != SIMDJSON_OK:
        return parse_mojo_bytes(bytes)
    return _view_of(tape.take_document())


def simdjson_accepts(bytes: Span[UInt8, _]) raises -> Bool:
    """Whether simdjson itself parses ``bytes``, with no fallback.

    Args:
        bytes: The JSON text.

    Returns:
        True if simdjson accepts ``bytes``.

    Raises:
        Error: If the library is not loaded.
    """
    var tape = SimdjsonTape()
    return tape.parse(bytes) == SIMDJSON_OK


def _view_of(var doc: Document) -> Value:
    var root_idx = doc.root()
    var arc = ArcPointer[Document](doc^)
    return make_view_value(arc, root_idx)
