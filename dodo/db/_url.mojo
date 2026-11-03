"""Connection URLs: `scheme://user:password@host:port/database?key=value`.

User, password, database and option values may be percent-encoded, so a
password can hold `@`, `:` or `/`.
"""

from ._bytes import hex_digit
from .error import DbError


struct DbUrl(Copyable, Writable):
    var scheme: String
    var user: String
    var password: String
    var host: String
    var port: Int
    var database: String
    var options: List[Tuple[String, String]]

    def __init__(out self):
        self.scheme = String()
        self.user = String()
        self.password = String()
        self.host = String()
        self.port = 0
        self.database = String()
        self.options = List[Tuple[String, String]]()

    @staticmethod
    def parse(url: String, default_port: Int) raises DbError -> DbUrl:
        var out = DbUrl()
        out.port = default_port
        var scheme_end = url.find("://")
        if scheme_end < 0:
            raise DbError.usage(
                "", String("connection URL needs a scheme://: ", _redact(url))
            )
        out.scheme = String(url[byte=:scheme_end])
        var rest = String(url[byte = scheme_end + 3 :])

        var query = String()
        var q = rest.find("?")
        if q >= 0:
            query = String(rest[byte = q + 1 :])
            var before_query = String(rest[byte=:q])
            rest = before_query^

        var path = String()
        var slash = rest.find("/")
        if slash >= 0:
            path = String(rest[byte = slash + 1 :])
            var before_path = String(rest[byte=:slash])
            rest = before_path^

        var at = rest.rfind("@")
        if at >= 0:
            var userinfo = String(rest[byte=:at])
            var after_at = String(rest[byte = at + 1 :])
            rest = after_at^
            var colon = userinfo.find(":")
            if colon >= 0:
                out.user = _decode(String(userinfo[byte=:colon]))
                out.password = _decode(String(userinfo[byte = colon + 1 :]))
            else:
                out.user = _decode(userinfo)

        # [::1]:5432 or host:5432 or host
        if rest.startswith("["):
            var close = rest.find("]")
            if close < 0:
                raise DbError.usage(
                    "", "unclosed [ in the host of a connection URL"
                )
            out.host = String(rest[byte=1:close])
            var after_bracket = String(rest[byte = close + 1 :])
            rest = after_bracket^
            if rest.startswith(":"):
                out.port = _port(String(rest[byte=1:]))
        else:
            var colon = rest.rfind(":")
            if colon >= 0:
                out.host = String(rest[byte=:colon])
                out.port = _port(String(rest[byte = colon + 1 :]))
            else:
                out.host = rest
        if out.host == "":
            out.host = "127.0.0.1"
        out.database = _decode(path)

        if query != "":
            for pair in query.split("&"):
                var item = String(pair)
                if item == "":
                    continue
                var eq = item.find("=")
                if eq < 0:
                    out.options.append((_decode(item), String()))
                else:
                    out.options.append(
                        (
                            _decode(String(item[byte=:eq])),
                            _decode(String(item[byte = eq + 1 :])),
                        )
                    )
        return out^

    def option(self, key: String, default: String) -> String:
        for pair in self.options:
            if pair[0] == key:
                return pair[1]
        return default

    def int_option(self, key: String, default: Int) raises DbError -> Int:
        var text = self.option(key, "")
        if text == "":
            return default
        try:
            return Int(text)
        except:
            raise DbError.usage(
                "",
                String("option ", key, " must be a number, got '", text, "'"),
            )

    def write_to[W: Writer](self, mut writer: W):
        """The URL with the password hidden."""
        writer.write(self.scheme, "://")
        if self.user != "":
            writer.write(self.user)
            if self.password != "":
                writer.write(":***")
            writer.write("@")
        writer.write(self.host, ":", self.port, "/", self.database)


def _port(text: String) raises DbError -> Int:
    try:
        var port = Int(text)
        if port > 0 and port < 65536:
            return port
    except:
        pass
    raise DbError.usage("", String("bad port '", text, "' in connection URL"))


def _decode(text: String) -> String:
    """Percent-decode; a malformed escape is kept as written."""
    var bytes = text.as_bytes()
    var out = List[UInt8](capacity=len(bytes))
    var i = 0
    while i < len(bytes):
        if Int(bytes[i]) == ord("%") and i + 2 < len(bytes):
            var high = hex_digit(bytes[i + 1])
            var low = hex_digit(bytes[i + 2])
            if high >= 0 and low >= 0:
                out.append(UInt8(high * 16 + low))
                i += 3
                continue
        out.append(bytes[i])
        i += 1
    return String(from_utf8_lossy=out)


def _redact(url: String) -> String:
    """`url` with anything between `://` and `@` hidden."""
    var start = url.find("://")
    var at = url.rfind("@")
    if start < 0 or at < start:
        return url
    return String(url[byte = : start + 3]) + "***" + String(url[byte=at:])
