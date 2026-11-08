# `dodo.http.template`

Tiny tag-based template engine.

Askama-shape minimal subset. Supports the five tags that
cover ~95% of HTML / email / config templating use:

* ``{{ name }}`` -- variable substitution (HTML-escaped by
  default; ``{{ name | safe }}`` opts out).
* ``{% if name %}...{% endif %}`` -- boolean conditional;
  ``name`` is truthy iff non-empty (matches Jinja2 semantics
  for ``string`` truthiness which is the most-common-by-far
  use).
* ``{% for x in name %}...{% endfor %}`` -- loop over a
  list-typed context value; each iteration shadows ``x`` for
  the body.
* ``{% block <name> %}...{% endblock %}`` -- named region with
  default content. Child templates override matching blocks
  via the ``extends`` mechanism below.
* ``{% extends "<parent>" %}`` -- declares this template a
  child of ``<parent>``. Must be the first non-whitespace tag.
  Render through :func:`Template.render_extending(ctx, parent)`
  so the renderer walks the parent's surrounding markup and
  pulls block content from the child.

Out of scope (potential future additions):

- Filters beyond ``| safe`` (``| upper``, ``| length``, etc.).
- ``{% else %}`` branches.
- Whitespace control flags (``{%- ... -%}``).
- Macros / includes.
- Multi-level inheritance (parent extending grandparent).

Type model:

The context is a ``Context`` struct with two flat maps —
``strings: Dict[String, String]`` for ``{{ var }}`` /
conditional truthiness, ``lists: Dict[String, List[String]]``
for ``{% for %}`` iteration. The render pass walks the parsed
tree and resolves names against the strings map first, then
the lists map (for ``{% if %}``: a non-empty list is also
truthy). Loop variables are pushed onto the strings map for
the duration of one iteration via a frame stack.

Why a parsed tree and not a single string-walk:

- ``{% for %}`` requires knowing where the matching ``{% endfor %}``
  is so we can re-render the body N times.
- ``{% if %}`` requires the same for skipping a false branch.
- The parser runs once per :func:`Template.compile` and the
  parsed tree is cached on the ``Template`` struct, so the
  per-render cost is just the tree walk + variable lookups.
- A future block-inheritance upgrade would be a tree-rewrite,
  not a re-parse.

Performance:

The tree walk is O(N) in the size of the rendered output plus
the number of variable lookups. Variable lookups are O(1)
``Dict`` hits. HTML escape is a single-pass byte loop allocating
one growing buffer. There is no pre-rendered "compiled function"
shape (askama / sailfish do this with codegen at compile time);
dodo's reactor latency budget is dominated by network IO not
template render, so the engine keeps the parser-tree-walker
simple.

Error handling:

Both :func:`Template.compile` and :func:`Template.render`
raise the typed :class:`TemplateError` (enumerated; one
``_variant`` field, comptime aliases per condition). Callers
can pattern-match on the variant to distinguish a parse error
from a runtime-rendering error from an unbound-name error,
without ``String(e)`` parsing.

```mojo
from dodo.http.template import Template, TemplateContext, TemplateError

try:
    var t = Template.compile("{{ name }")
except e:
    if e == TemplateError.UNTERMINATED_VAR:
        print("forgot to close {{:", e.detail)
```

## Structs

### `TemplateError`

```mojo
struct TemplateError
```

Typed error raised by :func:`Template.compile` / :func:`Template.render`.

Enumerated (``_variant`` Int field) with ``comptime``
aliases per condition. Equatable so callers can pattern-
match with ``e == TemplateError.UNTERMINATED_VAR`` etc. The
``detail`` field carries human-readable extra context (the
offending tag name, the unbound variable name, the malformed
raw text, ...) — empty when the variant is self-explanatory.

Variants:

- ``UNTERMINATED_VAR`` — ``{{ ... }}`` opener without a
  matching ``}}`` close.
- ``UNTERMINATED_TAG`` — ``{% ... %}`` opener without a
  matching ``%}`` close (or a ``{% endtag %}`` whose ``%}``
  ran off the end of source).
- ``UNKNOWN_FILTER`` — unsupported filter after ``|`` in
  ``{{ name | filter }}``. Only ``| safe`` is accepted.
- ``EMPTY_VAR`` — ``{{ }}`` or ``{{ | safe }}`` with no
  variable name.
- ``EMPTY_TAG`` — ``{% %}`` with no tokens.
- ``MALFORMED_IF`` — ``{% if %}`` not exactly one operand
  after ``if``.
- ``MALFORMED_FOR`` — ``{% for X in Y %}`` shape violated.
  ``detail`` carries the raw token list.
- ``UNMATCHED_END`` — ``{% endif %}`` / ``{% endfor %}``
  seen at the top level (no matching opener). ``detail``
  carries the unmatched tag head.
- ``UNKNOWN_TAG`` — unrecognised control tag in ``{% ... %}``.
  ``detail`` carries the tag head.
- ``UNBOUND_VARIABLE`` — ``{{ name }}`` for a name not in
  ``ctx.strings``. ``detail`` carries the variable name.
- ``UNBOUND_ITERABLE`` — ``{% for x in name %}`` for a name
  not in ``ctx.lists``. ``detail`` carries the variable name.
- ``UNKNOWN_NODE`` — internal: parsed tree contained a node
  kind the renderer doesn't handle. Should be unreachable
  unless ``TemplateNode.kind`` was constructed by hand.

Fields:

- `detail` (`String`)

Implemented traits: `AnyType`, `Copyable`, `Deinitable`, `Equatable`, `ImplicitlyCopyable`, `Movable`, `Writable`

Aliases:

- `UNTERMINATED_VAR = TemplateError(Int(1), String(""))`
- `UNTERMINATED_TAG = TemplateError(Int(2), String(""))`
- `UNKNOWN_FILTER = TemplateError(Int(3), String(""))`
- `EMPTY_VAR = TemplateError(Int(4), String(""))`
- `EMPTY_TAG = TemplateError(Int(5), String(""))`
- `MALFORMED_IF = TemplateError(Int(6), String(""))`
- `MALFORMED_FOR = TemplateError(Int(7), String(""))`
- `UNMATCHED_END = TemplateError(Int(8), String(""))`
- `UNKNOWN_TAG = TemplateError(Int(9), String(""))`
- `UNBOUND_VARIABLE = TemplateError(Int(10), String(""))`
- `UNBOUND_ITERABLE = TemplateError(Int(11), String(""))`
- `UNKNOWN_NODE = TemplateError(Int(12), String(""))`

#### `TemplateError.__eq__`

```mojo
def __eq__(self, other: Self) -> Bool
```

Compare on the ``_variant`` tag only — ``detail`` is human-readable context, not part of the identity.

#### `TemplateError.__ne__`

```mojo
def __ne__(self, other: Self) -> Bool
```

#### `TemplateError.variant_name`

```mojo
def variant_name(self) -> String
```

#### `TemplateError.write_to`

```mojo
def write_to[W: Writer](self, mut writer: W)
```

### `TemplateNode`

```mojo
struct TemplateNode
```

Single node in the parsed template tree.

``kind`` is one of the ``_NODE_*`` constants above. The other
fields are populated per-kind:

- ``_NODE_TEXT``: ``text`` holds the raw bytes; everything
  else is empty.
- ``_NODE_VAR``: ``name`` holds the variable name (HTML-
  escaped on render); everything else empty.
- ``_NODE_VAR_SAFE``: ``name`` holds the variable name
  (rendered verbatim); everything else empty.
- ``_NODE_IF``: ``name`` is the truthy-test variable;
  ``children`` is the body to render if truthy.
- ``_NODE_FOR``: ``loop_var`` is the per-iteration name,
  ``name`` is the iterable variable, ``children`` is the
  body rendered once per element.
- ``_NODE_BLOCK``: ``name`` is the block name; ``children``
  is the default content. Renderers swap ``children`` for
  a child template's override when the same name is found
  in :attr:`Template.blocks`.

Fields:

- `kind` (`Int`)
- `text` (`String`)
- `name` (`String`)
- `loop_var` (`String`)
- `children` (`List[TemplateNode]`)

Implemented traits: `AnyType`, `Copyable`, `Deinitable`, `Movable`

#### `TemplateNode.__deinit__`

```mojo
def __deinit__(deinit self)
```

### `TemplateContext`

```mojo
struct TemplateContext
```

Variable bag for :func:`Template.render`.

Two flat maps:

- ``strings`` — name → value for ``{{ var }}`` substitution
  and ``{% if var %}`` truthiness.
- ``lists`` — name → ``List[String]`` for ``{% for x in
  var %}`` iteration. A non-empty list is also truthy
  under ``{% if %}``.

Fields:

- `strings` (`Dict[String, String]`)
- `lists` (`Dict[String, List[String]]`)

Implemented traits: `AnyType`, `Copyable`, `Defaultable`, `Deinitable`, `Movable`

#### `TemplateContext.__init__`

```mojo
def __init__(out self)
```

#### `TemplateContext.set`

```mojo
def set(mut self, name: String, value: String)
```

Add or overwrite a string-typed binding.

#### `TemplateContext.set_list`

```mojo
def set_list(mut self, name: String, value: List[String])
```

Add or overwrite a list-typed binding.

### `Template`

```mojo
struct Template
```

Compiled template ready to render against a :class:`TemplateContext`.

Use :func:`Template.compile` to parse source bytes once;
re-render on every request via :func:`Template.render`. The
compile step is O(N) in source length; the render step is
O(M) in output length (one pass over the parsed tree, one
HTML-escape pass per ``{{ var }}``).

Inheritance support:

- ``{% extends "<name>" %}`` as the *first* non-whitespace
  tag marks this template as a child of another. The parsed
  ``extends_target`` field holds the parent's name.
- ``{% block <name> %}...{% endblock %}`` defines a named
  region. The block's body is the default content; child
  templates override it by declaring a same-named block.
- Render with inheritance via :func:`render_extending` --
  pass the parent template alongside the context. The
  renderer walks the parent's tree; each ``_NODE_BLOCK``
  pulls its content from the child's :attr:`blocks` map if
  a matching name exists, otherwise renders the parent's
  default.

Inheritance is single-level: the parent is not itself
expected to extend a grandparent. Transitive extends adds
code without buying enough use-case coverage to justify
the complexity.

Fields:

- `nodes` (`List[TemplateNode]`): Top-level parse tree. Always present even for child templates that ``extend`` -- a child's nodes still contain its own block definitions for resolution against the parent's placeholders.
- `extends_target` (`String`): Name of the parent template if ``{% extends "..." %}`` was present, else the empty string. Look-up is the caller's responsibility (file system, in-memory registry, etc.) -- the engine intentionally has no path resolver.
- `blocks` (`Dict[String, List[TemplateNode]]`): Named-block override map. Populated at compile-time from each ``{% block <name> %}`` encountered. When this template is the *child* in an extends relationship, the renderer consults this map first before falling back to the parent's block defaults.

Implemented traits: `AnyType`, `Copyable`, `Deinitable`, `Movable`

#### `Template.compile`

```mojo
def compile(src: String) raises -> Self
```

Parse ``src`` into a render-ready :class:`Template`.

Raises :class:`TemplateError` (variant indicates which):

- ``UNTERMINATED_VAR`` -- unterminated ``{{...}}``
- ``UNTERMINATED_TAG`` -- unterminated ``{%...%}``
- ``UNMATCHED_END`` -- unmatched ``{% endif %}`` /
  ``{% endfor %}`` / ``{% endblock %}``
- ``EMPTY_VAR`` -- empty variable name in ``{{...}}``
- ``EMPTY_TAG`` -- empty ``{% %}``
- ``UNKNOWN_FILTER`` -- only ``| safe`` is accepted
- ``MALFORMED_IF`` -- wrong operand count
- ``MALFORMED_FOR`` -- ``{% for X in Y %}`` shape violated
- ``MALFORMED_EXTENDS`` -- ``{% extends X %}`` shape
  violated (also raised when ``extends`` is not the
  first non-whitespace tag).
- ``UNKNOWN_TAG`` -- unrecognised tag head

#### `Template.render`

```mojo
def render(self, mut ctx: TemplateContext) raises -> String
```

Walk the parsed tree against ``ctx``, returning the rendered output as a ``String``.

``ctx`` is taken by mutable borrow because the renderer
scratches the strings map for ``{% for %}`` loop-variable
shadowing and restoration. After ``render`` returns,
``ctx`` is left exactly as it was before the call.

For child templates that ``{% extends %}`` a parent,
use :func:`render_extending` instead -- a child rendered
through this method emits its block defaults only, the
parent's surrounding markup is *not* consulted.

Raises :class:`TemplateError` (variant indicates which):

- ``UNBOUND_VARIABLE`` -- ``{{ name }}`` for a name not
  in ``ctx.strings``.
- ``UNBOUND_ITERABLE`` -- ``{% for x in name %}`` for a
  name not in ``ctx.lists``.
- ``UNKNOWN_NODE`` -- internal: parsed tree contained a
  node kind the renderer doesn't handle.

#### `Template.render_extending`

```mojo
def render_extending(self, mut ctx: TemplateContext, parent: Self) raises -> String
```

Render this child template against the parent's surrounding markup. The renderer walks ``parent.nodes``; each ``{% block X %}`` placeholder is satisfied by ``self.blocks[X]`` when present, otherwise by the parent's default content.

Args:

- `ctx`: Template variable bag (mutable borrow; restored across loop / block frames).
- `parent`: The compiled parent template. Typically loaded by name via the caller's registry; the engine has no built-in resolver.

Returns: The rendered output.

Raises: TemplateError: Same conditions as :func:`render`.

## Functions

### `html_escape`

```mojo
def html_escape(s: String) -> String
```

Escape ``s`` for safe inclusion in HTML body text or attribute values, per OWASP XSS Prevention Cheat Sheet rule #1 (body) + rule #2 (attribute). Replaces the five HTML-significant bytes.

- ``&`` → ``&amp;``
- ``<`` → ``&lt;``
- ``>`` → ``&gt;``
- ``"`` → ``&quot;``
- ``'`` → ``&#x27;``
