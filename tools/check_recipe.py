"""Check that packaging/recipe.yaml still matches the repo.

1. Every dependency in pixi.toml [dependencies] (except mojo, which the
   recipe pins exactly) is in the recipe's host or run requirements with
   the same version constraint.
2. Every libdodo_<name> library the Mojo code loads is in the list of
   libraries the recipe test checks for.
3. pixi.toml, the recipe and `cli/version.mojo` name the same version.

Run through `pixi run check-package`.
"""

import re
import sys
import tomllib
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
RECIPE = ROOT / "packaging" / "recipe.yaml"


def pixi_dependencies() -> dict[str, str]:
    with open(ROOT / "pixi.toml", "rb") as f:
        config = tomllib.load(f)
    deps = dict(config["dependencies"])
    del deps["mojo"]
    return deps


def recipe_requirements(text: str) -> dict[str, str]:
    """Name to constraint for each plain `- name constraint` line under
    requirements.host and requirements.run."""
    requirements = {}
    in_requirements = False
    section = ""
    for line in text.splitlines():
        top_level = re.match(r"^(\w+):", line)
        if top_level:
            in_requirements = top_level.group(1) == "requirements"
            continue
        if not in_requirements:
            continue
        heading = re.match(r"^  (\w+):\s*$", line)
        if heading:
            section = heading.group(1)
            continue
        if section not in ("host", "run"):
            continue
        item = re.match(r"^    - ([A-Za-z0-9_.-]+)(?: (.+))?$", line)
        if item:
            requirements[item.group(1)] = (item.group(2) or "").strip()
    return requirements


def recipe_tested_libraries(text: str) -> set[str]:
    match = re.search(r"for name in ([a-z0-9_ ]+); do", text)
    if not match:
        return set()
    return set(match.group(1).split())


def versions() -> dict[str, str]:
    """The dodo version each file names."""
    with open(ROOT / "pixi.toml", "rb") as f:
        pixi = tomllib.load(f)["workspace"]["version"]
    recipe = re.search(r'^  version: "([^"]+)"', RECIPE.read_text(), re.M)
    cli = re.search(
        r'^comptime DODO_VERSION = "([^"]+)"',
        (ROOT / "cli" / "version.mojo").read_text(),
        re.M,
    )
    found = {"pixi.toml": pixi}
    if recipe:
        found["packaging/recipe.yaml"] = recipe.group(1)
    else:
        found["packaging/recipe.yaml"] = "(not found)"
    if cli:
        found["cli/version.mojo"] = cli.group(1)
    else:
        found["cli/version.mojo"] = "(not found)"
    return found


def loaded_libraries() -> set[str]:
    names = set()
    for path in (ROOT / "dodo").rglob("*.mojo"):
        for name in re.findall(r"libdodo_([a-z0-9]+)\b", path.read_text()):
            names.add(name)
    return names


def main() -> int:
    text = RECIPE.read_text()
    problems = []

    requirements = recipe_requirements(text)
    for name, constraint in pixi_dependencies().items():
        if name not in requirements:
            problems.append(f"{name} is in pixi.toml but not in the recipe")
        elif requirements[name] != constraint:
            problems.append(
                f"{name}: pixi.toml has '{constraint}', the recipe has"
                f" '{requirements[name]}'"
            )

    tested = recipe_tested_libraries(text)
    for name in sorted(loaded_libraries() - tested):
        problems.append(
            f"libdodo_{name}.so is loaded by dodo but the recipe test does"
            " not check for it"
        )

    named = versions()
    if len(set(named.values())) > 1:
        listed = ", ".join(f"{path} {v}" for path, v in named.items())
        problems.append(f"the dodo version differs: {listed}")

    for problem in problems:
        print(f"packaging/recipe.yaml: {problem}", file=sys.stderr)
    if problems:
        return 1
    print(
        "packaging/recipe.yaml matches pixi.toml, the native libraries"
        " and the CLI version"
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
