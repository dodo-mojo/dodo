from std.subprocess import run
from std.testing import TestSuite


def test_starts_a_background_program() raises:
    # The pid file lets the CLI test check the program was killed.
    _ = run("sleep 30 > /dev/null 2>&1 & echo $! > leftover.pid")


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
