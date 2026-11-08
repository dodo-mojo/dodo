# Mojo closure declarations reference

*From Modular's Mojo docs (`Mojo/docs/site/reference/closure-declarations.mdx` at tag `mojo/v1.2.0`, Apache-2.0 with LLVM Exceptions, see `LICENSE.txt`), turned into plain Markdown by dodo.*

A *closure* is a nested function with a *capture list* that controls how
it accesses values from the scope it's nested in:

```mojo
def main():
    var multiplier = 3

    def scale(x: Int) {imm multiplier} -> Int:
        return x * multiplier

    print(scale(5))  # 15
```

`{imm multiplier}` references `multiplier` from the enclosing scope as an
immutable reference. Without the capture list, referencing any outer value
is a compile error.

A closure can't outlive the scope where it's declared.
Mojo doesn't support escaping closures or async execution.

**Note**
A closure is Copyable when every value it captures is Copyable. A closure
can be copied manually into heap-allocated memory, but Mojo doesn't provide
a built-in mechanism for heap-allocated or existential closures.

## Closure syntax

```text
def name(argument-list) {capture-list} -> ReturnType:
    body

def name[parameter-list](argument-list) {capture-list}
    -> ReturnType:
    body

def name(argument-list) raises {capture-list} -> ReturnType:
    body
```

Effects (for example, `raises`) go between the argument list and
the capture list. The capture list appears immediately before the
return arrow. It can be empty (`{}`) or omitted entirely; both forms
prohibit references to outer values.

The argument list, parameter list, effects, return type, and `where`
clauses follow the same rules as top-level functions. See
[Function declarations](../reference/function-declarations.md).

## Capture list grammar

A capture list is a brace-enclosed, comma-separated sequence of
*entries*:

| Form           | Meaning                                           |
|----------------|---------------------------------------------------|
| `<conv> name`  | Capture `name` with convention `<conv>`           |
| `<conv>`       | Default convention for all free variables         |
| `name`         | Capture `name` with convention `imm`              |
| `<conv> name^` | Transfer-capture (only with `var` or no `<conv>`) |

`<conv>` is one of `imm`, `mut`, `var`, or `ref`. Position within
the list isn't significant: `{mut, var z}` and `{var z, mut}` are
equivalent. Trailing commas are accepted.

At most one entry can omit a name (the default-convention entry). A second
unnamed entry produces an error, naming the default capture convention
duplication.

You may only use the `^` marker on `var` entries or entries with no
convention keyword.

## Capture conventions

| Convention | Form                     | Storage in closure                | Lifetime tie to outer |
|------------|--------------------------|-----------------------------------|-----------------------|
| `imm`      | `{imm name}` / `{imm}`   | Immutable reference               | Live                  |
| `mut`      | `{mut name}` / `{mut}`   | Mutable reference                 | Live                  |
| `ref`      | `{ref name}` / `{ref}`   | Reference, mutability from origin | Live                  |
| `var`      | `{var name}` / `{var}`   | Owned copy                        | Independent           |
| Transfer   | `{var name^}`            | Owned, consumed from outer        | Consumes outer        |
| Copyable   | `{var^}`                 | Owned, closure is `Copyable`      | Independent           |

## `imm`

Immutable reference. The default convention. The closure reads the outer
value each time it's called, rather than capturing a copy:

```mojo
def main():
    var limit = 10

    def check(x: Int) {imm limit} -> Bool:
        return x < limit

    print(check(5))   # True
    limit = 3
    print(check(5))   # False
```

`{imm}` with no variable name applies `imm` to every free variable in the
body. A bare name without a convention keyword also defaults to `imm`:
`{x}` is equivalent to `{imm x}`.

## `mut`

Mutable reference. Writing to a captured value inside the closure modifies
its binding in the outer scope:

```mojo
def main():
    var total = 0

    def accumulate(x: Int) {mut total}:
        total += x

    accumulate(10)
    accumulate(20)
    print(total)  # 30
```

`{mut}` with no variable name applies `mut` to every free variable in the
body, capturing each one by mutable reference.

## `var`

Owned copy. The closure receives its own copy of the value when the closure
is declared. Later changes to the outer binding don't affect the closure's
copy, and vice versa:

```mojo
def main():
    var snapshot = 42

    def frozen() {var snapshot} -> Int:
        return snapshot

    snapshot = 999
    print(frozen())  # 42
```

`{var}` with no variable name copies every free variable referenced in the
closure body. The copy initializer runs once per closure declaration.

Capturing a large `List` or `String` by `var` allocates at that point. Use
`imm` or `mut` when an independent copy isn't needed.

## Transfer capture: `var name^`

Transfers ownership of `name` into the closure. The outer binding is
consumed; using it after the closure declaration is a compile error:

```mojo
def main():
    var data: List[Int] = [1, 2, 3]

    def take_data() {var data^}:
        print(data)

    take_data()      # [1, 2, 3]
    # print(data)    # error: 'data' is uninitialized
                     #        after transfer
```

Move capture skips the copy that `var name` would perform.

Constraints:

- Only legal after `var` or after a bare name with no convention.
- `{imm name^}`, `{mut name^}`, and `{ref name^}` are rejected.
- A bare `name^` is equivalent to `var name^`.

## Copyable closures: `var^`

`{var^}` with no variable name makes owned capture the default for every free
variable in the body. When every captured type is `Copyable`, the resulting
closure value is also `Copyable`:

```mojo
def main():
    var label = "sensor-1"

    def tag() {var^} -> String:
        return label

    var clone = tag           # closure value copied
    print(tag())              # sensor-1
    print(clone())            # sensor-1
```

Copying the closure invokes the copy initializer of each captured value. The
copy happens at the assignment, not at the closure declaration.

Constraints:

- `{var^}` is a default-convention entry. A capture list can contain at most
  one default-convention entry.
- If any captured type is move-only, the closure is `Movable` but not
  `Copyable`.

Comparison with `{var name^}`:

| Form          | Captured names                  | Closure value                         |
|---------------|---------------------------------|---------------------------------------|
| `{var name^}` | Only `name`, transfers          | Not `Copyable` by default             |
| `{var^}`      | All referenced names, transfers | `Copyable` if captures are `Copyable` |

## `ref`

Reference whose mutability comes from the outer binding's origin. The closure
doesn't choose `imm` or `mut`; it preserves the mutability of that origin:

```mojo
def show_mutability(ref items: List[Int]):
    def report() {ref items}:
        comptime if origin_of(items).mut:
            print("mut")
        else:
            print("immut")
    report()

# `xs` uses default `imm` convention, immutable reference
def from_imm(xs: List[Int]):
    show_mutability(xs)

# `xs` uses `mut` convention, mutable reference
def from_mut(mut xs: List[Int]):
    show_mutability(xs)

def main():
    var nums: List[Int] = [10, 20, 30]
    from_imm(nums)    # immut
    from_mut(nums)    # mut
```

`ref` is the only convention that forwards origin information unchanged.
`imm` and `mut` create references with fixed mutability; `var` removes the
origin relationship entirely.

`ref` captures are intended for parameterized code that must work with
different mutability contexts. In ordinary closures, `imm` and `mut` produce
clearer signatures.

## Empty and omitted capture lists

An empty capture list (`{}`) has the same result as omitting the capture list:
any reference to an outer value is rejected with an error about inferring the
capture convention.

Both forms allow a body that uses only its arguments and locally declared
values. The function behaves as a plain nested function without captures.

Prefer `{}` when the absence of captures is intentional. The explicit braces
make the constraint visible at the declaration.

## Mixing conventions

Each captured value can use its own convention:

```mojo
def main():
    var config = "prod"
    var count = 0
    var label = "run-1"

    def process() {imm config, mut count, var label}:
        count += 1
        print(config, count, label)

    process()   # prod 1 run-1
    label = "run-2"
    process()   # prod 2 run-1
                # (label was copied at declaration time)
```

A bare name in a mixed list uses `imm`, not the convention of surrounding
entries:

```mojo
# y is captured as 'imm', not 'mut'
def f() {var z, mut x, y}:
    # ...
```

## Default convention

A convention keyword without a name sets the default for every free variable
not explicitly named:

```mojo
def main():
    var a = 1
    var b = 2
    var z = "snapshot"

    def mixed() {mut, var z}:
        a += 10           # 'a' uses default: mut
        b += 20           # 'b' uses default: mut
        print(a, b, z)

    mixed()               # 11 22 snapshot
    z = "changed"
    mixed()               # 21 42 snapshot
                          # ('z' was copied at declaration)
```

Rules:

- A capture list can contain at most one default-convention entry.
- Position within the list isn't significant.
- Trailing commas are accepted.
- The default doesn't apply to names covered by an explicit entry. In
  `{mut, var z}`, `var z` overrides the default for `z`.

## Parametric closures

A closure can declare its own compile-time parameter list:

```mojo
def main():
    # The `Intable` trait supports `Int` conversion
    def double[T: Intable](x: T) {} -> Int:
        return Int(x) * 2

    print(double[Int](5))         # 10
    print(double[Float64](3.4))   # 6
```

The parameter list, capture list, effects, and return type appear in the
same order as on top-level functions:
`name[parameters](arguments) effects {captures} -> ReturnType`.

Parameters and captures work independently. Parameters are supplied at each
call site, while the capture list controls the closure's relationship to the
enclosing scope. Variadic parameters are also supported
(`def closure[*Ts: Coord](*args: *Ts)`).

## Effects

Effects appear between the argument list and the capture list.

| Effect          | Form                            | Type example                           |
|-----------------|---------------------------------|----------------------------------------|
| `raises`        | `(args) raises {captures} -> T` | def (String) raises -> Int             |
| `thin`          | `(args) thin -> T`              | def (T) thin -> U                      |
| `abi(language)` | `(args) abi(language) -> T`     | def (Float64) thin abi("C") -> Float64 |

**Caution**

You may not combine non-Mojo `abi()` effects with raising functions.
Raising functions change calling conventions in a non-obvious ways.
The Mojo compiler:

- accepts `def (String) abi("Mojo") raises`
- rejects `def (String) abi("C") raises`

`raises` example:

```mojo
def main() raises:
    var y = 2

    def divide(x: Int) raises {var y} -> Int:
        if y == 0:
            raise Error("divide by zero")
        return x // y

    print(divide(10))   # 5
```

The `thin` effect applies to function *types*, not to closure declarations.
`thin` describes a non-capturing function type, so it can't represent a
closure that captures. A `thin` function type is also the only one that accepts
trailing `where` clauses. See
[Function declarations](../reference/function-declarations.md).

## Nesting

Closures can nest inside closures. Each level has its own capture list. An
inner closure can capture a name already captured by its enclosing closure:

```mojo
def main():
    var y = 4

    def outer() {var y} -> Int:
        def inner() {var y} -> Int:
            return y
        return inner() + y

    print(outer())   # 8
```

An inner closure can capture an outer closure by name. This is how nested
callbacks compose:

```mojo
def main():
    def make_adder(n: Int):
        def add(x: Int) {var n} -> Int:
            return x + n

        def twice(x: Int) {var add} -> Int:
            return add(add(x))

        print(twice(5))   # ((5 + 3) + 3) = 11
                          # add(add(5)) = add(8) = 11

    make_adder(3)
```

Closures are values and can be used in capture lists. An inner closure
captures an outer closure by `var`, `imm`, `mut`, or `ref`, just like any
other value.

## Capture-list errors

| Compiler complaint                          | Trigger                                                      |
|---------------------------------------------|--------------------------------------------------------------|
| Transfer sigil `^` without `var` convention | `^` after `mut`, `imm`, or `ref`                             |
| Duplicate default convention                | Two bare convention keywords in one list                     |
| Unrecognized token in capture position      | Token that isn't a convention keyword or name                |
| Missing comma between entries               | Identifier followed by an unrecognized token                 |
| Unterminated capture list                   | Missing closing `}`                                          |
| Outer name not covered by capture list      | Body references an outer name the capture list doesn't cover |
| Use after move capture                      | Reference to a name after `{var name^}` consumed it          |

## Restrictions

- **No escape.** A closure can't outlive its enclosing scope. Returning a
  closure from its declaring function or storing it past the enclosing
  scope's end isn't supported.
- **No `thin` on declarations.** These apply to function types,
  not closure declarations. A declaration with captures can't be `thin`.
- **Trait conformance with closure fields.** A struct can contain a
  closure-typed field and conform to a trait, but every method of that trait
  must be declared `capturing` until the capturing effect is removed (see
  `unified_closure_structs.mojo`).
