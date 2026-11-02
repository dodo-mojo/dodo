"""Probe the Mojo 1.2 features the database API leans on.

1. Variadic parameters with implicit conversion: `q("...", 1, "a", 2.5, True)`.
2. A lock usable across threads.
3. A guard whose destructor gives a connection back.
4. A trait with an associated type (driver config).
"""

from std.collections import Optional


struct Param(Copyable, Movable):
    var kind: Int
    var text: String

    @implicit
    def __init__(out self, value: Int):
        self.kind = 1
        self.text = String(value)

    @implicit
    def __init__(out self, value: String):
        self.kind = 2
        self.text = value

    @implicit
    def __init__(out self, value: StringLiteral):
        self.kind = 2
        self.text = String(value)

    @implicit
    def __init__(out self, value: Float64):
        self.kind = 3
        self.text = String(value)

    @implicit
    def __init__(out self, value: Bool):
        self.kind = 4
        self.text = String(value)

    def __init__(out self, *, kind: Int):
        self.kind = kind
        self.text = String()

    @staticmethod
    def null() -> Self:
        return Self(kind=0)


def q(sql: String, *params: Param) -> Int:
    var total = 0
    for p in params:
        total += p.kind
    return total


trait Driver:
    comptime Config: Copyable

    @staticmethod
    def open(config: Self.Config) raises -> Self:
        ...


@fieldwise_init
struct FakeConfig(Copyable, Movable):
    var url: String


struct FakeConn(Driver, Movable):
    comptime Config = FakeConfig
    var url: String

    def __init__(out self, url: String):
        self.url = url

    @staticmethod
    def open(config: Self.Config) raises -> Self:
        return Self(config.url)


def open_with[D: Driver & Movable](config: D.Config) raises -> D:
    return D.open(config)


struct Guard(Movable):
    var counter: Pointer[Int, MutUntrackedOrigin]

    def __init__(out self, counter: Pointer[Int, MutUntrackedOrigin]):
        self.counter = counter

    def __deinit__(deinit self):
        self.counter[] += 1


def main() raises:
    print("variadic:", q("select", 1, "a", 2.5, True, Param.null()))
    var name = String("bob")
    print("variadic String var:", q("select", name, 3))

    var c = open_with[FakeConn](FakeConfig("pg://x"))
    print("assoc type:", c.url)

    var returned = 0
    var p = Pointer[Int, MutUntrackedOrigin](
        unsafe_from_address=Int(Pointer(to=returned))
    )
    take_guard(p)
    print("guard returned:", returned)


def take_guard(p: Pointer[Int, MutUntrackedOrigin]):
    var g = Guard(p)
    _ = g.counter
