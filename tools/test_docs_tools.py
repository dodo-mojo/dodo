"""Tests for the docs converters: `python3 -m unittest tools/test_docs_tools.py`."""

import unittest

import mdx_to_md


def tag(target: str) -> str:
    return "X" + target


class CodeSpanTest(unittest.TestCase):
    def test_a_double_backtick_span_holds_a_backtick(self) -> None:
        found = [m.group(0) for m in mdx_to_md.CODE_SPAN.finditer("a `` ` `` b")]
        self.assertEqual(found, ["`` ` ``"])

    def test_a_span_may_run_over_a_line_break(self) -> None:
        found = [m.group(0) for m in mdx_to_md.CODE_SPAN.finditer("`mojo\nbuild` `x`")]
        self.assertEqual(found, ["`mojo\nbuild`", "`x`"])


class RewriteLinksTest(unittest.TestCase):
    def test_a_plain_link_is_rewritten(self) -> None:
        text = "See [the guide](/docs/manual/)."
        got = mdx_to_md.rewrite_links(text, tag)
        self.assertEqual(got, "See [the guide](X/docs/manual/).")

    def test_a_link_whose_words_are_code_is_rewritten(self) -> None:
        text = "Run [`mojo build`](/docs/cli/build/) first."
        got = mdx_to_md.rewrite_links(text, tag)
        self.assertEqual(got, "Run [`mojo build`](X/docs/cli/build/) first.")

    def test_brackets_inside_the_words_are_kept(self) -> None:
        text = "See [`OwnedPointer[Int]`](/docs/std/memory/) here."
        got = mdx_to_md.rewrite_links(text, tag)
        self.assertEqual(got, "See [`OwnedPointer[Int]`](X/docs/std/memory/) here.")

    def test_a_link_whose_code_words_wrap_a_line_is_rewritten(self) -> None:
        text = "use [`mojo\nbuild`](/docs/cli/build), then `program`"
        got = mdx_to_md.rewrite_links(text, tag)
        self.assertEqual(got, "use [`mojo\nbuild`](X/docs/cli/build), then `program`")

    def test_code_is_never_changed(self) -> None:
        text = "Write `[a](b)` in code.\n\n```mojo\n[c](d)\n```\n"
        got = mdx_to_md.rewrite_links(text, tag)
        self.assertEqual(got, text)

    def test_the_dark_copy_of_an_image_is_dropped(self) -> None:
        text = "![Plot](/img/light.png) ![Plot](/img/dark.png#dark)"
        got = mdx_to_md.rewrite_links(text, lambda target: target)
        self.assertEqual(got, "![Plot](/img/light.png) ")

    def test_a_link_title_is_kept(self) -> None:
        text = '[a](/docs/x/ "Title")'
        got = mdx_to_md.rewrite_links(text, tag)
        self.assertEqual(got, '[a](X/docs/x/ "Title")')


if __name__ == "__main__":
    unittest.main()
