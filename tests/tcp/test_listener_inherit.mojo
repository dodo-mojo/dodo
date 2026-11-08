"""TcpListener.inherit: taking over a listening socket by fd (DODO_LISTEN_FD)."""

from std.ffi import c_int, external_call
from std.sys.info import CompilationTarget
from std.testing import TestSuite, assert_equal, assert_raises, assert_true

from dodo.net import IpAddr, SocketAddr
from dodo.net._libc import _bind, _fcntl2
from dodo.net.socket import AF_INET, SOCK_STREAM, RawSocket, _build_sockaddr_in
from dodo.tcp import TcpListener, TcpStream


def _fd_is_open(fd: Int) -> Bool:
    # fcntl(F_GETFD) fails with EBADF on a closed fd.
    return Int(_fcntl2(c_int(fd), c_int(1), c_int(0))) >= 0


def test_inherit_keeps_address_and_accepts() raises:
    var original = TcpListener.bind(SocketAddr.localhost(0))
    var port = original.local_addr().port
    var fd = Int(original.into_raw_fd())
    var listener = TcpListener.inherit(fd)
    assert_equal(listener.local_addr().port, port)
    assert_equal(listener.local_addr().ip, IpAddr.localhost())
    var client = TcpStream.connect(SocketAddr.localhost(port))
    var server_side = listener.accept()
    _ = client.write("hi".as_bytes())
    var buf = List[UInt8](length=2, fill=0)
    var n = server_side.read(buf.unsafe_ptr(), len(buf))
    assert_equal(n, 2)


def test_inherit_ipv6() raises:
    var original = TcpListener.bind(SocketAddr(IpAddr.localhost_v6(), 0))
    var port = original.local_addr().port
    var listener = TcpListener.inherit(Int(original.into_raw_fd()))
    assert_true(listener.local_addr().ip.is_v6())
    var client = TcpStream.connect(SocketAddr(IpAddr.localhost_v6(), port))
    _ = listener.accept()
    _ = client^


def test_negative_fd() raises:
    with assert_raises(contains="must not be negative"):
        _ = TcpListener.inherit(-1)


def test_closed_fd() raises:
    var original = TcpListener.bind(SocketAddr.localhost(0))
    var fd = Int(original.into_raw_fd())
    _ = external_call["close", c_int](c_int(fd))
    with assert_raises(contains="is not an open socket"):
        _ = TcpListener.inherit(fd)


def test_regular_file_is_rejected_and_left_open() raises:
    var fd = Int(
        external_call["open", c_int]("/dev/null".unsafe_ptr(), c_int(0))
    )
    assert_true(fd >= 0)
    with assert_raises(contains="is not an open socket"):
        _ = TcpListener.inherit(fd)
    assert_true(_fd_is_open(fd))
    _ = external_call["close", c_int](c_int(fd))


def test_unbound_socket() raises:
    var sock = RawSocket(AF_INET, SOCK_STREAM)
    var fd = Int(sock.fd)
    with assert_raises(contains="is not bound to a port"):
        _ = TcpListener.inherit(fd)
    assert_true(_fd_is_open(fd))
    _ = sock^


def test_bound_socket_that_is_not_listening() raises:
    comptime if CompilationTarget.is_linux():
        var sock = RawSocket(AF_INET, SOCK_STREAM)
        var sa = _build_sockaddr_in(SocketAddr.localhost(0))
        assert_equal(_bind(sock.fd, sa[0], sa[1]), 0)
        sa[0].unsafe_free()
        var fd = Int(sock.fd)
        with assert_raises(contains="is not listening"):
            _ = TcpListener.inherit(fd)
        assert_true(_fd_is_open(fd))
        _ = sock^


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
