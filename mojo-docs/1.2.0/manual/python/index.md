# Python interoperability

*From Modular's Mojo docs (`Mojo/docs/site/manual/python/index.mdx` at tag `mojo/v1.2.0`, Apache-2.0 with LLVM Exceptions, see `LICENSE.txt`), turned into plain Markdown by dodo.*

Not only does Mojo use a Pythonic syntax, our plan is to provide full
compatibility with the Python ecosystem. There are two types of compatibility
(or interoperability) that we support:

- [Calling Python from Mojo](../../manual/python/python-from-mojo.md):

  You can import existing Python modules and use them in a Mojo program. This
  is 100% compatible because we use the CPython runtime without modification
  for full compatibility with existing Python libraries. You can construct
  Python objects and call Python functions directly from Mojo, using the
  CPython interpreter as a dynamic library (shown as `libpython.dylib` in
  figure 1).

- [Calling Mojo from Python](../../manual/python/mojo-from-python.md):

  You can extend your Python code with high-performance Mojo code (or
  incrementally migrate Python code to Mojo). Because Mojo is a compiled
  language, we can't directly "evaluate" Mojo code from Python. Instead, you
  must declare which Mojo functions and types are available to be called from
  Python (declare the "bindings"), and then you can import them in your Python
  code (shown as `mojo_module` in figure 1) just like any other module—there's
  no extra compilation step.

<figure style={{maxWidth: '550px'}}>
  <img src={require('../images/python/python-interop.png').default}
       className="light" alt="" />
  <img src={require('../images/python/python-interop-dark.png').default}
       className="dark" alt="" />
  <figcaption><b>Figure 1.</b> A simplified look at how a Mojo program calls
  into Python and a Python program calls into a Mojo module.</figcaption>
</figure>

By embracing both directions of language interoperability, you can choose
how to use Mojo with Python in a way that works best for your use case.

**Note: Python requirement**

Mojo itself doesn't require Python. To use the Mojo ↔ Python
interoperability features described in this section, you need
Python 3.10–3.14.

**To learn more about bridging Python ↔ Mojo, continue reading**:

  - [Calling Python from Mojo](../../manual/python/python-from-mojo.md): How to import Python modules and use them in Mojo code
  - [Calling Mojo from Python](../../manual/python/mojo-from-python.md): How to import Mojo modules and use them in Python code
