# `dodo.http.header_phf`

Comptime perfect-hash dispatch for ~70 standard HTTP header names.

Replaces the case-insensitive linear scan in
``HeaderMap.{get,set,has}`` with a length-first + case-insensitive
byte-compare lookup against a fixed table of RFC 7230 + RFC 7231
+ RFC 7232 + RFC 7233 + RFC 7234 + RFC 7235 + RFC 9110 + RFC 6265
header names.

Background
----------

``HeaderMap.get(name)`` walks the underlying ``List[String]``
linearly, ASCII-lowercase comparing each entry. With ~10 headers
in a typical request, that's ~10 case-folded compares per lookup.
Most headers users actually look up are **standard** (Host,
Content-Type, Content-Length, Connection, User-Agent, Accept,
Cookie, Authorization, etc.). For those, a length-first dispatch
into a pre-canonicalised lowercase table is a single ``len(slice)
== K`` branch + a small per-length switch + one byte compare —
faster than the loop and, more importantly, **stable in latency**
regardless of how many other headers the request carries.

The deliverable here is the **dispatch primitive**: given a byte
slice, return an integer index 0..N-1 if it matches a known
standard header (case-insensitively), else -1, plus the public
``StandardHeader.*`` index constants. ``HeaderMap`` does not use it.

Approach
--------

A "perfect hash" against a small fixed string set is most
practically implemented as **length-bucketed dispatch +
case-insensitive memcmp**. Mojo doesn't have a CHD / BDZ PHF
generator; for ~70 inputs the length-first approach is O(1) per
lookup with a tiny constant factor (single length compare → at
most 8-10 byte compares for the longest length-bucket), and it
generates instructions the branch predictor handles trivially.

Length 4 holds {Host, Date, From, ETag, Vary}. Length 5 holds
{Range, Allow}. Length 6 holds {Accept, Cookie, Server, Pragma,
Origin}. Length 7 holds {Referer, Trailer, Upgrade, Expires,
Warning, Refresh}. Etc. Most lengths have 1-5 candidates; the
pathological lengths (8 with {If-Match, If-Range, Location,
Set-Cookie/2-bytes-shy, etc.}) cap at ~6 candidates.

ASCII case folding
------------------

HTTP/1.1 header field names are case-insensitive (RFC 7230
§3.2). The lookup folds each input byte to lowercase via the
classic ``b | 0x20`` trick gated to ASCII letters [A-Z]. The
table itself stores the canonical lowercase form; one fold +
one byte compare per character.

What this module provides
-------------------------

* ``StandardHeader`` — namespace struct holding the canonical
  index constants (``StandardHeader.HOST``,
  ``StandardHeader.CONTENT_TYPE``, etc.). Indices are stable
  for the lifetime of a dodo release; downstream code
  (HeaderMap fast-path slot, SIMD HPACK decoder static table)
  can take dependencies on them.
* ``standard_header_count() -> Int`` — number of standard
  headers in the table (currently 70).
* ``standard_header_name(index) -> StaticString`` — inverse of
  the lookup; returns the canonical lowercase name for a
  valid index or empty ``StaticString`` for out-of-range.
* ``lookup_standard_header_bytes(slice) -> Int`` — the lookup
  primitive. Returns the index 0..N-1 on a hit (case-
  insensitive byte-compare against the table) or -1 on a miss.
* ``lookup_standard_header_string(name) -> Int`` — convenience
  ``String``-typed wrapper.
* ``is_standard_header(slice) -> Bool`` — boolean shorthand
  for callers that don't need the index.

The 70-name table covers (grouped by RFC):

* **Connection control (RFC 7230)**: Host, Connection,
  Keep-Alive, Transfer-Encoding, Trailer, Upgrade,
  Content-Length, Content-Type, Date, Via.
* **Conditionals (RFC 7232)**: ETag, If-Match, If-None-Match,
  If-Modified-Since, If-Unmodified-Since, Last-Modified.
* **Range (RFC 7233)**: Accept-Ranges, Range, If-Range,
  Content-Range.
* **Caching (RFC 7234)**: Cache-Control, Age, Expires, Pragma,
  Warning.
* **Authentication (RFC 7235)**: Authorization,
  WWW-Authenticate, Proxy-Authenticate,
  Proxy-Authorization.
* **Negotiation (RFC 9110)**: Accept, Accept-Encoding,
  Accept-Language, Accept-Charset, Allow, Content-Encoding,
  Content-Language, Content-Location, Content-Disposition,
  Vary, From, Referer, User-Agent, Server, Location,
  Retry-After.
* **Cookies (RFC 6265)**: Cookie, Set-Cookie.
* **CORS (W3C / Fetch)**: Origin, Access-Control-Allow-Origin,
  Access-Control-Allow-Methods, Access-Control-Allow-Headers,
  Access-Control-Allow-Credentials, Access-Control-Expose-
  Headers, Access-Control-Max-Age, Access-Control-Request-
  Method, Access-Control-Request-Headers.
* **Forwarding / Proxy (RFC 7239 + de facto)**: Forwarded,
  X-Forwarded-For, X-Forwarded-Proto, X-Forwarded-Host,
  X-Real-IP.
* **WebSocket / Upgrade**: Sec-WebSocket-Key, Sec-WebSocket-
  Version, Sec-WebSocket-Accept, Sec-WebSocket-Protocol,
  Sec-WebSocket-Extensions.
* **Misc widely-used**: Expect, Refresh, X-Request-ID,
  X-Content-Type-Options, X-Frame-Options, X-XSS-Protection,
  Strict-Transport-Security, Content-Security-Policy,
  Public-Key-Pins.

Measured, not adopted. Wiring this into
``HeaderMap`` (a parallel ``List[Int]`` of per-entry ids so a lookup
becomes an integer compare) was a consistent regression: interleaved
30 s A/B on the full-parse baseline gave -3.2 %, -2.8 %, -6.8 % across
three paired runs. The extra list allocation per ``HeaderMap`` costs
more than the faster compare saves, because the server builds a map
per request but performs only about one lookup on it.

It would pay on a map that is looked up many times -- a middleware
stack reading a dozen headers, say. Re-measure before wiring; do not
assume.

## Structs

### `StandardHeader`

```mojo
struct StandardHeader
```

Stable comptime indices for the 70 standard HTTP header names.

Indices are guaranteed not to renumber across dodo patch
releases; downstream code may pin specific constants (e.g. a
SIMD HPACK decoder using these as static-table indices).

Implemented traits: `AnyType`, `Deinitable`, `Movable`

Aliases:

- `HOST = Int(0)`
- `CONNECTION = Int(1)`
- `KEEP_ALIVE = Int(2)`
- `TRANSFER_ENCODING = Int(3)`
- `TRAILER = Int(4)`
- `UPGRADE = Int(5)`
- `CONTENT_LENGTH = Int(6)`
- `CONTENT_TYPE = Int(7)`
- `DATE = Int(8)`
- `VIA = Int(9)`
- `ETAG = Int(10)`
- `IF_MATCH = Int(11)`
- `IF_NONE_MATCH = Int(12)`
- `IF_MODIFIED_SINCE = Int(13)`
- `IF_UNMODIFIED_SINCE = Int(14)`
- `LAST_MODIFIED = Int(15)`
- `ACCEPT_RANGES = Int(16)`
- `RANGE = Int(17)`
- `IF_RANGE = Int(18)`
- `CONTENT_RANGE = Int(19)`
- `CACHE_CONTROL = Int(20)`
- `AGE = Int(21)`
- `EXPIRES = Int(22)`
- `PRAGMA = Int(23)`
- `WARNING = Int(24)`
- `AUTHORIZATION = Int(25)`
- `WWW_AUTHENTICATE = Int(26)`
- `PROXY_AUTHENTICATE = Int(27)`
- `PROXY_AUTHORIZATION = Int(28)`
- `ACCEPT = Int(29)`
- `ACCEPT_ENCODING = Int(30)`
- `ACCEPT_LANGUAGE = Int(31)`
- `ACCEPT_CHARSET = Int(32)`
- `ALLOW = Int(33)`
- `CONTENT_ENCODING = Int(34)`
- `CONTENT_LANGUAGE = Int(35)`
- `CONTENT_LOCATION = Int(36)`
- `CONTENT_DISPOSITION = Int(37)`
- `VARY = Int(38)`
- `FROM = Int(39)`
- `REFERER = Int(40)`
- `USER_AGENT = Int(41)`
- `SERVER = Int(42)`
- `LOCATION = Int(43)`
- `RETRY_AFTER = Int(44)`
- `COOKIE = Int(45)`
- `SET_COOKIE = Int(46)`
- `ORIGIN = Int(47)`
- `ACCESS_CONTROL_ALLOW_ORIGIN = Int(48)`
- `ACCESS_CONTROL_ALLOW_METHODS = Int(49)`
- `ACCESS_CONTROL_ALLOW_HEADERS = Int(50)`
- `ACCESS_CONTROL_ALLOW_CREDENTIALS = Int(51)`
- `ACCESS_CONTROL_EXPOSE_HEADERS = Int(52)`
- `ACCESS_CONTROL_MAX_AGE = Int(53)`
- `ACCESS_CONTROL_REQUEST_METHOD = Int(54)`
- `ACCESS_CONTROL_REQUEST_HEADERS = Int(55)`
- `FORWARDED = Int(56)`
- `X_FORWARDED_FOR = Int(57)`
- `X_FORWARDED_PROTO = Int(58)`
- `X_FORWARDED_HOST = Int(59)`
- `X_REAL_IP = Int(60)`
- `SEC_WEBSOCKET_KEY = Int(61)`
- `SEC_WEBSOCKET_VERSION = Int(62)`
- `SEC_WEBSOCKET_ACCEPT = Int(63)`
- `SEC_WEBSOCKET_PROTOCOL = Int(64)`
- `SEC_WEBSOCKET_EXTENSIONS = Int(65)`
- `EXPECT = Int(66)`
- `REFRESH = Int(67)`
- `X_REQUEST_ID = Int(68)`
- `STRICT_TRANSPORT_SECURITY = Int(69)`

## Functions

### `standard_header_count`

```mojo
def standard_header_count() -> Int
```

Return the number of standard headers in the lookup table.

Currently 70; will grow with future RFCs but never renumber.

### `standard_header_name`

```mojo
def standard_header_name(index: Int) -> StaticString
```

Return the canonical lowercase name for a standard header index, or an empty ``StaticString`` for out-of-range.

Inverse of :func:`lookup_standard_header_bytes` modulo case
folding — the input is normalised to lowercase, the output
is always the canonical lowercase form.

### `lookup_standard_header_bytes`

```mojo
def lookup_standard_header_bytes(slice: Span[UInt8]) -> Int
```

Return the standard-header index (0..N-1) if ``slice`` case-insensitively matches a known RFC 7230 / 7231 / 7232 / 7233 / 7234 / 7235 / 9110 / 6265 / CORS / WebSocket header name; -1 otherwise.

Length-first dispatch keeps the common case ("Host", "Date",
"Cookie", "Accept", "Content-Length", etc.) on a single
``len()`` compare + ≤ 6 byte compares.

Args:

- `slice`: Byte slice — typically a header-name field from an HTTP request line.

Returns: Index into the StandardHeader table on a hit; -1 on a miss.

### `lookup_standard_header_string`

```mojo
def lookup_standard_header_string(name: String) -> Int
```

``String``-typed convenience wrapper around :func:`lookup_standard_header_bytes`.

### `is_standard_header`

```mojo
def is_standard_header(slice: Span[UInt8]) -> Bool
```

Boolean shorthand: ``True`` iff the slice case-insensitively matches a standard header name.
