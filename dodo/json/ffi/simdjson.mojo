"""simdjson parsing through ``libdodo_simdjson.so``.

The library (built by ``dodo/json/ffi/build.sh``) parses JSON with simdjson
and lays the result out as a ``Document`` tape in its own buffers. This
module loads it once per process, resolves its three entry points, and
copies those buffers into a ``Document``.
"""

from std.collections import List
from std.ffi import _get_global
from std.memory import Layout, OptionalPointer, Pointer, alloc

from ..document import Document
from ...utils.dylib import pinned_dodo_lib

# Returned by the library when a parse succeeds. Any other value is a
# failure, which the caller handles the same way.
comptime SIMDJSON_OK: Int = 0

comptime _THREAD_PARSER = 0
comptime _PARSE_TO_TAPE = 1
comptime _TAPE_BUFFERS = 2
comptime _COPY = 3
comptime _SYMBOL_COUNT = 4

comptime _ThreadParserFn = def() thin abi("C") -> Int
comptime _ParseFn = def(Int, Int, Int) thin abi("C") -> Int
comptime _TapeBuffersFn = def(Int, Int) thin abi("C") -> None
comptime _CopyFn = def(Int, Int, Int) thin abi("C") -> None


def _load_symbols() -> OptionalPointer[NoneType, UntrackedOrigin[mut=True]]:
    """Resolve the entry points into a leaked table of addresses.

    Every slot stays zero when the library or one of its symbols is
    missing. The library handle is pinned for the life of the process, so
    the addresses stay valid.
    """
    var table = alloc(Layout[Int](count=_SYMBOL_COUNT)).unsafe_leak()
    for slot in range(_SYMBOL_COUNT):
        table.unsafe_offset(slot).unsafe_write(0)
    try:
        ref lib = pinned_dodo_lib["simdjson"]()[]
        var names = [
            "dodo_simdjson_thread_parser",
            "dodo_simdjson_parse_to_tape",
            "dodo_simdjson_tape_buffers",
            "dodo_simdjson_copy",
        ]
        var addresses = List[Int]()
        for name in names:
            var symbol = lib.get_symbol[NoneType](name)
            if not symbol:
                raise Error("missing symbol " + name)
            addresses.append(Int(symbol.value()))
        for slot in range(_SYMBOL_COUNT):
            table.unsafe_offset(slot).unsafe_write(addresses[slot])
    except:
        # No library or a missing symbol: every slot stays zero.
        pass
    return Pointer[NoneType, UntrackedOrigin[mut=True]](
        unsafe_from_address=Int(table)
    )


def _free_symbols(
    table: OptionalPointer[NoneType, UntrackedOrigin[mut=True]],
):
    if table:
        Pointer[Int, MutUntrackedOrigin](
            unsafe_from_address=Int(table.value())
        ).unsafe_free()


def _symbol_address(slot: Int) -> Int:
    var table = Int(
        _get_global[
            "dodo_json_simdjson_symbols", _load_symbols, _free_symbols
        ]().value()
    )
    var address = Pointer[Int, MutUntrackedOrigin](
        unsafe_from_address=table + slot * 8
    )[]
    return address


def simdjson_available() -> Bool:
    """Whether ``libdodo_simdjson.so`` loaded. Checked once per process."""
    return _symbol_address(_THREAD_PARSER) != 0


struct SimdjsonTape:
    """Entry points over the calling thread's parser.

    The parser is created once per thread and reuses its buffers, so a
    small document costs little beyond simdjson's own work.
    """

    var _parse_to_tape: _ParseFn
    var _tape_buffers: _TapeBuffersFn
    var _copy: _CopyFn
    var _parser: Int

    def __init__(out self) raises:
        """Resolve the entry points.

        Raises:
            Error: If the library is not available.
        """
        if not simdjson_available():
            raise Error("libdodo_simdjson.so is not available")
        self._parse_to_tape = _as_function[_ParseFn](_PARSE_TO_TAPE)
        self._tape_buffers = _as_function[_TapeBuffersFn](_TAPE_BUFFERS)
        self._copy = _as_function[_CopyFn](_COPY)
        var thread_parser = _as_function[_ThreadParserFn](_THREAD_PARSER)
        self._parser = thread_parser()

    def parse(self, json: Span[UInt8, _]) -> Int:
        """Parse ``json`` into the parser's tape buffers.

        Args:
            json: The JSON text, any bytes.

        Returns:
            ``SIMDJSON_OK``, or the code of the failure.
        """
        return self._parse_to_tape(
            self._parser, Int(json.unsafe_ptr()), len(json)
        )

    def take_document(self) -> Document:
        """Copy the last successful parse out of the parser's buffers."""
        # Filled by the wrapper as pointer and length pairs: tape, string
        # arena, float pool, int pool. Lengths count elements.
        var buffers = List[Int64](length=8, fill=0)
        self._tape_buffers(self._parser, Int(buffers.unsafe_ptr()))

        var doc = Document()
        doc.tape = List[UInt64](length=Int(buffers[1]), fill=0)
        self._copy_in(Int(doc.tape.unsafe_ptr()), buffers[0], buffers[1] * 8)

        var arena = List[UInt8](length=Int(buffers[3]), fill=0)
        self._copy_in(Int(arena.unsafe_ptr()), buffers[2], buffers[3])
        doc.input = String(unsafe_from_utf8=arena)

        doc.float_pool = List[Float64](length=Int(buffers[5]), fill=0.0)
        self._copy_in(
            Int(doc.float_pool.unsafe_ptr()), buffers[4], buffers[5] * 8
        )

        doc.int_pool = List[Int64](length=Int(buffers[7]), fill=0)
        self._copy_in(
            Int(doc.int_pool.unsafe_ptr()), buffers[6], buffers[7] * 8
        )
        return doc^

    def _copy_in(self, destination: Int, source: Int64, byte_count: Int64):
        if byte_count > 0:
            self._copy(destination, Int(source), Int(byte_count))


def _as_function[FT: TrivialRegisterPassable](slot: Int) -> FT:
    var address = _symbol_address(slot)
    return Pointer(to=address).unsafe_bitcast[FT]()[]
