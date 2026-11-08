# `dodo.http.conditional`

Conditional GET / PUT middleware (RFC 9110 §13).

``Conditional[Inner]`` evaluates the four standard precondition
headers against the response that the wrapped ``Inner`` handler
produces:

- ``If-Match``         (RFC 9110 §13.1.1) → 412 Precondition Failed
                                              when no token matches
                                              the response ETag.
- ``If-None-Match``    (RFC 9110 §13.1.2) → 304 Not Modified for
                                              GET / HEAD; 412 for
                                              other methods.
- ``If-Modified-Since`` (RFC 9110 §13.1.3) → 304 Not Modified for
                                              GET / HEAD when the
                                              resource hasn't
                                              changed since the
                                              client's cached copy.
- ``If-Unmodified-Since`` (RFC 9110 §13.1.4) → 412 Precondition
                                                  Failed for any
                                                  method when the
                                                  resource has
                                                  changed since
                                                  ``Last-Modified``.

When the inner response carries no ``ETag``, this middleware can
generate a weak one from a 64-bit FNV-1a hash of the body. Auto-ETag
is opt-in via ``Conditional.with_auto_etag`` (default off — the
caller explicitly chooses whether to pay the body-hash cost on each
request, since for large bodies it's not free).

Behaviour notes:

- Precedence per RFC 9110 §13.2.2: If-Match > If-Unmodified-Since >
  If-None-Match > If-Modified-Since. Conditional honours the order
  exactly; the first failing precondition short-circuits.
- Strong vs weak comparison: If-Match always uses strong comparison
  (only strong ETags match). If-None-Match uses weak comparison
  when the request method is GET / HEAD and strong otherwise — the
  spec's distinction between "safe / cacheable" and "state-changing"
  methods.
- The inner handler still runs (we need its response to read the
  ETag / Last-Modified headers); the middleware only rewrites the
  outbound status + body. For a cache-aware origin you'd usually
  put a body-skipping fast-path inside the inner handler that
  computes ETag without rendering — that's an inner-handler
  optimisation orthogonal to this middleware.
- 304 Not Modified responses must drop the body and the
  Content-Length header per RFC 9110 §15.4.5. Conditional does this.
- 412 responses keep the body bytes the inner handler emitted (so
  the caller sees the conflict reason); only the status code is
  rewritten.

Example:

```mojo
from dodo.http import Conditional, Router, Response, ok

def handler(req: Request) raises -> Response:
    var resp = ok("hello")
    resp.headers.set("ETag", '"abc123"')
    return resp^

var app = Conditional[Router](Router())  # wraps any Handler-shaped Inner
```

## Aliases

### `ValidatorLookup`

```mojo
comptime ValidatorLookup = def(Request) raises thin -> Validators
```

Looks up the current validators for the resource ``req`` targets, without changing it. Lets :class:`Conditional` evaluate preconditions on an unsafe method *before* the handler runs.

## Structs

### `Validators`

```mojo
struct Validators
```

The current validators of the resource a request targets, as returned by a :data:`ValidatorLookup`. Either field may be empty.

Fields:

- `etag` (`String`): Current ``ETag`` (e.g. ``'"v7"'``), or empty if none.
- `last_modified` (`String`): Current ``Last-Modified`` as an HTTP-date, or empty if none.

Implemented traits: `AnyType`, `Copyable`, `Deinitable`, `Movable`

### `Conditional`

```mojo
struct Conditional[Inner: Handler & Copyable]
```

Honour RFC 9110 §13 precondition headers around ``Inner``.

**Safe methods** (GET, HEAD): calls ``inner.serve(req)`` first, since
the response's ``ETag`` / ``Last-Modified`` are the validators, then
rewrites a 2xx to 304 / 412 when a precondition fails. Error
responses are passed through untouched.

**Unsafe methods** (PUT, POST, DELETE, ...): preconditions exist to
stop a lost update, so they must be checked *before* the handler
changes anything. With a :data:`ValidatorLookup` (see
:meth:`with_validators`) the current validators are looked up
first and a failing request gets 412 without reaching ``Inner``.
Without one this middleware cannot know the current state, and it
passes the request and response through unchanged: the handler must
check ``If-Match`` itself. Evaluating afterwards -- what this used
to do -- ran the write and then told the client it had failed.

The middleware never mutates the ``Inner`` response when all
preconditions pass — pass-through is byte-identical so a cache
revalidation downstream sees the same headers as a non-cached
response.

Toggles:

- ``auto_etag`` (default ``False``) — when the inner response
  has no ``ETag``, generate a weak one via ``fnv1a_etag``
  before evaluating ``If-None-Match`` / ``If-Match``.

Example:

```mojo
var c = Conditional[Router](Router())
var c2 = Conditional[Router].with_auto_etag(Router())
var c3 = Conditional[Router].with_validators(Router(), lookup_doc)
```

Fields:

- `inner` (`Inner`)
- `auto_etag` (`Bool`)
- `lookup` (`Optional[def(Request) raises thin -> Validators]`)

Implemented traits: `AnyType`, `Copyable`, `Deinitable`, `Handler`, `Movable`

Aliases:

- `BodyType = InlineBody`: The ``Body`` impl this handler authors its response with.

#### `Conditional.__init__`

```mojo
def __init__(out self, var inner: Inner)
```

#### `Conditional.with_auto_etag`

```mojo
def with_auto_etag(var inner: Inner) -> Self
```

Construct a ``Conditional[Inner]`` that auto-generates a weak FNV-1a ETag for any inner response missing one.

#### `Conditional.with_validators`

```mojo
def with_validators(var inner: Inner, lookup: def(Request) raises thin -> Validators) -> Self
```

Construct a ``Conditional[Inner]`` that evaluates preconditions on unsafe methods before dispatch, using ``lookup`` for the resource's current validators.

#### `Conditional.serve`

```mojo
def serve(self, req: Request) raises -> Response
```

#### `Conditional.may_block`

```mojo
def may_block(self) -> Bool
```

#### `Conditional.route_list`

```mojo
def route_list(self) raises -> List[RouteInfo]
```

#### `Conditional.blocking`

```mojo
def blocking(self, req: Request) raises -> Bool
```

## Functions

### `fnv1a_etag`

```mojo
def fnv1a_etag(body: Span[UInt8]) -> String
```

Return a weak ETag derived from a 64-bit FNV-1a hash of ``body``.

Format: ``W/"<16-hex-digits>"``. Weak rather than strong because
the hash is not collision-proof under adversarial input — for a
GET-cache key this is fine (304 short-circuits a re-fetch); for
state-changing requests use a strong ETag from your data layer
instead.
