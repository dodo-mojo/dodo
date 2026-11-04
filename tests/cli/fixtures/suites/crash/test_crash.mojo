from std.os import abort
from std.testing import TestSuite


def test_aborts() raises:
    print("about to abort")
    abort()


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
