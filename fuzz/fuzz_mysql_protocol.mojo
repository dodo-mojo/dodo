"""Fuzz harness: MySQL and MariaDB server packets.

Two targets:

- one packet as the server's first words: the handshake, an OK, an ERR,
  a prepare OK
- a command's whole reply as the connection reads it, through
  `MySqlConnection._read_results` on a replayed stream: OK, ERR, or result
  sets (a column count, the definitions, the rows, an EOF). The first
  input byte picks text or binary rows and the EOF style

Every row is then read back cell by cell. A hostile server must get a
`DbError`, never a crash.

Run:
    pixi run fuzz mysql_protocol
"""

from mozz import fuzz, FuzzConfig
from dodo.db._stream import DbStream
from dodo.db.mysql.connection import MySqlConnection
from dodo.db.mysql.protocol import (
    CLIENT_DEPRECATE_EOF,
    parse_error,
    parse_handshake,
    parse_ok,
    parse_prepare_ok,
)
from dodo.db.rows import Rows


def target_packet(data: List[UInt8]) raises:
    var packet = Span(data)
    try:
        var handshake = parse_handshake(packet)
        _ = handshake.server_version
    except:
        pass
    try:
        _ = parse_ok(packet).affected
    except:
        pass
    _ = String(parse_error(packet))
    _ = parse_prepare_ok(packet).statement_id


def target_result_set(data: List[UInt8]) raises:
    if len(data) == 0:
        return
    var binary = (data[0] & 1) == 1
    var stream = DbStream(replay=Span(data)[1:], database="mysql")
    var conn = MySqlConnection(stream^)
    if (data[0] & 2) == 2:
        conn._capabilities = CLIENT_DEPRECATE_EOF
    _read_all(conn._read_results(binary))


def _read_all(rows: Rows) raises:
    for row in range(len(rows)):
        for column in range(len(rows.columns)):
            if rows.is_null(row, column):
                continue
            _ = rows.get_bytes(row, column)
    _ = String(rows)


# ── Seeds ───────────────────────────────────────────────────────────────────


def _packet(mut out: List[UInt8], payload: List[UInt8], seq: Int):
    var length = len(payload)
    out.append(UInt8(length & 0xFF))
    out.append(UInt8((length >> 8) & 0xFF))
    out.append(UInt8((length >> 16) & 0xFF))
    out.append(UInt8(seq))
    out.extend(Span(payload))


def _lenenc_text(mut out: List[UInt8], text: String):
    out.append(UInt8(text.byte_length()))
    out.extend(text.as_bytes())


def _column(name: String, type_code: Int, flags: Int) -> List[UInt8]:
    var out = List[UInt8]()
    for part in ["def", "dodo", "t", "t"]:
        _lenenc_text(out, part)
    _lenenc_text(out, name)
    _lenenc_text(out, name)
    out.append(0x0C)
    out.append(45)  # utf8mb4
    out.append(0)
    for _ in range(4):
        out.append(0)  # display length
    out.append(UInt8(type_code))
    out.append(UInt8(flags & 0xFF))
    out.append(UInt8(flags >> 8))
    out.append(0)  # decimals
    out.append(0)
    out.append(0)
    return out^


def _result_set(binary: Bool, deprecate_eof: Bool) -> List[UInt8]:
    var out = List[UInt8]()
    var mode = 0
    if binary:
        mode += 1
    if deprecate_eof:
        mode += 2
    out.append(UInt8(mode))
    var count = List[UInt8]()
    count.append(3)
    _packet(out, count, 0)
    _packet(out, _column("id", 0x08, 0x20), 1)  # BIGINT UNSIGNED
    _packet(out, _column("name", 0xFD, 0), 2)  # VARCHAR
    _packet(out, _column("at", 0x0C, 0), 3)  # DATETIME
    var seq = 4
    if not deprecate_eof:
        _packet(out, _from([0xFE, 0, 0, 2, 0]), seq)
        seq += 1
    var row = List[UInt8]()
    if binary:
        row.append(0)
        row.append(0)  # null bitmap
        for b in [7, 0, 0, 0, 0, 0, 0, 0]:
            row.append(UInt8(b))
        _lenenc_text(row, "ada")
        for b in [7, 0xE8, 0x07, 1, 2, 3, 4, 5]:
            row.append(UInt8(b))
    else:
        _lenenc_text(row, "7")
        _lenenc_text(row, "ada")
        row.append(0xFB)  # NULL
    _packet(out, row, seq)
    seq += 1
    if deprecate_eof:
        _packet(out, _from([0xFE, 0, 0, 2, 0, 0, 0]), seq)
    else:
        _packet(out, _from([0xFE, 0, 0, 2, 0]), seq)
    return out^


def _alone(payload: List[UInt8]) -> List[UInt8]:
    """One packet as a whole reply, after the mode byte."""
    var out = List[UInt8]()
    out.append(0)
    _packet(out, payload, 0)
    return out^


def _from(values: List[Int]) -> List[UInt8]:
    var out = List[UInt8](capacity=len(values))
    for value in values:
        out.append(UInt8(value))
    return out^


def _handshake() -> List[UInt8]:
    """A MySQL 8.4 greeting offering caching_sha2_password."""
    var out = _from([10])
    out.extend("8.4.0".as_bytes())
    out.append(0)
    out.extend(Span(_from([1, 0, 0, 0])))  # connection id
    out.extend(Span(_from([1, 2, 3, 4, 5, 6, 7, 8, 0])))  # nonce, part 1
    out.extend(Span(_from([0xFF, 0xF7, 45, 2, 0, 0xFF, 0x81, 21])))
    for _ in range(10):
        out.append(0)
    out.extend("abcdefghijkl".as_bytes())  # nonce, part 2
    out.append(0)
    out.extend("caching_sha2_password".as_bytes())
    out.append(0)
    return out^


def _err() -> List[UInt8]:
    var out = _from([0xFF, 0x7A, 0x04])  # 1146
    out.extend("#42S02no such table".as_bytes())
    return out^


def main() raises:
    var packet_seeds = List[List[UInt8]]()
    packet_seeds.append(_handshake())
    packet_seeds.append(_from([0, 1, 5, 2, 0, 0, 0]))  # OK
    packet_seeds.append(_err())
    packet_seeds.append(_from([0, 1, 0, 0, 0, 2, 0, 1, 0]))  # prepare OK

    print("[mozz] fuzzing MySQL single packets\n")
    fuzz(
        target_packet,
        FuzzConfig(
            max_runs=200_000,
            seed=0,
            verbose=True,
            crash_dir=".mozz_crashes/mysql_packet",
            max_input_len=512,
        ),
        packet_seeds,
    )

    var result_seeds = List[List[UInt8]]()
    for binary in [False, True]:
        for deprecate_eof in [False, True]:
            result_seeds.append(_result_set(binary, deprecate_eof))
    result_seeds.append(_alone(_from([0, 1, 5, 2, 0, 0, 0])))  # OK
    result_seeds.append(_alone(_err()))

    print("\n[mozz] fuzzing MySQL result sets\n")
    fuzz(
        target_result_set,
        FuzzConfig(
            max_runs=200_000,
            seed=1,
            verbose=True,
            crash_dir=".mozz_crashes/mysql_result_set",
            max_input_len=2048,
        ),
        result_seeds,
    )
