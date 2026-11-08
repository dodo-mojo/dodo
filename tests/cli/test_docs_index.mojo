"""Reading docs indexes: links, safe paths and short versions."""

from std.testing import (
    TestSuite,
    assert_equal,
    assert_false,
    assert_raises,
    assert_true,
)

from cli.docs_index import (
    has_scheme,
    index_links,
    is_safe_path,
    pick_version,
    saved_versions,
    version_parts,
    without_code_spans,
)


def test_links_of_an_llms_txt_index() raises:
    var text = String(
        "# Mojo 1.2.0\n\n> About.\n\n## Start here\n\n",
        "- [What changed](changes-in-1x.md): Old syntax.\n",
        "- [Lists](std/collections/list.md#append): The list.\n",
        "- [Again](changes-in-1x.md)\n",
    )
    var links = index_links(text)
    assert_equal(len(links), 2)
    assert_equal(links[0], "changes-in-1x.md")
    assert_equal(links[1], "std/collections/list.md")


def test_web_addresses_and_bare_anchors_are_not_files() raises:
    var text = (
        "[a](https://mojolang.org/) [b](mailto:x@y.z) [c](#top) [d](d.md)"
    )
    var links = index_links(text)
    assert_equal(len(links), 1)
    assert_equal(links[0], "d.md")


def test_links_in_code_are_not_files() raises:
    var text = String(
        "Write `[a](a.md)` or ``[b](b.md)`` here.\n",
        "```markdown\n[c](c.md)\n```\n",
        "~~~\n[d](d.md)\n~~~\n",
        "[e](e.md)\n",
    )
    var links = index_links(text)
    assert_equal(len(links), 1)
    assert_equal(links[0], "e.md")


def test_a_link_title_is_not_part_of_the_target() raises:
    var links = index_links('[a](a.md "The title")')
    assert_equal(len(links), 1)
    assert_equal(links[0], "a.md")


def test_unsafe_targets_are_still_listed() raises:
    # The caller rejects them, so a bad index is reported, not skipped.
    var links = index_links("[a](../secret.md) [b](/etc/passwd)")
    assert_equal(len(links), 2)
    assert_equal(links[0], "../secret.md")
    assert_equal(links[1], "/etc/passwd")


def test_code_spans_are_cut_out() raises:
    assert_equal(without_code_spans("a `b` c"), "a  c")
    assert_equal(without_code_spans("a `` ` `` c"), "a  c")
    assert_equal(without_code_spans("a ``b` c"), "a ``b` c")
    assert_equal(without_code_spans("no code"), "no code")
    assert_equal(without_code_spans("`x`"), "")


def test_has_scheme() raises:
    assert_true(has_scheme("https://x"))
    assert_true(has_scheme("mailto:a"))
    assert_false(has_scheme("std/list.md"))
    assert_false(has_scheme(":x"))
    assert_false(has_scheme("C1:x"))


def test_safe_paths() raises:
    assert_true(is_safe_path("index.md"))
    assert_true(is_safe_path("std/collections/list.md"))
    assert_true(is_safe_path("LICENSE.txt"))
    assert_true(is_safe_path("manual/get-started_2.md"))


def test_unsafe_paths() raises:
    assert_false(is_safe_path(""))
    assert_false(is_safe_path("/etc/passwd"))
    assert_false(is_safe_path("../x.md"))
    assert_false(is_safe_path("a/../../x.md"))
    assert_false(is_safe_path("a/./x.md"))
    assert_false(is_safe_path("a//x.md"))
    assert_false(is_safe_path("a/"))
    assert_false(is_safe_path(".hidden"))
    assert_false(is_safe_path("a/.git/config"))
    assert_false(is_safe_path("a\\b.md"))
    assert_false(is_safe_path("a b.md"))
    assert_false(is_safe_path("a%2e%2e/b.md"))
    assert_false(is_safe_path("café.md"))


def test_version_parts() raises:
    var parts = version_parts("1.2.0")
    assert_equal(len(parts), 3)
    assert_equal(parts[1], 2)
    assert_equal(len(version_parts("1")), 1)
    with assert_raises(contains="not a version"):
        _ = version_parts("")
    with assert_raises(contains="not a version"):
        _ = version_parts("1.2.0.1")
    with assert_raises(contains="not a version"):
        _ = version_parts("1..2")
    with assert_raises(contains="not a version"):
        _ = version_parts("v1.2")
    with assert_raises(contains="not a version"):
        _ = version_parts("1.2.x")
    with assert_raises(contains="not a version"):
        _ = version_parts("1.-2")
    with assert_raises(contains="not a version"):
        _ = version_parts("99999999999999999999")


def test_pick_version_takes_the_newest_match() raises:
    var saved: List[String] = ["1.2.0", "1.10.1", "1.2.3", "1.10.0", "2.0.0"]
    assert_equal(pick_version("1.2", saved), "1.2.3")
    assert_equal(pick_version("1.2.0", saved), "1.2.0")
    assert_equal(pick_version("1", saved), "1.10.1")
    assert_equal(pick_version("1.10", saved), "1.10.1")
    assert_equal(pick_version("2", saved), "2.0.0")


def test_pick_version_finds_nothing() raises:
    var saved: List[String] = ["1.2.0", "nightly", "1.3"]
    assert_equal(pick_version("1.3", saved), "")
    assert_equal(pick_version("1.2.1", saved), "")
    assert_equal(pick_version("1.2", List[String]()), "")
    with assert_raises(contains="not a version"):
        _ = pick_version("latest", saved)


def test_saved_versions() raises:
    var text = String(
        "# Mojo docs saved by dodo\n\n",
        "- [Mojo 1.3.0](1.3.0/index.md)\n",
        "- [Mojo 1.2.0](1.2.0/index.md)\n",
        "- [Notes](notes.md)\n",
        "- [Deep](a/b/index.md)\n",
    )
    var versions = saved_versions(text)
    assert_equal(len(versions), 2)
    assert_equal(versions[0], "1.3.0")
    assert_equal(versions[1], "1.2.0")


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
