"""Every `dodo` command: its spec (for parsing and help) and where it runs."""

from .args import CommandSpec, FlagSpec


def command_specs() -> List[CommandSpec]:
    """The commands, in the order help lists them."""
    var specs = List[CommandSpec]()
    specs.append(
        CommandSpec(
            name="new",
            summary="Create a project laid out the way dodo itself is run",
            usage="NAME",
            flags=[
                FlagSpec("no-git", "", "Do not create a git repository"),
            ],
            max_positionals=1,
            allows_passthrough=False,
        )
    )
    specs.append(
        CommandSpec(
            name="run",
            summary="Build the app and run it",
            usage="[FILE] [-- ARGS...]",
            flags=List[FlagSpec](),
            max_positionals=1,
            allows_passthrough=True,
        )
    )
    specs.append(
        CommandSpec(
            name="dev",
            summary=(
                "Run the app and restart it on every save, keeping the port"
                " open"
            ),
            usage="[FILE] [-- ARGS...]",
            flags=[
                FlagSpec("port", "PORT", "Port to listen on (default 8000)"),
                FlagSpec(
                    "host", "HOST", "Address to listen on (default 127.0.0.1)"
                ),
            ],
            max_positionals=1,
            allows_passthrough=True,
        )
    )
    specs.append(
        CommandSpec(
            name="test",
            summary="Build and run every tests/**/test_*.mojo file",
            usage="[PATH...]",
            flags=[
                FlagSpec("only", "NAME", "Run only the test with this name"),
                FlagSpec(
                    "jobs",
                    "N",
                    "Build this many files at once (default: cores, at most 4)",
                ),
            ],
            max_positionals=-1,
            allows_passthrough=False,
        )
    )
    specs.append(
        CommandSpec(
            name="routes",
            summary="List the app's routes",
            usage="[FILE]",
            flags=[
                FlagSpec(
                    "timeout", "SECONDS", "Give up after this long (default 60)"
                ),
            ],
            max_positionals=1,
            allows_passthrough=False,
        )
    )
    specs.append(
        CommandSpec(
            name="doctor",
            summary="Check the toolchain, project and machine",
            usage="",
            flags=List[FlagSpec](),
            max_positionals=0,
            allows_passthrough=False,
        )
    )
    specs.append(
        CommandSpec(
            name="docs pull",
            summary="Download the Mojo and dodo docs into .dodo/docs/",
            usage="[mojo@VERSION] [dodo@VERSION]",
            flags=[
                FlagSpec(
                    "mojo", "VERSION", "Mojo version (default: the project's)"
                ),
                FlagSpec(
                    "dodo", "VERSION", "dodo version (default: the project's)"
                ),
            ],
            max_positionals=2,
            allows_passthrough=False,
        )
    )
    specs.append(
        CommandSpec(
            name="help",
            summary="Show help for dodo or one command",
            usage="[COMMAND]",
            flags=List[FlagSpec](),
            max_positionals=2,
            allows_passthrough=False,
        )
    )
    return specs^


def find_spec(specs: List[CommandSpec], name: String) -> Int:
    """The index of the command called `name`, or -1."""
    for i in range(len(specs)):
        if specs[i].name == name:
            return i
    return -1
