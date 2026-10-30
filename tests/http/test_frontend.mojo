"""`HttpFrontend` on real sockets: which loop it picks and what it serves."""

from std.testing import assert_equal, assert_false, assert_true, TestSuite

from dodo.http import Handler, HttpFrontend, Request, Response, ok
from dodo.http.server import ServerConfig
from dodo.http2.server import Http2Config
from dodo.net import SocketAddr
from dodo.runtime import Scheduler
from dodo.tcp import TcpListener, TcpStream

comptime _H2_PREFACE = "PRI * HTTP/2.0\r\n\r\nSM\r\n\r\n"
comptime _H2_FRAME_SETTINGS = 4
comptime _H2_SETTINGS_MAX_STREAMS = 3
comptime _H2_FRAME_HEADER_LEN = 9
comptime _H2_SETTING_LEN = 6


@fieldwise_init
struct _Tagged(Copyable, Handler):
    """Echoes the tag it was built with, to show each worker's copy has it."""

    var tag: String

    def serve(self, req: Request) raises -> Response:
        return ok(String(self.tag, " ", req.url))


def _config() -> ServerConfig:
    var config = ServerConfig()
    config.idle_timeout_ms = 200
    config.shutdown_timeout_ms = 300
    return config^


def _free_port() raises -> UInt16:
    var listener = TcpListener.bind(SocketAddr.localhost(0))
    var port = listener.local_addr().port
    listener.close()
    return port


def _start(
    port: UInt16,
    var frontend: HttpFrontend[_Tagged],
    num_workers: Int = 1,
    extra_addrs: List[SocketAddr] = List[SocketAddr](),
) raises -> Scheduler[HttpFrontend[_Tagged]]:
    return Scheduler[HttpFrontend[_Tagged]].start(
        addr=SocketAddr.localhost(port),
        frontend=frontend^,
        num_workers=num_workers,
        pin_cores=False,
        extra_addrs=extra_addrs,
    )


def _read_some(mut conn: TcpStream) raises -> List[UInt8]:
    """Everything the peer sends until it closes or goes quiet."""
    var out = List[UInt8]()
    var buf = List[UInt8](length=4096, fill=0)
    while True:
        var n: Int
        try:
            n = conn.read(buf.unsafe_ptr(), len(buf))
        except:
            return out^
        if n <= 0:
            return out^
        for i in range(n):
            out.append(buf[i])


def _http1_get(port: UInt16, path: String) raises -> String:
    var conn = TcpStream.connect(SocketAddr.localhost(port))
    conn.set_recv_timeout(2000)
    var request = String(
        "GET ", path, " HTTP/1.1\r\nHost: x\r\nConnection: close\r\n\r\n"
    )
    conn.write_all(request.as_bytes())
    var reply = _read_some(conn)
    conn.close()
    return String(unsafe_from_utf8=reply)


def _send_h2_preface(port: UInt16) raises -> List[UInt8]:
    var conn = TcpStream.connect(SocketAddr.localhost(port))
    conn.set_recv_timeout(500)
    conn.write_all(String(_H2_PREFACE).as_bytes())
    # An empty SETTINGS frame, as a client's preface must include.
    var settings = List[UInt8](length=_H2_FRAME_HEADER_LEN, fill=0)
    settings[3] = UInt8(_H2_FRAME_SETTINGS)
    conn.write_all(settings)
    var reply = _read_some(conn)
    conn.close()
    return reply^


def _is_h2_settings(reply: List[UInt8]) -> Bool:
    if len(reply) < _H2_FRAME_HEADER_LEN:
        return False
    return Int(reply[3]) == _H2_FRAME_SETTINGS


def _advertised_max_streams(reply: List[UInt8]) raises -> Int:
    """SETTINGS_MAX_CONCURRENT_STREAMS from the server's first frame."""
    var length = (Int(reply[0]) << 16) | (Int(reply[1]) << 8) | Int(reply[2])
    var offset = _H2_FRAME_HEADER_LEN
    var end = _H2_FRAME_HEADER_LEN + length
    while offset + _H2_SETTING_LEN <= end:
        var id = (Int(reply[offset]) << 8) | Int(reply[offset + 1])
        if id == _H2_SETTINGS_MAX_STREAMS:
            var value = 0
            for i in range(2, 6):
                value = (value << 8) | Int(reply[offset + i])
            return value
        offset += _H2_SETTING_LEN
    raise Error("server did not advertise max concurrent streams")


def test_http1_path_serves_the_handler() raises:
    var port = _free_port()
    var sched = _start(port, HttpFrontend(_Tagged("one"), _config()))
    var reply = _http1_get(port, "/a")
    sched.shutdown()
    assert_true(reply.startswith("HTTP/1.1 200"), reply)
    assert_true(reply.endswith("one /a"), reply)


def test_http1_path_does_not_speak_h2() raises:
    var port = _free_port()
    var sched = _start(port, HttpFrontend(_Tagged("one"), _config()))
    var reply = _send_h2_preface(port)
    sched.shutdown()
    assert_false(_is_h2_settings(reply))


def test_auto_protocol_serves_http1() raises:
    var port = _free_port()
    var sched = _start(
        port, HttpFrontend(_Tagged("auto"), _config(), auto_protocol=True)
    )
    var reply = _http1_get(port, "/b")
    sched.shutdown()
    assert_true(reply.startswith("HTTP/1.1 200"), reply)
    assert_true(reply.endswith("auto /b"), reply)


def test_auto_protocol_answers_h2_preface() raises:
    var port = _free_port()
    var sched = _start(
        port, HttpFrontend(_Tagged("auto"), _config(), auto_protocol=True)
    )
    var reply = _send_h2_preface(port)
    sched.shutdown()
    assert_true(_is_h2_settings(reply))


def test_auto_protocol_uses_given_h2_config() raises:
    var port = _free_port()
    var h2 = Http2Config()
    h2.max_concurrent_streams = 7
    var sched = _start(
        port,
        HttpFrontend(_Tagged("auto"), _config(), h2^, auto_protocol=True),
    )
    var reply = _send_h2_preface(port)
    sched.shutdown()
    assert_equal(_advertised_max_streams(reply), 7)


def test_config_reaches_the_workers() raises:
    var port = _free_port()
    var config = _config()
    config.max_uri_length = 16
    var sched = _start(port, HttpFrontend(_Tagged("one"), config^))
    var short_reply = _http1_get(port, "/ok")
    var long_reply = _http1_get(port, String("/", "x" * 64))
    sched.shutdown()
    assert_true(short_reply.startswith("HTTP/1.1 200"), short_reply)
    assert_true(long_reply.startswith("HTTP/1.1 414"), long_reply)


def test_extra_address_is_served_without_auto_protocol() raises:
    var port = _free_port()
    var extra_port = _free_port()
    var extra = List[SocketAddr]()
    extra.append(SocketAddr.localhost(extra_port))
    var sched = _start(
        port, HttpFrontend(_Tagged("multi"), _config()), extra_addrs=extra
    )
    var first = _http1_get(port, "/first")
    var second = _http1_get(extra_port, "/second")
    var h2_reply = _send_h2_preface(extra_port)
    sched.shutdown()
    assert_true(first.endswith("multi /first"), first)
    assert_true(second.endswith("multi /second"), second)
    assert_true(_is_h2_settings(h2_reply))


def test_four_workers_answer_every_request() raises:
    var port = _free_port()
    var sched = _start(
        port, HttpFrontend(_Tagged("many"), _config()), num_workers=4
    )
    var failures = 0
    for i in range(32):
        var reply = _http1_get(port, String("/", i))
        if not reply.endswith(String("many /", i)):
            failures += 1
    sched.shutdown()
    assert_equal(failures, 0)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
