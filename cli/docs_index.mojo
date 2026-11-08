"""Reading a docs index: the files it lists, and which saved version a
short version such as `1.2` means.

An index is an llms.txt-shaped Markdown file. Every relative link in it,
outside code, is a file of the same docs folder, and nothing else is.
"""

comptime _BACKTICK = UInt8(ord("`"))
comptime _CLOSE_BRACKET = UInt8(ord("]"))
comptime _OPEN_PAREN = UInt8(ord("("))
comptime _CLOSE_PAREN = UInt8(ord(")"))
comptime _SPACE = UInt8(ord(" "))
comptime _TAB = UInt8(ord("\t"))


def index_links(text: String) -> List[String]:
    """The relative link targets in `text`, each once, in order, without
    their `#anchor`. Links inside code and web addresses are left out."""
    var links = List[String]()
    var fence = String("")
    for line in text.splitlines():
        var stripped = String(line.strip())
        if fence != "":
            if stripped.startswith(fence):
                fence = ""
            continue
        if stripped.startswith("```"):
            fence = "```"
            continue
        if stripped.startswith("~~~"):
            fence = "~~~"
            continue
        _add_links(without_code_spans(String(line)), links)
    return links^


def without_code_spans(line: String) -> String:
    """`line` with every code span cut out. A run of backticks opens a
    span that the next run of the same length closes; a run with no
    partner is plain text."""
    var bytes = line.as_bytes()
    var size = len(bytes)
    var out = String("")
    var kept_from = 0
    var i = 0
    while i < size:
        if bytes[i] != _BACKTICK:
            i += 1
            continue
        var run = _backticks_at(bytes, i)
        var close = _closing_run(bytes, i + run, run)
        if close < 0:
            i += run
            continue
        out += String(line[byte=kept_from:i])
        i = close + run
        kept_from = i
    out += String(line[byte=kept_from:])
    return out^


def _backticks_at(bytes: Span[UInt8, _], start: Int) -> Int:
    """How many backticks start at `start`."""
    var end = start
    while end < len(bytes) and bytes[end] == _BACKTICK:
        end += 1
    return end - start


def _closing_run(bytes: Span[UInt8, _], start: Int, run: Int) -> Int:
    """Where the next run of exactly `run` backticks at or after `start`
    begins, or -1."""
    var i = start
    while i < len(bytes):
        if bytes[i] != _BACKTICK:
            i += 1
            continue
        var found = _backticks_at(bytes, i)
        if found == run:
            return i
        i += found
    return -1


def _add_links(line: String, mut links: List[String]):
    var bytes = line.as_bytes()
    var size = len(bytes)
    var i = 0
    while i + 1 < size:
        var opens_target = (
            bytes[i] == _CLOSE_BRACKET and bytes[i + 1] == _OPEN_PAREN
        )
        if not opens_target:
            i += 1
            continue
        var start = i + 2
        var end = start
        while end < size and not _ends_target(bytes[end]):
            end += 1
        var target = _without_anchor(String(line[byte=start:end]))
        var wanted = target != "" and not has_scheme(target)
        if wanted and target not in links:
            links.append(target)
        i = end
    return


def _ends_target(byte: UInt8) -> Bool:
    if byte == _CLOSE_PAREN:
        return True
    if byte == _SPACE:
        return True
    return byte == _TAB


def _without_anchor(target: String) -> String:
    var hash = target.find("#")
    if hash < 0:
        return target
    return String(target[byte=:hash])


def has_scheme(target: String) -> Bool:
    """Whether `target` starts like `https:` or `mailto:`."""
    var colon = target.find(":")
    if colon <= 0:
        return False
    var scheme = String(target[byte=:colon])
    for code in scheme.as_bytes():
        var is_lower = code >= UInt8(ord("a")) and code <= UInt8(ord("z"))
        if not is_lower:
            return False
    return True


def is_safe_path(path: String) -> Bool:
    """Whether `path` names a file inside the docs folder: relative, no
    `.` or `..` parts, no hidden names, and only letters, digits and
    `._-/`, so it is the same as a URL path and as a file name."""
    if path == "":
        return False
    for code in path.as_bytes():
        if not _is_path_byte(code):
            return False
    for part in path.split("/"):
        if part.byte_length() == 0:
            return False
        if String(part).startswith("."):
            return False
    return True


def _is_path_byte(code: UInt8) -> Bool:
    if code >= UInt8(ord("a")) and code <= UInt8(ord("z")):
        return True
    if code >= UInt8(ord("A")) and code <= UInt8(ord("Z")):
        return True
    if code >= UInt8(ord("0")) and code <= UInt8(ord("9")):
        return True
    if code == UInt8(ord(".")) or code == UInt8(ord("_")):
        return True
    return code == UInt8(ord("-")) or code == UInt8(ord("/"))


def version_parts(text: String) raises -> List[Int]:
    """`1.2` is `[1, 2]`. One to three numbers joined by dots.

    Raises:
        Error: If `text` is not such a version.
    """
    var parts = text.split(".")
    if len(parts) > 3:
        raise Error("`", text, "` is not a version such as 1.2 or 1.2.0")
    var numbers = List[Int]()
    for part in parts:
        var word = String(part)
        var digits = word.byte_length() > 0 and word.is_ascii_digit()
        if not digits or word.byte_length() > 6:
            raise Error("`", text, "` is not a version such as 1.2 or 1.2.0")
        numbers.append(Int(word))
    return numbers^


def pick_version(wanted: String, saved: List[String]) raises -> String:
    """The newest full version in `saved` that `wanted` names: `1.2`
    names every `1.2.x`, `1.2.0` only itself. "" when none is saved.

    Raises:
        Error: If `wanted` is not a version.
    """
    var want = version_parts(wanted)
    var best = String("")
    var best_parts = List[Int]()
    for version in saved:
        var parts: List[Int]
        try:
            parts = version_parts(version)
        except:
            continue
        if len(parts) != 3 or not _starts_with(parts, want):
            continue
        if best == "" or _newer(parts, best_parts):
            best = version
            best_parts = parts^
    return best^


def _starts_with(parts: List[Int], prefix: List[Int]) -> Bool:
    for i in range(len(prefix)):
        if parts[i] != prefix[i]:
            return False
    return True


def _newer(a: List[Int], b: List[Int]) -> Bool:
    for i in range(len(a)):
        if a[i] != b[i]:
            return a[i] > b[i]
    return False


def saved_versions(versions_index: String) -> List[String]:
    """The versions an archive's top index lists, from its `1.2.0/index.md`
    links."""
    var versions = List[String]()
    for link in index_links(versions_index):
        if not link.endswith("/index.md"):
            continue
        var name = String(link[byte = : link.byte_length() - 9])
        if "/" not in name:
            versions.append(name^)
    return versions^
