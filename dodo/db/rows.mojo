"""Result sets from the SQL drivers, and reading them into structs.

Every SQL driver (PostgreSQL, MySQL, SQLite, ClickHouse) returns `Rows`.
Cells keep the form the driver read them in (text, a native integer or
float, or raw bytes), and the getters convert on the way out, so a column
reads the same whichever database it came from.

```mojo
@fieldwise_init
struct User(Movable):
    var id: Int
    var name: String
    var note: Optional[String]

var rows = db.query("select id, name, note from users where id > $1", 10)
for row in rows:
    print(row.int("id"), row.string("name"))
var users = rows.to[User]()            # columns matched to fields by name
var one = db.query("...", 1).one[User]()
```
"""

from std.builtin.rebind import downcast
from std.collections import Optional
from std.memory import MaybeUninit, Pointer

from .error import DbError


comptime CELL_TEXT: UInt8 = 0
"""The server's text form: `42`, `9.5`, `t`, `2026-11-02`."""
comptime CELL_INT: UInt8 = 1
"""A 64-bit integer, 8 bytes little-endian."""
comptime CELL_FLOAT: UInt8 = 2
"""A 64-bit float, 8 bytes little-endian."""
comptime CELL_BYTES: UInt8 = 3
"""Raw bytes (`bytea`, `BLOB`)."""


@fieldwise_init
struct Column(Copyable, Writable):
    """A result column: its name and the database's name for its type."""

    var name: String
    var type_name: String

    def write_to[W: Writer](self, mut writer: W):
        writer.write(self.name, " ", self.type_name)


struct Rows(Movable, Sized, Writable):
    """The rows a statement returned, plus what it changed.

    `affected` is the number of rows a write changed; `last_insert_id` is
    the generated key MySQL and SQLite report (0 elsewhere).
    """

    var columns: List[Column]
    var affected: Int
    var last_insert_id: Int
    var _data: List[UInt8]
    var _starts: List[Int]
    var _lengths: List[Int]
    """Length of each cell; -1 for NULL."""
    var _kinds: List[UInt8]
    var _row_count: Int

    def __init__(out self):
        self.columns = List[Column]()
        self.affected = 0
        self.last_insert_id = 0
        self._data = List[UInt8]()
        self._starts = List[Int]()
        self._lengths = List[Int]()
        self._kinds = List[UInt8]()
        self._row_count = 0

    # ── Building (drivers) ──────────────────────────────────────────────────

    def add_column(mut self, name: String, type_name: String):
        self.columns.append(Column(name, type_name))

    def push_null(mut self):
        self._starts.append(len(self._data))
        self._lengths.append(-1)
        self._kinds.append(CELL_TEXT)

    def push_text(mut self, text: Span[UInt8, _]):
        self._starts.append(len(self._data))
        self._lengths.append(len(text))
        self._kinds.append(CELL_TEXT)
        self._data.extend(text)

    def push_bytes(mut self, data: Span[UInt8, _]):
        self._starts.append(len(self._data))
        self._lengths.append(len(data))
        self._kinds.append(CELL_BYTES)
        self._data.extend(data)

    def push_int(mut self, value: Int):
        self._starts.append(len(self._data))
        self._lengths.append(8)
        self._kinds.append(CELL_INT)
        for i in range(8):
            self._data.append(UInt8((value >> (8 * i)) & 0xFF))

    def push_float(mut self, value: Float64):
        self._starts.append(len(self._data))
        self._lengths.append(8)
        self._kinds.append(CELL_FLOAT)
        var bits = Int(value.to_bits())
        for i in range(8):
            self._data.append(UInt8((bits >> (8 * i)) & 0xFF))

    def end_row(mut self) raises DbError:
        """Close the row just pushed; it must have one cell per column."""
        var expected = (self._row_count + 1) * len(self.columns)
        if len(self._lengths) != expected:
            raise DbError.protocol(
                "",
                String(
                    "row has ",
                    len(self._lengths) - self._row_count * len(self.columns),
                    " cells for ",
                    len(self.columns),
                    " columns",
                ),
            )
        self._row_count += 1

    # ── Reading ─────────────────────────────────────────────────────────────

    def __len__(self) -> Int:
        return self._row_count

    def column_index(self, name: String) raises DbError -> Int:
        """The position of the column called `name`."""
        for i in range(len(self.columns)):
            if self.columns[i].name == name:
                return i
        raise DbError.usage("", String("no column named '", name, "'"))

    def __getitem__(
        ref self, index: Int
    ) raises DbError -> Row[origin_of(self)]:
        if index < 0 or index >= self._row_count:
            raise DbError.usage(
                "",
                String(
                    "row ", index, " out of range (", self._row_count, " rows)"
                ),
            )
        return Row(self, index)

    def __iter__(ref self) -> RowsIter[origin_of(self)]:
        return RowsIter(self)

    def _cell(self, row: Int, column: Int) raises DbError -> Int:
        if column < 0 or column >= len(self.columns):
            raise DbError.usage(
                "",
                String(
                    "column ",
                    column,
                    " out of range (",
                    len(self.columns),
                    " columns)",
                ),
            )
        return row * len(self.columns) + column

    def is_null(self, row: Int, column: Int) raises DbError -> Bool:
        return self._lengths[self._cell(row, column)] < 0

    def _span(self, cell: Int) -> Span[UInt8, origin_of(self._data)]:
        var start = self._starts[cell]
        return Span(self._data)[start : start + self._lengths[cell]]

    def _null_error(self, column: Int) -> DbError:
        return DbError.decode(
            String("column '", self.columns[column].name, "' is NULL")
        )

    def _le64(self, cell: Int) -> Int:
        var start = self._starts[cell]
        var value = 0
        for i in range(8):
            value |= Int(self._data[start + i]) << (8 * i)
        return value

    def get_int(self, row: Int, column: Int) raises DbError -> Int:
        var cell = self._cell(row, column)
        if self._lengths[cell] < 0:
            raise self._null_error(column)
        var kind = self._kinds[cell]
        if kind == CELL_INT:
            return self._le64(cell)
        if kind == CELL_TEXT:
            return _parse_int(self._span(cell), self.columns[column].name)
        if kind == CELL_FLOAT:
            var value = Float64(from_bits=UInt64(self._le64(cell)))
            var whole = Int(value)
            if Float64(whole) == value:
                return whole
        raise DbError.decode(
            String("column '", self.columns[column].name, "' is not an integer")
        )

    def get_float(self, row: Int, column: Int) raises DbError -> Float64:
        var cell = self._cell(row, column)
        if self._lengths[cell] < 0:
            raise self._null_error(column)
        var kind = self._kinds[cell]
        if kind == CELL_FLOAT:
            return Float64(from_bits=UInt64(self._le64(cell)))
        if kind == CELL_INT:
            return Float64(self._le64(cell))
        if kind == CELL_TEXT:
            var text = String(from_utf8_lossy=self._span(cell))
            try:
                return Float64(text)
            except:
                pass
        raise DbError.decode(
            String("column '", self.columns[column].name, "' is not a number")
        )

    def get_bool(self, row: Int, column: Int) raises DbError -> Bool:
        var cell = self._cell(row, column)
        if self._lengths[cell] < 0:
            raise self._null_error(column)
        var kind = self._kinds[cell]
        if kind == CELL_INT:
            return self._le64(cell) != 0
        if kind == CELL_TEXT:
            var text = String(from_utf8_lossy=self._span(cell)).lower()
            if text == "t" or text == "true" or text == "1":
                return True
            if text == "f" or text == "false" or text == "0":
                return False
        raise DbError.decode(
            String("column '", self.columns[column].name, "' is not a boolean")
        )

    def get_string(self, row: Int, column: Int) raises DbError -> String:
        var cell = self._cell(row, column)
        if self._lengths[cell] < 0:
            raise self._null_error(column)
        var kind = self._kinds[cell]
        if kind == CELL_INT:
            return String(self._le64(cell))
        if kind == CELL_FLOAT:
            return String(Float64(from_bits=UInt64(self._le64(cell))))
        if kind == CELL_BYTES:
            try:
                return String(from_utf8=self._span(cell))
            except:
                raise DbError.decode(
                    String(
                        "column '",
                        self.columns[column].name,
                        "' is binary, not UTF-8 text",
                    )
                )
        return String(from_utf8_lossy=self._span(cell))

    def get_bytes(self, row: Int, column: Int) raises DbError -> List[UInt8]:
        var cell = self._cell(row, column)
        if self._lengths[cell] < 0:
            raise self._null_error(column)
        var kind = self._kinds[cell]
        if kind == CELL_INT or kind == CELL_FLOAT:
            raise DbError.decode(
                String(
                    "column '",
                    self.columns[column].name,
                    "' is a number, not bytes",
                )
            )
        return List[UInt8](self._span(cell))

    # ── Into structs ────────────────────────────────────────────────────────

    def to[T: Movable & Deinitable](self) raises DbError -> List[T]:
        """Every row as a `T`, filling each field from the column of the
        same name. A field typed `Optional[...]` takes NULL; any other
        field raises on NULL. Extra columns are ignored."""
        var indexes = _field_columns[T](self)
        var out = List[T](capacity=self._row_count)
        for row in range(self._row_count):
            out.append(_row_into[T](self, row, indexes))
        return out^

    def one[T: Movable & Deinitable](self) raises DbError -> T:
        """The first row as a `T`; raises when there are no rows."""
        if self._row_count == 0:
            raise DbError.usage("", "expected a row, got none")
        var indexes = _field_columns[T](self)
        return _row_into[T](self, 0, indexes)

    def first[T: Movable & Deinitable](self) raises DbError -> Optional[T]:
        """The first row as a `T`, or None when there are no rows."""
        if self._row_count == 0:
            return None
        return self.one[T]()

    def write_to[W: Writer](self, mut writer: W):
        writer.write(self._row_count, " rows, ", self.affected, " affected")


struct Row[mut: Bool, //, origin: Origin[mut=mut]](Copyable):
    """One row of a `Rows`. Columns are found by name or position."""

    var _rows: Pointer[Rows, Self.origin]
    var index: Int

    def __init__(out self, ref[Self.origin] rows: Rows, index: Int):
        self._rows = Pointer(to=rows)
        self.index = index

    def _col(self, name: String) raises DbError -> Int:
        return self._rows[].column_index(name)

    def is_null(self, column: Int) raises DbError -> Bool:
        return self._rows[].is_null(self.index, column)

    def is_null(self, name: String) raises DbError -> Bool:
        return self._rows[].is_null(self.index, self._col(name))

    def int(self, column: Int) raises DbError -> Int:
        return self._rows[].get_int(self.index, column)

    def int(self, name: String) raises DbError -> Int:
        return self._rows[].get_int(self.index, self._col(name))

    def float(self, column: Int) raises DbError -> Float64:
        return self._rows[].get_float(self.index, column)

    def float(self, name: String) raises DbError -> Float64:
        return self._rows[].get_float(self.index, self._col(name))

    def bool(self, column: Int) raises DbError -> Bool:
        return self._rows[].get_bool(self.index, column)

    def bool(self, name: String) raises DbError -> Bool:
        return self._rows[].get_bool(self.index, self._col(name))

    def string(self, column: Int) raises DbError -> String:
        return self._rows[].get_string(self.index, column)

    def string(self, name: String) raises DbError -> String:
        return self._rows[].get_string(self.index, self._col(name))

    def bytes(self, column: Int) raises DbError -> List[UInt8]:
        return self._rows[].get_bytes(self.index, column)

    def bytes(self, name: String) raises DbError -> List[UInt8]:
        return self._rows[].get_bytes(self.index, self._col(name))

    def get[T: Movable & Deinitable](self, name: String) raises DbError -> T:
        """The column as `T`: any type a struct field may have in `to[T]`."""
        var slot = MaybeUninit[T]()
        _read_into[T](
            self._rows[],
            self.index,
            self._col(name),
            Pointer(to=slot.unsafe_assume_init()),
        )
        return slot^.unsafe_assume_init()


struct RowsIter[mut: Bool, //, origin: Origin[mut=mut]](Copyable, Iterator):
    comptime Element = Row[Self.origin]

    var _rows: Pointer[Rows, Self.origin]
    var _index: Int

    def __init__(out self, ref[Self.origin] rows: Rows):
        self._rows = Pointer(to=rows)
        self._index = 0

    def __iter__(self) -> Self:
        return self.copy()

    def __has_next__(self) -> Bool:
        return self._index < len(self._rows[])

    def __next__(mut self) -> Row[Self.origin]:
        var row = Row(self._rows[], self._index)
        self._index += 1
        return row^


# ── Text to integer ─────────────────────────────────────────────────────────


def _parse_int(text: Span[UInt8, _], column: String) raises DbError -> Int:
    var n = len(text)
    var negative = False
    var i = 0
    if n > 0 and (Int(text[0]) == ord("-") or Int(text[0]) == ord("+")):
        negative = Int(text[0]) == ord("-")
        i = 1
    if i == n or n - i > 19:
        raise DbError.decode(String("column '", column, "' is not an integer"))
    var value = 0
    while i < n:
        var digit = Int(text[i]) - ord("0")
        if digit < 0 or digit > 9:
            raise DbError.decode(
                String("column '", column, "' is not an integer")
            )
        value = value * 10 + digit
        i += 1
    # 19 digits can pass Int64; the multiply above wrapped if so.
    if value < 0:
        raise DbError.decode(
            String("column '", column, "' is out of Int range")
        )
    if negative:
        return -value
    return value


# ── Reflection ──────────────────────────────────────────────────────────────


def _field_columns[T: AnyType](rows: Rows) raises DbError -> List[Int]:
    """The column feeding each field of `T`, checked once per result."""
    comptime assert reflect[T].is_struct(), "rows.to[T]() needs a struct"
    comptime field_count = reflect[T].field_count()
    comptime field_names = reflect[T].field_names()
    var out = List[Int](capacity=field_count)
    comptime for idx in range(field_count):
        comptime name = field_names[idx]
        var found = -1
        for c in range(len(rows.columns)):
            if rows.columns[c].name == name:
                found = c
                break
        if found < 0:
            raise DbError.usage(
                "",
                String(
                    "field '",
                    name,
                    "' of ",
                    reflect[T].name(),
                    " has no column of that name in the result",
                ),
            )
        out.append(found)
    return out^


def _row_into[
    T: Movable & Deinitable
](rows: Rows, row: Int, indexes: List[Int]) raises DbError -> T:
    comptime field_count = reflect[T].field_count()
    comptime field_types = reflect[T].field_types()
    var slot = MaybeUninit[T]()
    ref target = slot.unsafe_assume_init()
    var written = 0
    comptime for idx in range(field_count):
        comptime field_type = field_types[idx]
        ref field = reflect[T].field_ref[idx](target)
        try:
            _read_into[field_type](
                rows,
                row,
                indexes[idx],
                Pointer(to=field).unsafe_bitcast[field_type](),
            )
        except e:
            _destroy_first[T](target, written)
            slot^.unsafe_forget()
            raise e^
        written += 1
    return slot^.unsafe_assume_init()


def _destroy_first[T: AnyType](mut target: T, count: Int):
    """Destroy the first `count` fields, after a later one failed."""
    comptime field_types = reflect[T].field_types()
    comptime for idx in range(reflect[T].field_count()):
        comptime field_type = field_types[idx]
        if idx < count:
            ref field = reflect[T].field_ref[idx](target)
            Pointer(to=field).unsafe_bitcast[
                downcast[field_type, Movable & Deinitable]
            ]().unsafe_deinit_pointee()


def _read_into[
    T: AnyType, po: MutOrigin
](rows: Rows, row: Int, column: Int, ptr: Pointer[T, po]) raises DbError:
    """Write cell (`row`, `column`) into `ptr` as a `T`."""
    comptime if T == Int:
        ptr.unsafe_bitcast[Int]().unsafe_write(rows.get_int(row, column))
    elif T == Int64:
        ptr.unsafe_bitcast[Int64]().unsafe_write(
            Int64(rows.get_int(row, column))
        )
    elif T == Int32:
        ptr.unsafe_bitcast[Int32]().unsafe_write(
            Int32(rows.get_int(row, column))
        )
    elif T == Int16:
        ptr.unsafe_bitcast[Int16]().unsafe_write(
            Int16(rows.get_int(row, column))
        )
    elif T == UInt64:
        ptr.unsafe_bitcast[UInt64]().unsafe_write(
            UInt64(rows.get_int(row, column))
        )
    elif T == UInt32:
        ptr.unsafe_bitcast[UInt32]().unsafe_write(
            UInt32(rows.get_int(row, column))
        )
    elif T == Float64:
        ptr.unsafe_bitcast[Float64]().unsafe_write(rows.get_float(row, column))
    elif T == Float32:
        ptr.unsafe_bitcast[Float32]().unsafe_write(
            Float32(rows.get_float(row, column))
        )
    elif T == Bool:
        ptr.unsafe_bitcast[Bool]().unsafe_write(rows.get_bool(row, column))
    elif T == String:
        ptr.unsafe_bitcast[String]().unsafe_write(rows.get_string(row, column))
    elif T == List[UInt8]:
        ptr.unsafe_bitcast[List[UInt8]]().unsafe_write(
            rows.get_bytes(row, column)
        )
    elif T == Optional[Int]:
        var value = Optional[Int](None)
        if not rows.is_null(row, column):
            value = rows.get_int(row, column)
        ptr.unsafe_bitcast[Optional[Int]]().unsafe_write(value)
    elif T == Optional[Int64]:
        var value = Optional[Int64](None)
        if not rows.is_null(row, column):
            value = Int64(rows.get_int(row, column))
        ptr.unsafe_bitcast[Optional[Int64]]().unsafe_write(value)
    elif T == Optional[Float64]:
        var value = Optional[Float64](None)
        if not rows.is_null(row, column):
            value = rows.get_float(row, column)
        ptr.unsafe_bitcast[Optional[Float64]]().unsafe_write(value)
    elif T == Optional[Bool]:
        var value = Optional[Bool](None)
        if not rows.is_null(row, column):
            value = rows.get_bool(row, column)
        ptr.unsafe_bitcast[Optional[Bool]]().unsafe_write(value)
    elif T == Optional[String]:
        var value = Optional[String](None)
        if not rows.is_null(row, column):
            value = rows.get_string(row, column)
        ptr.unsafe_bitcast[Optional[String]]().unsafe_write(value^)
    elif T == Optional[List[UInt8]]:
        var value = Optional[List[UInt8]](None)
        if not rows.is_null(row, column):
            value = rows.get_bytes(row, column)
        ptr.unsafe_bitcast[Optional[List[UInt8]]]().unsafe_write(value^)
    else:
        comptime assert False, (
            "rows.to[T](): unsupported field type "
            + reflect[T].name()
            + "; use Int, Int64, Int32, Int16, UInt64, UInt32, Float64,"
            " Float32, Bool, String, List[UInt8] or an Optional of one"
        )
