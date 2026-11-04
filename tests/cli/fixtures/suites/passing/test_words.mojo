from std.testing import TestSuite, assert_true


def test_upper() raises:
    assert_true("dodo".upper() == "DODO")


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
