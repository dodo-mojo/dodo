"""Query parameters: one value sent to the server apart from the SQL text."""

from std.builtin.variadics import VariadicList
from std.collections import Optional


struct Param(Copyable, Writable):
    """A value bound to a placeholder (`$1`, `?`, `{name:Type}`).

    Converts implicitly from the common types, so calls read naturally:

    ```mojo
    db.query("select * from users where id = $1 and active = $2", 42, True)
    db.execute("update users set note = $1", Param.null())
    ```

    `Optional` values become NULL when empty.
    """

    var kind: Int
    var int_value: Int
    var float_value: Float64
    var text: String
    var data: List[UInt8]

    comptime NULL = 0
    comptime INT = 1
    comptime FLOAT = 2
    comptime BOOL = 3
    comptime TEXT = 4
    comptime BYTES = 5

    def __init__(out self, *, kind: Int):
        self.kind = kind
        self.int_value = 0
        self.float_value = 0.0
        self.text = String()
        self.data = List[UInt8]()

    @staticmethod
    def null() -> Self:
        """SQL NULL."""
        return Self(kind=Self.NULL)

    @staticmethod
    def bytes(data: Span[UInt8, _]) -> Self:
        """Raw bytes (`bytea`, `BLOB`, `VARBINARY`)."""
        var p = Self(kind=Self.BYTES)
        p.data = List[UInt8](data)
        return p^

    @implicit
    def __init__(out self, value: Int):
        self = Self(kind=Self.INT)
        self.int_value = value

    @implicit
    def __init__(out self, value: Int64):
        self = Self(kind=Self.INT)
        self.int_value = Int(value)

    @implicit
    def __init__(out self, value: Int32):
        self = Self(kind=Self.INT)
        self.int_value = Int(value)

    @implicit
    def __init__(out self, value: Float64):
        self = Self(kind=Self.FLOAT)
        self.float_value = value

    @implicit
    def __init__(out self, value: Float32):
        self = Self(kind=Self.FLOAT)
        self.float_value = Float64(value)

    @implicit
    def __init__(out self, value: Bool):
        self = Self(kind=Self.BOOL)
        self.int_value = 1 if value else 0

    @implicit
    def __init__(out self, value: String):
        self = Self(kind=Self.TEXT)
        self.text = value

    @implicit
    def __init__(out self, value: StringLiteral):
        self = Self(kind=Self.TEXT)
        self.text = String(value)

    @implicit
    def __init__(out self, value: StringSlice):
        self = Self(kind=Self.TEXT)
        self.text = String(value)

    @implicit
    def __init__(out self, value: Optional[Int]):
        if value:
            self = Self(value.value())
        else:
            self = Self.null()

    @implicit
    def __init__(out self, value: Optional[Float64]):
        if value:
            self = Self(value.value())
        else:
            self = Self.null()

    @implicit
    def __init__(out self, value: Optional[Bool]):
        if value:
            self = Self(value.value())
        else:
            self = Self.null()

    @implicit
    def __init__(out self, value: Optional[String]):
        if value:
            self = Self(value.value())
        else:
            self = Self.null()

    def is_null(self) -> Bool:
        return self.kind == Self.NULL

    def as_text(self) -> String:
        """The value as the text a server parses: `42`, `9.5`, `true`.

        Bytes are not text; drivers send them in binary form instead.
        """
        if self.kind == Self.INT:
            return String(self.int_value)
        if self.kind == Self.FLOAT:
            return String(self.float_value)
        if self.kind == Self.BOOL:
            if self.int_value == 1:
                return "true"
            return "false"
        if self.kind == Self.TEXT:
            return self.text
        return String()

    def write_to[W: Writer](self, mut writer: W):
        if self.kind == Self.NULL:
            writer.write("NULL")
        elif self.kind == Self.BYTES:
            writer.write("<", len(self.data), " bytes>")
        else:
            writer.write(self.as_text())


def params_of(params: VariadicList[Param, ...]) -> List[Param]:
    """Copy variadic parameters into a list a driver can keep."""
    var out = List[Param](capacity=len(params))
    for p in params:
        out.append(p.copy())
    return out^
