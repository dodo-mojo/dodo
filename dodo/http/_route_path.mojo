"""Route path parsing shared by ``Router`` and ``ComptimeRouter``.

Route syntax:

- ``/users``: literal segment.
- ``/{id}``: param, must fill the whole segment.
- ``/{*rest}``: catch-all, only as the last segment. It captures the
  remaining path joined with ``/`` under the name ``rest``.

``parse_route_path`` never raises, so it can run at compile time. It
returns the first problem it finds as text in ``error``.

``same_route_shape`` tells whether two routes match the same requests.
``percent_decode`` turns a raw param or query value into its text.
"""

from .proto.ascii import ascii_unchecked_string

comptime SEG_LITERAL: Int = 0
comptime SEG_PARAM: Int = 1
comptime SEG_CATCH_ALL: Int = 2

comptime _SLASH: UInt8 = 47
comptime _COLON: UInt8 = 58
comptime _STAR: UInt8 = 42
comptime _OPEN: UInt8 = 123
comptime _CLOSE: UInt8 = 125
comptime _UNDERSCORE: UInt8 = 95


struct _Segment(Copyable):
    """A compiled path segment.

    ``kind`` is ``SEG_LITERAL``, ``SEG_PARAM`` or ``SEG_CATCH_ALL``.
    ``text`` is the literal text, or the param name.
    """

    var kind: Int
    var text: String

    def __init__(out self, kind: Int, text: String):
        self.kind = kind
        self.text = text


struct ParsedRoutePath(Copyable):
    """The segments of a route path, or the reason it is invalid."""

    var segs: List[_Segment]
    var error: String

    def __init__(out self):
        self.segs = List[_Segment]()
        self.error = String("")


def _is_letter_or_underscore(b: UInt8) -> Bool:
    if b == _UNDERSCORE:
        return True
    if b >= 65 and b <= 90:
        return True
    return b >= 97 and b <= 122


def _is_digit(b: UInt8) -> Bool:
    return b >= 48 and b <= 57


def _is_valid_name(name: String) -> Bool:
    """True for ``[A-Za-z_][A-Za-z0-9_]*``."""
    var bytes = name.as_bytes()
    if len(bytes) == 0:
        return False
    if not _is_letter_or_underscore(bytes[0]):
        return False
    for i in range(1, len(bytes)):
        if not _is_letter_or_underscore(bytes[i]) and not _is_digit(bytes[i]):
            return False
    return True


def _count_byte(s: String, target: UInt8) -> Int:
    var count = 0
    for b in s.as_bytes():
        if b == target:
            count += 1
    return count


def _first_index(s: String, target: UInt8) -> Int:
    """Index of the first ``target`` byte in ``s``, or -1."""
    var bytes = s.as_bytes()
    for i in range(len(bytes)):
        if bytes[i] == target:
            return i
    return -1


def _split_segments(path: String) -> List[String]:
    """Split on ``/`` and drop empty segments, so ``/a//b/`` gives
    ``["a", "b"]``."""
    var out = List[String]()
    var bytes = path.as_bytes()
    var start = 0
    for i in range(len(bytes) + 1):
        if i == len(bytes) or bytes[i] == _SLASH:
            if i > start:
                out.append(ascii_unchecked_string(bytes[start:i]))
            start = i + 1
    return out^


def _contains_name(names: List[String], name: String) -> Bool:
    for seen in names:
        if seen == name:
            return True
    return False


def _brace_error(seg: String) -> String:
    """Describe what is wrong with the braces of ``seg``, or return an
    empty string when it is exactly one ``{...}`` filling the segment."""
    var opens = _count_byte(seg, _OPEN)
    var closes = _count_byte(seg, _CLOSE)
    var first_open = _first_index(seg, _OPEN)
    var first_close = _first_index(seg, _CLOSE)
    if closes > 0 and (first_open == -1 or first_close < first_open):
        return String("'}' without '{' in route segment '", seg, "'")
    if opens > closes:
        return String("unclosed '{' in route segment '", seg, "'")
    var bytes = seg.as_bytes()
    var fills_segment = bytes[0] == _OPEN and bytes[len(bytes) - 1] == _CLOSE
    if opens != 1 or closes != 1 or not fills_segment:
        return String(
            "route segment '", seg, "' must be one whole '{name}' param"
        )
    return String("")


def _old_syntax_error(seg: String) -> String:
    """Return the migration message for a ``:name`` or ``*`` segment,
    or an empty string for any other segment."""
    var bytes = seg.as_bytes()
    if bytes[0] == _COLON:
        var name = ascii_unchecked_string(bytes[1:])
        return String(
            "route segment '",
            seg,
            "' uses the old syntax; write '{",
            name,
            "}'",
        )
    if seg == "*":
        return String("route segment '*' uses the old syntax; write '{*rest}'")
    return String("")


def _name_error(name: String, seg: String, names: List[String]) -> String:
    """Describe what is wrong with a param name, or return an empty
    string when it is valid and new to this path."""
    if len(name.as_bytes()) == 0:
        return String("empty param name in route segment '", seg, "'")
    if not _is_valid_name(name):
        return String(
            "invalid param name '",
            name,
            "' in route segment '",
            seg,
            "'; use letters, digits and '_', and do not start with a digit",
        )
    if _contains_name(names, name):
        return String("duplicate param name '", name, "' in route path")
    return String("")


def parse_route_path(path: String) -> ParsedRoutePath:
    """Parse ``path`` into segments, or set ``error`` to the first problem."""
    var result = ParsedRoutePath()
    var bytes = path.as_bytes()
    if len(bytes) == 0 or bytes[0] != _SLASH:
        result.error = String("route path '", path, "' must start with '/'")
        return result^

    var names = List[String]()
    var raw = _split_segments(path)
    for i in range(len(raw)):
        var seg = raw[i]
        var is_last = i == len(raw) - 1
        var old = _old_syntax_error(seg)
        if len(old.as_bytes()) > 0:
            result.error = old^
            return result^
        if _first_index(seg, _OPEN) == -1 and _first_index(seg, _CLOSE) == -1:
            result.segs.append(_Segment(SEG_LITERAL, seg))
            continue
        var brace = _brace_error(seg)
        if len(brace.as_bytes()) > 0:
            result.error = brace^
            return result^

        var seg_bytes = seg.as_bytes()
        var inner = ascii_unchecked_string(seg_bytes[1 : len(seg_bytes) - 1])
        var kind = SEG_PARAM
        if inner.startswith("*"):
            kind = SEG_CATCH_ALL
            var after_star = ascii_unchecked_string(inner.as_bytes()[1:])
            inner = after_star^
        var name_error = _name_error(inner, seg, names)
        if len(name_error.as_bytes()) > 0:
            result.error = name_error^
            return result^
        if kind == SEG_CATCH_ALL and not is_last:
            result.error = String(
                "catch-all '", seg, "' must be the last segment in a route"
            )
            return result^
        names.append(inner)
        result.segs.append(_Segment(kind, inner))
    return result^


def same_route_shape(a: List[_Segment], b: List[_Segment]) -> Bool:
    """True when ``a`` and ``b`` match the same paths. Param names do not
    count: ``/users/{id}`` and ``/users/{name}`` are the same shape."""
    if len(a) != len(b):
        return False
    for i in range(len(a)):
        if a[i].kind != b[i].kind:
            return False
        if a[i].kind == SEG_LITERAL and a[i].text != b[i].text:
            return False
    return True


def _hex_value(byte: UInt8) -> Int:
    """The value of one hex digit, or -1."""
    var c = Int(byte)
    if c >= ord("0") and c <= ord("9"):
        return c - ord("0")
    if c >= ord("a") and c <= ord("f"):
        return c - ord("a") + 10
    if c >= ord("A") and c <= ord("F"):
        return c - ord("A") + 10
    return -1


def percent_decode(text: String, plus_is_space: Bool) raises -> String:
    """Decode ``%XX`` escapes, and ``+`` when ``plus_is_space`` is set.

    Raises on a truncated or non-hex escape, and when the decoded bytes
    are not valid UTF-8.
    """
    var bytes = text.as_bytes()
    var decoded = List[UInt8](capacity=len(bytes))
    var i = 0
    while i < len(bytes):
        var byte = bytes[i]
        if byte == UInt8(ord("+")) and plus_is_space:
            decoded.append(UInt8(ord(" ")))
            i += 1
        elif byte == UInt8(ord("%")):
            if i + 2 >= len(bytes):
                raise Error("bad percent escape in '", text, "'")
            var high = _hex_value(bytes[i + 1])
            var low = _hex_value(bytes[i + 2])
            if high < 0 or low < 0:
                raise Error("bad percent escape in '", text, "'")
            decoded.append(UInt8(high * 16 + low))
            i += 3
        else:
            decoded.append(byte)
            i += 1
    return String(from_utf8=decoded)
