# `std.python`

Python interoperability: import packages and modules, call functions, type conversion.

The `python` package enables interoperability between Mojo and Python
code. It provides mechanisms for importing Python packages and modules, calling Python
functions, and converting values between Mojo and Python types. This package
allows Mojo programs to leverage the extensive Python ecosystem while
maintaining Mojo's performance characteristics.

Use this package when you need to call Python libraries, integrate existing
Python code into Mojo applications, or leverage Python's ecosystem for
functionality not yet available in native Mojo.

## Modules

- [`std.python.bindings`](bindings.md): Provides infrastructure for creating Python bindings to Mojo code.
- [`std.python.conversions`](conversions.md): Implements conversion traits to and from PythonObject.
- [`std.python.numpy`](numpy.md): NumPy interoperability helpers for Mojo collections.
- [`std.python.python`](python.md): Implements Python interoperability.
- [`std.python.python_object`](python_object.md): Implements PythonObject.
