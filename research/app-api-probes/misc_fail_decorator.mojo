"""P4a: a user-defined decorator (does not compile)."""


def route(path: String):
    pass


@route("/hello")
def hello() raises -> String:
    return String("hi")


def main() raises:
    print(hello())
