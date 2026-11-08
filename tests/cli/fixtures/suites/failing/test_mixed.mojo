from std.testing import TestSuite, assert_equal


def test_fine() raises:
    assert_equal(2, 2)


def test_wrong() raises:
    assert_equal(1, 2, "one is not two")


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
