# `dodo.http.redirect_policy`

HTTP redirect policy: configurable cross-origin + auth gating.

The default ``HttpClient`` follows redirects unconditionally up to a
configurable hop count and silently strips state-changing methods
(POST → GET on 301/302/303, per the spec). That covers the
80% case but leaves three sharp edges for callers who care:

1. **Cross-origin redirects.** A 302 from ``api.example.com`` to
   ``evil.com`` is a textbook open-redirect leak — every
   request your client sends to ``api.example.com`` (including
   the Authorization header, cookies, custom auth tokens) will
   silently follow to ``evil.com`` if you don't gate on origin.
   :class:`RedirectPolicy.same_origin_only` says "follow same-origin
   redirects, error on cross-origin". :class:`.deny` says "never
   follow; surface the 3xx to the caller".
2. **Authorization-header forwarding.** Even when a cross-origin
   redirect is intentional (image CDN with separate auth domain,
   for example), the Authorization header should not be forwarded
   to the new host by default — that's the requests-library
   default since 2014 and curl's --location-trusted behaviour
   inverts. :class:`.forward_auth_cross_origin` (default ``False``)
   controls this.
3. **307 / 308 method preservation.** RFC 9110 §15.4 mandates
   that 307 / 308 redirects preserve the original method + body
   (whereas 301 / 302 / 303 historically degrade POST → GET).
   The default policy honours this; the :func:`.decide` helper
   is the single source of truth.

Public surface:

- :class:`RedirectPolicy` — the policy struct (max hops + cross-
  origin gating + auth-forwarding gating).
- :class:`RedirectAction` — the three-way decision: ``Follow``,
  ``Stop`` (cap hit / DENY rule), or ``Reject`` (cross-origin
  while in SAME_ORIGIN mode).
- :class:`RedirectDecision` — the decision plus its derived
  next-request shape (method + whether to forward the Authorization
  header).

The decision-helper :meth:`RedirectPolicy.decide` is pure (no
network), so :class:`HttpClient` drives it and tests check it in
isolation: each cross-origin / auth-forwarding rule has an explicit
assertion in :mod:`tests.test_redirect_policy`.

Example:

```mojo
from dodo.http import (
    HttpClient, RedirectPolicy, RedirectMode,
)

# Restrict redirects to the same origin (scheme + host + port);
# refuse to forward Authorization across origins.
var pol = RedirectPolicy.same_origin_only(max_redirects=5)

# Equivalent open-redirect-tolerant configuration (the legacy
# default, byte-for-byte):
var pol_legacy = RedirectPolicy.follow_all(max_redirects=10)
```

## Structs

### `RedirectMode`

```mojo
struct RedirectMode
```

Cross-origin policy as a small enum-shaped namespace.

Mojo doesn't ship an ``enum`` keyword; the constants are exposed
as ``Int`` aliases so callers can pattern-match in plain ``if``
chains.

Implemented traits: `AnyType`, `Deinitable`, `Movable`

Aliases:

- `FOLLOW_ALL = Int(0)`: Follow any 3xx with a Location header, no origin gating. The legacy ``HttpClient`` default — preserves byte-for-byte behaviour.
- `SAME_ORIGIN_ONLY = Int(1)`: Follow only when the redirect target shares scheme + host + port with the previous request. Cross-origin redirects raise ``CrossOriginRedirect`` (mapped to ``HttpError`` at the client surface).
- `DENY = Int(2)`: Never follow. The 3xx response is surfaced to the caller unchanged (status + Location header). Useful when the application wants to inspect the redirect target before deciding.

### `RedirectAction`

```mojo
struct RedirectAction
```

Decision outcome from :meth:`RedirectPolicy.decide`.

Implemented traits: `AnyType`, `Deinitable`, `Movable`

Aliases:

- `FOLLOW = Int(0)`: Follow the redirect; the :class:`RedirectDecision`'s ``next_method`` / ``next_url`` / ``forward_authorization`` fields apply.
- `STOP = Int(1)`: Stop following — either max-hops reached, or the policy is :data:`RedirectMode.DENY`. The caller surfaces the current 3xx response to the application.
- `REJECT = Int(2)`: Reject — the policy is :data:`RedirectMode.SAME_ORIGIN_ONLY` and the target was cross-origin. The caller raises :class:`CrossOriginRedirect` (mapped to ``HttpError``).

### `RedirectDecision`

```mojo
struct RedirectDecision
```

The full output of :meth:`RedirectPolicy.decide`.

Fields:
    action: One of :data:`RedirectAction.FOLLOW` /
        ``STOP`` / ``REJECT``.
    next_method: HTTP method for the next request (only
        populated when ``action == FOLLOW``). ``""`` for
        STOP / REJECT.
    next_url: Absolute URL for the next request (only
        populated when ``action == FOLLOW``). ``""`` for
        STOP / REJECT.
    next_body_dropped: When ``True``, the next request
        should drop its body (POST/PUT/PATCH → GET on
        301/302/303). When ``False``, the body is preserved
        (307/308 method-preserving redirect).
    forward_authorization: Whether the Authorization header
        should be forwarded to ``next_url`` (only meaningful
        when ``action == FOLLOW``). ``False`` for any
        cross-origin redirect under the default policy.

Fields:

- `action` (`Int`)
- `next_method` (`String`)
- `next_url` (`String`)
- `next_body_dropped` (`Bool`)
- `forward_authorization` (`Bool`)

Implemented traits: `AnyType`, `Copyable`, `Deinitable`, `Movable`

### `RedirectPolicy`

```mojo
struct RedirectPolicy
```

Configurable redirect-following policy.

Fields:
    max_redirects: Hard cap on the redirect chain length.
        Hit → ``RedirectAction.STOP``.
    mode: One of :data:`RedirectMode.FOLLOW_ALL`,
        ``SAME_ORIGIN_ONLY``, or ``DENY``.
    forward_auth_cross_origin: Whether to forward the
        Authorization header on a cross-origin redirect.
        Defaults to ``False`` (security default; matches the
        requests-library default since 2014). Setting this
        ``True`` is the equivalent of curl's
        ``--location-trusted`` flag — only do it when both
        origins are under your control.

Construct via the named factories rather than the raw
``__init__`` for readable call sites:

```mojo
``RedirectPolicy.follow_all()``        # legacy default
``RedirectPolicy.same_origin_only()``  # security-default
``RedirectPolicy.deny()``              # never follow
```

Fields:

- `max_redirects` (`Int`)
- `mode` (`Int`)
- `forward_auth_cross_origin` (`Bool`)

Implemented traits: `AnyType`, `Copyable`, `Defaultable`, `Deinitable`, `Movable`

#### `RedirectPolicy.__init__`

```mojo
def __init__(out self)
```

Default policy: matches legacy ``HttpClient`` behaviour (FOLLOW_ALL, max_redirects=10, no auth forwarding to cross-origin).

#### `RedirectPolicy.follow_all`

```mojo
def follow_all(max_redirects: Int = Int(10)) -> Self
```

Follow every 3xx with a Location header, up to ``max_redirects`` hops. Authorization is NOT forwarded cross-origin (security default).

#### `RedirectPolicy.same_origin_only`

```mojo
def same_origin_only(max_redirects: Int = Int(10)) -> Self
```

Follow only same-origin redirects (scheme + host + port). Cross-origin → ``RedirectAction.REJECT``.

#### `RedirectPolicy.deny`

```mojo
def deny() -> Self
```

Never follow. Always returns ``RedirectAction.STOP``.

#### `RedirectPolicy.decide`

```mojo
def decide(self, current_url: String, current_method: String, status: Int, location: String, hops_so_far: Int) raises -> RedirectDecision
```

Compute the redirect decision for one 3xx response.

Args:

- `current_url`: Absolute URL the previous request hit.
- `current_method`: HTTP method of the previous request (uppercase, e.g. ``"POST"``).
- `status`: 3xx status code from the previous response.
- `location`: Raw ``Location`` header value (may be relative; resolved against ``current_url``).
- `hops_so_far`: Count of redirects already followed in this chain (excluding this one).

Returns: A :class:`RedirectDecision` describing how the caller should proceed.

Raises: Error: On a malformed Location header.
