"""Wire-neutral types shared by HTTP/1.1 and HTTP/2.

``Request``, ``Response``, ``HeaderMap``, ``Method`` and ``Status`` are
built and emitted by every wire. The definitions live in
``dodo/http/{request,response,headers}.mojo``; this package re-exports
them so ``dodo.http2`` can reach them without importing ``dodo.http``,
which would create an import cycle.

Enforced by ``tests/tools/check_no_http_http2_cycle.sh``:

- ``dodo/http/**`` may import ``dodo.http2`` only in the reactor bridge
  (``dodo/http/_h2_conn_handle.mojo``) and helpers that drive
  ``Http2Connection``.
- ``dodo/http2/**`` imports ``dodo.http.wire`` for these types and
  ``dodo.http.proto`` for codec primitives, never ``dodo.http`` itself.
"""

from dodo.http.request import Request, Method
from dodo.http.response import Response, Status
from dodo.http.headers import (
    HeaderMap,
    HeaderInjectionError,
    trailer_field_allowed,
)
