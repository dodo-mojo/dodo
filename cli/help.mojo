"""Help text, built from the command specs so it never drifts from them."""

from .args import CommandSpec
from .report import (
    EXIT_BUILD_FAILED,
    EXIT_FAILED,
    EXIT_INTERNAL,
    EXIT_OK,
    EXIT_UNAVAILABLE,
    EXIT_USAGE,
)
from .version import DODO_VERSION


def overview(specs: List[CommandSpec]) -> String:
    """The help for `dodo` itself."""
    var width = 0
    for spec in specs:
        width = max(width, spec.name.byte_length())

    var text = String(
        "dodo ", DODO_VERSION, ": the dodo web framework's command line\n\n"
    )
    text += "Usage: dodo COMMAND [ARGS] [--json]\n\nCommands:\n"
    for spec in specs:
        text += String("  ", _pad(spec.name, width), "  ", spec.summary, "\n")
    text += (
        "\nEvery command takes --json (one JSON object on stdout) and --help.\n"
    )
    text += "dodo never asks questions; everything is a flag.\n\n"
    text += exit_codes()
    return text^


def command_help(spec: CommandSpec) -> String:
    """The help for one command."""
    var text = String(spec.summary, "\n\nUsage: dodo ", spec.name)
    if spec.usage != "":
        text += String(" ", spec.usage)
    text += " [--json]\n"
    if len(spec.flags) > 0:
        var width = 0
        for flag in spec.flags:
            width = max(
                width, _flag_label(flag.name, flag.value_name).byte_length()
            )
        text += "\nFlags:\n"
        for flag in spec.flags:
            var label = _flag_label(flag.name, flag.value_name)
            text += String("  ", _pad(label, width), "  ", flag.help, "\n")
    return text^


def exit_codes() -> String:
    var text = String("Exit codes:\n")
    text += String("  ", EXIT_OK, "   done\n")
    text += String(
        "  ", EXIT_FAILED, "   ran and found a failure (a test, a check)\n"
    )
    text += String(
        "  ", EXIT_BUILD_FAILED, "   the project's code did not build\n"
    )
    text += String("  ", EXIT_USAGE, "  wrong command line\n")
    text += String(
        "  ",
        EXIT_UNAVAILABLE,
        "  something outside dodo is missing (network, mojo, git)\n",
    )
    text += String("  ", EXIT_INTERNAL, "  a bug in dodo\n")
    text += "`dodo run` exits with the app's own code.\n"
    text += "`dodo dev` runs until Ctrl-C and then exits with 130.\n"
    return text^


def _flag_label(name: String, value_name: String) -> String:
    if value_name == "":
        return String("--", name)
    return String("--", name, " ", value_name)


def _pad(text: String, width: Int) -> String:
    var out = text
    while out.byte_length() < width:
        out += " "
    return out^
