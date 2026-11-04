#!/usr/bin/env python3
"""Pull the Mojo and dodo docs for this checkout into `.dodo/docs/`.

Agents read these files instead of guessing at Mojo 1.x syntax or dodo's API:

    .dodo/docs/mojo-<version>/   llms-full.txt: the Mojo manual and language
                                 reference; std/: one Markdown page per
                                 stdlib API, as on mojolang.org/docs/std/
    .dodo/docs/dodo-<version>/   README.md and docs/ (guides, ADRs), and
                                 api.json from `mojo doc dodo`

The Mojo version is the one `mojo --version` reports, so the docs match the
compiler this checkout builds with. mojolang.org only serves the latest
release; when it no longer matches, the script keeps the Mojo docs already
pulled, still refreshes dodo's, and exits with status 1.

Run from anywhere in the repo with `pixi run docs-pull`.
"""

# `Path | None` in annotations on the Python 3.9 macOS ships.
from __future__ import annotations

import re
import shutil
import subprocess
import sys
import tempfile
import time
import urllib.request
from concurrent.futures import ThreadPoolExecutor
from datetime import date
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
OUT = REPO / ".dodo" / "docs"
MOJO_DOCS = "https://mojolang.org/"
STD_PREFIX = MOJO_DOCS + "docs/std/"
DOWNLOADS_AT_ONCE = 16
FETCH_TRIES = 3


def fetch(url: str) -> bytes:
    request = urllib.request.Request(url, headers={"User-Agent": "dodo-docs-pull"})
    # Hundreds of pages come down at once; retry so one dropped connection
    # doesn't throw the whole pull away.
    for attempt in range(FETCH_TRIES):
        try:
            with urllib.request.urlopen(request, timeout=60) as response:
                return response.read()
        except OSError:
            if attempt == FETCH_TRIES - 1:
                raise
            time.sleep(1 + attempt)
    raise AssertionError("unreachable")


def mojo_version() -> str:
    # Prints "Mojo 1.2.0 (2016d0cd)".
    result = subprocess.run(
        ["mojo", "--version"], capture_output=True, text=True, check=True
    )
    return result.stdout.split()[1]


def dodo_version() -> str:
    # The first `version = "..."` in pixi.toml is the [workspace] one. Parsed
    # by hand because macOS ships a Python without tomllib.
    text = (REPO / "pixi.toml").read_text(encoding="utf-8")
    match = re.search(r'^version\s*=\s*"([^"]+)"', text, re.MULTILINE)
    if match is None:
        sys.exit("docs-pull: no version in pixi.toml")
    return match.group(1)


def served_version(llms_txt: str) -> str:
    for line in llms_txt.splitlines():
        if line.startswith("Version:"):
            return line.split(":", 1)[1].strip()
    return "unknown"


def install(staging: Path, target: Path) -> None:
    """Swap a fully built directory into place."""
    if target.exists():
        shutil.rmtree(target)
    staging.rename(target)


def pull_mojo(version: str, staging: Path) -> Path | None:
    """The Mojo docs in `staging`, or None when mojolang.org serves another
    version."""
    served = served_version(fetch(MOJO_DOCS + "llms.txt").decode("utf-8"))
    if served != version:
        print(
            f"docs-pull: mojolang.org serves the Mojo {served} docs, but this "
            f"checkout builds with Mojo {version}. Kept the Mojo docs already "
            f"in {OUT.relative_to(REPO)}.",
            file=sys.stderr,
        )
        return None
    staging.mkdir()
    (staging / "llms-full.txt").write_bytes(fetch(MOJO_DOCS + "llms-full.txt"))
    pull_std(staging / "std")
    return staging


def std_pages() -> list[str]:
    """Paths under docs/std/ listed in llms-stdlib.txt, like `os/os/listdir`."""
    index = fetch(MOJO_DOCS + "llms-stdlib.txt").decode("utf-8")
    pages = set()
    for url in re.findall(r"\]\((https://mojolang\.org/docs/std/[^)]+)\)", index):
        pages.add(url[len(STD_PREFIX) :].strip("/"))
    return sorted(pages)


def pull_std(target: Path) -> None:
    # Every docs page has a Markdown twin at its URL plus ".md".
    def download(page: str) -> None:
        path = target / (page + ".md")
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(fetch(STD_PREFIX + page + ".md"))

    pages = std_pages()
    with ThreadPoolExecutor(max_workers=DOWNLOADS_AT_ONCE) as pool:
        # list() re-raises the first failed download.
        list(pool.map(download, pages))
    print(f"docs-pull: {len(pages)} stdlib pages")


def pull_dodo(staging: Path) -> Path:
    staging.mkdir()
    shutil.copy2(REPO / "README.md", staging / "README.md")
    for source in sorted((REPO / "docs").rglob("*.md")):
        target = staging / source.relative_to(REPO)
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(source, target)
    # `mojo doc` writes one JSON file for the whole package. The format is
    # marked early and may change between Mojo releases.
    subprocess.run(
        ["mojo", "doc", "-I", ".", "-o", str(staging / "api.json"), "dodo"],
        check=True,
        cwd=REPO,
    )
    return staging


def write_index(mojo_dir: str, dodo_dir: str) -> None:
    lines = [
        "# Pulled docs",
        "",
        f"Generated by `pixi run docs-pull` (`tools/docs_pull.py`) on "
        f"{date.today().isoformat()}.",
        "Don't edit these files; rerun the command.",
        "",
    ]
    if (OUT / mojo_dir).is_dir():
        lines += [
            f"- [`{mojo_dir}/llms-full.txt`]({mojo_dir}/llms-full.txt): the Mojo",
            f"  manual and language reference, from {MOJO_DOCS}.",
            f"- [`{mojo_dir}/std/`]({mojo_dir}/std/): the standard library API, one",
            "  page per module, type and function (`std/os/os/listdir.md`",
            "  documents `std.os.listdir`).",
        ]
    else:
        lines += [f"- No Mojo docs for `{mojo_dir}` yet: see the docs-pull output."]
    lines += [
        f"- [`{dodo_dir}/`]({dodo_dir}/): dodo's README, guides and ADRs, and its",
        "  API as JSON in `api.json` (from `mojo doc`).",
        "",
    ]
    (OUT / "README.md").write_text("\n".join(lines), encoding="utf-8")


def main() -> None:
    mojo_ver = mojo_version()
    dodo_ver = dodo_version()
    mojo_dir = f"mojo-{mojo_ver}"
    dodo_dir = f"dodo-{dodo_ver}"
    OUT.mkdir(parents=True, exist_ok=True)
    # Build both in a scratch directory next to the output, so a failed
    # download or `mojo doc` run leaves the previous docs untouched.
    with tempfile.TemporaryDirectory(dir=OUT) as scratch:
        mojo = pull_mojo(mojo_ver, Path(scratch) / mojo_dir)
        dodo = pull_dodo(Path(scratch) / dodo_dir)
        if mojo is not None:
            install(mojo, OUT / mojo_dir)
        install(dodo, OUT / dodo_dir)
    write_index(mojo_dir, dodo_dir)
    if mojo is not None:
        print(f"docs-pull: Mojo {mojo_ver} -> {(OUT / mojo_dir).relative_to(REPO)}")
    print(f"docs-pull: dodo {dodo_ver} -> {(OUT / dodo_dir).relative_to(REPO)}")
    if mojo is None:
        sys.exit(1)


if __name__ == "__main__":
    main()
