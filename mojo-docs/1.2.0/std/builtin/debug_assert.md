# `std.builtin.debug_assert`

Implements run-time assertions.

These are Mojo built-ins, so you don't need to import them.

## Aliases

### `ASSERT_MODE`

```mojo
comptime ASSERT_MODE = get_defined_string[StringSpan("ASSERT"), StringSpan("safe")]()
```

The compile-time assertion mode from the ASSERT environment variable.

## Functions

### `debug_assert`

```mojo
def debug_assert[Cond: def() -> Bool, assert_mode: StringSpan[ImmStaticOrigin] = StringSpan("none"), *Ts: Writable = *?, *, cpu_only: Bool = False](cond: Cond, *messages: *Ts.values, *, location: Optional[SourceLocation] = None)
```

Asserts that the condition is true at run time.

If the condition is false, the assertion displays the given message and
causes the program to exit.

You can pass in multiple arguments to generate a formatted
message. No string allocation occurs unless the assertion is triggered.

```mojo
var x = 0
debug_assert(x > 0, "expected x to be more than 0 but got: ", x)
```

Normal assertions are off by default—they only run when the program is
compiled with all assertions enabled. You can set the `assert_mode` to
`safe` to create an assertion that's on by default:

```mojo
var x = 0
debug_assert[assert_mode="safe"](
    x > 0, "expected x to be more than 0 but got: ", x
)
```

Use the `ASSERT` variable to turn assertions on or off when building or
running a Mojo program:

```sh
mojo -D ASSERT=all main.mojo
```

The `ASSERT` variable takes the following values:

- all: Turn on all assertions.
- safe: Turn on "safe" assertions only. This is the default.
- none: Turn off all assertions, for performance at the cost of safety.
- warn: Turn on all assertions, but print any errors instead of exiting.

To ensure that you have no run-time penalty from your assertions even when
they're disabled, make sure there are no side effects in your message and
condition expressions. For example:

```mojo
var person = "name: john, age: 50"
var name = "john"
debug_assert(String("name: ", name) in person, "unexpected name")
```

This will have a run-time penalty due to allocating a `String` in the
condition expression, even when assertions are disabled. To avoid this, pass
the condition as a closure so it runs only when the assertion is turned on:

```mojo
def main():
    var person = "name: john, age: 50"
    var name = "john"

    def check_name() {name, person} -> Bool:
        return String("name: ", name) in person

    debug_assert(check_name, "unexpected name")
```

If you need to allocate, and so don't want the assert to ever run on GPU,
you can set it to CPU only:

```mojo
def main():
    var person = "name: john, age: 50"
    var name = "john"

    def check_name() {name, person} -> Bool:
        return String("name: ", name) in person

    debug_assert[cpu_only=True](check_name, "unexpected name")
```

For compile-time assertions, see [`comptime
assert`](../../manual/metaprogramming/constraints.md#compile-time-assertions)

Parameters:

- `Cond`: The type of the closure to invoke to check if the assertion holds.
- `assert_mode`: Determines when the assert is turned on. - default ("none"): Turned on when compiled with `-D ASSERT=all`. - "safe": Turned on by default.
- `*Ts`: The element types for the message arguments.
- `cpu_only`: If true, only run the assert on CPU.

Args:

- `cond`: The closure to invoke to check if the assertion holds.
- `*messages`: A set of [`Writable`](../../std/format/index.md#writable) arguments to convert to a `String` message.
- `location`: Source location to report on assertion failure.

```mojo
def debug_assert[assert_mode: StringSpan[ImmStaticOrigin] = StringSpan("none"), *Ts: Writable = *?, *, cpu_only: Bool = False, _use_compiler_assume: Bool = False](cond: Bool, *messages: *Ts.values, *, location: Optional[SourceLocation] = None)
```

Asserts that the condition is true at run time.

If the condition is false, the assertion displays the given message and
causes the program to exit.

You can pass in multiple arguments to generate a formatted
message. No string allocation occurs unless the assertion is triggered.

```mojo
var x = 0
debug_assert(x > 0, "expected x to be more than 0 but got: ", x)
```

Normal assertions are off by default—they only run when the program is
compiled with all assertions enabled. You can set the `assert_mode` to
`safe` to create an assertion that's on by default:

```mojo
var x = 0
debug_assert[assert_mode="safe"](
    x > 0, "expected x to be more than 0 but got: ", x
)
```

Use the `ASSERT` variable to turn assertions on or off when building or
running a Mojo program:

```sh
mojo -D ASSERT=all main.mojo
```

The `ASSERT` variable takes the following values:

- all: Turn on all assertions.
- safe: Turn on "safe" assertions only. This is the default.
- none: Turn off all assertions, for performance at the cost of safety.
- warn: Turn on all assertions, but print any errors instead of exiting.

To ensure that you have no run-time penalty from your assertions even when
they're disabled, make sure there are no side effects in your message and
condition expressions. For example:

```mojo
var person = "name: john, age: 50"
var name = "john"
debug_assert(String("name: ", name) in person, "unexpected name")
```

This will have a run-time penalty due to allocating a `String` in the
condition expression, even when assertions are disabled. To avoid this, pass
the condition as a closure so it runs only when the assertion is turned on:

```mojo
def main():
    var person = "name: john, age: 50"
    var name = "john"

    def check_name() {name, person} -> Bool:
        return String("name: ", name) in person

    debug_assert(check_name, "unexpected name")
```

If you need to allocate, and so don't want the assert to ever run on GPU,
you can set it to CPU only:

```mojo
def main():
    var person = "name: john, age: 50"
    var name = "john"

    def check_name() {name, person} -> Bool:
        return String("name: ", name) in person

    debug_assert[cpu_only=True](check_name, "unexpected name")
```

For compile-time assertions, see [`comptime
assert`](../../manual/metaprogramming/constraints.md#compile-time-assertions)

Parameters:

- `assert_mode`: Determines when the assert is turned on. - default ("none"): Turned on when compiled with `-D ASSERT=all`. - "safe": Turned on by default.
- `*Ts`: The element types for the message arguments.
- `cpu_only`: If true, only run the assert on CPU.
- `_use_compiler_assume`: If true, assume the condition is true for repeated checks, to help the compiler optimize (default False).

Args:

- `cond`: The bool value to assert.
- `*messages`: A set of [`Writable`](../../std/format/index.md#writable) arguments to convert to a `String` message.
- `location`: Source location to report on assertion failure.

```mojo
def debug_assert[Cond: def() -> Bool, assert_mode: StringSpan[ImmStaticOrigin] = StringSpan("none"), cpu_only: Bool = False](cond: Cond)
```

Asserts that the condition is true at run time, with no message.

On failure this reports `assertion failed` at the call site. Use the
overload taking `messages` to report a formatted message instead.

```mojo
def main():
    var x = 1

    def check() {x} -> Bool:
        return x > 0

    debug_assert(check)
```

Parameters:

- `Cond`: The type of the closure to invoke to check if the assertion holds.
- `assert_mode`: Determines when the assert is turned on.
- `cpu_only`: If true, only run the assert on CPU.

Args:

- `cond`: The closure to invoke to check if the assertion holds.

```mojo
def debug_assert[assert_mode: StringSpan[ImmStaticOrigin] = StringSpan("none"), cpu_only: Bool = False, _use_compiler_assume: Bool = False](cond: Bool)
```

Asserts that the condition is true at run time, with no message.

On failure this reports `assertion failed` at the call site. Use the
overload taking `messages` to report a formatted message instead.

```mojo
var x = 1
debug_assert(x > 0)
```

Parameters:

- `assert_mode`: Determines when the assert is turned on.
- `cpu_only`: If true, only run the assert on CPU.
- `_use_compiler_assume`: If true, assume the condition is true for repeated checks, to help the compiler optimize (default False).

Args:

- `cond`: The bool value to assert.

```mojo
def debug_assert[assert_mode: StringSpan[ImmStaticOrigin] = StringSpan("none"), cpu_only: Bool = False, _use_compiler_assume: Bool = False](cond: Bool, message: StringLiteral)
```

Asserts that the condition is true at run time.

If the condition is false, the assertion displays the given message and
causes the program to exit.

You can pass in multiple arguments to generate a formatted
message. No string allocation occurs unless the assertion is triggered.

```mojo
var x = 0
debug_assert(x > 0, "expected x to be more than 0 but got: ", x)
```

Normal assertions are off by default—they only run when the program is
compiled with all assertions enabled. You can set the `assert_mode` to
`safe` to create an assertion that's on by default:

```mojo
var x = 0
debug_assert[assert_mode="safe"](
    x > 0, "expected x to be more than 0 but got: ", x
)
```

Use the `ASSERT` variable to turn assertions on or off when building or
running a Mojo program:

```sh
mojo -D ASSERT=all main.mojo
```

The `ASSERT` variable takes the following values:

- all: Turn on all assertions.
- safe: Turn on "safe" assertions only. This is the default.
- none: Turn off all assertions, for performance at the cost of safety.
- warn: Turn on all assertions, but print any errors instead of exiting.

To ensure that you have no run-time penalty from your assertions even when
they're disabled, make sure there are no side effects in your message and
condition expressions. For example:

```mojo
var person = "name: john, age: 50"
var name = "john"
debug_assert(String("name: ", name) in person, "unexpected name")
```

This will have a run-time penalty due to allocating a `String` in the
condition expression, even when assertions are disabled. To avoid this, pass
the condition as a closure so it runs only when the assertion is turned on:

```mojo
def main():
    var person = "name: john, age: 50"
    var name = "john"

    def check_name() {name, person} -> Bool:
        return String("name: ", name) in person

    debug_assert(check_name, "unexpected name")
```

If you need to allocate, and so don't want the assert to ever run on GPU,
you can set it to CPU only:

```mojo
def main():
    var person = "name: john, age: 50"
    var name = "john"

    def check_name() {name, person} -> Bool:
        return String("name: ", name) in person

    debug_assert[cpu_only=True](check_name, "unexpected name")
```

For compile-time assertions, see [`comptime
assert`](../../manual/metaprogramming/constraints.md#compile-time-assertions)

Parameters:

- `assert_mode`: Determines when the assert is turned on. - default ("none"): Turned on when compiled with `-D ASSERT=all`. - "safe": Turned on by default.
- `cpu_only`: If true, only run the assert on CPU.
- `_use_compiler_assume`: If true, assume the condition is true for repeated checks, to help the compiler optimize (default False).

Args:

- `cond`: The bool value to assert.
- `message`: A static string message.
