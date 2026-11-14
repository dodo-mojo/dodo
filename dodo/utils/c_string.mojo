"""Passing a `String` to C.

Call `prepare_c_string` on a string before `as_c_string_span()`.

In Mojo 1.2.0, an empty `String` that came from a `= ""` default
argument, or a copy of one, keeps a pointer into the program's static
string pool. `as_c_string_span()` hands C that pointer unchanged, so C
reads whatever string the pool holds next instead of an empty string.
`TlsConfig()` hit this: its empty `ca_bundle` reached OpenSSL as a file
called `Runtime`, and every HTTPS request failed to load its CA bundle.
"""


def prepare_c_string(mut text: String):
    """Give an empty `text` a buffer of its own, so `as_c_string_span()`
    returns an empty C string. A non-empty `text` is left as it is."""
    if text.byte_length() == 0:
        text = String()
