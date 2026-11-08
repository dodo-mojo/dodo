# `std.testing.assert_aborts`

Asserts that code aborts the process, without losing the rest of the test suite.

A hard abort (e.g. a failed `debug_assert`) kills the whole process, so it
can't be caught with `try`/`except`. This runs the code under test in a
re-exec'd child and checks that the child crashed with the expected message.
