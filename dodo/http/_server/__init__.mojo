"""``dodo.http._server`` -- free-function helpers extracted from
``dodo.http.server``.

This sub-package holds the I/O-light helper layers that used to trail
the ``HttpServer`` struct in ``server.mojo`` (which grew past the
reactor-size budget). Splitting them out keeps each unit inside a
reviewer's working memory and lets the size lint guard the result:

* :mod:`dodo.http._server.parse` -- HTTP/1.1 request parsers (the
  full RFC path, the minimal-headers fast path, the legacy stream
  wrapper).
* :mod:`dodo.http._server.parse_util` -- the byte-level lexing
  primitives the parsers build on: RFC 7230 token / field validation,
  CRLF line readers, scan wrappers, and the ASCII string helpers.
* :mod:`dodo.http._server.responses` -- the public response
  constructors (``ok`` / ``ok_json`` / ``not_found`` / ``redirect`` /
  ...) plus the ``String`` -> bytes copy helper they share.
* :mod:`dodo.http._server.write` -- HTTP/1.1 response serialization
  (``_write_response_buffered`` + the ``itoa`` / append primitives)
  and the status-reason table.

``dodo.http.server`` re-exports every symbol below under its original
name, so all existing ``from dodo.http.server import ...`` call sites
keep resolving unchanged. Internal namespace: nothing here is part of
the public ``dodo`` API beyond what ``server`` already re-exported.
"""
