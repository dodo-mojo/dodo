"""ClickHouse HTTP interface spike against Docker.

Proves: auth headers, `{name:Type}` query parameters sent as `param_*` URL
fields, RowBinaryWithNamesAndTypes decoding (ints, floats, strings,
Nullable, Bool, Date, DateTime64, Array), inserts, and error reporting.
"""

from dodo.http import HttpClient
from dodo.http.request import Request


def percent_encode(s: String) -> String:
    var digits = "0123456789ABCDEF"
    var out = String()
    for b in s.as_bytes():
        var c = Int(b)
        var unreserved = (
            (c >= 48 and c <= 57)
            or (c >= 65 and c <= 90)
            or (c >= 97 and c <= 122)
            or c == 45 or c == 46 or c == 95 or c == 126
        )
        if unreserved:
            out += chr(c)
        else:
            out += "%"
            out += digits[byte = c >> 4]
            out += digits[byte = c & 15]
    return out


struct Reader:
    var data: List[UInt8]
    var at: Int

    def __init__(out self, var data: List[UInt8]):
        self.data = data^
        self.at = 0

    def varuint(mut self) -> Int:
        var v = 0
        var shift = 0
        while True:
            var b = Int(self.data[self.at])
            self.at += 1
            v |= (b & 0x7F) << shift
            if b < 0x80:
                return v
            shift += 7

    def le(mut self, n: Int) -> Int:
        var v = 0
        for i in range(n):
            v |= Int(self.data[self.at + i]) << (8 * i)
        self.at += n
        return v

    def string(mut self) -> String:
        var n = self.varuint()
        var s = String(unsafe_from_utf8=self.data[self.at : self.at + n])
        self.at += n
        return s

    def done(self) -> Bool:
        return self.at >= len(self.data)


def decode(mut r: Reader, type_name: String) raises -> String:
    if type_name.startswith("Nullable("):
        var is_null = r.le(1)
        if is_null == 1:
            return "NULL"
        return decode(r, String(type_name[byte=9 : type_name.byte_length() - 1]))
    if type_name.startswith("Array("):
        var n = r.varuint()
        var inner = String(type_name[byte=6 : type_name.byte_length() - 1])
        var out = String("[")
        for i in range(n):
            if i > 0:
                out += ","
            out += decode(r, inner)
        return out + "]"
    if type_name.startswith("LowCardinality("):
        return decode(r, String(type_name[byte=15 : type_name.byte_length() - 1]))
    if type_name == "String":
        return '"' + r.string() + '"'
    if type_name == "UInt8" or type_name == "Bool":
        return String(r.le(1))
    if type_name == "UInt16" or type_name == "Date":
        return String(r.le(2))
    if type_name == "UInt32" or type_name == "DateTime":
        return String(r.le(4))
    if type_name == "UInt64" or type_name == "Int64" or type_name.startswith("DateTime64"):
        return String(r.le(8))
    if type_name == "Int32":
        return String(Int32(r.le(4)))
    if type_name == "Float64":
        return String(Float64(from_bits=UInt64(r.le(8))))
    if type_name == "Float32":
        return String(Float32(from_bits=UInt32(r.le(4))))
    raise Error("type not in spike: " + type_name)


def run(client: HttpClient, sql: String, params: List[Tuple[String, String]]) raises:
    var url = String("http://127.0.0.1:48123/?database=dodo")
    url += "&default_format=RowBinaryWithNamesAndTypes"
    for p in params:
        url += "&param_" + percent_encode(p[0]) + "=" + percent_encode(p[1])
    var req = Request("POST", url, List[UInt8](sql.as_bytes()))
    req.headers.set("X-ClickHouse-User", "dodo")
    req.headers.set("X-ClickHouse-Key", "dodo-test")
    var resp = client.send(req)
    if resp.status != 200:
        print(
            "  error",
            resp.status,
            resp.headers.get("X-ClickHouse-Exception-Code"),
            resp.text()[codepoint=:120],
        )
        return
    if len(resp.body) == 0:
        print("  ok")
        return
    var r = Reader(List[UInt8](resp.body))
    var n = r.varuint()
    var names = List[String]()
    var types = List[String]()
    for _ in range(n):
        names.append(r.string())
    for _ in range(n):
        types.append(r.string())
    var header = String("  columns:")
    for i in range(n):
        header += " " + names[i] + ":" + types[i]
    print(header)
    while not r.done():
        var line = String("  row:")
        for i in range(n):
            line += " " + decode(r, types[i])
        print(line)


def main() raises:
    var client = HttpClient()
    run(client, "select version() as v, 1 + 1 as two", [])
    run(client, "drop table if exists spike_events", [])
    run(
        client,
        "create table spike_events (id UInt64, name String, score Float64,"
        " active Bool, note Nullable(String), day Date, at DateTime64(3),"
        " tags Array(String)) engine = MergeTree order by id",
        [],
    )
    run(
        client,
        "insert into spike_events values ({id:UInt64}, {name:String},"
        " {score:Float64}, {active:Bool}, {note:Nullable(String)},"
        " {day:Date}, {at:DateTime64(3)}, {tags:Array(String)})",
        [
            ("id", "1"),
            ("name", "bob 'q'; drop table x;-- 🦤"),
            ("score", "-1.25"),
            ("active", "true"),
            ("note", "\\N"),
            ("day", "2026-11-02"),
            ("at", "2026-11-02 10:30:00.123"),
            ("tags", "['a','b c']"),
        ],
    )
    run(
        client,
        "insert into spike_events (id, name, score, active, note, day, at, tags)"
        " values (2, 'ada', 9.5, false, 'n', '2000-01-01', '2000-01-01 00:00:00', [])",
        [],
    )
    run(client, "select * from spike_events where id >= {min:UInt64} order by id", [("min", "1")])
    run(client, "select count() as n, avg(score) as mean from spike_events", [])
    run(client, "select * from no_such_table", [])
