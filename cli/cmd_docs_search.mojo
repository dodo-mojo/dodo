"""`dodo docs search QUERY`: find pages in the pulled docs (`.dodo/docs/`).

Every Markdown file is scored against the words of the query, ignoring
case. A page that has more of the words ranks first; then one whose title
has them; then the one where they appear more often. Each result shows
its best lines with their line numbers, so an agent can open the file
right there.
"""

from std.os import listdir
from std.os.path import isdir, islink, join

from dodo.json import Value

from .args import ParsedArgs
from .files import read_text
from .project import find_root
from .report import EXIT_OK, EXIT_UNAVAILABLE, EXIT_USAGE, Report

comptime DEFAULT_LIMIT = 10
comptime MAX_LIMIT = 100
comptime MAX_TERMS = 20
comptime MAX_COUNTED = 50
"""Times one word is counted in one page, so a word repeated all over
one page does not swamp the ranking."""
comptime LINES_SHOWN = 3
comptime MAX_LINE_BYTES = 200


@fieldwise_init
struct Line(Copyable, Movable):
    var number: Int
    var text: String
    var terms: Int
    """How many of the query's words the line has."""


@fieldwise_init
struct Hit(Copyable, Movable):
    var path: String
    """Relative to `.dodo/docs/`."""
    var title: String
    var terms: Int
    """How many of the query's words the page has."""
    var title_terms: Int
    var count: Int
    var lines: List[Line]

    def ranks_above(self, other: Hit) -> Bool:
        if self.terms != other.terms:
            return self.terms > other.terms
        if self.title_terms != other.title_terms:
            return self.title_terms > other.title_terms
        if self.count != other.count:
            return self.count > other.count
        return self.path < other.path


def cmd_docs_search(parsed: ParsedArgs, mut report: Report) raises -> Int:
    var query = String(" ").join(parsed.positionals)
    var terms = query_terms(query)
    if len(terms) == 0:
        return report.fail(
            "usage",
            "say what to search for",
            EXIT_USAGE,
            hint='dodo docs search "path params"',
        )
    if len(terms) > MAX_TERMS:
        return report.fail(
            "usage",
            String("the query has more than ", MAX_TERMS, " words"),
            EXIT_USAGE,
        )
    var limit: Int
    try:
        limit = parse_limit(parsed.value("limit", String(DEFAULT_LIMIT)))
    except e:
        return report.fail("usage", String(e), EXIT_USAGE)

    var docs = join(find_root("."), ".dodo", "docs")
    if not isdir(docs):
        return report.fail(
            "not_found",
            "no docs in .dodo/docs/ yet",
            EXIT_UNAVAILABLE,
            hint="pull them first: dodo docs pull",
        )

    var hits = search(docs, terms, limit)
    var results = Value.array()
    var text = String("")
    for hit in hits:
        results.append(_as_value(hit))
        text += String(hit.path, "  ", hit.title, "\n")
        for line in hit.lines:
            text += String("  ", line.number, ": ", line.text, "\n")
    if len(hits) == 0:
        text = String("nothing in .dodo/docs/ matches `", query, "`")
    report.set("query", Value(query))
    report.set("results", results^)
    report.say(String(text.rstrip("\n")))
    return EXIT_OK


def query_terms(query: String) -> List[String]:
    """The query's words, lowercased, each once."""
    var terms = List[String]()
    for word in query.lower().split():
        var term = String(word)
        if term == "":
            continue
        var seen = False
        for kept in terms:
            if kept == term:
                seen = True
        if not seen:
            terms.append(term)
    return terms^


def parse_limit(text: String) raises -> Int:
    """`--limit`: a whole number from 1 to `MAX_LIMIT`.

    Raises:
        Error: If `text` is not such a number.
    """
    var bad = Error("--limit must be a number from 1 to ", MAX_LIMIT)
    if text.byte_length() == 0 or text.byte_length() > 3:
        raise bad^
    for byte in text.as_bytes():
        if byte < UInt8(ord("0")) or byte > UInt8(ord("9")):
            raise bad^
    var limit = Int(text)
    if limit < 1 or limit > MAX_LIMIT:
        raise bad^
    return limit


def search(docs: String, terms: List[String], limit: Int) -> List[Hit]:
    """The best `limit` pages under `docs` for `terms`, best first."""
    var hits = List[Hit]()
    for path in markdown_files(docs, ""):
        var found = score_page(path, read_text(join(docs, path)), terms)
        if found:
            _insert_ranked(hits, found.value().copy(), limit)
    return hits^


def score_page(
    path: String, text: String, terms: List[String]
) -> Optional[Hit]:
    """How `text` matches `terms`, or None when it has none of them."""
    var lower = text.lower()
    var page_terms = 0
    var count = 0
    for term in terms:
        var times = _count(lower, term)
        if times > 0:
            page_terms += 1
            count += times
    if page_terms == 0:
        return None

    var title = page_title(text, path)
    var title_lower = title.lower()
    var title_terms = 0
    for term in terms:
        if term in title_lower:
            title_terms += 1

    var lines = List[Line]()
    var number = 0
    for line in text.splitlines():
        number += 1
        var line_lower = String(line).lower()
        var line_terms = 0
        for term in terms:
            if term in line_lower:
                line_terms += 1
        if line_terms > 0:
            var shown = _shorten(String(String(line).strip()))
            _insert_line(lines, Line(number, shown, line_terms))
    return Hit(path, title, page_terms, title_terms, count, lines^)


def page_title(text: String, path: String) -> String:
    """The page's first `# ` heading, or its path when it has none."""
    for line in text.splitlines():
        var stripped = String(line).strip()
        if stripped.startswith("# "):
            return String(stripped[byte=2:].strip())
    return path


def markdown_files(root: String, relative: String) -> List[String]:
    """Every `.md` file under `root/relative`, relative to `root`, sorted.
    Links are not followed."""
    var found = List[String]()
    var dir = root
    if relative != "":
        dir = join(root, relative)
    var names: List[String]
    try:
        names = listdir(dir)
    except:
        return found^
    sort(names)
    for name in names:
        var child = name
        if relative != "":
            child = join(relative, name)
        var full = join(root, child)
        if islink(full):
            continue
        if isdir(full):
            found.extend(markdown_files(root, child))
        elif name.endswith(".md"):
            found.append(child)
    return found^


def _count(text: String, term: String) -> Int:
    var times = 0
    var start = text.find(term)
    while start >= 0 and times < MAX_COUNTED:
        times += 1
        start = text.find(term, start + term.byte_length())
    return times


def _shorten(line: String) -> String:
    if line.byte_length() <= MAX_LINE_BYTES:
        return line
    var cut = MAX_LINE_BYTES
    # Back up to the start of a character.
    while cut > 0 and (line.as_bytes()[cut] & 0xC0) == 0x80:
        cut -= 1
    return String(line[byte=:cut], "...")


def _insert_line(mut lines: List[Line], var line: Line):
    """Keep the `LINES_SHOWN` lines with the most terms, earliest first
    among equals."""
    var at = len(lines)
    while at > 0 and lines[at - 1].terms < line.terms:
        at -= 1
    if at >= LINES_SHOWN:
        return
    lines.insert(at, line^)
    if len(lines) > LINES_SHOWN:
        _ = lines.pop()


def _insert_ranked(mut hits: List[Hit], var hit: Hit, limit: Int):
    var at = len(hits)
    while at > 0 and hit.ranks_above(hits[at - 1]):
        at -= 1
    if at >= limit:
        return
    hits.insert(at, hit^)
    if len(hits) > limit:
        _ = hits.pop()


def _as_value(hit: Hit) raises -> Value:
    var result = Value.object()
    result["path"] = Value(String(".dodo/docs/", hit.path))
    result["title"] = Value(hit.title)
    result["terms"] = Value(hit.terms)
    var lines = Value.array()
    for line in hit.lines:
        var entry = Value.object()
        entry["line"] = Value(line.number)
        entry["text"] = Value(line.text)
        lines.append(entry^)
    result["lines"] = lines^
    return result^
