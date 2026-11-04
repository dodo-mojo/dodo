from std.testing import TestSuite


def test_types() raises:
    var x: Int = "not a number"


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
