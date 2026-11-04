"""Reading what a `TestSuite` program printed.

`TestSuite.run()` prints one line per test, and under a failed test the
error, indented:

    Running 3 tests for /path/test_x.mojo
        PASS [ 0.001 ] test_ok
        FAIL [ 0.051 ] test_bad
          At /path/test_x.mojo:7:17: AssertionError: ...
    --------
    Summary [ 0.053 ] 3 tests run: 1 passed , 1 failed , 1 skipped

Times are in milliseconds. The report goes to stdout when every test
passed and to stderr when one failed, so `dodo test` reads both together.
"""

comptime _RESULT_INDENT = "    "
comptime _DETAIL_INDENT = "      "


@fieldwise_init
struct TestCase(Copyable, Movable):
    """One test in a file."""

    var name: String
    var outcome: String
    """"pass", "fail" or "skip"."""
    var ms: Float64
    var message: String
    """The error of a failed test, "" otherwise."""


struct SuiteOutput(Movable):
    """The tests one `TestSuite` program reported."""

    var tests: List[TestCase]
    var finished: Bool
    """The closing `Summary` line was there, so the report is whole."""

    def __init__(out self):
        self.tests = List[TestCase]()
        self.finished = False

    def count(self, outcome: String) -> Int:
        var total = 0
        for test in self.tests:
            if test.outcome == outcome:
                total += 1
        return total


def parse_suite_output(text: String) -> SuiteOutput:
    """The tests in `text`. Lines a test printed itself are ignored."""
    var parsed = SuiteOutput()
    var in_failure = False
    for raw in text.splitlines():
        var line = String(raw)
        var test = _result_line(line)
        if test:
            parsed.tests.append(test.take())
            in_failure = parsed.tests[len(parsed.tests) - 1].outcome == "fail"
            continue
        if line.startswith("Summary ["):
            parsed.finished = True
            in_failure = False
            continue
        if in_failure and line.startswith(_DETAIL_INDENT):
            _add_message_line(parsed.tests[len(parsed.tests) - 1], line)
            continue
        in_failure = False
    return parsed^


def _result_line(line: String) -> Optional[TestCase]:
    """`    PASS [ 0.001 ] test_ok` as a `TestCase`."""
    if not line.startswith(_RESULT_INDENT):
        return None
    var rest = String(line[byte = _RESULT_INDENT.byte_length() :])
    var outcome: String
    if rest.startswith("PASS [ "):
        outcome = "pass"
    elif rest.startswith("FAIL [ "):
        outcome = "fail"
    elif rest.startswith("SKIP [ "):
        outcome = "skip"
    else:
        return None
    var close = rest.find(" ] ")
    if close < 0:
        return None
    var ms: Float64
    try:
        ms = Float64(String(rest[byte=7:close]))
    except:
        return None
    var name = String(rest[byte = close + 3 :])
    if name == "":
        return None
    return TestCase(name, outcome, ms, "")


def _add_message_line(mut test: TestCase, line: String):
    var text = String(line[byte = _DETAIL_INDENT.byte_length() :])
    if test.message != "":
        test.message += "\n"
    test.message += text
