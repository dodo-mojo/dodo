"""ClickHouse over HTTP, without I/O: request URLs, parameters, the
RowBinaryWithNamesAndTypes result format, and errors.

Parameters travel as `param_p1=...` URL fields and the SQL names them with
their type, `{p1:UInt64}`, so a value is never spliced into the SQL.
"""

from .._bytes import ByteReader
from ..error import DbError
from ..param import Param
from ..rows import Rows


comptime DB = "clickhouse"
comptime FORMAT = "RowBinaryWithNamesAndTypes"


# ── Requests ────────────────────────────────────────────────────────────────


def percent_encode(text: Span[UInt8, _]) -> String:
    comptime digits = "0123456789ABCDEF"
    var out = String()
    for b in text:
        var c = Int(b)
        var unreserved = (
            (c >= ord("0") and c <= ord("9"))
            or (c >= ord("A") and c <= ord("Z"))
            or (c >= ord("a") and c <= ord("z"))
            or c == ord("-")
            or c == ord(".")
            or c == ord("_")
            or c == ord("~")
        )
        if unreserved:
            out += chr(c)
        else:
            out += "%"
            out += digits[byte=c >> 4]
            out += digits[byte=c & 15]
    return out^


def escape_value(param: Param) -> List[UInt8]:
    """A parameter in ClickHouse's escaped text format, which is how the
    server parses `param_*` values: backslash, tab and line breaks are
    escaped, NULL is `\\N`."""
    var out = List[UInt8]()
    if param.kind == Param.NULL:
        out.append(UInt8(ord("\\")))
        out.append(UInt8(ord("N")))
        return out^
    var raw: List[UInt8]
    if param.kind == Param.BYTES:
        raw = param.data.copy()
    else:
        raw = List[UInt8](param.as_text().as_bytes())
    for b in raw:
        var c = Int(b)
        if c == ord("\\"):
            out.append(UInt8(ord("\\")))
            out.append(UInt8(ord("\\")))
        elif c == ord("\t"):
            out.append(UInt8(ord("\\")))
            out.append(UInt8(ord("t")))
        elif c == ord("\n"):
            out.append(UInt8(ord("\\")))
            out.append(UInt8(ord("n")))
        elif c == ord("\r"):
            out.append(UInt8(ord("\\")))
            out.append(UInt8(ord("r")))
        elif c == 0:
            out.append(UInt8(ord("\\")))
            out.append(UInt8(ord("0")))
        else:
            out.append(b)
    return out^


def query_string(
    database: String,
    settings: List[Tuple[String, String]],
    params: List[Param],
    sql: String,
) raises DbError -> String:
    """`?database=...&default_format=...&param_p1=...` for one query.

    Each parameter must be used: `{p1:Type}` for the first, `{p2:Type}`
    for the second, and so on."""
    var out = String("?database=")
    out += percent_encode(database.as_bytes())
    out += "&default_format=" + FORMAT
    # Buffer the whole result on the server, so a failure halfway through
    # comes back as an error status, not a truncated body.
    out += "&wait_end_of_query=1"
    for ref setting in settings:
        out += (
            "&"
            + percent_encode(setting[0].as_bytes())
            + "="
            + percent_encode(setting[1].as_bytes())
        )
    for i in range(len(params)):
        var name = String("p", i + 1)
        if sql.find("{" + name + ":") < 0:
            raise DbError.usage(
                DB,
                String(
                    "parameter ",
                    i + 1,
                    " is not used; write {",
                    name,
                    ":Type} in the SQL",
                ),
            )
        out += (
            "&param_"
            + name
            + "="
            + percent_encode(Span(escape_value(params[i])))
        )
    return out^


def split_script(sql: String) -> List[String]:
    """Statements of a `;`-separated script. Semicolons inside quotes or
    comments don't split."""
    var out = List[String]()
    var bytes = sql.as_bytes()
    var start = 0
    var i = 0
    var n = len(bytes)
    while i < n:
        var c = Int(bytes[i])
        if c == ord("'") or c == ord('"') or c == ord("`"):
            i += 1
            while i < n and Int(bytes[i]) != c:
                if Int(bytes[i]) == ord("\\"):
                    i += 1
                i += 1
        elif c == ord("-") and i + 1 < n and Int(bytes[i + 1]) == ord("-"):
            while i < n and Int(bytes[i]) != ord("\n"):
                i += 1
        elif c == ord("/") and i + 1 < n and Int(bytes[i + 1]) == ord("*"):
            i += 2
            while i + 1 < n and not (
                Int(bytes[i]) == ord("*") and Int(bytes[i + 1]) == ord("/")
            ):
                i += 1
            i += 1
        elif c == ord(";"):
            _keep(out, String(from_utf8_lossy=bytes[start:i]))
            start = i + 1
        i += 1
    if start < n:
        _keep(out, String(from_utf8_lossy=bytes[start:n]))
    return out^


def _keep(mut out: List[String], statement: String):
    var trimmed = String(statement.strip())
    if trimmed != "":
        out.append(trimmed)


# ── Errors ──────────────────────────────────────────────────────────────────


def server_error(status: Int, code: String, body: String) -> DbError:
    """The error for a non-200 reply."""
    var message = String(body.strip())
    if message == "":
        message = String("HTTP status ", status)
    if code == "516" or code == "192" or code == "193" or code == "194":
        return DbError.auth(DB, message, code)
    return DbError.server(DB, code, message)


def written_rows(summary: String) -> Int:
    """`written_rows` from the X-ClickHouse-Summary header."""
    var key = String('"written_rows":"')
    var at = summary.find(key)
    if at < 0:
        return 0
    var value = 0
    var bytes = summary.as_bytes()
    var i = at + key.byte_length()
    while (
        i < len(bytes)
        and Int(bytes[i]) >= ord("0")
        and Int(bytes[i]) <= ord("9")
    ):
        value = value * 10 + Int(bytes[i]) - ord("0")
        i += 1
    return value


# ── RowBinaryWithNamesAndTypes ──────────────────────────────────────────────


def _varuint(mut r: ByteReader) raises DbError -> Int:
    var value = 0
    var shift = 0
    while True:
        var b = r.u8()
        value |= (b & 0x7F) << shift
        if b < 0x80:
            return value
        shift += 7
        if shift > 63:
            raise DbError.protocol(DB, "varint too long")


def _string(mut r: ByteReader) raises DbError -> String:
    var n = _varuint(r)
    return String(from_utf8_lossy=r.bytes(n))


def decode(body: Span[UInt8, _]) raises DbError -> Rows:
    """A whole result: the header (names, then types), then every row."""
    var rows = Rows()
    if len(body) == 0:
        return rows^
    var r = ByteReader(body, DB)
    var count = _varuint(r)
    var names = List[String]()
    for _ in range(count):
        names.append(_string(r))
    var types = List[String]()
    for i in range(count):
        var type_name = _string(r)
        rows.add_column(names[i], type_name)
        types.append(type_name^)
    while not r.done():
        for ref type_name in types:
            _cell(r, type_name, rows)
        rows.end_row()
    return rows^


def _cell(mut r: ByteReader, type_name: String, mut rows: Rows) raises DbError:
    """Decode one value straight into a cell."""
    if type_name.startswith("Nullable("):
        if r.u8() != 0:
            rows.push_null()
            return
        _cell(r, _inner(type_name, "Nullable("), rows)
        return
    if type_name.startswith("LowCardinality("):
        _cell(r, _inner(type_name, "LowCardinality("), rows)
        return
    if type_name == "String":
        var n = _varuint(r)
        rows.push_text(r.bytes(n))
        return
    if type_name.startswith("FixedString("):
        rows.push_text(r.bytes(_int_arg(type_name, "FixedString(")))
        return
    if type_name == "Float64":
        rows.push_float(Float64(from_bits=UInt64(r.le(8))))
        return
    if type_name == "Float32":
        rows.push_float(Float64(Float32(from_bits=UInt32(r.le(4)))))
        return
    if type_name == "UInt64":
        var value = r.le(8)
        if value < 0:
            rows.push_text(String(UInt64(value)).as_bytes())
        else:
            rows.push_int(value)
        return
    var width = _int_width(type_name)
    if width > 0:
        if type_name.startswith("U") or type_name == "Bool":
            rows.push_int(r.le(width))
        else:
            rows.push_int(r.le_signed(width))
        return
    rows.push_text(_text(r, type_name, False).as_bytes())


def _int_width(type_name: String) -> Int:
    if type_name == "UInt8" or type_name == "Int8" or type_name == "Bool":
        return 1
    if type_name == "UInt16" or type_name == "Int16":
        return 2
    if type_name == "UInt32" or type_name == "Int32":
        return 4
    if type_name == "Int64":
        return 8
    return 0


def _text(
    mut r: ByteReader, type_name: String, quoted: Bool
) raises DbError -> String:
    """Decode one value as text. Nested values (arrays, tuples, maps) are
    written as ClickHouse literals: `['a', 'b']`, `(1, 'x')`, `{'k': 1}`."""
    if type_name.startswith("Nullable("):
        if r.u8() != 0:
            return "NULL"
        return _text(r, _inner(type_name, "Nullable("), quoted)
    if type_name.startswith("LowCardinality("):
        return _text(r, _inner(type_name, "LowCardinality("), quoted)
    if type_name == "String" or type_name.startswith("FixedString("):
        var n = _varuint(r) if type_name == "String" else _int_arg(
            type_name, "FixedString("
        )
        var text = String(from_utf8_lossy=r.bytes(n))
        return _quote(text) if quoted else text^
    if type_name == "Bool":
        return "true" if r.u8() != 0 else "false"
    if type_name == "Float64":
        return String(Float64(from_bits=UInt64(r.le(8))))
    if type_name == "Float32":
        return String(Float32(from_bits=UInt32(r.le(4))))
    if type_name == "UInt64":
        return String(UInt64(r.le(8)))
    var width = _int_width(type_name)
    if width > 0:
        if type_name.startswith("U"):
            return String(r.le(width))
        return String(r.le_signed(width))
    if type_name == "Date":
        return _maybe_quote(_date(r.le(2)), quoted)
    if type_name == "Date32":
        return _maybe_quote(_date(r.le_signed(4)), quoted)
    if type_name == "DateTime" or type_name.startswith("DateTime("):
        return _maybe_quote(_datetime(r.le(4), 0, 0), quoted)
    if type_name.startswith("DateTime64("):
        var precision = _int_arg(type_name, "DateTime64(")
        var ticks = r.le_signed(8)
        var scale = _pow10(precision)
        var seconds = ticks // scale
        return _maybe_quote(
            _datetime(seconds, ticks - seconds * scale, precision), quoted
        )
    if type_name == "UUID":
        var high = r.le(8)
        var low = r.le(8)
        var hex = _hex64(high) + _hex64(low)
        var text = String(
            hex[byte=0:8],
            "-",
            hex[byte=8:12],
            "-",
            hex[byte=12:16],
            "-",
            hex[byte=16:20],
            "-",
            hex[byte=20:32],
        )
        return _maybe_quote(text, quoted)
    if type_name == "IPv4":
        var v = r.le(4)
        var text = String(
            (v >> 24) & 255,
            ".",
            (v >> 16) & 255,
            ".",
            (v >> 8) & 255,
            ".",
            v & 255,
        )
        return _maybe_quote(text, quoted)
    if type_name == "IPv6":
        var raw = r.bytes(16)
        var text = String()
        for i in range(8):
            if i > 0:
                text += ":"
            text += _hex_short((Int(raw[2 * i]) << 8) | Int(raw[2 * i + 1]))
        return _maybe_quote(text, quoted)
    if type_name.startswith("Decimal"):
        return _decimal(r, type_name)
    if type_name.startswith("Enum8(") or type_name.startswith("Enum16("):
        var is8 = type_name.startswith("Enum8(")
        var value = r.le_signed(1 if is8 else 2)
        var name = _enum_name(type_name, "Enum8(" if is8 else "Enum16(", value)
        return _quote(name) if quoted else name^
    if type_name.startswith("Array("):
        var inner = _inner(type_name, "Array(")
        var n = _varuint(r)
        var out = String("[")
        for i in range(n):
            if i > 0:
                out += ", "
            out += _text(r, inner, True)
        return out + "]"
    if type_name.startswith("Tuple("):
        var parts = _args(_inner(type_name, "Tuple("))
        var out = String("(")
        for i in range(len(parts)):
            if i > 0:
                out += ", "
            out += _text(r, _tuple_element_type(parts[i]), True)
        return out + ")"
    if type_name.startswith("Map("):
        var parts = _args(_inner(type_name, "Map("))
        if len(parts) != 2:
            raise DbError.decode("bad Map type " + type_name)
        var n = _varuint(r)
        var out = String("{")
        for i in range(n):
            if i > 0:
                out += ", "
            out += _text(r, parts[0], True) + ": " + _text(r, parts[1], True)
        return out + "}"
    if type_name == "Nothing":
        return "NULL"
    raise DbError.decode(
        "ClickHouse type "
        + type_name
        + " is not supported yet; cast it with toString() in the SQL"
    )


# ── Type strings ────────────────────────────────────────────────────────────


def _inner(type_name: String, prefix: String) -> String:
    """`Nullable(String)` with prefix `Nullable(` gives `String`."""
    return String(
        type_name[byte = prefix.byte_length() : type_name.byte_length() - 1]
    )


def _args(text: String) -> List[String]:
    """Split on top-level commas: `String, Array(Int8)` -> two parts."""
    var out = List[String]()
    var depth = 0
    var quoted = False
    var start = 0
    var bytes = text.as_bytes()
    for i in range(len(bytes)):
        var c = Int(bytes[i])
        if c == ord("'"):
            quoted = not quoted
        elif quoted:
            continue
        elif c == ord("("):
            depth += 1
        elif c == ord(")"):
            depth -= 1
        elif c == ord(",") and depth == 0:
            out.append(String(String(from_utf8_lossy=bytes[start:i]).strip()))
            start = i + 1
    out.append(String(String(from_utf8_lossy=bytes[start:]).strip()))
    return out^


def _int_arg(type_name: String, prefix: String) raises DbError -> Int:
    """The first number in `FixedString(16)` or `DateTime64(3, 'UTC')`."""
    var first = _args(_inner(type_name, prefix))[0]
    try:
        return Int(first)
    except:
        raise DbError.decode("bad type " + type_name)


def _tuple_element_type(part: String) -> String:
    """`a String` (a named tuple element) gives `String`."""
    var space = part.find(" ")
    var paren = part.find("(")
    if space > 0 and (paren < 0 or space < paren):
        return String(String(part[byte = space + 1 :]).strip())
    return part


def _enum_name(
    type_name: String, prefix: String, value: Int
) raises DbError -> String:
    for item in _args(_inner(type_name, prefix)):
        var eq = item.rfind("=")
        if eq < 0:
            continue
        var number: Int
        try:
            number = Int(String(String(item[byte = eq + 1 :]).strip()))
        except:
            continue
        if number == value:
            var name = String(String(item[byte=:eq]).strip())
            if (
                name.startswith("'")
                and name.endswith("'")
                and name.byte_length() >= 2
            ):
                return String(name[byte = 1 : name.byte_length() - 1])
            return name^
    raise DbError.decode(String("value ", value, " is not in ", type_name))


def _decimal(mut r: ByteReader, type_name: String) raises DbError -> String:
    var precision: Int
    var scale: Int
    if type_name.startswith("Decimal("):
        var parts = _args(_inner(type_name, "Decimal("))
        try:
            precision = Int(parts[0])
            scale = Int(parts[1]) if len(parts) > 1 else 0
        except:
            raise DbError.decode("bad type " + type_name)
    elif type_name.startswith("Decimal32("):
        precision = 9
        scale = _int_arg(type_name, "Decimal32(")
    elif type_name.startswith("Decimal64("):
        precision = 18
        scale = _int_arg(type_name, "Decimal64(")
    else:
        precision = 38
        scale = 0
    if precision > 18:
        raise DbError.decode(
            type_name
            + " is wider than 64 bits; cast it with toString() in the SQL"
        )
    var raw = r.le_signed(4 if precision <= 9 else 8)
    if scale == 0:
        return String(raw)
    var negative = raw < 0
    var digits = String(-raw if negative else raw)
    while digits.byte_length() <= scale:
        digits = "0" + digits
    var cut = digits.byte_length() - scale
    var text = String(digits[byte=:cut], ".", digits[byte=cut:])
    return "-" + text if negative else text^


# ── Formatting ──────────────────────────────────────────────────────────────


def _pow10(n: Int) -> Int:
    var power = 1
    for _ in range(n):
        power *= 10
    return power


def _pad(value: Int, width: Int) -> String:
    var text = String(value)
    while text.byte_length() < width:
        text = "0" + text
    return text^


def _civil(days: Int) -> Tuple[Int, Int, Int]:
    """(year, month, day) for days since 1970-01-01, negative included
    (Howard Hinnant's days_from_civil, inverted)."""
    var z = days + 719_468
    var era = z // 146_097
    var doe = z - era * 146_097
    var yoe = (doe - doe // 1460 + doe // 36_524 - doe // 146_096) // 365
    var doy = doe - (365 * yoe + yoe // 4 - yoe // 100)
    var mp = (5 * doy + 2) // 153
    var day = doy - (153 * mp + 2) // 5 + 1
    var month = mp + 3 if mp < 10 else mp - 9
    var year = yoe + era * 400 + (1 if month <= 2 else 0)
    return (year, month, day)


def _date(days: Int) -> String:
    var ymd = _civil(days)
    return String(_pad(ymd[0], 4), "-", _pad(ymd[1], 2), "-", _pad(ymd[2], 2))


def _datetime(seconds: Int, fraction: Int, precision: Int) -> String:
    """`YYYY-MM-DD hh:mm:ss[.fff]` in UTC."""
    var days = seconds // 86_400
    var of_day = seconds - days * 86_400
    var out = String(
        _date(days),
        " ",
        _pad(of_day // 3600, 2),
        ":",
        _pad((of_day % 3600) // 60, 2),
        ":",
        _pad(of_day % 60, 2),
    )
    if precision > 0:
        out += "." + _pad(fraction, precision)
    return out^


def _hex64(value: Int) -> String:
    comptime digits = "0123456789abcdef"
    var out = String()
    for i in range(16):
        var nibble = (value >> (4 * (15 - i))) & 15
        out += digits[byte=nibble]
    return out^


def _hex_short(value: Int) -> String:
    comptime digits = "0123456789abcdef"
    if value == 0:
        return "0"
    var out = String()
    var v = value
    while v > 0:
        out = String(digits[byte=v & 15]) + out
        v >>= 4
    return out^


def _quote(text: String) -> String:
    return "'" + text.replace("\\", "\\\\").replace("'", "\\'") + "'"


def _maybe_quote(text: String, quoted: Bool) -> String:
    return _quote(text) if quoted else text
