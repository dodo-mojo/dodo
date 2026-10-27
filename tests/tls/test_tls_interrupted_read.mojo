"""A blocking TLS read interrupted by a signal keeps waiting.

On a socket with ``SO_RCVTIMEO`` the kernel never restarts a ``recv``
that a signal interrupts; it fails with ``EINTR``. On Linux, io_uring
task work (queued when a ring the thread created is closed) does the
same. OpenSSL reports that as ``SSL_ERROR_WANT_READ``, which the client
read turned into ``Timeout("recv")`` long before the timeout.

The server is a forked child that handshakes, waits, then writes one
message. While the client waits for it, a helper thread sends
``SIGALRM`` to the reading thread, which has a handler that does
nothing.
"""

from std.ffi import c_int, external_call
from std.testing import assert_equal, TestSuite

from dodo.net import SocketAddr
from dodo.runtime import Pool
from dodo.runtime._thread import ThreadHandle, _OpaquePtr, _null_ptr
from dodo.tcp import TcpListener
from dodo.tls import TlsAcceptor, TlsConfig, TlsServerConfig, TlsStream
from dodo.tls._server_ffi import server_ssl_write_ex
from dodo.utils import SIGKILL, exit, fork, kill, usleep, waitpid


comptime _CRT: String = "tests/certs/server.crt"
comptime _KEY: String = "tests/certs/server.key"
comptime _CA: String = "tests/certs/ca.crt"
comptime _SIGALRM: c_int = 14


def _serve_late(var lis: TcpListener, message: String):
    """Child side: handshake, wait 500 ms, write ``message``, then stay
    up until the test kills it."""
    try:
        var stream = lis.accept()
        var acc = TlsAcceptor(TlsServerConfig(cert_file=_CRT, key_file=_KEY))
        var r = acc.handshake_fd(Int(stream._socket.fd))
        usleep(500_000)
        var bytes = message.as_bytes()
        var off = 0
        while off < len(bytes):
            var n = server_ssl_write_ex(acc._ctx, r[0], bytes, off)
            if n <= 0:
                break
            off += n
        usleep(10_000_000)
        _ = stream^
    except:
        pass
    exit()


def _on_alarm(sig: c_int):
    """Does nothing: it only has to exist so the signal interrupts."""
    pass


def _interrupt_soon(arg: _OpaquePtr) -> _OpaquePtr:
    """Send ``SIGALRM`` to the thread whose id ``arg`` holds, 100 ms
    from now, while it waits in the read."""
    var target = Pool[UInt64].get_ptr(Int(arg))[]
    usleep(100_000)
    _ = external_call["pthread_kill", c_int](target, _SIGALRM)
    return _null_ptr()


def test_tls_read_interrupted_by_a_signal_keeps_waiting() raises:
    var lis = TcpListener.bind(SocketAddr.localhost(0))
    var port = lis.local_addr().port
    var pid = fork()
    if pid == 0:
        _serve_late(lis^, "late")
    _ = external_call["signal", Int, c_int, def(c_int) thin -> None](
        _SIGALRM, _on_alarm
    )
    # Without this macOS restarts the recv and the test proves nothing.
    _ = external_call["siginterrupt", c_int](_SIGALRM, c_int(1))
    var got: String
    try:
        var s = TlsStream.connect("localhost", port, TlsConfig(ca_bundle=_CA))
        s.set_recv_timeout(5_000)
        var me = external_call["pthread_self", UInt64]()
        var slot = Pool[UInt64].alloc_move(me)
        var kicker = ThreadHandle.spawn_os[_interrupt_soon](
            _OpaquePtr(unsafe_from_address=slot)
        )
        var buf = List[UInt8](length=64, fill=0)
        var n = s.read(buf.unsafe_ptr(), len(buf))
        got = String(unsafe_from_utf8=Span[UInt8, _](buf)[:n])
        kicker.join()
        Pool[UInt64].free(slot)
        s.close()
    except e:
        got = "raised: " + String(e)
    _ = kill(pid, SIGKILL)
    waitpid(pid)
    assert_equal(got, "late")


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
