"""Turn one page of Modular's Mojo docs (MDX for Docusaurus) into plain
Markdown that an agent can read without a website.

What changes:

- The front matter becomes a `# title` heading; its other fields are read
  by the caller (`front_matter`) for the index.
- JavaScript imports, JSX and HTML comments are dropped.
- The site's components become plain Markdown: admonitions (`:::note`),
  `Panel`, `Intro`, `Tabs`, `Link`, `ListingCard`, `Alert`, `Yes`/`No`/
  `Partial` and `Sheet`; `VersionSubheader` is dropped. `ConditionalVersionDocs` keeps only the stable
  build's part. `DocCardList` becomes a list of the pages it stood for.
- Code fences keep only their language; a `title` is shown on the line
  before the fence.
- Links are rewritten by the caller's `link` function.

Code (fenced and inline) is never changed. Any other component left after
the conversion raises `UnknownMarkup`, so a new one in a later release is
handled on purpose instead of leaking into the docs.
"""

from __future__ import annotations

import re
from typing import Callable, Dict, List, Optional, Tuple

ADMONITIONS = {
    "note": "Note",
    "tip": "Tip",
    "caution": "Caution",
    "warning": "Warning",
    "danger": "Danger",
    "important": "Important",
    "info": "Info",
    "experiment": "Experimental",
}


class UnknownMarkup(Exception):
    """Markup the converter does not know is still in a page."""


def front_matter(text: str) -> Tuple[Dict[str, str], str]:
    """The front matter's simple `key: value` fields, and the rest."""
    if not text.startswith("---\n"):
        return {}, text
    end = text.find("\n---\n", 4)
    if end < 0:
        return {}, text
    fields: Dict[str, str] = {}
    key = ""
    folded: List[str] = []
    for line in text[4:end].splitlines():
        if key != "" and (line.startswith((" ", "\t")) or line.strip() == ""):
            # A line of a `key: >` or `key: |` value.
            folded.append(line.strip())
            continue
        if key != "":
            fields[key] = " ".join(part for part in folded if part != "")
            key = ""
        match = re.match(r"^([A-Za-z_][A-Za-z0-9_-]*):\s*(.*)$", line)
        if match is None:
            continue
        value = match.group(2).strip()
        if value in (">", ">-", "|", "|-"):
            key = match.group(1)
            folded = []
            continue
        if len(value) >= 2 and value[0] == value[-1] and value[0] in "'\"":
            value = value[1:-1]
        fields[match.group(1)] = value
    if key != "":
        fields[key] = " ".join(part for part in folded if part != "")
    return fields, text[end + len("\n---\n") :]


def split_fences(text: str) -> List[Tuple[bool, str]]:
    """The text in pieces: (is_code, piece). A code piece is a whole fenced
    block, fence lines included. A fence closes on a line of the same
    character, at least as long as the one that opened it."""
    pieces: List[Tuple[bool, str]] = []
    prose: List[str] = []
    code: List[str] = []
    opener = ""
    for line in text.splitlines(keepends=True):
        stripped = line.strip()
        if opener == "":
            match = re.match(r"^(`{3,}|~{3,})", stripped)
            if match is not None:
                if prose:
                    pieces.append((False, "".join(prose)))
                    prose = []
                opener = match.group(1)
                code = [line]
            else:
                prose.append(line)
            continue
        code.append(line)
        if stripped.startswith(opener) and stripped.strip(opener[0]) == "":
            pieces.append((True, "".join(code)))
            code = []
            opener = ""
    if opener != "":
        # An unclosed fence runs to the end of the page.
        pieces.append((True, "".join(code)))
    if prose:
        pieces.append((False, "".join(prose)))
    return pieces


def convert(
    text: str,
    link: Callable[[str], str],
    doc_cards: Callable[[], str] = lambda: "",
) -> str:
    """The page `text` as plain Markdown, with its `# title`.

    `link` turns each link target into the one to write. `doc_cards` is
    the list a `<DocCardList />` stands for.
    """
    fields, body = front_matter(text)
    out = []
    title = fields.get("title", "")
    if title != "":
        out.append(f"# {title}\n\n")
    # A comment can span a code fence's line (none do today), so comments
    # go first, on the whole page.
    body = _drop_comments(body)
    body = _drop_nightly_parts(body)
    for is_code, piece in split_fences(body):
        if is_code:
            out.append(_convert_fence(piece))
        else:
            out.append(_convert_prose(piece, link, doc_cards))
    result = "".join(out)
    result = re.sub(r"\n{3,}", "\n\n", result).strip() + "\n"
    check_plain(result)
    return result


def _drop_comments(text: str) -> str:
    text = re.sub(r"\{/\*.*?\*/\}", "", text, flags=re.DOTALL)
    return re.sub(r"<!--.*?-->", "", text, flags=re.DOTALL)


def _drop_nightly_parts(text: str) -> str:
    text = re.sub(
        r'<ConditionalVersionDocs\s+version="nightly"\s*>.*?</ConditionalVersionDocs>',
        "",
        text,
        flags=re.DOTALL,
    )
    text = re.sub(r'<ConditionalVersionDocs\s+version="stable"\s*>', "", text)
    return text.replace("</ConditionalVersionDocs>", "")


def _convert_fence(block: str) -> str:
    first, _, rest = block.partition("\n")
    match = re.match(r'^(\s*)(`{3,}|~{3,})\s*([^\s`]*)(.*)$', first)
    if match is None:
        return block
    indent, fence, language, info = match.groups()
    title = re.search(r'title="([^"]*)"', info)
    lead = ""
    if title is not None:
        lead = f"{indent}`{title.group(1)}`:\n\n"
    return f"{lead}{indent}{fence}{language}\n{rest}"


def _convert_prose(
    text: str, link: Callable[[str], str], doc_cards: Callable[[], str]
) -> str:
    text = _drop_imports(text)
    text = _convert_admonitions(text)
    text = _convert_components(text, link, doc_cards)
    text = _rewrite_links(text, link)
    text = re.sub(r"^(#{1,6} .*?)\s*\{#[^}]*\}\s*$", r"\1", text, flags=re.M)
    return text


def _drop_imports(text: str) -> str:
    text = re.sub(
        r"^import\s+.*?\s+from\s+['\"][^'\"]+['\"];?[ \t]*\n",
        "",
        text,
        flags=re.M | re.DOTALL,
    )
    return re.sub(r"^export\s+.*\n", "", text, flags=re.M)


def _convert_admonitions(text: str) -> str:
    lines = []
    for line in text.splitlines(keepends=True):
        match = re.match(r"^(\s*):::([a-z]*)\s*(.*?)\s*$", line)
        if match is None:
            lines.append(line)
            continue
        indent, kind, title = match.groups()
        if kind == "":
            # The end of an admonition.
            lines.append("\n")
            continue
        if kind not in ADMONITIONS:
            raise UnknownMarkup(f"admonition :::{kind}")
        title = title.strip('"')
        label = ADMONITIONS[kind]
        if title != "":
            label = f"{label}: {title}"
        lines.append(f"{indent}**{label}**\n")
    return "".join(lines)


def _attributes(tag: str) -> Dict[str, str]:
    found = {}
    for match in re.finditer(r'([A-Za-z]+)=(?:"([^"]*)"|\'([^\']*)\')', tag):
        value = match.group(2)
        if value is None:
            value = match.group(3)
        found[match.group(1)] = value
    return found


def _convert_components(
    text: str, link: Callable[[str], str], doc_cards: Callable[[], str]
) -> str:
    def panel(match: re.Match) -> str:
        found = _attributes(match.group(0))
        heading = f"**{found.get('title', '')}**"
        if found.get("summary", "") != "":
            heading += f": {found['summary']}"
        return heading

    def card(match: re.Match) -> str:
        found = _attributes(match.group(0))
        line = f"- [{found.get('title', '')}]({link(found.get('url', ''))})"
        if found.get("description", "") != "":
            line += f": {found['description']}"
        return line

    def alert(match: re.Match) -> str:
        found = _attributes(match.group(0))
        return f"**{found.get('title', '')}**"

    def tab(match: re.Match) -> str:
        found = _attributes(match.group(0))
        label = found.get("label", found.get("value", ""))
        return f"**{label}:**\n"

    def anchor(match: re.Match) -> str:
        found = _attributes(match.group(1))
        words = " ".join(match.group(2).split())
        target = found.get("href", found.get("to", ""))
        return f"[{words}]({target})"

    text = re.sub(r"<Panel\b[^>]*>", panel, text, flags=re.DOTALL)
    text = text.replace("</Panel>", "")
    text = re.sub(r"<Intro>(.*?)</Intro>", r"**\1**", text, flags=re.DOTALL)
    text = re.sub(r"<ListingCard\b[^>]*/>", card, text, flags=re.DOTALL)
    text = re.sub(r"</?ListingCards\b[^>]*>", "", text)
    text = re.sub(r"<Alert\b[^>]*/>", alert, text, flags=re.DOTALL)
    text = re.sub(r"<Tabs\b[^>]*>", "", text)
    text = text.replace("</Tabs>", "")
    text = re.sub(r"<TabItem\b[^>]*>", tab, text)
    text = text.replace("</TabItem>", "")
    text = re.sub(r"<Link\b([^>]*)>(.*?)</Link>", anchor, text, flags=re.DOTALL)
    text = re.sub(r"<Sheet\b[^>]*>", "", text)
    text = text.replace("</Sheet>", "")
    text = re.sub(r"<DocCardList\s*/>", lambda _: doc_cards(), text)
    # A badge with the release's number, which the page title already has.
    text = re.sub(r"<VersionSubheader\s*/>", "", text)
    text = re.sub(r"<Yes\s*/>", "yes", text)
    text = re.sub(r"<No\s*/>", "no", text)
    text = re.sub(r"<Yes>(.*?)</Yes>", r"yes \1", text)
    text = re.sub(r"<No>(.*?)</No>", r"no \1", text)
    text = re.sub(r"<Partial>(.*?)</Partial>", r"partly: \1", text)
    return text


def rewrite_links(markdown: str, link: Callable[[str], str]) -> str:
    """`markdown` with every link outside code rewritten by `link`."""
    out = []
    for is_code, piece in split_fences(markdown):
        if is_code:
            out.append(piece)
        else:
            out.append(_rewrite_links(piece, link))
    return "".join(out)


def _rewrite_links(text: str, link: Callable[[str], str]) -> str:
    """Rewrite `[words](target)` and `![words](target)` outside inline
    code. The code spans are swapped for placeholders first, so a link
    whose words are code, such as [`mojo build`](...), still matches."""

    def one(match: re.Match) -> str:
        target = match.group(2).strip()
        title = ""
        quoted = re.match(r'^(\S+)\s+("[^"]*")$', target)
        if quoted is not None:
            target, title = quoted.group(1), " " + quoted.group(2)
        return f"{match.group(1)}({link(target)}{title})"

    spans: List[str] = []

    def hide(match: re.Match) -> str:
        spans.append(match.group(0))
        return f"{_HIDDEN}{len(spans) - 1}{_HIDDEN}"

    hidden = CODE_SPAN.sub(hide, text)
    # Each site image has a light and a dark copy; keep the light one.
    hidden = _DARK_IMAGE.sub("", hidden)
    hidden = _LINK.sub(one, hidden)

    def show(match: re.Match) -> str:
        return spans[int(match.group(1))]

    return re.sub(f"{_HIDDEN}(\\d+){_HIDDEN}", show, hidden)


_HIDDEN = "\x00"
# A code span, as Markdown reads it: a run of backticks closed by a run of the
# same length, which may run over a line break. ``a ` b`` holds one backtick.
CODE_SPAN = re.compile(r"(?<!`)(`+)(?!`).*?(?<!`)\1(?!`)", re.DOTALL)
_LINK = re.compile(
    # The words may hold one level of brackets, as in `OwnedPointer[Int]`,
    # and run over several lines.
    r"(!?\[(?:[^\[\]]|\[[^\[\]]*\])*\])"
    r"\(([^)\s]+(?:\s+\"[^\"]*\")?)\)"
)
_DARK_IMAGE = re.compile(r"!\[(?:[^\[\]]|\[[^\[\]]*\])*\]\([^)\s]+#dark\)")


def check_plain(markdown: str) -> None:
    """Raise `UnknownMarkup` when markup the converter does not know is
    left outside code."""
    for is_code, piece in split_fences(markdown):
        if is_code:
            continue
        for number, line in enumerate(piece.splitlines(), start=1):
            outside = re.sub(r"`[^`]*`", "", line)
            found = _leftover(outside)
            if found is not None:
                raise UnknownMarkup(f"{found!r} in line: {line.strip()[:120]}")


def _leftover(line: str) -> Optional[str]:
    tag = re.search(r"</?[A-Z][A-Za-z]*(\s|/?>|$)", line)
    if tag is not None:
        return tag.group(0).strip()
    for marker in ("{/*", ":::"):
        if marker in line:
            return marker
    if re.match(r"^import\s+\S+\s+from\s+['\"]", line):
        return "import"
    return None
