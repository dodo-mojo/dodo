"""Command-line parsing for `dodo`.

Each command is described by a `CommandSpec`: its name, its flags and how
many plain arguments it takes. `parse_args` matches the words after
`dodo` against those specs and returns `ParsedArgs`. A mistake (unknown
command, unknown flag, a flag without its value) is reported in
`ParsedArgs.error`, so the caller prints it and exits with the usage code.

Accepted forms: `--flag`, `--flag value`, `--flag=value`, `-h`, and `--`
to pass every later word on untouched (only for commands that allow it).
`--json` and `--help` work on every command.
"""


@fieldwise_init
struct FlagSpec(Copyable, ImplicitlyCopyable, Movable):
    """One flag a command accepts."""

    var name: String
    """The long name, without the leading dashes."""
    var value_name: String
    """The placeholder shown in help for the flag's value, or "" for a
    flag that takes no value."""
    var help: String
    """One line for the help text."""

    def takes_value(self) -> Bool:
        return self.value_name != ""


@fieldwise_init
struct CommandSpec(Copyable, Movable):
    """One `dodo` command."""

    var name: String
    """The words that select it, such as "docs pull"."""
    var summary: String
    """One line for the command list."""
    var usage: String
    """The arguments part of the usage line, such as "[PATH]"."""
    var flags: List[FlagSpec]
    var max_positionals: Int
    """How many plain arguments it takes; -1 for any number."""
    var allows_passthrough: Bool
    """Whether words after `--` are passed on to a program."""


struct ParsedArgs(Movable):
    """The words after `dodo`, sorted out."""

    var command: String
    """The matched command's name, or "" when none was given."""
    var positionals: List[String]
    var values: Dict[String, String]
    """Flags that take a value, by name."""
    var switches: List[String]
    """Flags without a value that were given, by name."""
    var passthrough: List[String]
    """Words after `--`."""
    var json: Bool
    var help: Bool
    var version: Bool
    var error: String
    """Why the words could not be parsed, or "" when they could."""

    def __init__(out self):
        self.command = ""
        self.positionals = List[String]()
        self.values = Dict[String, String]()
        self.switches = List[String]()
        self.passthrough = List[String]()
        self.json = False
        self.help = False
        self.version = False
        self.error = ""

    def has(self, switch: String) -> Bool:
        """Whether a flag without a value was given."""
        for name in self.switches:
            if name == switch:
                return True
        return False

    def value(self, flag: String, default: String = "") -> String:
        """A flag's value, or `default` when it was not given."""
        var found = self.values.get(flag)
        if found:
            return found.value()
        return default

    def given(self, flag: String) -> Bool:
        """Whether a flag that takes a value was given."""
        return flag in self.values


def parse_args(words: List[String], specs: List[CommandSpec]) -> ParsedArgs:
    """Parse the words after `dodo` (not including the program name)."""
    var parsed = ParsedArgs()
    # Known before anything can fail, so even a parse error comes out as
    # JSON when it was asked for.
    parsed.json = _asks_for_json(words)
    # `--json`, `--help` and `--version` may come before the command.
    var next_word = 0
    while next_word < len(words) and _is_global_flag(words[next_word]):
        _record_global_flag(words[next_word], parsed)
        next_word += 1
    var spec_index = _match_command(words, next_word, specs)
    if spec_index >= 0:
        parsed.command = specs[spec_index].name
        next_word += _word_count(specs[spec_index].name)

    while next_word < len(words):
        var word = words[next_word]
        next_word += 1

        if word == "--":
            if spec_index < 0 or not specs[spec_index].allows_passthrough:
                parsed.error = "unexpected `--`: this command passes nothing on"
                return parsed^
            for i in range(next_word, len(words)):
                parsed.passthrough.append(words[i])
            return parsed^

        if _is_global_flag(word):
            _record_global_flag(word, parsed)
            continue

        if word.startswith("--"):
            if spec_index < 0:
                parsed.error = String("unknown flag ", word)
                return parsed^
            var taken = _take_flag(
                word, words, next_word, specs[spec_index].flags, parsed
            )
            if parsed.error != "":
                return parsed^
            next_word += taken
            continue

        if word.startswith("-") and word != "-":
            parsed.error = String(
                "unknown flag ", word, " (dodo uses long flags such as --json)"
            )
            return parsed^

        if spec_index < 0:
            parsed.error = _unknown_command(word, specs)
            return parsed^
        parsed.positionals.append(word)

    if spec_index >= 0 and not parsed.help:
        var limit = specs[spec_index].max_positionals
        if limit >= 0 and len(parsed.positionals) > limit:
            parsed.error = _too_many(specs[spec_index], parsed.positionals)
    return parsed^


def _take_flag(
    word: String,
    words: List[String],
    next_word: Int,
    flags: List[FlagSpec],
    mut parsed: ParsedArgs,
) -> Int:
    """Record one `--flag` and return how many extra words it used."""
    var body = String(word[byte=2:])
    var name = body
    var inline_value = String("")
    var has_inline_value = False
    var equals = body.find("=")
    if equals >= 0:
        name = String(body[byte=:equals])
        inline_value = String(body[byte = equals + 1 :])
        has_inline_value = True

    var flag_index = -1
    for i in range(len(flags)):
        if flags[i].name == name:
            flag_index = i
    if flag_index < 0:
        parsed.error = String("unknown flag --", name)
        return 0
    var flag = flags[flag_index]

    if not flag.takes_value():
        if has_inline_value:
            parsed.error = String("--", name, " takes no value")
            return 0
        if parsed.has(name):
            parsed.error = String("--", name, " is given twice")
            return 0
        parsed.switches.append(name)
        return 0

    if parsed.given(name):
        parsed.error = String("--", name, " is given twice")
        return 0
    if has_inline_value:
        parsed.values[name] = inline_value
        return 0
    if next_word >= len(words) or words[next_word].startswith("--"):
        parsed.error = String(
            "--", name, " needs a value: --", name, " ", flag.value_name
        )
        return 0
    parsed.values[name] = words[next_word]
    return 1


def _asks_for_json(words: List[String]) -> Bool:
    """Whether `--json` appears before any `--`."""
    for word in words:
        if word == "--":
            return False
        if word == "--json":
            return True
    return False


def _is_global_flag(word: String) -> Bool:
    """A flag every command takes."""
    if word == "--json" or word == "--help" or word == "-h":
        return True
    return word == "--version" or word == "-V"


def _record_global_flag(word: String, mut parsed: ParsedArgs):
    if word == "--json":
        parsed.json = True
    elif word == "--help" or word == "-h":
        parsed.help = True
    else:
        parsed.version = True


def _match_command(
    words: List[String], start: Int, specs: List[CommandSpec]
) -> Int:
    """The spec whose name matches the words from `start`, longest first."""
    var best = -1
    var best_words = 0
    for i in range(len(specs)):
        var count = _word_count(specs[i].name)
        if start + count > len(words) or count <= best_words:
            continue
        var leading = String(" ").join(words[start : start + count])
        if leading == specs[i].name:
            best = i
            best_words = count
    return best


def _unknown_command(word: String, specs: List[CommandSpec]) -> String:
    """Name the subcommands when `word` starts a group such as `docs`."""
    var group = String(word, " ")
    var subcommands = List[String]()
    for spec in specs:
        if spec.name.startswith(group):
            subcommands.append(String(spec.name[byte = group.byte_length() :]))
    if len(subcommands) == 0:
        return String("unknown command `", word, "`")
    return String(
        "`", word, "` needs a subcommand: ", String(", ").join(subcommands)
    )


def _word_count(name: String) -> Int:
    return len(name.split(" "))


def _too_many(spec: CommandSpec, positionals: List[String]) -> String:
    """The message for extra arguments. `Report` adds "dodo <command>: "."""
    var extra = positionals[spec.max_positionals]
    if spec.max_positionals == 0:
        return String("takes no arguments (got `", extra, "`)")
    return String(
        "takes at most ",
        spec.max_positionals,
        " argument(s) (got `",
        extra,
        "` too)",
    )
