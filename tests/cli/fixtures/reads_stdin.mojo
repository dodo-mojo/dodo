from std.testing import TestSuite


def test_reads_stdin() raises:
    try:
        _ = input()
    except:
        pass


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
