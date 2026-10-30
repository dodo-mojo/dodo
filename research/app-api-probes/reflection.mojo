"""P1: build a JSON Schema string from a struct through comptime reflection."""

@fieldwise_init
struct Address:
    var city: String
    var zip: Int


@fieldwise_init
struct User:
    var name: String
    var age: Int
    var score: Float64
    var active: Bool
    var tags: List[String]
    var address: Address


def _schema_of[T: AnyType]() -> String:
    comptime if T == String:
        return String('{"type":"string"}')
    elif T == Int:
        return String('{"type":"integer"}')
    elif T == Float64:
        return String('{"type":"number"}')
    elif T == Bool:
        return String('{"type":"boolean"}')
    elif T == List[String]:
        return String('{"type":"array","items":{"type":"string"}}')
    elif reflect[T].name().startswith("SIMD"):
        comptime assert False, "unsupported number type in a Json struct"
        return String("")
    elif reflect[T].is_struct():
        return _struct_schema[T]()
    else:
        comptime assert False, "unsupported field type " + reflect[T].name()
        return String("")


def _struct_schema[T: AnyType]() -> String:
    comptime count = reflect[T].field_count()
    comptime names = reflect[T].field_names()
    comptime types = reflect[T].field_types()
    var out = String('{"type":"object","properties":{')
    comptime for i in range(count):
        comptime if i > 0:
            out += ","
        out += '"'
        comptime name = names[i]
        out += String(name)
        out += '":'
        out += _schema_of[types[i]]()
    out += "}}"
    return out^


def schema_of[T: AnyType]() -> String:
    return _struct_schema[T]()


comptime user_schema = schema_of[User]()


def main():
    comptime count = reflect[User].field_count()
    comptime names = reflect[User].field_names()
    comptime types = reflect[User].field_types()
    print("field count (comptime):", count)
    comptime for i in range(count):
        comptime name = names[i]
        comptime type_name = reflect[types[i]].name()
        print(name, "->", type_name)
    print(schema_of[User]())
    print("comptime schema:", user_schema)
