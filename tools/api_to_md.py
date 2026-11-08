"""Turn the JSON from `mojo doc` into Markdown, one page per module.

    <out>/index.md                      the package: its modules and subpackages
    <out>/<module>.md                   a module: its aliases, functions,
                                        structs and traits, with every member
    <out>/<package>/index.md            a subpackage, and so on

Members a package's `__init__.mojo` defines itself go on the package's
`index.md`. Names starting with `_` are left out; `mojo doc` already leaves
out most of them.
"""

from __future__ import annotations

from dataclasses import dataclass, field
from pathlib import Path
from typing import Dict, List


@dataclass
class Page:
    """One Markdown page to write: where (relative to the output folder),
    what it documents, and its text."""

    path: str
    name: str
    summary: str
    text: str


@dataclass
class _Context:
    """What every page of one run needs."""

    root_name: str
    pages: List[Page] = field(default_factory=list)


def render(api: dict, root_name: str) -> List[Page]:
    """Every page for the `mojo doc` JSON `api`, whose top package is
    `root_name` (`std`, `dodo`). Pages come in a stable order: each
    package's page, then its modules, then its subpackages."""
    context = _Context(root_name)
    _package(context, api["decl"], root_name, "")
    return context.pages


def write(pages: List[Page], out: Path) -> None:
    for page in pages:
        target = out / page.path
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text(page.text, encoding="utf-8")


def _public(name: str) -> bool:
    if name.startswith("__") and name.endswith("__"):
        return True
    return not name.startswith("_")


def _package(context: _Context, decl: dict, dotted: str, folder: str) -> None:
    modules = [m for m in decl.get("modules", []) if m["name"] != "__init__"]
    modules = [m for m in modules if _public(m["name"])]
    packages = [p for p in decl.get("packages", []) if _public(p["name"])]
    own = [m for m in decl.get("modules", []) if m["name"] == "__init__"]

    lines = [f"# `{dotted}`", ""]
    lines += _text(decl.get("summary", ""), decl.get("description", ""))
    if packages:
        lines += ["## Packages", ""]
        for package in sorted(packages, key=lambda p: p["name"]):
            target = f"{package['name']}/index.md"
            lines.append(_listed(f"{dotted}.{package['name']}", target, package))
        lines.append("")
    if modules:
        lines += ["## Modules", ""]
        for module in sorted(modules, key=lambda m: m["name"]):
            target = f"{module['name']}.md"
            lines.append(_listed(f"{dotted}.{module['name']}", target, module))
        lines.append("")
    for module in own:
        lines += _members(module)

    path = "index.md"
    if folder != "":
        path = f"{folder}/index.md"
    context.pages.append(
        Page(path, dotted, _one_line(decl.get("summary", "")), _join(lines))
    )
    for module in sorted(modules, key=lambda m: m["name"]):
        _module(context, module, f"{dotted}.{module['name']}", folder)
    for package in sorted(packages, key=lambda p: p["name"]):
        inner = package["name"]
        if folder != "":
            inner = f"{folder}/{package['name']}"
        _package(context, package, f"{dotted}.{package['name']}", inner)


def _module(context: _Context, decl: dict, dotted: str, folder: str) -> None:
    lines = [f"# `{dotted}`", ""]
    lines += _text(decl.get("summary", ""), decl.get("description", ""))
    lines += _members(decl)
    path = f"{decl['name']}.md"
    if folder != "":
        path = f"{folder}/{decl['name']}.md"
    context.pages.append(
        Page(path, dotted, _one_line(decl.get("summary", "")), _join(lines))
    )


def _listed(name: str, target: str, decl: dict) -> str:
    line = f"- [`{name}`]({target})"
    summary = _one_line(decl.get("summary", ""))
    if summary != "":
        line += f": {summary}"
    return line


def _members(decl: dict) -> List[str]:
    """A module's aliases, functions, structs and traits."""
    lines: List[str] = []
    aliases = _public_only(decl.get("aliases", []))
    functions = _public_only(decl.get("functions", []))
    structs = _public_only(decl.get("structs", []))
    traits = _public_only(decl.get("traits", []))
    if aliases:
        lines += ["## Aliases", ""]
        lines += _aliases(aliases)
    if structs:
        lines += ["## Structs", ""]
        for struct in structs:
            lines += _type(struct, "struct")
    if traits:
        lines += ["## Traits", ""]
        for trait in traits:
            lines += _type(trait, "trait")
    if functions:
        lines += ["## Functions", ""]
        for function in functions:
            lines += _function(function, "###", "")
    return lines


def _public_only(decls: List[dict]) -> List[dict]:
    return [d for d in decls if _public(d["name"])]


def _aliases(aliases: List[dict]) -> List[str]:
    lines: List[str] = []
    for alias in aliases:
        signature = alias.get("signature", f"comptime {alias['name']}")
        value = alias.get("value", "")
        if value != "":
            signature += f" = {value}"
        lines += [f"### `{alias['name']}`", "", "```mojo", signature, "```", ""]
        lines += _deprecated(alias)
        lines += _text(alias.get("summary", ""), alias.get("description", ""))
    return lines


def _type(decl: dict, kind: str) -> List[str]:
    name = decl["name"]
    lines = [f"### `{name}`", ""]
    lines += ["```mojo", decl.get("signature", f"{kind} {name}"), "```", ""]
    lines += _deprecated(decl)
    lines += _text(decl.get("summary", ""), decl.get("description", ""))
    lines += _arguments("Parameters", decl.get("parameters", []))
    lines += _fields(decl.get("fields", []))
    traits = decl.get("parentTraits", [])
    if traits:
        names = ", ".join(f"`{t['name']}`" for t in traits)
        label = "Implemented traits"
        if kind == "trait":
            label = "Inherits from"
        lines += [f"{label}: {names}", ""]
    aliases = _public_only(decl.get("aliases", []))
    if aliases:
        lines += ["Aliases:", ""]
        for alias in aliases:
            entry = f"- `{alias['name']}`"
            if alias.get("value", "") != "":
                entry = f"- `{alias['name']} = {alias['value']}`"
            summary = _one_line(alias.get("summary", ""))
            if summary != "":
                entry += f": {summary}"
            lines.append(entry)
        lines.append("")
    for method in _public_only(decl.get("functions", [])):
        lines += _function(method, "####", f"{name}.")
    return lines


def _fields(fields: List[dict]) -> List[str]:
    if not fields:
        return []
    lines = ["Fields:", ""]
    for one in fields:
        entry = f"- `{one['name']}` (`{one.get('type', '')}`)"
        text = _one_line(one.get("summary", "") or one.get("description", ""))
        if text != "":
            entry += f": {text}"
        lines.append(entry)
    return lines + [""]


def _function(decl: dict, level: str, owner: str) -> List[str]:
    overloads = decl.get("overloads", [])
    lines = [f"{level} `{owner}{decl['name']}`", ""]
    for overload in overloads:
        lines += ["```mojo", overload.get("signature", decl["name"]), "```", ""]
        lines += _deprecated(overload)
        lines += _text(overload.get("summary", ""), overload.get("description", ""))
        if overload.get("constraints", "") != "":
            lines += [f"Constraints: {overload['constraints'].strip()}", ""]
        lines += _arguments("Parameters", overload.get("parameters", []))
        args = [a for a in overload.get("args", []) if a["name"] != "self"]
        lines += _arguments("Args", args)
        returns = overload.get("returns") or {}
        returns_doc = (returns.get("doc") or "").strip()
        if returns_doc != "":
            lines += [f"Returns: {_one_line(returns_doc)}", ""]
        raises_doc = (overload.get("raisesDoc") or "").strip()
        if raises_doc != "":
            lines += [f"Raises: {_one_line(raises_doc)}", ""]
    return lines


def _arguments(label: str, args: List[dict]) -> List[str]:
    """Only arguments with something to say: their types are already in the
    signature."""
    described = [a for a in args if (a.get("description") or "").strip() != ""]
    if not described:
        return []
    lines = [f"{label}:", ""]
    for arg in described:
        lines.append(f"- `{arg['name']}`: {_one_line(arg['description'])}")
    return lines + [""]


def _deprecated(decl: dict) -> List[str]:
    note = (decl.get("deprecated") or "").strip()
    if note == "":
        return []
    return [f"**Deprecated:** {_one_line(note)}", ""]


def _text(summary: str, description: str) -> List[str]:
    lines: List[str] = []
    if summary.strip() != "":
        lines += [summary.strip(), ""]
    if description.strip() != "":
        lines += [description.strip(), ""]
    return lines


def _one_line(text: str) -> str:
    return " ".join(text.split())


def _join(lines: List[str]) -> str:
    text = "\n".join(lines).strip() + "\n"
    while "\n\n\n" in text:
        text = text.replace("\n\n\n", "\n\n")
    return text


def summaries(pages: List[Page]) -> Dict[str, str]:
    """Each page's path and one-line summary, for an index."""
    return {page.path: page.summary for page in pages}
