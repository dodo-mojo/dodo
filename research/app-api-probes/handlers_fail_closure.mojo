"""P2c (does not compile): can a closure that captures state be stored in a List?"""


struct Model(Copyable):
    var name: String

    def __init__(out self, name: String):
        self.name = name


def make_greeter(var model: Model) -> def(String) -> String:
    def greet(who: String) -> String:
        return String(model.name, " greets ", who)

    return greet^


def main():
    var all = List[def(String) -> String]()
    all.append(make_greeter(Model("a")))
    all.append(make_greeter(Model("b")))
    print(all[0]("x"))
    print(all[1]("y"))
