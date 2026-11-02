"""Bounds-checked reading and plain writing of protocol bytes, sans I/O.

Every read checks the remaining length, so a short or lying message from a
server raises `DbError.protocol` instead of reading past the buffer.
"""

from .error import DbError


struct ByteReader[origin: ImmOrigin]:
    var data: Span[UInt8, Self.origin]
    var at: Int
    var database: String

    def __init__(out self, data: Span[UInt8, Self.origin], database: String):
        self.data = data
        self.at = 0
        self.database = database

    def remaining(self) -> Int:
        return len(self.data) - self.at

    def done(self) -> Bool:
        return self.at >= len(self.data)

    def _need(self, n: Int) raises DbError:
        if n < 0 or self.at + n > len(self.data):
            raise DbError.protocol(
                self.database,
                String(
                    "message truncated: wanted ",
                    n,
                    " bytes at offset ",
                    self.at,
                    " of ",
                    len(self.data),
                ),
            )

    def u8(mut self) raises DbError -> Int:
        self._need(1)
        var value = Int(self.data[self.at])
        self.at += 1
        return value

    def peek(self) raises DbError -> Int:
        self._need(1)
        return Int(self.data[self.at])

    def be(mut self, n: Int) raises DbError -> Int:
        """An unsigned big-endian integer of `n` bytes."""
        self._need(n)
        var value = 0
        for i in range(n):
            value = (value << 8) | Int(self.data[self.at + i])
        self.at += n
        return value

    def be_signed(mut self, n: Int) raises DbError -> Int:
        """A two's-complement big-endian integer of `n` bytes (n < 8)."""
        var value = self.be(n)
        var sign_bit = 1 << (8 * n - 1)
        if value & sign_bit != 0:
            value -= 1 << (8 * n)
        return value

    def le(mut self, n: Int) raises DbError -> Int:
        """A little-endian integer of `n` bytes (8 bytes wraps to Int)."""
        self._need(n)
        var value = 0
        for i in range(n):
            value |= Int(self.data[self.at + i]) << (8 * i)
        self.at += n
        return value

    def le_signed(mut self, n: Int) raises DbError -> Int:
        var value = self.le(n)
        if n < 8:
            var sign_bit = 1 << (8 * n - 1)
            if value & sign_bit != 0:
                value -= 1 << (8 * n)
        return value

    def bytes(mut self, n: Int) raises DbError -> Span[UInt8, Self.origin]:
        self._need(n)
        var out = self.data[self.at : self.at + n]
        self.at += n
        return out

    def skip(mut self, n: Int) raises DbError:
        self._need(n)
        self.at += n

    def cstr(mut self) raises DbError -> String:
        """A NUL-terminated string."""
        var end = self.at
        while end < len(self.data) and self.data[end] != 0:
            end += 1
        if end >= len(self.data):
            raise DbError.protocol(
                self.database, "string is not NUL-terminated"
            )
        var text = String(from_utf8_lossy=self.data[self.at : end])
        self.at = end + 1
        return text^

    def rest(mut self) -> Span[UInt8, Self.origin]:
        var out = self.data[self.at :]
        self.at = len(self.data)
        return out


def put_be(mut out: List[UInt8], value: Int, n: Int):
    for i in range(n):
        out.append(UInt8((value >> (8 * (n - 1 - i))) & 0xFF))


def put_le(mut out: List[UInt8], value: Int, n: Int):
    for i in range(n):
        out.append(UInt8((value >> (8 * i)) & 0xFF))


def put_cstr(mut out: List[UInt8], text: String):
    out.extend(text.as_bytes())
    out.append(0)


def has_nul(text: String) -> Bool:
    """Whether `text` holds a NUL byte, which C-string fields can't carry."""
    for b in text.as_bytes():
        if b == 0:
            return True
    return False


def hex_digit(c: UInt8) -> Int:
    """The value of one hex digit, or -1."""
    var code = Int(c)
    if code >= ord("0") and code <= ord("9"):
        return code - ord("0")
    if code >= ord("a") and code <= ord("f"):
        return code - ord("a") + 10
    if code >= ord("A") and code <= ord("F"):
        return code - ord("A") + 10
    return -1
