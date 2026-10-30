"""P4: (b) generic owned state, (c) dispatch on trait conformance at comptime.

(a) user decorators: see misc_fail_decorator.mojo.
"""

from std.builtin.rebind import downcast


trait Describe:
    def describe(self) -> String:
        ...


@fieldwise_init
struct Model(Describe, Movable):
    var name: String

    def describe(self) -> String:
        return String("model ", self.name)


@fieldwise_init
struct Plain(Movable):
    var value: Int


struct Holder[S: Movable & Deinitable](Movable):
    var state: Self.S

    def __init__(out self, var state: Self.S):
        self.state = state^


struct App:
    var count: Int

    def __init__(out self):
        self.count = 0

    # (b) any Movable type, taken by var, no trait beyond Movable.
    def take_state[S: Movable & Deinitable](mut self, var state: S):
        _ = Holder[S](state^)
        self.count += 1


def describe_or_default[T: AnyType](value: T) -> String:
    # (c) trait conformance picked at comptime.
    comptime if conforms_to(T, Describe):
        ref described = rebind[downcast[T, Describe]](value)
        return described.describe()
    else:
        return String("no description for ", reflect[T].name())


def main():
    var app = App()
    app.take_state(Model("m1"))
    app.take_state(Plain(3))
    app.take_state(String("a string"))
    print("states taken:", app.count)
    print(describe_or_default(Model("m2")))
    print(describe_or_default(Plain(1)))
