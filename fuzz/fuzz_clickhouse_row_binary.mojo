"""Fuzz harness: ClickHouse RowBinaryWithNamesAndTypes results.

Hands the input to `decode` as an HTTP reply body: the column count, the
names, the type names, then the rows. Every row is read back cell by cell.
A hostile server must get a `DbError`, never a crash or a hang.

Run:
    pixi run fuzz clickhouse_row_binary
"""

from mozz import fuzz, FuzzConfig
from dodo.db.clickhouse.protocol import decode
from dodo.db.rows import Rows


def target_body(data: List[UInt8]) raises:
    _read_all(decode(Span(data)))


def _read_all(rows: Rows) raises:
    for row in range(len(rows)):
        for column in range(len(rows.columns)):
            if rows.is_null(row, column):
                continue
            _ = rows.get_bytes(row, column)
    _ = String(rows)


def _varuint(mut out: List[UInt8], value: Int):
    var v = value
    while v >= 0x80:
        out.append(UInt8((v & 0x7F) | 0x80))
        v >>= 7
    out.append(UInt8(v))


def _string(mut out: List[UInt8], text: String):
    _varuint(out, text.byte_length())
    out.extend(text.as_bytes())


def _le(mut out: List[UInt8], value: Int, n: Int):
    for i in range(n):
        out.append(UInt8((value >> (8 * i)) & 0xFF))


def _body(names: List[String], types: List[String]) -> List[UInt8]:
    var out = List[UInt8]()
    _varuint(out, len(names))
    for name in names:
        _string(out, name)
    for type_name in types:
        _string(out, type_name)
    return out^


def _scalars() -> List[UInt8]:
    var out = _body(
        ["id", "note", "price", "at", "day", "ok"],
        [
            "UInt64",
            "Nullable(String)",
            "Decimal(9, 2)",
            "DateTime64(3, 'UTC')",
            "Date",
            "Bool",
        ],
    )
    _le(out, 7, 8)
    out.append(0)
    _string(out, "hi")
    _le(out, -1234, 4)
    _le(out, 1_000_123, 8)
    _le(out, 20757, 2)
    out.append(1)
    return out^


def _nested() -> List[UInt8]:
    var out = _body(
        ["tags", "pair", "attrs", "mood", "addr", "uid"],
        [
            "Array(LowCardinality(String))",
            "Tuple(a Int32, b String)",
            "Map(String, Array(Int8))",
            "Enum8('sad' = 1, 'happy' = 2)",
            "IPv6",
            "UUID",
        ],
    )
    _varuint(out, 2)
    _string(out, "a")
    _string(out, "b")
    _le(out, -5, 4)
    _string(out, "x")
    _varuint(out, 1)
    _string(out, "k")
    _varuint(out, 2)
    out.append(1)
    out.append(0xFF)
    out.append(2)
    for i in range(16):
        out.append(UInt8(i))
    for i in range(16):
        out.append(UInt8(255 - i))
    return out^


def main() raises:
    print("[mozz] fuzzing ClickHouse RowBinary bodies\n")
    var seeds = List[List[UInt8]]()
    seeds.append(_scalars())
    seeds.append(_nested())
    seeds.append(_body(["n"], ["Int32"]))
    seeds.append(List[UInt8]())
    fuzz(
        target_body,
        FuzzConfig(
            max_runs=200_000,
            seed=0,
            verbose=True,
            crash_dir=".mozz_crashes/clickhouse_row_binary",
            max_input_len=2048,
        ),
        seeds,
    )
