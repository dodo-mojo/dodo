from std.testing import TestSuite, assert_equal

from helpers import double


def test_add() raises:
    assert_equal(1 + 1, 2)


def test_double() raises:
    assert_equal(double(4), 8)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
