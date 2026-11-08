# `dodo.json.value.value`

## Structs

### `Null`

```mojo
struct Null
```

Represents JSON null.

Implemented traits: `AnyType`, `Deinitable`, `Movable`, `Writable`

#### `Null.__init__`

```mojo
def __init__(out self)
```

#### `Null.__str__`

```mojo
def __str__(self) -> String
```

#### `Null.write_to`

```mojo
def write_to[W: Writer](self, mut writer: W)
```

### `Value`

```mojo
struct Value
```

A JSON value.

Holds either a tape-backed view over a shared `Document` (what the
parsers produce) or an owned mutable tree (what the constructors and
factories produce, and what a parsed value becomes on first
mutation). See the module header for why both exist; callers use the
same API either way.

The type behaves the way a caller who has met a JSON value in any
other language expects it to: `len` counts elements or members,
`in` tests membership, `==` is a structural deep comparison, a
value may key a `Dict`, an array iterates, and an object hands back
`items()` / `keys()` / `values()`. `Iterable` conformance is the one
thing missing: the trait requires an iterator alias parameterized
over the iterable's origin in a shape this compiler cannot spell for
a type whose iterator must also carry a mode, so `__iter__` is
defined directly instead. A `for` loop over a `Value` works either
way, because the loop resolves `__iter__` rather than the trait.

Implemented traits: `AnyType`, `Boolable`, `Copyable`, `Deinitable`, `Equatable`, `Hashable`, `Movable`, `SizedRaising`, `Writable`

#### `Value.__init__`

```mojo
def __init__(out self, doc: ArcPointer[Document], tape_idx: Int)
```

Tape-backed view over `doc[].tape[tape_idx]`.

The parser entry point: `make_view_value` and `_make_view_child`
both land here, sharing one `ArcPointer` across every view into
the same document.

```mojo
def __init__(out self, var owned: OwnedValue)
```

Owned-tree value. Takes ownership; no document is built.

```mojo
def __init__(out self, null: Null)
```

```mojo
def __init__(out self, none: NoneType)
```

```mojo
def __init__(out self, b: Bool)
```

```mojo
def __init__(out self, i: Int)
```

```mojo
def __init__(out self, i: Int64)
```

```mojo
def __init__(out self, f: Float64)
```

```mojo
def __init__(out self, var s: String)
```

```mojo
def __init__(out self, u: UInt64)
```

A JSON integer whose magnitude may exceed `Int64.MAX`.

The unsigned range was readable through `is_uint` / `uint_value`
from the day the parser learned to keep it, but no constructor
reached it, so a caller could observe a big integer coming out
of a document and had no way to put an equal one back in.

```mojo
def __init__(out self, i: Int8)
```

A JSON integer widened from a narrower signed type.

JSON has one number type, so a caller holding an `Int8` from
elsewhere in a program should not have to widen it by hand
before it can become a `Value`.

```mojo
def __init__(out self, i: Int16)
```

A JSON integer widened from `Int16`. See `Value(Int8)`.

```mojo
def __init__(out self, i: Int32)
```

A JSON integer widened from `Int32`. See `Value(Int8)`.

```mojo
def __init__(out self, u: UInt8)
```

A JSON integer widened from `UInt8`. See `Value(Int8)`.

```mojo
def __init__(out self, u: UInt16)
```

A JSON integer widened from `UInt16`. See `Value(Int8)`.

```mojo
def __init__(out self, u: UInt32)
```

A JSON integer widened from `UInt32`. See `Value(Int8)`.

Widened into the signed range rather than the unsigned one,
because every `UInt32` fits `Int64` exactly and a value that
answers `is_int` is the one nearly every caller reaches for.

```mojo
def __init__(out self, f: Float32)
```

A JSON number widened from `Float32`.

The widening is the plain one, so a `Float32` that cannot name
its decimal literal exactly keeps the error it already had
rather than gaining a different one.

```mojo
def __init__(out self, var items: List[Self]) raises
```

A JSON array holding `items`, in order.

Takes the list a caller already has and moves each element's
subtree in, so nothing is deep-copied on the way.

Example:

```mojo
var a = Value([Value(1), Value(2), Value(3)]).
```

```mojo
def __init__(out self, var members: Dict[String, Self]) raises
```

A JSON object holding `members`.

Member order follows the `Dict`'s own iteration order, which it
does not promise to be insertion order. Build with
`Value.object()` plus `set` when the emitted order matters, or
serialize with `sort_keys=True`.

Example:

```mojo
var d = Dict[String, Value]()
d["a"] = Value(1)
var o = Value(d^).
```

#### `Value.__bool__`

```mojo
def __bool__(self) -> Bool
```

Whether this value is truthy, the way JSON callers read JSON.

Follows the rule every dynamic language that speaks JSON
settled on: null is false, a boolean is itself, a number is
false only at zero, and a string, array or object is false only
when empty. That makes `if doc["items"]:` mean "there are
items", which is the test callers actually want to write.

Note this is not `is_null()` inverted: a present-but-empty
array is false here and not null.

#### `Value.__getitem__`

```mojo
def __getitem__(self, index: Int) raises -> Self
```

Get array element by index.

A negative index counts back from the end, so `arr[-1]` is the
last element, matching `List`.

Example:

```mojo
var arr = loads('[1, 2, 3]')
print(arr[0])   # Prints 1.
print(arr[-1])  # Prints 3.
```

Args:

- `index`: Array index. Negative counts from the end.

Returns: The Value at the given index.

```mojo
def __getitem__(self, key: String) raises -> Self
```

Get object value by key.

Example:

```mojo
var obj = loads('{"name": "Alice"}')
print(obj["name"])  # Prints "Alice".
```

Args:

- `key`: Object key.

Returns: The Value for the given key.

#### `Value.__setitem__`

```mojo
def __setitem__(mut self, key: String, var value: Self) raises
```

`obj["k"] = v`, the subscript spelling of `set(key, value)`.

Assignment is how a mapping is written to in every language
this API is read from, and there was no reason for a type whose
reads are already subscripts to make its writes a method call.
Consumes the value, so the common `obj["k"] = Value(1)` moves
the subtree in rather than copying it.

Args:

- `key`: Object key.
- `value`: New value to install.

Raises: Error: If this value is not a JSON object.

```mojo
def __setitem__(mut self, index: Int, var value: Self) raises
```

`arr[0] = v`, the subscript spelling of `set(index, value)`.

A negative index counts back from the end, matching
`__getitem__`. Only replaces an existing element; use `append`
to grow the array.

Args:

- `index`: Array index. Negative counts from the end.
- `value`: New value to install.

Raises: Error: If this value is not an array, or `index` names no element.

#### `Value.__eq__`

```mojo
def __eq__(self, other: Self) -> Bool
```

Structural deep equality, as JSON defines sameness.

Two values are equal when they are the same JSON, not when
they serialize to the same text. That distinction is the whole
point: an object's members carry no order, so `{"a":1,"b":2}`
and `{"b":2,"a":1}` are one value spelled two ways, and a JSON
number has no type, so `1` and `1.0` are one number spelled two
ways. Comparing text answered no to both, which made `==`
unusable for exactly the job callers reached for it to do.

Numbers are compared in the widest domain that holds them
exactly rather than by widening everything to `Float64`, so two
integers beyond the range a `Float64` can name apart stay
apart. A float equals an integer only when it is integral and
converts back to that integer exactly, which is also what keeps
`__hash__` in step with this.

Walks the two representations directly instead of materializing
either side, so comparing two parsed documents allocates
nothing beyond the strings it has to read out of the pools.

#### `Value.__ne__`

```mojo
def __ne__(self, other: Self) -> Bool
```

#### `Value.__contains__`

```mojo
def __contains__(self, key: String) -> Bool
```

Whether an object has a member named `key`.

For an array this asks whether some element is that string, so
`"a" in loads('["a"]')` is true; the two readings cannot
collide, because an array has no members and an object's
members are named by strings rather than held as them.
Anything else contains nothing and answers false rather than
raising, matching what `in` does in the languages this spelling
comes from.

```mojo
def __contains__(self, needle: Int) -> Bool
```

Whether an array holds `needle`, so `3 in arr` reads directly.

Present as its own overload because an integer literal does not
become a `Value` on its own, and `Value(3) in arr` is a worse
thing to have to write than the test it performs.

```mojo
def __contains__(self, needle: Self) -> Bool
```

Whether an array holds an element structurally equal to `needle`.

Equality is `Value.__eq__`, so member order inside a candidate
element does not matter and `Value(1)` finds a `1.0`. For an
object this tests the member values rather than the names,
since the names are strings and the `String` overload already
answers those. Anything else answers false.

#### `Value.object`

```mojo
def object() -> Self
```

An empty JSON object, ready to `set` into.

Allocation-free, and the intended way to build an object from
scratch.

Example:

```mojo
var o = Value.object()
o.set("name", Value("Ada"))
```

#### `Value.array`

```mojo
def array() -> Self
```

An empty JSON array, ready to `append` into.

Allocation-free. See `object()`.

Example:

```mojo
var a = Value.array()
a.append(Value(1))
```

#### `Value.copy`

```mojo
def copy(self) -> Self
```

Create a copy of this Value.

A tape view copies for free -- the document lives behind an
`ArcPointer`, so this is a refcount bump plus the tape index. An
owned tree is deep-copied, giving the copy independent value
semantics.

Returns: A new Value with the same content.

#### `Value.clone`

```mojo
def clone(self) -> Self
```

Alias for copy(). Creates a deep copy of this Value.

Returns: A new Value with the same content.

#### `Value.type_name`

```mojo
def type_name(self) -> String
```

The JSON type of this value, spelled as JSON spells it.

Exists so the raising accessors can say what they found rather
than only what they wanted, which is the difference between an
error a caller can act on and one that sends them back to the
document with a print statement.

#### `Value.is_null`

```mojo
def is_null(self) -> Bool
```

#### `Value.is_bool`

```mojo
def is_bool(self) -> Bool
```

#### `Value.is_int`

```mojo
def is_int(self) -> Bool
```

A signed integer that fits `Int64`.

A magnitude above `Int64.MAX` answers `is_uint` instead, so
that a caller reaching for `int_value` cannot be handed a
wrapped negative number by accident.

#### `Value.is_uint`

```mojo
def is_uint(self) -> Bool
```

An integer above `Int64.MAX`, readable through `uint_value`.

#### `Value.is_float`

```mojo
def is_float(self) -> Bool
```

#### `Value.is_string`

```mojo
def is_string(self) -> Bool
```

#### `Value.is_array`

```mojo
def is_array(self) -> Bool
```

#### `Value.is_object`

```mojo
def is_object(self) -> Bool
```

#### `Value.is_number`

```mojo
def is_number(self) -> Bool
```

#### `Value.bool_value`

```mojo
def bool_value(self) -> Bool
```

#### `Value.int_value`

```mojo
def int_value(self) -> Int64
```

#### `Value.uint_value`

```mojo
def uint_value(self) -> UInt64
```

The value as an unsigned magnitude.

Accepts any integer entry, so a caller that has checked
`is_number` and wants the widest reading does not have to test
the tag first.

#### `Value.float_value`

```mojo
def float_value(self) -> Float64
```

#### `Value.string_value`

```mojo
def string_value(self) -> String
```

#### `Value.as_bool`

```mojo
def as_bool(self) raises -> Bool
```

This value as a boolean, or an error naming what it is.

Returns: The boolean this value holds.

Raises: Error: If this value is not a JSON boolean.

#### `Value.as_int`

```mojo
def as_int(self) raises -> Int64
```

This value as a signed integer, or an error naming what it is.

An integer too large for `Int64` answers `is_uint` rather than
`is_int`, so it is rejected here instead of being handed back
wrapped into a negative number. Reach for `as_uint` for those.

Returns: The integer this value holds.

Raises: Error: If this value is not a signed JSON integer.

#### `Value.as_uint`

```mojo
def as_uint(self) raises -> UInt64
```

This value as an unsigned integer, or an error naming what it is.

Accepts either integer tag, because a caller asking for the
unsigned reading of `1` means the same thing whichever range
the parser happened to store it in. A negative integer is
rejected rather than wrapped.

Returns: The integer this value holds, as an unsigned magnitude.

Raises: Error: If this value is not a JSON integer, or is negative.

#### `Value.as_float`

```mojo
def as_float(self) raises -> Float64
```

This value as a float, or an error naming what it is.

Accepts any JSON number, not only one that was spelled with a
decimal point. JSON has a single number type, so whether `1` or
`1.0` reached the parser is a fact about the text rather than
about the value, and a caller asking for a float would
otherwise have to test three tags before reading a field that
is a number in every document they will ever see.

Returns: The number this value holds, widened to `Float64`.

Raises: Error: If this value is not a JSON number.

#### `Value.as_string`

```mojo
def as_string(self) raises -> String
```

This value as a string, or an error naming what it is.

Does not stringify a number or a boolean. A caller who wants
the JSON text of any value already has `to_json()`, and
silently accepting `42` here is what turns a mistyped field
into a bug two layers away.

Returns: The string this value holds, unescaped.

Raises: Error: If this value is not a JSON string.

#### `Value.bool_or`

```mojo
def bool_or(self, default: Bool) -> Bool
```

The boolean this value holds, or `default` if it holds none.

#### `Value.int_or`

```mojo
def int_or(self, default: Int64) -> Int64
```

The signed integer this value holds, or `default` otherwise.

#### `Value.uint_or`

```mojo
def uint_or(self, default: UInt64) -> UInt64
```

The unsigned integer this value holds, or `default` otherwise.

Matches `as_uint`: either integer tag is accepted, and a
negative integer falls back rather than wrapping.

#### `Value.float_or`

```mojo
def float_or(self, default: Float64) -> Float64
```

The number this value holds as a float, or `default` otherwise.

Matches `as_float`: any JSON number is accepted.

#### `Value.string_or`

```mojo
def string_or(self, default: String) -> String
```

The string this value holds, or `default` if it holds none.

#### `Value.raw_json`

```mojo
def raw_json(self) -> String
```

#### `Value.pretty_json`

```mojo
def pretty_json(self, indent: String) -> String
```

This value as indented JSON.

One structural walk with an indent-aware writer, rather than
serializing compactly and re-scanning the text.

#### `Value.to_json`

```mojo
def to_json(self, *, indent: String = String(), ascii_only: Bool = False, escape_solidus: Bool = False, sort_keys: Bool = False) -> String
```

This value as JSON, with serializer options applied.

See `_to_json`. The two escaping options are parameters so the
walk that does not use them carries no check for them.

Args:

- `indent`: One level of indentation. Empty means compact.
- `ascii_only`: Escape every code point above U+007F.
- `escape_solidus`: Escape `/` as `\/`.
- `sort_keys`: Emit object members ordered by key.

#### `Value.array_count`

```mojo
def array_count(self) -> Int
```

#### `Value.object_keys`

```mojo
def object_keys(self) -> List[String]
```

#### `Value.object_count`

```mojo
def object_count(self) -> Int
```

#### `Value.__str__`

```mojo
def __str__(self) -> String
```

#### `Value.write_to`

```mojo
def write_to[W: Writer](self, mut writer: W)
```

#### `Value.__hash__`

```mojo
def __hash__[H: Hasher](self, mut hasher: H)
```

Feed this value's digest to `hasher`.

The `Hashable` requirement, and the reason a `Value` may key a
`Dict`. The digest itself is `hash_u64`, which is where the
agreement with `__eq__` is worked out; this hands the finished
number to whichever hasher the collection chose.

Parameters:

- `H`: The hasher type the collection is using.

Args:

- `hasher`: The hasher to update.

#### `Value.hash_u64`

```mojo
def hash_u64(self) -> UInt64
```

A hash that agrees with `__eq__`, so a `Value` can key a `Dict`.

Agreement is the whole constraint, and it is what dictates the
two unobvious choices here. An object's members carry no order,
so its members' hashes are combined with an operation that does
not care about order; anything order-sensitive would hash
`{"a":1,"b":2}` and `{"b":2,"a":1}` into different buckets after
`__eq__` has just called them equal. And a number is hashed by
its value rather than by its tag or its bits, so `1`, `1.0` and
the same magnitude read out of the unsigned range all land
together.

Hashing a container walks it, so it costs what the subtree
costs. Key a `Dict` by a scalar where you can.

#### `Value.__len__`

```mojo
def __len__(self) raises -> Int
```

The number of things this value contains.

An array answers its element count and an object its member
count, which is what `len` means everywhere a JSON value is
used. A string answers its length in bytes, matching
`String.byte_length()` rather than a count of code points,
because that is the number the rest of this library measures a
string in.

A null, a boolean and a number contain nothing, and they raise
rather than answering 0. Answering 0 would make `len(v) == 0`
mean two different things, and a caller reaching for `len` on a
number has usually reached for the wrong field. Use
`is_array()` / `is_object()` first if the shape is genuinely
not known.

Returns: Element count, member count, or the string's byte length.

Raises: Error: If this value is a null, a boolean or a number.

#### `Value.get`

```mojo
def get(self, key: String) raises -> Optional[Self]
```

The member named `key`, or `None` when there is no such member.

For the member's raw JSON text, use `raw_member(key)`.

A value that is not an object still raises, matching
`__getitem__`. Only the absent key is answered with `None`,
because "this document has no such field" is data and "I called
a member lookup on an array" is a bug.

Example:

```mojo
var data = loads('{"name":"Alice"}')
var name = data.get("name")
if name:
    print(name.value().string_value()).
```

Args:

- `key`: The member name to look for.

Returns: The member's value, or `None` if the object has no such member.

Raises: Error: If this value is not a JSON object.

```mojo
def get(self, key: String, default: Self) raises -> Self
```

The member named `key`, or `default` when there is no such member.

The two-argument form of `get`, for the common shape where the
caller has a fallback ready and does not want to unwrap an
`Optional` to use it.

Example:

```mojo
var port = config.get("port", Value(8080)).
```

Args:

- `key`: The member name to look for.
- `default`: The value to return when the member is absent.

Returns: The member's value, or `default`.

Raises: Error: If this value is not a JSON object.

#### `Value.raw_member`

```mojo
def raw_member(self, key: String) raises -> String
```

The member named `key`, serialized back to JSON text.

This is a serialization, not a lookup: reading a member
this way and parsing the result costs a full round trip, so
prefer `get` / `__getitem__` and the typed accessors unless the
JSON text itself is what you want.

Args:

- `key`: The member name to extract.

Returns: The member's value as JSON text.

Raises: Error: If this value is not an object, or has no such member.

#### `Value.array_items`

```mojo
def array_items(self) raises -> List[Self]
```

Every element of a JSON array, as a `List`.

Prefer iterating the value itself. This builds the whole list
before the loop body runs once, so a loop that stops early has
already paid for every element it will not look at, and a large
array costs a second copy of itself. `for item in data:` walks
the same elements one at a time. Kept because it predates the
iterator and callers hold its result.

Example:

```mojo
var data = loads('[1, "hello", true]')
for item in data.array_items():
    print(item).
```

Returns: List of Value objects representing array elements.

Raises: Error if not an array.

#### `Value.object_items`

```mojo
def object_items(self) raises -> List[Tuple[String, Self]]
```

Every member of a JSON object, as a `List` of pairs.

Prefer `items()`. This builds the whole list, with a copy of
every key and every member subtree, before the loop body runs
once; `items()` yields one pair at a time. Kept because it
predates the iterator and callers hold its result.

Example:

```mojo
var data = loads('{"a": 1, "b": 2}')
for pair in data.object_items():
    var key = pair[0]
    var value = pair[1]
    print(key, value).
```

Returns: List of (key, value) tuples.

Raises: Error if not an object.

#### `Value.set`

```mojo
def set(mut self, key: String, value: Self) raises
```

Set or update a value in a JSON object.

Routes through `OwnedValue` so the in-memory tree stays the
source of truth for the mutation, and every read API on *this*
value observes it immediately.

The mutation is local to the value it is called on. `__getitem__`
hands back an independent value rather than a handle into its
parent, so `doc["a"].set("b", v)` edits a child that `doc` no
longer shares and `doc` is unchanged. To write through a parent
chain, name the destination with a JSON Pointer:
`doc.set_at("/a/b", v)`.

Example:

```mojo
var obj = loads('{"name": "Alice"}')
obj.set("age", Value(30))
obj.set("name", Value("Bob"))  # Update existing.
```

Args:

- `key`: Object key.
- `value`: New value to set.

```mojo
def set(mut self, var key: String, var value: Self) raises
```

`set` that consumes its arguments.

Selected automatically when the value is a temporary -- the
common `o.set("k", Value(1))` shape -- so the subtree is moved
in rather than deep-copied. Mojo resolves this against the
borrowed overload above by argument convention; existing callers
passing a named variable keep the copying behaviour and their
value stays usable.

```mojo
def set(mut self, index: Int, value: Self) raises
```

Set a value at an array index.

A negative index counts back from the end, as it does for
`__getitem__`, so `arr.set(-1, v)` replaces the last element.

Example:

```mojo
var arr = loads('[1, 2, 3]')
arr.set(1, Value(20))  # Result is `[1, 20, 3]`.
```

Args:

- `index`: Array index. Negative counts from the end.
- `value`: New value to set.

```mojo
def set(mut self, index: Int, var value: Self) raises
```

`set(index, ...)` that consumes its value. See `set(key, ...)`.

#### `Value.remove`

```mojo
def remove(mut self, key: String) raises
```

Remove the member named `key` from an object.

The counterpart to `set`.

Args:

- `key`: The member name to remove.

Raises: Error: If this value is not an object, or has no such member. Use `pop(key, default)` shaped code, or test with `key in obj`, when absence is expected.

```mojo
def remove(mut self, index: Int) raises
```

Remove element `index` from an array, shifting the rest down.

A negative index counts back from the end, matching
`__getitem__`.

Args:

- `index`: Array index. Negative counts from the end.

Raises: Error: If this value is not an array, or `index` names no element.

#### `Value.pop`

```mojo
def pop(mut self, key: String) raises -> Self
```

Remove the member named `key` and return its value.

`remove` when the removed value is not wanted, `pop` when it
is. The value is moved out of the tree rather than copied, so
popping a large subtree costs no more than popping a scalar.

Args:

- `key`: The member name to remove.

Returns: The value that was stored under `key`.

Raises: Error: If this value is not an object, or has no such member.

```mojo
def pop(mut self, index: Int) raises -> Self
```

Remove element `index` from an array and return it.

A negative index counts back from the end, so `arr.pop(-1)`
takes the last element.

Args:

- `index`: Array index. Negative counts from the end.

Returns: The element that was stored at `index`.

Raises: Error: If this value is not an array, or `index` names no element.

```mojo
def pop(mut self) raises -> Self
```

Remove the last element of an array and return it.

The no-argument form, so using an array as a stack does not
need the length computed at the call site.

Returns: The element that was last in the array.

Raises: Error: If this value is not an array, or the array is empty.

#### `Value.__iter__`

```mojo
def __iter__(ref self) raises -> ValueArrayIter[origin_of(self)]
```

Iterate an array's elements, one at a time.

Lazy, unlike `array_items()`: nothing is built ahead of the
loop, so a loop that stops at the first match pays for what it
looked at and no more. The iterator borrows this value, so the
value has to outlive the loop, which for the usual
`for item in doc["items"]:` it does.

Example:

```mojo
var data = loads('[1, 2, 3]')
for item in data:
    print(item.int_value()).
```

Returns: An iterator over the array's elements.

Raises: Error: If this value is not a JSON array. Iterating an object is ambiguous enough that it is spelled out: `items()`, `keys()` or `values()`.

#### `Value.items`

```mojo
def items(ref self) raises -> ValueItemsIter[origin_of(self)]
```

Iterate an object's members as `(key, value)` pairs.

The lazy counterpart to `object_items()`, which copies every
key and every member subtree before the loop starts. Members
come back in the order the object holds them, which for a
parsed document is document order.

Example:

```mojo
var data = loads('{"a": 1, "b": 2}')
for pair in data.items():
    print(pair[0], pair[1]).
```

Returns: An iterator over `(key, value)` pairs.

Raises: Error: If this value is not a JSON object.

#### `Value.keys`

```mojo
def keys(ref self) raises -> ValueKeysIter[origin_of(self)]
```

Iterate an object's member names.

The lazy counterpart to `object_keys()`, which materializes a
`List[String]`. Prefer this when the loop only reads the names.

Returns: An iterator over the object's member names.

Raises: Error: If this value is not a JSON object.

#### `Value.values`

```mojo
def values(ref self) raises -> ValueValuesIter[origin_of(self)]
```

Iterate an object's member values, without their names.

Returns: An iterator over the object's member values.

Raises: Error: If this value is not a JSON object.

#### `Value.append`

```mojo
def append(mut self, value: Self) raises
```

Append a value to a JSON array.

Example:

```mojo
var arr = loads('[1, 2]')
arr.append(Value(3))  # Result is `[1, 2, 3]`.
```

Args:

- `value`: Value to append.

```mojo
def append(mut self, var value: Self) raises
```

`append` that consumes its value.

This is the one that matters for building: appending a freshly
built element into a growing array does not deep-copy the
element's subtree.

#### `Value.set_at`

```mojo
def set_at(mut self, pointer: String, value: Self) raises
```

Set a nested value via JSON Pointer (RFC 6901).

Unlike chained `__getitem__`, this propagates the mutation through the
full parent chain. Intermediate objects/arrays are created or updated
as required by the pointer; missing scalar parents raise.

Example:

```mojo
var doc = loads('{"a":{"b":1}}')
doc.set_at("/a/b", Value(42))  # Result is `{"a":{"b":42}}`.
```

Args:

- `pointer`: JSON Pointer string (`""` for root, `"/a/b"` for nested).
- `value`: New value to install at `pointer`.

```mojo
def set_at(mut self, pointer: String, var value: Self) raises
```

`set_at` that consumes its value. See `set(key, ...)`.

#### `Value.at`

```mojo
def at(self, pointer: String) raises -> Self
```

Navigate to a value using JSON Pointer (RFC 6901).

JSON Pointer syntax:

```mojo
"" (empty) = the whole document.
"/foo" = member "foo" of object.
"/foo/0" = first element of array "foo".
"/a~1b" = member "a/b" (/ escaped as ~1).
"/m~0n" = member "m~n" (~ escaped as ~0).
```

Example:

```mojo
var data = loads('{"users":[{"name":"Alice"}]}')
var name = data.at("/users/0/name")  # `Value("Alice")`.
```

Args:

- `pointer`: JSON Pointer string (e.g., "/users/0/name").

Returns: The Value at the pointer location.

Raises: Error if pointer is invalid or path doesn't exist.

#### `Value.try_at`

```mojo
def try_at(self, pointer: String) raises -> Optional[Self]
```

The value at `pointer`, or `None` if nothing is there.

The twin of `at`, for the case `at` handles badly: probing a
document for a field that may or may not be present. `at`
raises on the first missing segment, so probing meant wrapping
the call in `try`, which also swallows the errors worth
hearing about.

A pointer that is not a well-formed JSON Pointer still raises,
because that is a mistake in the program rather than a fact
about the document. Only a segment that names nothing, or one
that tries to descend into a scalar, answers `None`.

Example:

```mojo
var data = loads('{"a":{"b":1}}')
var hit = data.try_at("/a/b")     # `Some(Value(1))`.
var miss = data.try_at("/a/zz")   # `None`.
```

Args:

- `pointer`: JSON Pointer string. `""` names the whole value.

Returns: The value at the pointer location, or `None`.

Raises: Error: If `pointer` is not a well-formed JSON Pointer.

### `ValueArrayIter`

```mojo
struct ValueArrayIter[mut: Bool, //, origin: Origin[mut=mut]]
```

Yields the elements of a JSON array, one at a time.

Built by `Value.__iter__`, so `for item in arr:` reaches it.

Implemented traits: `AnyType`, `Copyable`, `Deinitable`, `Iterator`, `Movable`

Aliases:

- `Element = Value`

#### `ValueArrayIter.__init__`

```mojo
def __init__(out self, ref[origin] src: Value)
```

Start at the first element of `src`.

#### `ValueArrayIter.__iter__`

```mojo
def __iter__(self) -> Self
```

An iterator is its own iterable.

Present so `for pair in obj.items():` reaches the loop
protocol directly, the way a `for` loop over any other
iterator does.

#### `ValueArrayIter.__has_next__`

```mojo
def __has_next__(self) -> Bool
```

Whether any element remains.

#### `ValueArrayIter.__next__`

```mojo
def __next__(mut self) -> Value
```

The next element.

### `ValueItemsIter`

```mojo
struct ValueItemsIter[mut: Bool, //, origin: Origin[mut=mut]]
```

Yields an object's members as `(key, value)` pairs.

Built by `Value.items()`.

Implemented traits: `AnyType`, `Copyable`, `Deinitable`, `Iterator`, `Movable`

Aliases:

- `Element = Tuple[String, Value]`

#### `ValueItemsIter.__init__`

```mojo
def __init__(out self, ref[origin] src: Value)
```

Start at the first member of `src`.

#### `ValueItemsIter.__iter__`

```mojo
def __iter__(self) -> Self
```

An iterator is its own iterable.

Present so `for pair in obj.items():` reaches the loop
protocol directly, the way a `for` loop over any other
iterator does.

#### `ValueItemsIter.__has_next__`

```mojo
def __has_next__(self) -> Bool
```

Whether any member remains.

#### `ValueItemsIter.__next__`

```mojo
def __next__(mut self) -> Tuple[String, Value]
```

The next `(key, value)` pair.

### `ValueKeysIter`

```mojo
struct ValueKeysIter[mut: Bool, //, origin: Origin[mut=mut]]
```

Yields an object's member names. Built by `Value.keys()`.

Implemented traits: `AnyType`, `Copyable`, `Deinitable`, `Iterator`, `Movable`

Aliases:

- `Element = String`

#### `ValueKeysIter.__init__`

```mojo
def __init__(out self, ref[origin] src: Value)
```

Start at the first member of `src`.

#### `ValueKeysIter.__iter__`

```mojo
def __iter__(self) -> Self
```

An iterator is its own iterable.

Present so `for pair in obj.items():` reaches the loop
protocol directly, the way a `for` loop over any other
iterator does.

#### `ValueKeysIter.__has_next__`

```mojo
def __has_next__(self) -> Bool
```

Whether any member remains.

#### `ValueKeysIter.__next__`

```mojo
def __next__(mut self) -> String
```

The next member name.

### `ValueValuesIter`

```mojo
struct ValueValuesIter[mut: Bool, //, origin: Origin[mut=mut]]
```

Yields an object's member values. Built by `Value.values()`.

Implemented traits: `AnyType`, `Copyable`, `Deinitable`, `Iterator`, `Movable`

Aliases:

- `Element = Value`

#### `ValueValuesIter.__init__`

```mojo
def __init__(out self, ref[origin] src: Value)
```

Start at the first member of `src`.

#### `ValueValuesIter.__iter__`

```mojo
def __iter__(self) -> Self
```

An iterator is its own iterable.

Present so `for pair in obj.items():` reaches the loop
protocol directly, the way a `for` loop over any other
iterator does.

#### `ValueValuesIter.__has_next__`

```mojo
def __has_next__(self) -> Bool
```

Whether any member remains.

#### `ValueValuesIter.__next__`

```mojo
def __next__(mut self) -> Value
```

The next member value.

## Functions

### `make_view_value`

```mojo
def make_view_value(doc: ArcPointer[Document], tape_idx: Int) -> Value
```

Build a tape-backed `Value` view over `doc[].tape[tape_idx]`.

Thin wrapper around the `Value(doc, tape_idx)` primary
constructor. Kept as a free function so callers don't need to
spell out the type, and so the construction site reads as
"make a view" rather than "build a Value".

### `write_value`

```mojo
def write_value(mut w: JsonWriter, v: Value)
```

Emit `v` into an existing writer.

The point is the writer: a caller already building a document can
splice a `Value` into it without the value first becoming its own
`String` and then being copied in.
