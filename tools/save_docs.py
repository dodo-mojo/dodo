#!/usr/bin/env python3
"""Save the docs that `dodo docs pull` hands out.

    python3 tools/save_docs.py mojo 1.2.0     the Mojo 1.2.0 docs, into
                                              mojo-docs/1.2.0/
    python3 tools/save_docs.py dodo           dodo's API pages (docs/api/)
                                              and docs/index.md
    python3 tools/save_docs.py dodo --check   exit 1 when those are stale

**Mojo.** Built from Modular's `mojo/v<version>` tag: the manual, the
language reference, the tools guides and the 1.x release notes turned from
MDX into plain Markdown (`mdx_to_md.py`), plus the standard library's API
from `mojo doc` on the stdlib source at that tag (`api_to_md.py`). The
compiler in use must be that version, so the API is the one it reports.
Modular's license is checked first; a change stops the run for a human to
read. Run it once per Mojo release, from `dev`, and commit the result.
`mojo-docs/<version>/changes-in-1x.md` is ours and written by hand: a new
version starts with a copy of the newest one.

**dodo.** `docs/api/` is generated from `mojo doc dodo`, and
`docs/index.md` lists every page in `docs/`. CI runs `--check`, so both
always match the code.

Each `index.md` is shaped like llms.txt and is the only list of files:
`dodo docs pull` fetches every relative link in it.
"""

from __future__ import annotations

import filecmp
import json
import posixpath
import re
import shutil
import subprocess
import sys
import tempfile
import urllib.error
import urllib.request
from dataclasses import dataclass
from pathlib import Path
from typing import Dict, List, Optional, Tuple

sys.path.insert(0, str(Path(__file__).resolve().parent))

import api_to_md  # noqa: E402
import mdx_to_md  # noqa: E402

REPO = Path(__file__).resolve().parent.parent
MOJO_DOCS = REPO / "mojo-docs"
DODO_DOCS = REPO / "docs"
MODULAR_GIT = "https://github.com/modular/modular.git"
MODULAR_RAW = "https://raw.githubusercontent.com/modular/modular"
MOJO_SITE = "https://mojolang.org"
SITE = "Mojo/docs/site"
STDLIB = "Mojo/stdlib/std"
CHEAT_SHEET = "changes-in-1x.md"
LICENSE_LINE = (
    "The Modular repository is licensed under the Apache License v2.0 with "
    "LLVM Exceptions"
)

# Pages of the site that are kept, by top folder or file. The landing page,
# the packages table and the nightly notes are made of site components with
# nothing to read without the website.
KEPT_FOLDERS = ["manual", "reference", "tools", "api-docs"]
KEPT_FILES = {
    "faq.md": "faq.md",
    "roadmap.mdx": "roadmap.md",
    "requirements.mdx": "requirements.md",
    "pixi.mdx": "pixi.md",
    "vision.mdx": "vision.md",
    "docs_root/install.mdx": "install.md",
}
SECTIONS = [
    ("Start here", ["changes-in-1x.md", "install.md", "requirements.md", "pixi.md", "faq.md"]),
    ("Manual", ["manual/"]),
    ("Cheat sheets", ["reference/cheat-sheets/"]),
    ("Language reference", ["reference/"]),
    ("Tools", ["tools/"]),
    ("API docs and stability", ["api-docs/"]),
    ("Release notes", ["releases/"]),
    ("Direction", ["roadmap.md", "vision.md"]),
]


class SaveError(Exception):
    """A reason to stop that a person must look at."""


# ── Mojo ──


@dataclass
class SitePage:
    source: str
    """Path under `Mojo/docs/site/`."""
    target: str
    """Path under `mojo-docs/<version>/`."""
    url: str
    """Its path on mojolang.org, such as `/docs/manual/basics/`."""
    title: str
    description: str
    position: int


def save_mojo(version: str) -> None:
    compiler = mojo_version()
    if compiler != version:
        raise SaveError(
            f"the compiler in use is Mojo {compiler}; the stdlib API of "
            f"{version} must come from a Mojo {version} compiler. Change "
            "pixi.toml first."
        )
    out = MOJO_DOCS / version
    with tempfile.TemporaryDirectory() as scratch:
        source = Path(scratch) / "modular"
        clone_modular(version, source)
        license_text = check_license(source)
        staging = Path(scratch) / version
        staging.mkdir()
        pages = site_pages(source / SITE)
        notes = release_notes(source / SITE, version, staging, pages)
        convert_site(source / SITE, pages, version, staging)
        std = save_std(source / STDLIB, staging / "std", pages, version)
        (staging / "LICENSE.txt").write_text(license_text, encoding="utf-8")
        keep_cheat_sheet(version, staging)
        (staging / "index.md").write_text(
            mojo_index(version, pages, notes, std), encoding="utf-8"
        )
        check_links(staging)
        if out.exists():
            shutil.rmtree(out)
        shutil.copytree(staging, out)
    write_versions_index()
    print(f"save_docs: Mojo {version} -> {out.relative_to(REPO)}")


def mojo_version() -> str:
    # Prints "Mojo 1.2.0 (2016d0cd)".
    result = subprocess.run(
        ["mojo", "--version"], capture_output=True, text=True, check=True
    )
    return result.stdout.split()[1]


def clone_modular(version: str, target: Path) -> None:
    """Only the docs and the stdlib at the tag: a shallow, sparse clone."""
    tag = f"mojo/v{version}"
    run_git(
        [
            "clone",
            "-q",
            "--depth",
            "1",
            "--branch",
            tag,
            "--filter=blob:none",
            "--sparse",
            MODULAR_GIT,
            str(target),
        ]
    )
    run_git(["-C", str(target), "sparse-checkout", "set", SITE, STDLIB])


def run_git(args: List[str]) -> None:
    result = subprocess.run(["git", "-c", "advice.detachedHead=false"] + args, capture_output=True, text=True)
    if result.returncode != 0:
        raise SaveError(f"git {' '.join(args)} failed:\n{result.stderr}")


def check_license(source: Path) -> str:
    """Modular's license text, after checking it is still the one dodo's
    credit in THIRD_PARTY_NOTICES.md describes."""
    text = (source / "LICENSE").read_text(encoding="utf-8")
    if LICENSE_LINE not in "\n".join(text.splitlines()[:5]):
        raise SaveError(
            "Modular's LICENSE no longer starts with the Apache-2.0 with LLVM "
            "Exceptions line. Read it before saving these docs."
        )
    for folder in (SITE, STDLIB):
        for path in (source / folder).rglob("*"):
            if path.name.upper().startswith(("LICENSE", "COPYING", "NOTICE")):
                raise SaveError(f"{path.relative_to(source)} has its own terms; read it")
    return text


def site_pages(site: Path) -> List[SitePage]:
    pages = []
    for path in sorted(site.rglob("*")):
        if path.suffix not in (".md", ".mdx"):
            continue
        relative = path.relative_to(site).as_posix()
        target = kept_target(relative)
        if target is None:
            continue
        fields, _ = mdx_to_md.front_matter(path.read_text(encoding="utf-8"))
        pages.append(
            SitePage(
                source=relative,
                target=target,
                url=site_url(relative),
                title=fields.get("title", relative),
                description=fields.get("description", ""),
                position=int(fields.get("sidebar_position", "999") or 999),
            )
        )
    return pages


def kept_target(relative: str) -> Optional[str]:
    if relative in KEPT_FILES:
        return KEPT_FILES[relative]
    top = relative.split("/")[0]
    if top not in KEPT_FOLDERS:
        return None
    return re.sub(r"\.mdx?$", ".md", relative)


def site_url(relative: str) -> str:
    """Where mojolang.org serves a page of `Mojo/docs/site/`."""
    path = re.sub(r"\.mdx?$", "", relative)
    if path.startswith("docs_root/"):
        return "/" + path[len("docs_root/") :] + "/"
    if path.endswith("/index"):
        path = path[: -len("/index")]
    return "/docs/" + path + "/"


def release_notes(
    site: Path, version: str, staging: Path, known: List[SitePage]
) -> List[SitePage]:
    """The 1.x release notes up to `version`. The tag holds the older ones;
    a version's own notes are published on `main` after its tag. `known` is
    the site's pages, the targets of the notes' links."""
    wanted = parse_version(version)
    pages = []
    folder = staging / "releases"
    folder.mkdir()
    for path in sorted((site / "releases").glob("v1.*.md")):
        name = path.stem[1:]
        if not re.fullmatch(r"\d+\.\d+\.\d+", name):
            continue
        if parse_version(name) >= wanted:
            continue
        pages.append(save_notes(path.read_text(encoding="utf-8"), name, folder, known, version))
    own = site / "releases" / f"v{version}.md"
    if own.exists():
        text = own.read_text(encoding="utf-8")
    else:
        text = fetch_text(f"{MODULAR_RAW}/main/{SITE}/releases/v{version}.md")
    pages.append(save_notes(text, version, folder, known, version))
    pages.sort(key=lambda page: parse_version(page.target[len("releases/v") : -3]))
    return pages


def save_notes(
    text: str, name: str, folder: Path, known: List[SitePage], version: str
) -> SitePage:
    source = f"releases/v{name}.md"
    page = SitePage(
        source=source,
        target=source,
        url=site_url(source),
        title=f"Mojo v{name}",
        description=f"What changed in Mojo {name}.",
        position=0,
    )
    by_url = {p.url: p.target for p in known}

    def link(target: str) -> str:
        return site_link(target, page, by_url, version)

    markdown = mdx_to_md.convert(text, link)
    markdown = add_source_line(markdown, f"{SITE}/{source}", name)
    (folder / f"v{name}.md").write_text(markdown, encoding="utf-8")
    return page


def parse_version(text: str) -> Tuple[int, ...]:
    return tuple(int(part) for part in text.split("."))


def fetch_text(url: str) -> str:
    request = urllib.request.Request(url, headers={"User-Agent": "dodo-save-docs"})
    try:
        with urllib.request.urlopen(request, timeout=60) as response:
            return response.read().decode("utf-8")
    except urllib.error.URLError as error:
        raise SaveError(f"cannot fetch {url}: {error}")


def convert_site(site: Path, pages: List[SitePage], version: str, staging: Path) -> None:
    by_url = {page.url: page.target for page in pages}
    for page in pages:
        text = (site / page.source).read_text(encoding="utf-8")

        def link(target: str, page: SitePage = page) -> str:
            return site_link(target, page, by_url, version)

        def cards(page: SitePage = page) -> str:
            return doc_cards(page, pages)

        try:
            markdown = mdx_to_md.convert(text, link, cards)
        except mdx_to_md.UnknownMarkup as error:
            raise SaveError(f"{page.source}: {error}")
        markdown = add_source_line(markdown, f"{SITE}/{page.source}", version)
        out = staging / page.target
        out.parent.mkdir(parents=True, exist_ok=True)
        out.write_text(markdown, encoding="utf-8")


def add_source_line(markdown: str, source: str, version: str) -> str:
    """Apache-2.0 asks that a changed file says so."""
    note = (
        f"*From Modular's Mojo docs (`{source}` at tag `mojo/v{version}`, "
        "Apache-2.0 with LLVM Exceptions, see `LICENSE.txt`), turned into "
        "plain Markdown by dodo.*"
    )
    if markdown.startswith("# "):
        title, _, rest = markdown.partition("\n")
        return f"{title}\n\n{note}\n\n{rest.lstrip()}"
    return f"{note}\n\n{markdown}"


def site_link(target: str, page: SitePage, by_url: Dict[str, str], version: str) -> str:
    """A link of a site page, rewritten to point into the saved docs."""
    if target.startswith(MOJO_SITE + "/"):
        # A full address of the site is the same page as its path.
        target = target[len(MOJO_SITE) :]
    if re.match(r"^[a-z]+:", target) or target.startswith("#"):
        return target
    path, _, anchor = target.partition("#")
    if path == "":
        return target
    source_dir = posixpath.dirname(f"{SITE}/{page.source}")
    if re.search(r"\.(png|jpe?g|svg|gif|webp)$", path):
        if path.startswith("/"):
            return MOJO_SITE + path
        image = posixpath.normpath(posixpath.join(source_dir, path))
        return f"{MODULAR_RAW}/mojo/v{version}/{image}"
    if re.search(r"\.mdx?$", path):
        # A link to a source file, relative to the page's own file.
        file = posixpath.normpath(posixpath.join(posixpath.dirname(page.source), path))
        path = site_url(file)
    elif not path.startswith("/"):
        # A link to a web page, relative to the page's address.
        path = posixpath.normpath(posixpath.join(page.url, path))
    if not path.endswith("/"):
        path += "/"
    if path.startswith("/docs/std/"):
        return relative_link(page.target, std_link(path, anchor))
    if path in by_url:
        found = by_url[path]
        if anchor != "":
            found += "#" + anchor
        return relative_link(page.target, found)
    with_anchor = path
    if anchor != "":
        with_anchor += "#" + anchor
    return MOJO_SITE + with_anchor


def std_link(path: str, anchor: str) -> str:
    """`/docs/std/collections/list/List/` is `std/collections/list.md#list`.
    Which parts are packages and which a module is not known here, so the
    link names the deepest page `check_links` finds; see `std_target`."""
    parts = [p for p in path[len("/docs/std/") :].split("/") if p != ""]
    found = "std/" + "/".join(parts)
    if anchor != "":
        found += "#" + anchor
    return "std:" + found


def relative_link(source: str, target: str) -> str:
    if target.startswith("std:"):
        # Resolved by `check_links` once the std pages exist.
        return target
    depth = source.count("/")
    return "../" * depth + target


def doc_cards(page: SitePage, pages: List[SitePage]) -> str:
    folder = page.target.rsplit("/", 1)[0] + "/"
    siblings = [p for p in pages if p.target.startswith(folder) and p.target != page.target]
    siblings = [p for p in siblings if "/" not in p.target[len(folder) :]]
    siblings.sort(key=lambda p: (p.position, p.title))
    lines = []
    for sibling in siblings:
        line = f"- [{sibling.title}]({sibling.target[len(folder):]})"
        if sibling.description != "":
            line += f": {sibling.description}"
        lines.append(line)
    return "\n".join(lines)


def save_std(
    stdlib: Path, out: Path, site: List[SitePage], version: str
) -> List[api_to_md.Page]:
    """The stdlib API pages, with their docstrings' site links rewritten
    like the site's own."""
    with tempfile.TemporaryDirectory() as scratch:
        api_json = Path(scratch) / "std.json"
        run_mojo_doc(["mojo", "doc", "-o", str(api_json), str(stdlib)], REPO)
        api = json.loads(api_json.read_text(encoding="utf-8"))
    pages = api_to_md.render(api, "std")
    by_url = {page.url: page.target for page in site}
    for page in pages:
        target = f"std/{page.path}"
        here = SitePage("", target, "/docs/" + target[: -len(".md")] + "/", "", "", 0)

        def link(found: str, here: SitePage = here) -> str:
            # Only a site path is a link to rewrite. A relative target is the
            # API page's own link to a sibling page, already a file of these docs.
            if found.startswith("/") or found.startswith(MOJO_SITE + "/"):
                return site_link(found, here, by_url, version)
            return found

        page.text = mdx_to_md.rewrite_links(page.text, link)
    api_to_md.write(pages, out)
    return pages


def run_mojo_doc(argv: List[str], cwd: Path) -> None:
    result = subprocess.run(argv, capture_output=True, text=True, cwd=cwd)
    if result.returncode != 0:
        raise SaveError(f"{' '.join(argv)} failed:\n{result.stdout}{result.stderr}")


def keep_cheat_sheet(version: str, staging: Path) -> None:
    """Ours, written by hand: keep this version's, or start from the newest
    other one."""
    own = MOJO_DOCS / version / CHEAT_SHEET
    if own.exists():
        shutil.copy2(own, staging / CHEAT_SHEET)
        return
    others = sorted(
        (parse_version(p.parent.name), p) for p in MOJO_DOCS.glob(f"*/{CHEAT_SHEET}")
    )
    if not others:
        raise SaveError(f"write mojo-docs/{version}/{CHEAT_SHEET} first")
    shutil.copy2(others[-1][1], staging / CHEAT_SHEET)
    print(f"save_docs: {CHEAT_SHEET} copied from {others[-1][1].parent.name}; review it for {version}")


def mojo_index(
    version: str,
    pages: List[SitePage],
    notes: List[SitePage],
    std: List[api_to_md.Page],
) -> str:
    entries = [(p.target, p.title, p.description, p.position) for p in pages + notes]
    entries.append((CHEAT_SHEET, "What changed in Mojo 1.x", "Old syntax next to the 1.x form, for code and habits from before 1.0.", 0))
    lines = [
        f"# Mojo {version}",
        "",
        f"> The Mojo {version} manual, language reference, tools guides, release "
        "notes and standard library API as plain Markdown. Saved by dodo from "
        f"Modular's `mojo/v{version}` tag; Modular's license is in `LICENSE.txt`.",
        "",
        "Every relative link below is a file of these docs. `std/` has one page "
        "per module: `std/collections/list.md` documents `std.collections.list`, "
        "and `std/collections/index.md` the package.",
        "",
    ]
    placed = set()
    for section, prefixes in SECTIONS:
        chosen = []
        for entry in entries:
            if entry[0] in placed:
                continue
            for prefix in prefixes:
                if entry[0] == prefix or (prefix.endswith("/") and entry[0].startswith(prefix)):
                    chosen.append(entry)
                    break
        if not chosen:
            continue
        chosen.sort(key=lambda entry: index_order(entry, entries, prefixes))
        lines += [f"## {section}", ""]
        for target, title, description, _ in chosen:
            placed.add(target)
            lines.append(index_line(title, target, description))
        lines.append("")
    left = [entry[0] for entry in entries if entry[0] not in placed]
    if left:
        raise SaveError(f"pages in no index section: {left}")
    lines += ["## Standard library", ""]
    for page in std:
        lines.append(index_line(f"`{page.name}`", f"std/{page.path}", page.summary))
    lines += ["", "## License", "", "- [LICENSE.txt](LICENSE.txt): Apache-2.0 with LLVM Exceptions, Modular's terms for these docs", ""]
    return "\n".join(lines)


def index_order(entry: tuple, entries: list, prefixes: List[str]) -> tuple:
    """Pages in sidebar order: folders by their index page's position,
    pages by their own, then by title."""
    if len(prefixes) > 1 or not prefixes[0].endswith("/"):
        for i, prefix in enumerate(prefixes):
            if entry[0] == prefix:
                return (i,)
    positions = {e[0]: e[3] for e in entries}
    parts = entry[0].split("/")
    key = []
    for depth in range(1, len(parts)):
        folder = "/".join(parts[:depth])
        key.append((positions.get(folder + "/index.md", 999), parts[depth - 1]))
    own = entry[3]
    if parts[-1] == "index.md":
        own = -1
    key.append((own, entry[1]))
    return tuple(key)


def index_line(title: str, target: str, description: str) -> str:
    line = f"- [{title}]({target})"
    if description.strip() != "":
        line += f": {' '.join(description.split())}"
    return line


def check_links(staging: Path) -> None:
    """Resolve `std:` links to the module or package page that exists, and
    fail on a `std:` link left unresolved or a link to a file that does not
    exist."""
    missing = []
    for page in sorted(staging.rglob("*.md")):
        relative = page.relative_to(staging).as_posix()
        text = page.read_text(encoding="utf-8")

        def resolve(match: re.Match) -> str:
            found = std_target(staging, match.group(2))
            if found is None:
                # Left as it is; the scan for leftovers below reports it.
                return match.group(0)
            return f"{match.group(1)}({relative_link(relative, found)})"

        text = _STD_LINK.sub(resolve, text)
        page.write_text(text, encoding="utf-8")
        for left in re.findall(r"\]\((std:[^)]*)\)", text):
            # No page for it, or words the pattern above could not read.
            missing.append(f"{relative}: {left}")
        for target in relative_targets(text):
            if not (page.parent / target).exists():
                missing.append(f"{relative}: {target}")
    if missing:
        raise SaveError("links to missing pages:\n  " + "\n  ".join(missing))


# `[words](std:...)`, where the words may hold one level of brackets, as in
# [`List[T]`](std:...).
_STD_LINK = re.compile(r"(\[(?:[^\[\]]|\[[^\[\]]*\])*\])\(std:([^)]+)\)")


def std_target(staging: Path, link: str) -> Optional[str]:
    """The page and anchor for `std/a/b/c#d`: the deepest of `a/b/c.md`,
    `a/b/c/index.md`, `a/b.md` ... that exists; the parts after it name a
    member, whose heading is its anchor (`List.append` is `#listappend`)."""
    path, _, anchor = link.partition("#")
    parts = path.split("/")
    for cut in range(len(parts), 0, -1):
        base = "/".join(parts[:cut])
        rest = parts[cut:]
        for candidate in (base + ".md", base + "/index.md"):
            if (staging / candidate).exists():
                return candidate + member_anchor(rest, anchor)
    return None


def member_anchor(rest: List[str], anchor: str) -> str:
    names = list(rest)
    if anchor != "":
        names.append(anchor)
    if not names:
        return ""
    return "#" + slug(".".join(names))


def slug(heading: str) -> str:
    """The anchor GitHub gives a heading."""
    text = heading.strip().lower()
    text = re.sub(r"[^\w\- ]", "", text)
    return text.replace(" ", "-")


def relative_targets(text: str) -> List[str]:
    """Every link target outside code that is not a web address, without
    its anchor. A site-absolute `/docs/...` target is included: it was not
    rewritten, so no file of these docs answers it."""
    found = []
    for is_code, piece in mdx_to_md.split_fences(text):
        if is_code:
            continue
        piece = mdx_to_md.CODE_SPAN.sub("", piece)
        for match in re.finditer(r"\]\(([^)\s]+)\)", piece):
            target = match.group(1).split("#")[0]
            if target == "" or re.match(r"^[a-z]+:", target):
                continue
            found.append(target)
    return found


def write_versions_index() -> None:
    versions = sorted(
        (p.name for p in MOJO_DOCS.iterdir() if (p / "index.md").exists()),
        key=parse_version,
        reverse=True,
    )
    lines = [
        "# Mojo docs saved by dodo",
        "",
        "> One folder per Mojo release, newest first. `dodo docs pull` reads "
        "these from dodo's `dev` branch; `tools/save_docs.py mojo VERSION` "
        "saves a new one.",
        "",
    ]
    for version in versions:
        lines.append(f"- [Mojo {version}]({version}/index.md)")
    (MOJO_DOCS / "index.md").write_text("\n".join(lines) + "\n", encoding="utf-8")


# ── dodo ──


def save_dodo(check: bool) -> int:
    with tempfile.TemporaryDirectory() as scratch:
        staging = Path(scratch) / "docs"
        build_dodo_docs(staging)
        if check:
            return compare_dodo_docs(staging)
        if (DODO_DOCS / "api").exists():
            shutil.rmtree(DODO_DOCS / "api")
        shutil.copytree(staging / "api", DODO_DOCS / "api")
        shutil.copy2(staging / "index.md", DODO_DOCS / "index.md")
    print("save_docs: docs/api and docs/index.md are up to date")
    return 0


def build_dodo_docs(staging: Path) -> None:
    """`api/` and `index.md` as they should be, in `staging`."""
    api_json = staging.parent / "dodo.json"
    run_mojo_doc(["mojo", "doc", "-I", ".", "-o", str(api_json), "dodo"], REPO)
    api = json.loads(api_json.read_text(encoding="utf-8"))
    pages = api_to_md.render(api, "dodo")
    api_to_md.write(pages, staging / "api")
    (staging / "index.md").write_text(dodo_index(pages), encoding="utf-8")


def dodo_index(api_pages: List[api_to_md.Page]) -> str:
    lines = [
        f"# dodo {dodo_version()}",
        "",
        "> dodo's guides, design, decisions (ADRs) and API as plain Markdown. "
        "Read at a release tag, these match that release.",
        "",
        "Every relative link below is a file of these docs. `tools/save_docs.py "
        "dodo` writes this index and `api/`; edit the guides themselves.",
        "",
    ]
    groups = [
        ("Guides", lambda p: p.parent == DODO_DOCS and p.name != "index.md" and not p.stem.endswith("-audit")),
        ("Best practices", lambda p: p.parent.name == "best-practices"),
        ("Decisions (ADRs)", lambda p: p.parent.name == "adr" and not p.name.startswith("0000")),
        ("Audits", lambda p: p.parent == DODO_DOCS and p.stem.endswith("-audit")),
    ]
    for title, wanted in groups:
        chosen = [p for p in sorted(DODO_DOCS.rglob("*.md")) if "api" not in p.relative_to(DODO_DOCS).parts and wanted(p)]
        if not chosen:
            continue
        lines += [f"## {title}", ""]
        for path in chosen:
            heading, summary = first_heading_and_line(path)
            lines.append(index_line(heading, path.relative_to(DODO_DOCS).as_posix(), summary))
        lines.append("")
    lines += ["## API", ""]
    for page in api_pages:
        lines.append(index_line(f"`{page.name}`", f"api/{page.path}", page.summary))
    return "\n".join(lines) + "\n"


def first_heading_and_line(path: Path) -> Tuple[str, str]:
    """A page's `# heading` and the first sentence after it."""
    heading = path.stem
    summary = ""
    text = path.read_text(encoding="utf-8")
    for is_code, piece in mdx_to_md.split_fences(text):
        if is_code:
            continue
        for block in piece.split("\n\n"):
            block = block.strip()
            if block.startswith("# ") and heading == path.stem:
                heading = block.splitlines()[0][2:].strip()
                continue
            if block == "" or block.startswith(("#", "|", "-", "*", ">", "<")):
                continue
            if summary == "":
                sentence = " ".join(block.split())
                summary = re.split(r"(?<=[.:])\s", sentence, maxsplit=1)[0]
        if summary != "":
            break
    return heading, summary


def dodo_version() -> str:
    text = (REPO / "pixi.toml").read_text(encoding="utf-8")
    match = re.search(r'^version\s*=\s*"([^"]+)"', text, re.MULTILINE)
    if match is None:
        raise SaveError("no version in pixi.toml")
    return match.group(1)


def compare_dodo_docs(staging: Path) -> int:
    stale = []
    if not same_file(staging / "index.md", DODO_DOCS / "index.md"):
        stale.append("docs/index.md")
    want = {p.relative_to(staging / "api").as_posix() for p in (staging / "api").rglob("*.md")}
    have = set()
    if (DODO_DOCS / "api").exists():
        have = {p.relative_to(DODO_DOCS / "api").as_posix() for p in (DODO_DOCS / "api").rglob("*.md")}
    for name in sorted(want | have):
        if name not in want or name not in have:
            stale.append(f"docs/api/{name}")
        elif not same_file(staging / "api" / name, DODO_DOCS / "api" / name):
            stale.append(f"docs/api/{name}")
    if stale:
        print("save_docs: stale, run `python3 tools/save_docs.py dodo`:", file=sys.stderr)
        for name in stale:
            print(f"  {name}", file=sys.stderr)
        return 1
    print("save_docs: docs/api and docs/index.md match the code")
    return 0


def same_file(want: Path, have: Path) -> bool:
    if not have.exists():
        return False
    return filecmp.cmp(want, have, shallow=False)


def main(argv: List[str]) -> int:
    try:
        if len(argv) == 2 and argv[0] == "mojo" and re.fullmatch(r"\d+\.\d+\.\d+", argv[1]):
            save_mojo(argv[1])
            return 0
        if argv == ["dodo"]:
            return save_dodo(check=False)
        if argv == ["dodo", "--check"]:
            return save_dodo(check=True)
    except SaveError as error:
        print(f"save_docs: {error}", file=sys.stderr)
        return 1
    print(__doc__.split("\n\n")[1], file=sys.stderr)
    return 64


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
