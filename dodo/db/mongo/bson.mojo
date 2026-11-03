"""BSON, MongoDB's document format: building, validating and reading.

`Bson` is one document, used both to build a query and to read a result:

```mojo
var user = Bson().add("name", "ada").add("score", 9.5).add("tags", BsonArray().append("admin"))
var name = found.string("name")
var city = found.doc("address").string("city")
```

Values are kept encoded. A nested document is just its bytes inside the
parent, so no type has to contain itself. A document from the server is
validated once, bounds and all, when it arrives; reads after that trust it.
"""

from std.collections import Optional
from std.ffi import external_call

from ...crypto.random import random_bytes
from .._bytes import hex_digit
from ..error import DbError


comptime DB = "mongo"

comptime DOUBLE: UInt8 = 0x01
comptime STRING: UInt8 = 0x02
comptime DOCUMENT: UInt8 = 0x03
comptime ARRAY: UInt8 = 0x04
comptime BINARY: UInt8 = 0x05
comptime UNDEFINED: UInt8 = 0x06
comptime OBJECT_ID: UInt8 = 0x07
comptime BOOL: UInt8 = 0x08
comptime DATETIME: UInt8 = 0x09
comptime NULL: UInt8 = 0x0A
comptime REGEX: UInt8 = 0x0B
comptime DB_POINTER: UInt8 = 0x0C
comptime JAVASCRIPT: UInt8 = 0x0D
comptime SYMBOL: UInt8 = 0x0E
comptime CODE_WITH_SCOPE: UInt8 = 0x0F
comptime INT32: UInt8 = 0x10
comptime TIMESTAMP: UInt8 = 0x11
comptime INT64: UInt8 = 0x12
comptime DECIMAL128: UInt8 = 0x13
comptime MIN_KEY: UInt8 = 0xFF
comptime MAX_KEY: UInt8 = 0x7F

comptime MAX_DEPTH = 100
"""Documents nested deeper than this are refused (the server's own limit)."""


# ── Little-endian helpers ───────────────────────────────────────────────────


def _put_le(mut out: List[UInt8], value: Int, n: Int):
    for i in range(n):
        out.append(UInt8((value >> (8 * i)) & 0xFF))


def _le(data: Span[UInt8, _], at: Int, n: Int) -> Int:
    var value = 0
    for i in range(n):
        value |= Int(data[at + i]) << (8 * i)
    return value


def _le_signed(data: Span[UInt8, _], at: Int, n: Int) -> Int:
    var value = _le(data, at, n)
    if n < 8 and value >= 1 << (8 * n - 1):
        value -= 1 << (8 * n)
    return value


# ── Values ──────────────────────────────────────────────────────────────────


struct BsonValue(Copyable, Writable):
    """One value: its BSON type byte and its encoded bytes.

    Converts implicitly from Int, Float64, Bool, String, `Bson` and
    `BsonArray`, so builders read naturally. An Int that fits 32 bits is
    sent as int32, like the official drivers do.
    """

    var kind: UInt8
    var data: List[UInt8]

    def __init__(out self, kind: UInt8, var data: List[UInt8]):
        self.kind = kind
        self.data = data^

    @implicit
    def __init__(out self, value: Int):
        var data = List[UInt8]()
        if value >= -(1 << 31) and value < (1 << 31):
            _put_le(data, value, 4)
            self = Self(INT32, data^)
        else:
            _put_le(data, value, 8)
            self = Self(INT64, data^)

    @implicit
    def __init__(out self, value: Float64):
        var data = List[UInt8]()
        _put_le(data, Int(value.to_bits()), 8)
        self = Self(DOUBLE, data^)

    @implicit
    def __init__(out self, value: Bool):
        var data = List[UInt8]()
        data.append(UInt8(1) if value else UInt8(0))
        self = Self(BOOL, data^)

    @implicit
    def __init__(out self, value: String):
        var data = List[UInt8]()
        _put_le(data, value.byte_length() + 1, 4)
        data.extend(value.as_bytes())
        data.append(0)
        self = Self(STRING, data^)

    @implicit
    def __init__(out self, value: StringLiteral):
        self = Self(String(value))

    @implicit
    def __init__(out self, value: Bson):
        self = Self(DOCUMENT, value.encoded())

    @implicit
    def __init__(out self, value: BsonArray):
        self = Self(ARRAY, value._doc.encoded())

    @staticmethod
    def null() -> Self:
        return Self(NULL, List[UInt8]())

    @staticmethod
    def int64(value: Int) -> Self:
        """Always 64 bits (cursor ids, counters that will grow)."""
        var data = List[UInt8]()
        _put_le(data, value, 8)
        return Self(INT64, data^)

    @staticmethod
    def binary(data: Span[UInt8, _], subtype: UInt8 = 0) -> Self:
        var out = List[UInt8]()
        _put_le(out, len(data), 4)
        out.append(subtype)
        out.extend(data)
        return Self(BINARY, out^)

    @staticmethod
    def date_ms(ms: Int) -> Self:
        """A UTC datetime, as milliseconds since 1970."""
        var data = List[UInt8]()
        _put_le(data, ms, 8)
        return Self(DATETIME, data^)

    @staticmethod
    def object_id(hex: String) raises DbError -> Self:
        """An ObjectId from its 24 hex digits."""
        var text = hex.as_bytes()
        if len(text) != 24:
            raise DbError.usage(
                DB, "an ObjectId is 24 hex digits, got '" + hex + "'"
            )
        var data = List[UInt8](capacity=12)
        for i in range(12):
            var high = hex_digit(text[2 * i])
            var low = hex_digit(text[2 * i + 1])
            if high < 0 or low < 0:
                raise DbError.usage(
                    DB, "an ObjectId is 24 hex digits, got '" + hex + "'"
                )
            data.append(UInt8(high * 16 + low))
        return Self(OBJECT_ID, data^)

    @staticmethod
    def new_object_id() raises DbError -> Self:
        """A fresh ObjectId: the time in seconds, then 8 random bytes."""
        var seconds = external_call["time", Int](0)
        var data = List[UInt8](capacity=12)
        for i in range(4):
            data.append(UInt8((seconds >> (8 * (3 - i))) & 0xFF))
        try:
            data.extend(Span(random_bytes(8)))
        except e:
            raise DbError.usage(
                DB, String("no randomness for an ObjectId: ", e)
            )
        return Self(OBJECT_ID, data^)

    # ── Reading ─────────────────────────────────────────────────────────────

    def is_null(self) -> Bool:
        return self.kind == NULL or self.kind == UNDEFINED

    def as_string(self) raises DbError -> String:
        """A string (also a symbol or JavaScript code)."""
        if (
            self.kind == STRING
            or self.kind == SYMBOL
            or self.kind == JAVASCRIPT
        ):
            var n = _le(Span(self.data), 0, 4)
            return String(from_utf8_lossy=Span(self.data)[4 : 4 + n - 1])
        if self.kind == OBJECT_ID:
            return self.object_id_hex()
        raise self._wrong("a string")

    def as_int(self) raises DbError -> Int:
        """An Int (int32, int64, datetime milliseconds, or a whole double)."""
        if self.kind == INT32:
            return _le_signed(Span(self.data), 0, 4)
        if self.kind == INT64 or self.kind == DATETIME:
            return _le(Span(self.data), 0, 8)
        if self.kind == DOUBLE:
            var value = Float64(from_bits=UInt64(_le(Span(self.data), 0, 8)))
            var whole = Int(value)
            if Float64(whole) == value:
                return whole
        raise self._wrong("an integer")

    def as_float(self) raises DbError -> Float64:
        if self.kind == DOUBLE:
            return Float64(from_bits=UInt64(_le(Span(self.data), 0, 8)))
        if self.kind == INT32 or self.kind == INT64:
            return Float64(self.as_int())
        raise self._wrong("a number")

    def as_bool(self) raises DbError -> Bool:
        if self.kind == BOOL:
            return self.data[0] != 0
        raise self._wrong("a boolean")

    def as_bytes(self) raises DbError -> List[UInt8]:
        """Binary data, without its subtype."""
        if self.kind == BINARY:
            var n = _le(Span(self.data), 0, 4)
            return List[UInt8](Span(self.data)[5 : 5 + n])
        raise self._wrong("binary")

    def as_doc(self) raises DbError -> Bson:
        if self.kind == DOCUMENT or self.kind == ARRAY:
            return Bson(_body_of(Span(self.data)))
        raise self._wrong("a document")

    def as_array(self) raises DbError -> List[BsonValue]:
        if self.kind != ARRAY:
            raise self._wrong("an array")
        return self.as_doc().values()

    def object_id_hex(self) raises DbError -> String:
        if self.kind != OBJECT_ID:
            raise self._wrong("an ObjectId")
        return _hex(Span(self.data))

    def type_name(self) -> String:
        return _type_name(self.kind)

    def _wrong(self, wanted: String) -> DbError:
        return DbError.decode(
            String("BSON ", self.type_name(), " is not ", wanted)
        )

    def write_to[W: Writer](self, mut writer: W):
        """Relaxed Extended JSON, for logs and debugging."""
        _write_value(writer, self.kind, Span(self.data))


# ── Documents ───────────────────────────────────────────────────────────────


struct Bson(Copyable, Sized, Writable):
    """One document: its elements, in order, without the length header."""

    var _body: List[UInt8]

    def __init__(out self):
        self._body = List[UInt8]()

    def __init__(out self, var body: List[UInt8]):
        self._body = body^

    @staticmethod
    def parse(data: Span[UInt8, _]) raises DbError -> Bson:
        """Validate a whole encoded document and keep it."""
        _validate(data, 0)
        return Bson(_body_of(data))

    # ── Building ────────────────────────────────────────────────────────────

    def add(var self, key: String, value: BsonValue) raises DbError -> Self:
        """Append a field and return the document, for chaining."""
        self.put(key, value)
        return self^

    def put(mut self, key: String, value: BsonValue) raises DbError:
        """Append a field."""
        for b in key.as_bytes():
            if b == 0:
                raise DbError.usage(
                    DB, "a BSON field name can't contain a NUL byte"
                )
        self._body.append(value.kind)
        self._body.extend(key.as_bytes())
        self._body.append(0)
        self._body.extend(Span(value.data))

    def encoded(self) -> List[UInt8]:
        """The document as BSON bytes."""
        var out = List[UInt8](capacity=len(self._body) + 5)
        _put_le(out, len(self._body) + 5, 4)
        out.extend(Span(self._body))
        out.append(0)
        return out^

    def with_first(self, key: String, value: BsonValue) raises DbError -> Bson:
        """A copy with `key` put first (a generated `_id`)."""
        var out = Bson()
        out.put(key, value)
        out._body.extend(Span(self._body))
        return out^

    # ── Reading ─────────────────────────────────────────────────────────────

    def _element_at(self, at: Int) -> Tuple[UInt8, Int, Int, Int]:
        """(type, end of key, start of value, end of value) at `at`."""
        var body = Span(self._body)
        var kind = body[at]
        var key_end = at + 1
        while body[key_end] != 0:
            key_end += 1
        var start = key_end + 1
        var end = start + _size_trusted(body, kind, start)
        return (kind, key_end, start, end)

    def find(self, key: String) -> Optional[BsonValue]:
        """The value of a top-level field, or None."""
        var wanted = key.as_bytes()
        var at = 0
        while at < len(self._body):
            var e = self._element_at(at)
            if _same(Span(self._body)[at + 1 : e[1]], wanted):
                return BsonValue(
                    e[0], List[UInt8](Span(self._body)[e[2] : e[3]])
                )
            at = e[3]
        return None

    def get(self, key: String) raises DbError -> BsonValue:
        var value = self.find(key)
        if not value:
            raise DbError.decode("document has no field '" + key + "'")
        return value.take()

    def has(self, key: String) -> Bool:
        return Bool(self.find(key))

    def is_null(self, key: String) -> Bool:
        """True when the field is missing or null."""
        var value = self.find(key)
        return not value or value.value().is_null()

    def string(self, key: String) raises DbError -> String:
        return self.get(key).as_string()

    def int(self, key: String) raises DbError -> Int:
        return self.get(key).as_int()

    def float(self, key: String) raises DbError -> Float64:
        return self.get(key).as_float()

    def bool(self, key: String) raises DbError -> Bool:
        return self.get(key).as_bool()

    def doc(self, key: String) raises DbError -> Bson:
        return self.get(key).as_doc()

    def array(self, key: String) raises DbError -> List[BsonValue]:
        return self.get(key).as_array()

    def keys(self) -> List[String]:
        var out = List[String]()
        var at = 0
        while at < len(self._body):
            var e = self._element_at(at)
            out.append(String(from_utf8_lossy=Span(self._body)[at + 1 : e[1]]))
            at = e[3]
        return out^

    def values(self) -> List[BsonValue]:
        var out = List[BsonValue]()
        var at = 0
        while at < len(self._body):
            var e = self._element_at(at)
            out.append(
                BsonValue(e[0], List[UInt8](Span(self._body)[e[2] : e[3]]))
            )
            at = e[3]
        return out^

    def __len__(self) -> Int:
        var count = 0
        var at = 0
        while at < len(self._body):
            at = self._element_at(at)[3]
            count += 1
        return count

    def write_to[W: Writer](self, mut writer: W):
        """Relaxed Extended JSON, for logs and debugging."""
        _write_doc(writer, Span(self._body), False)


struct BsonArray(Copyable, Sized):
    """An array under construction: `BsonArray().append(1).append("two")`."""

    var _doc: Bson
    var _count: Int

    def __init__(out self):
        self._doc = Bson()
        self._count = 0

    def append(var self, value: BsonValue) -> Self:
        self.push(value)
        return self^

    def push(mut self, value: BsonValue):
        try:
            self._doc.put(String(self._count), value)
        except:
            pass  # a decimal index never holds a NUL byte
        self._count += 1

    def __len__(self) -> Int:
        return self._count


def _same(a: Span[UInt8, _], b: Span[UInt8, _]) -> Bool:
    if len(a) != len(b):
        return False
    for i in range(len(a)):
        if a[i] != b[i]:
            return False
    return True


# ── Validation ──────────────────────────────────────────────────────────────


def _body_of(doc: Span[UInt8, _]) -> List[UInt8]:
    """The elements of an encoded document, without header and trailer."""
    return List[UInt8](doc[4 : len(doc) - 1])


def _validate(doc: Span[UInt8, _], depth: Int) raises DbError:
    """Check every length and terminator, so later reads stay in bounds."""
    if depth > MAX_DEPTH:
        raise DbError.protocol(DB, "BSON nested too deeply")
    if len(doc) < 5 or _le(doc, 0, 4) != len(doc) or doc[len(doc) - 1] != 0:
        raise DbError.protocol(DB, "bad BSON document length")
    var end = len(doc) - 1
    var at = 4
    while at < end:
        var kind = doc[at]
        var key_end = at + 1
        while key_end < end and doc[key_end] != 0:
            key_end += 1
        if key_end >= end:
            raise DbError.protocol(DB, "BSON field name runs past the document")
        var start = key_end + 1
        var size = _size_checked(doc, kind, start, end)
        if kind == DOCUMENT or kind == ARRAY:
            _validate(doc[start : start + size], depth + 1)
        elif kind == CODE_WITH_SCOPE:
            var n = _le(doc, start + 4, 4)
            if 8 + n > size:
                raise DbError.protocol(DB, "bad BSON code-with-scope")
            _validate(doc[start + 8 + n : start + size], depth + 1)
        at = start + size
    if at != end:
        raise DbError.protocol(DB, "BSON element runs past the document")


def _need(doc: Span[UInt8, _], at: Int, n: Int, end: Int) raises DbError:
    if n < 0 or at + n > end:
        raise DbError.protocol(DB, "BSON value runs past the document")


def _size_checked(
    doc: Span[UInt8, _], kind: UInt8, at: Int, end: Int
) raises DbError -> Int:
    var fixed = _fixed_size(kind)
    if fixed >= 0:
        _need(doc, at, fixed, end)
        if kind == BOOL and doc[at] > 1:
            raise DbError.protocol(DB, "bad BSON boolean")
        return fixed
    _need(doc, at, 4, end)
    if kind == STRING or kind == JAVASCRIPT or kind == SYMBOL:
        var n = _le_signed(doc, at, 4)
        _need(doc, at + 4, n, end)
        if n < 1 or doc[at + 4 + n - 1] != 0:
            raise DbError.protocol(DB, "bad BSON string")
        return 4 + n
    if kind == DB_POINTER:
        var n = _le_signed(doc, at, 4)
        _need(doc, at + 4, n + 12, end)
        if n < 1:
            raise DbError.protocol(DB, "bad BSON string")
        return 4 + n + 12
    if kind == DOCUMENT or kind == ARRAY or kind == CODE_WITH_SCOPE:
        var n = _le_signed(doc, at, 4)
        _need(doc, at, n, end)
        if n < 5:
            raise DbError.protocol(DB, "bad BSON document length")
        return n
    if kind == BINARY:
        var n = _le_signed(doc, at, 4)
        _need(doc, at + 4, n + 1, end)
        return 5 + n
    if kind == REGEX:
        var i = at
        for _ in range(2):
            while i < end and doc[i] != 0:
                i += 1
            if i >= end:
                raise DbError.protocol(DB, "bad BSON regex")
            i += 1
        return i - at
    raise DbError.protocol(DB, String("unknown BSON type ", Int(kind)))


def _fixed_size(kind: UInt8) -> Int:
    if kind == DOUBLE or kind == DATETIME or kind == TIMESTAMP or kind == INT64:
        return 8
    if kind == INT32:
        return 4
    if kind == BOOL:
        return 1
    if kind == NULL or kind == UNDEFINED or kind == MIN_KEY or kind == MAX_KEY:
        return 0
    if kind == OBJECT_ID:
        return 12
    if kind == DECIMAL128:
        return 16
    return -1


def _size_trusted(doc: Span[UInt8, _], kind: UInt8, at: Int) -> Int:
    """A value's size in a document already validated or built here."""
    var fixed = _fixed_size(kind)
    if fixed >= 0:
        return fixed
    if kind == STRING or kind == JAVASCRIPT or kind == SYMBOL:
        return 4 + _le(doc, at, 4)
    if kind == DB_POINTER:
        return 4 + _le(doc, at, 4) + 12
    if kind == BINARY:
        return 5 + _le(doc, at, 4)
    if kind == REGEX:
        var i = at
        for _ in range(2):
            while doc[i] != 0:
                i += 1
            i += 1
        return i - at
    return _le(doc, at, 4)


# ── Text ────────────────────────────────────────────────────────────────────


def _hex(data: Span[UInt8, _]) -> String:
    comptime digits = "0123456789abcdef"
    var out = String()
    for b in data:
        out += digits[byte=Int(b >> 4)]
        out += digits[byte=Int(b & 15)]
    return out^


def _type_name(kind: UInt8) -> String:
    if kind == DOUBLE:
        return "double"
    if kind == STRING:
        return "string"
    if kind == DOCUMENT:
        return "document"
    if kind == ARRAY:
        return "array"
    if kind == BINARY:
        return "binary"
    if kind == OBJECT_ID:
        return "objectId"
    if kind == BOOL:
        return "bool"
    if kind == DATETIME:
        return "date"
    if kind == NULL:
        return "null"
    if kind == INT32:
        return "int"
    if kind == INT64:
        return "long"
    if kind == DECIMAL128:
        return "decimal"
    if kind == TIMESTAMP:
        return "timestamp"
    return String("type ", Int(kind))


def _write_json_string[W: Writer](mut writer: W, text: Span[UInt8, _]):
    writer.write('"')
    var plain = String(from_utf8_lossy=text)
    for ch in plain.codepoint_slices():
        if ch == '"':
            writer.write('\\"')
        elif ch == "\\":
            writer.write("\\\\")
        elif ch == "\n":
            writer.write("\\n")
        elif ch.byte_length() == 1 and Int(ch.as_bytes()[0]) < 0x20:
            writer.write("\\u00", _hex(ch.as_bytes()))
        else:
            writer.write(ch)
    writer.write('"')


def _write_doc[W: Writer](mut writer: W, body: Span[UInt8, _], is_array: Bool):
    writer.write("[" if is_array else "{")
    var at = 0
    var first = True
    while at < len(body):
        var kind = body[at]
        var key_end = at + 1
        while body[key_end] != 0:
            key_end += 1
        var start = key_end + 1
        var end = start + _size_trusted(body, kind, start)
        if not first:
            writer.write(", ")
        first = False
        if not is_array:
            _write_json_string(writer, body[at + 1 : key_end])
            writer.write(": ")
        _write_value(writer, kind, body[start:end])
        at = end
    writer.write("]" if is_array else "}")


def _write_value[W: Writer](mut writer: W, kind: UInt8, data: Span[UInt8, _]):
    if kind == DOUBLE:
        writer.write(Float64(from_bits=UInt64(_le(data, 0, 8))))
    elif kind == STRING or kind == SYMBOL or kind == JAVASCRIPT:
        _write_json_string(writer, data[4 : len(data) - 1])
    elif kind == DOCUMENT or kind == ARRAY:
        _write_doc(writer, data[4 : len(data) - 1], kind == ARRAY)
    elif kind == BINARY:
        writer.write('{"$binary": "<', _le(data, 0, 4), ' bytes>"}')
    elif kind == OBJECT_ID:
        writer.write('{"$oid": "', _hex(data), '"}')
    elif kind == BOOL:
        writer.write("true" if data[0] != 0 else "false")
    elif kind == DATETIME:
        writer.write('{"$date": ', _le(data, 0, 8), "}")
    elif kind == NULL or kind == UNDEFINED:
        writer.write("null")
    elif kind == INT32:
        writer.write(_le_signed(data, 0, 4))
    elif kind == INT64:
        writer.write(_le(data, 0, 8))
    else:
        writer.write('"<', _type_name(kind), '>"')
