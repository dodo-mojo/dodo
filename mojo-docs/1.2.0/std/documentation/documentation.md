# `std.documentation.documentation`

Provides decorators and utilities for interacting with Mojo documentation generation and validation.

These are Mojo built-ins, so you don't need to import them.

## Functions

### `doc_hidden`

```mojo
def doc_hidden()
```

Indicate that the decorated declaration is hidden from documentation generation.

This decorator allows for hiding the documentation for a declaration during
generation. This is often used to hide `__init__`, and other special
methods, that are not intended to be part of a library's documentation.

For example:

```mojo
struct Foo:
    @doc_hidden
    def __init__(out self):
        "This should not be called directly, use `Foo.create` instead."
        return

    @staticmethod
    def create() -> Self:
        return Self()
```
