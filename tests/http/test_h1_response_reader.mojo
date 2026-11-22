"""``H1ResponseReader`` frames a response from bytes as they arrive, the
way the loop client reads them."""

from std.testing import (
    TestSuite,
    assert_equal,
    assert_false,
    assert_raises,
    assert_true,
)

from dodo.http._client.parse import H1ResponseReader


def _bytes(text: String) -> List[UInt8]:
    return List[UInt8](text.as_bytes())


def _feed_one_by_one(mut reader: H1ResponseReader, text: String) raises -> Int:
    """Feed ``text`` a byte at a time. Returns how many bytes it took to
    complete, or -1 when it never did."""
    var data = _bytes(text)
    for i in range(len(data)):
        if reader.feed(Span[UInt8, _](data)[i : i + 1]):
            return i + 1
    return -1


def test_a_length_body_completes_on_its_last_byte() raises:
    var reader = H1ResponseReader("GET")
    var text = String("HTTP/1.1 200 OK\r\nContent-Length: 5\r\n\r\nhello")
    assert_true(reader.got_nothing())
    assert_equal(_feed_one_by_one(reader, text), text.byte_length())
    assert_true(reader.reusable())
    var resp = reader.take()
    assert_true(reader.reusable())
    assert_equal(resp.status, 200)
    assert_equal(resp.text(), "hello")


def test_a_chunked_body_is_walked_chunk_by_chunk() raises:
    var reader = H1ResponseReader("GET")
    var text = String(
        "HTTP/1.1 200 OK\r\nTransfer-Encoding: chunked\r\n\r\n"
        "8\r\na\r\n0\r\nbc\r\n0\r\n\r\n"
    )
    assert_equal(_feed_one_by_one(reader, text), text.byte_length())
    assert_equal(reader.take().text(), "a\r\n0\r\nbc")


def test_informational_heads_are_read_past() raises:
    var reader = H1ResponseReader("GET")
    var text = String(
        "HTTP/1.1 103 Early Hints\r\nLink: </a>\r\n\r\n"
        "HTTP/1.1 201 Created\r\nContent-Length: 2\r\n\r\nok"
    )
    assert_true(reader.feed(Span[UInt8, _](_bytes(text))))
    assert_equal(reader.take().status, 201)


def test_no_body_responses_end_at_the_head() raises:
    var head = H1ResponseReader("HEAD")
    assert_true(
        head.feed(
            Span[UInt8, _](
                _bytes("HTTP/1.1 200 OK\r\nContent-Length: 9\r\n\r\n")
            )
        )
    )
    assert_equal(len(head.take().body), 0)
    var empty = H1ResponseReader("GET")
    assert_true(
        empty.feed(Span[UInt8, _](_bytes("HTTP/1.1 204 No Content\r\n\r\n")))
    )
    assert_true(empty.reusable())


def test_a_body_read_to_close_ends_with_the_stream() raises:
    var reader = H1ResponseReader("GET")
    assert_false(
        reader.feed(Span[UInt8, _](_bytes("HTTP/1.1 200 OK\r\n\r\nall of it")))
    )
    reader.end_of_stream()
    assert_false(reader.reusable())
    assert_equal(reader.take().text(), "all of it")


def test_an_unclean_tls_close_cannot_end_a_body() raises:
    var reader = H1ResponseReader("GET")
    _ = reader.feed(Span[UInt8, _](_bytes("HTTP/1.1 200 OK\r\n\r\npart")))
    with assert_raises(contains="close_notify"):
        reader.end_of_stream(unclean_tls=True)


def test_a_close_mid_message_says_where() raises:
    var nothing = H1ResponseReader("GET")
    with assert_raises(contains="no reply"):
        nothing.end_of_stream()
    var in_head = H1ResponseReader("GET")
    _ = in_head.feed(Span[UInt8, _](_bytes("HTTP/1.1 200 OK\r\n")))
    with assert_raises(contains="missing header terminator"):
        in_head.end_of_stream()
    var in_body = H1ResponseReader("GET")
    _ = in_body.feed(
        Span[UInt8, _](_bytes("HTTP/1.1 200 OK\r\nContent-Length: 9\r\n\r\nab"))
    )
    with assert_raises(contains="EOF in body"):
        in_body.end_of_stream()
    var in_chunks = H1ResponseReader("GET")
    _ = in_chunks.feed(
        Span[UInt8, _](
            _bytes(
                "HTTP/1.1 200 OK\r\nTransfer-Encoding: chunked\r\n\r\n5\r\nab"
            )
        )
    )
    with assert_raises(contains="EOF in chunked body"):
        in_chunks.end_of_stream()
    with assert_raises(contains="incomplete"):
        _ = in_chunks.take()


def test_reuse_needs_http11_no_close_and_nothing_after() raises:
    var closing = H1ResponseReader("GET")
    _ = closing.feed(
        Span[UInt8, _](
            _bytes(
                "HTTP/1.1 200 OK\r\nConnection: keep-alive, close\r\n"
                "Content-Length: 0\r\n\r\n"
            )
        )
    )
    assert_false(closing.reusable())
    var old = H1ResponseReader("GET")
    _ = old.feed(
        Span[UInt8, _](_bytes("HTTP/1.0 200 OK\r\nContent-Length: 0\r\n\r\n"))
    )
    assert_false(old.reusable())
    var extra = H1ResponseReader("GET")
    _ = extra.feed(
        Span[UInt8, _](
            _bytes("HTTP/1.1 200 OK\r\nContent-Length: 1\r\n\r\nxEXTRA")
        )
    )
    assert_false(extra.reusable())
    assert_equal(extra.take().text(), "x")
    assert_false(extra.reusable())


def test_bad_heads_and_bodies_raise() raises:
    var bare_lf = H1ResponseReader("GET")
    with assert_raises(contains="bare LF"):
        _ = bare_lf.feed(
            Span[UInt8, _](_bytes("HTTP/1.1 200 OK\nX: y\r\n\r\n"))
        )
    var both = H1ResponseReader("GET")
    with assert_raises(contains="Transfer-Encoding"):
        _ = both.feed(
            Span[UInt8, _](
                _bytes(
                    "HTTP/1.1 200 OK\r\nTransfer-Encoding: chunked\r\n"
                    "Content-Length: 3\r\n\r\n"
                )
            )
        )
    var chunks = H1ResponseReader("GET")
    with assert_raises(contains="malformed chunked"):
        _ = chunks.feed(
            Span[UInt8, _](
                _bytes(
                    "HTTP/1.1 200 OK\r\nTransfer-Encoding:"
                    " chunked\r\n\r\nzz\r\n"
                )
            )
        )
    var huge_head = H1ResponseReader("GET")
    var filler = String("HTTP/1.1 200 OK\r\nX: ") + String("a") * 70_000
    with assert_raises(contains="head too large"):
        _ = huge_head.feed(Span[UInt8, _](_bytes(filler)))


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
