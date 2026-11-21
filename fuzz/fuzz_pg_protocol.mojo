"""Fuzz harness: PostgreSQL backend messages.

Reads the input as a stream of backend messages (a tag byte, an Int32
length, then the body), the way a connection reads a server's replies,
and hands each one to its parser:

- `T` RowDescription, then `D` DataRow against those columns
- `E` ErrorResponse and `N` NoticeResponse
- `C` CommandComplete

Every row is then read back cell by cell. A hostile server must get a
`DbError`, never a crash.

Run:
    pixi run fuzz pg_protocol
"""

from mozz import fuzz, FuzzConfig
from dodo.db.error import DbError
from dodo.db.postgres.protocol import (
    frame_length,
    parse_command_tag,
    parse_data_row,
    parse_error,
    parse_row_description,
)
from dodo.db.rows import Rows


def target_messages(data: List[UInt8]) raises:
    var rows = Rows()
    var oids = List[Int]()
    var at = 0
    while at + 5 <= len(data):
        var length = frame_length(Span(data)[at : at + 5])
        var tag = Int(data[at])
        var start = at + 5
        if start + length > len(data):
            raise DbError.protocol("postgres", "message runs past the input")
        var body = Span(data)[start : start + length]
        if tag == ord("T"):
            rows = Rows()
            oids = parse_row_description(body, rows)
        elif tag == ord("D"):
            parse_data_row(body, oids, rows)
        elif tag == ord("E") or tag == ord("N"):
            _ = String(parse_error(body))
        elif tag == ord("C"):
            _ = parse_command_tag(body)
        at = start + length
    _read_all(rows)


def _read_all(rows: Rows) raises:
    for row in range(len(rows)):
        for column in range(len(rows.columns)):
            if rows.is_null(row, column):
                continue
            _ = rows.get_bytes(row, column)
    _ = String(rows)


def _message(tag: String, body: List[UInt8]) -> List[UInt8]:
    var out = List[UInt8]()
    out.append(tag.as_bytes()[0])
    var length = len(body) + 4
    out.append(UInt8((length >> 24) & 0xFF))
    out.append(UInt8((length >> 16) & 0xFF))
    out.append(UInt8((length >> 8) & 0xFF))
    out.append(UInt8(length & 0xFF))
    out.extend(Span(body))
    return out^


def _be(mut out: List[UInt8], value: Int, n: Int):
    for i in range(n):
        out.append(UInt8((value >> (8 * (n - 1 - i))) & 0xFF))


def _text(mut out: List[UInt8], text: String):
    out.extend(text.as_bytes())


def _cstr(mut out: List[UInt8], text: String):
    _text(out, text)
    out.append(0)


def _row_description() -> List[UInt8]:
    """Two columns: `id` int4 and `data` bytea."""
    var body = List[UInt8]()
    _be(body, 2, 2)
    _column(body, "id", 23)
    _column(body, "data", 17)
    return _message("T", body)


def _column(mut body: List[UInt8], name: String, oid: Int):
    _cstr(body, name)
    _be(body, 0, 6)  # table OID, column number
    _be(body, oid, 4)
    _be(body, 0, 8)  # type size, type modifier, format code


def _data_row(id: String, data: String) -> List[UInt8]:
    var body = List[UInt8]()
    _be(body, 2, 2)
    _be(body, id.byte_length(), 4)
    _text(body, id)
    _be(body, data.byte_length(), 4)
    _text(body, data)
    return _message("D", body)


def _null_row() -> List[UInt8]:
    var body = List[UInt8]()
    _be(body, 2, 2)
    _be(body, 0xFFFFFFFF, 4)  # -1: NULL
    _be(body, 0xFFFFFFFF, 4)
    return _message("D", body)


def _error() -> List[UInt8]:
    var body = List[UInt8]()
    _cstr(body, "SERROR")
    _cstr(body, "C42P01")
    _cstr(body, "Mno such table")
    body.append(0)
    return _message("E", body)


def _complete(tag: String) -> List[UInt8]:
    var body = List[UInt8]()
    _cstr(body, tag)
    return _message("C", body)


def main() raises:
    print("[mozz] fuzzing PostgreSQL backend messages\n")
    var seeds = List[List[UInt8]]()

    var result = _row_description()
    result.extend(_data_row("1", "\\x6869"))
    result.extend(_null_row())
    result.extend(_complete("SELECT 2"))
    seeds.append(result^)
    seeds.append(_error())
    seeds.append(_complete("INSERT 0 5"))
    seeds.append(_complete("UPDATE 12"))
    seeds.append(List[UInt8]())

    fuzz(
        target_messages,
        FuzzConfig(
            max_runs=200_000,
            seed=0,
            verbose=True,
            crash_dir=".mozz_crashes/pg_protocol",
            max_input_len=2048,
        ),
        seeds,
    )
