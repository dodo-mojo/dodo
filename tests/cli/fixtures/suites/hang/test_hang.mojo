from std.testing import TestSuite
from std.time import sleep


def test_sleeps() raises:
    sleep(600.0)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
