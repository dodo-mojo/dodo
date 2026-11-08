# `dodo.dns.async_resolve`

DNS resolution on a separate thread + happy-eyeballs ordering.

``getaddrinfo(3)`` is a blocking syscall with no async variant on the
platforms dodo targets. :func:`resolve_async` runs it on a fresh OS
thread (the pthread mechanism :func:`block_in_pool` uses) **and waits
for that thread**: the caller is blocked for the whole lookup, exactly
as with :func:`dodo.dns.resolve`. What it adds is a separate stack and
a :class:`Cancel` check before the lookup starts and after it returns.
It does not free a reactor thread to serve other connections while the
lookup runs, and a cancel that arrives mid-lookup takes effect only
when ``getaddrinfo`` returns. Errors come back with the resolver's
message (``DnsError(host): reason``) as a plain ``Error``, which is
what a raised ``DnsError`` is by the time any caller sees it.

:func:`order_happy_eyeballs` reorders a resolved address list into the
RFC 8305 connection-attempt order (interleave IPv6 / IPv4, starting with
the family of the first address) so a dialer can race families without one
stalling the other.

The worker thread is joined (the public API is synchronous --
the submitter waits for the result anyway), so a flipped ``cancel`` is
honored at the pre-flight and post-flight boundaries, the same contract
as ``block_in_pool``. A truly fire-and-forget resolve that returns the
reactor to its loop while the lookup runs would need reactor-side
completion wiring (eventfd/pipe wakeup) instead.

## Functions

### `resolve_async`

```mojo
def resolve_async(host: String, cancel: Cancel) raises -> List[IpAddr]
```

Resolve ``host`` on a pool thread and wait for it.

Same result as :func:`dodo.dns.resolve`, and it blocks the caller
just as long: the ``getaddrinfo`` call runs on a fresh kernel thread
that this function joins. A flipped ``cancel`` is honoured before
the thread starts and after it finishes, not during the lookup.

Args:

- `host`: Hostname or numeric IP string.
- `cancel`: Per-request cancel token (use ``Cancel.never()`` for an uncancellable call).

Returns: A non-empty ``List[IpAddr]`` (OS-preference order; pass through :func:`order_happy_eyeballs` for connection-attempt order).

Raises: AddressParseError: empty ``host``. DnsError / Error: resolver failure (propagated from the worker), or cancellation.

### `order_happy_eyeballs`

```mojo
def order_happy_eyeballs(addrs: List[IpAddr]) -> List[IpAddr]
```

Reorder ``addrs`` into RFC 8305 connection-attempt order.

Interleaves the two address families, **starting with the family of
``addrs[0]``** (the resolver's most-preferred address, RFC 8305 §4:
"whichever address family is first in the list should be followed by an
address of the other address family"), preserving each family's relative
order: ``[v6, v4, v6, v4, ...]`` for an IPv6-first input and
``[v4, v6, v4, v6, ...]`` for an IPv4-first one. A dialer can then race
the two families without one family's slow first address starving the
other, and the first attempt still goes to the address the OS ranked
highest. Returns a new list; the input is unchanged.
