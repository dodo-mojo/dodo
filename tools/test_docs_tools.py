"""Tests for the docs converters: `python3 -m unittest tools/test_docs_tools.py`."""

import unittest

import api_to_md
import mdx_to_md
import save_docs


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


class WithRaisesTest(unittest.TestCase):
    def test_raises_goes_after_the_arguments(self) -> None:
        got = api_to_md.with_raises("def f(x: Int) -> Int")
        self.assertEqual(got, "def f(x: Int) raises -> Int")

    def test_no_return_type(self) -> None:
        self.assertEqual(api_to_md.with_raises("def g()"), "def g() raises")

    def test_parameters_and_closure_arguments(self) -> None:
        got = api_to_md.with_raises("def h[n: Int](f: def(Int) -> Int) -> Int where (n > Int(0))")
        self.assertEqual(got, "def h[n: Int](f: def(Int) -> Int) raises -> Int where (n > Int(0))")

    def test_brackets_in_a_default_string(self) -> None:
        got = api_to_md.with_raises('def j(s: String = ")", t: List[Int] = []) -> Int')
        self.assertEqual(got, 'def j(s: String = ")", t: List[Int] = []) raises -> Int')

    def test_an_unreadable_signature_is_kept(self) -> None:
        self.assertEqual(api_to_md.with_raises("def k(x: Int"), "def k(x: Int")
        self.assertEqual(api_to_md.with_raises("k"), "k")

    def test_a_raising_function_page_says_raises(self) -> None:
        decl = {"name": "f", "overloads": [{"signature": "def f() -> Int", "raises": True}]}
        self.assertIn("def f() raises -> Int", "\n".join(api_to_md._function(decl, "###", "")))

    def test_a_function_that_does_not_raise_is_unchanged(self) -> None:
        decl = {"name": "f", "overloads": [{"signature": "def f() -> Int", "raises": False}]}
        self.assertIn("def f() -> Int", "\n".join(api_to_md._function(decl, "###", "")))


class FenceIndentedCodeTest(unittest.TestCase):
    def test_a_block_under_a_colon_line_is_fenced(self) -> None:
        text = "Example:\n    var v = f[T](x)\n    g()\n\nAfter."
        want = "Example:\n\n```mojo\nvar v = f[T](x)\ng()\n```\n\nAfter."
        self.assertEqual(api_to_md.fence_indented_code(text), want)

    def test_blank_lines_inside_the_block_stay(self) -> None:
        text = "Example:\n\n    a()\n\n    b()\n"
        want = "Example:\n\n\n```mojo\na()\n\nb()\n```\n"
        self.assertEqual(api_to_md.fence_indented_code(text), want)

    def test_deeper_lines_keep_their_extra_indent(self) -> None:
        text = "Example:\n    if x:\n        y()"
        want = "Example:\n\n```mojo\nif x:\n    y()\n```\n"
        self.assertEqual(api_to_md.fence_indented_code(text), want)

    def test_fenced_code_is_left_alone(self) -> None:
        text = "Example:\n```mojo\n    indented()\n```"
        self.assertEqual(api_to_md.fence_indented_code(text), text)

    def test_a_list_item_continuation_is_not_code(self) -> None:
        text = "- one thing:\n    more about it"
        self.assertEqual(api_to_md.fence_indented_code(text), text)

    def test_lines_right_under_example_are_code(self) -> None:
        text = "Example:\nvar v = f[T](x)\nprint(v)\n\nAfter."
        want = "Example:\n\n```mojo\nvar v = f[T](x)\nprint(v)\n```\n\n\nAfter."
        self.assertEqual(api_to_md.fence_indented_code(text), want)

    def test_a_fence_right_under_example_is_left_alone(self) -> None:
        text = "Example:\n```mojo\nf()\n```"
        self.assertEqual(api_to_md.fence_indented_code(text), text)

    def test_a_docstring_section_is_not_code(self) -> None:
        text = "Fields:\n    name: what it holds\n\nReturns:\n    The thing."
        self.assertEqual(api_to_md.fence_indented_code(text), text)

    def test_indent_after_a_plain_sentence_is_not_code(self) -> None:
        text = "A sentence.\n    still the sentence"
        self.assertEqual(api_to_md.fence_indented_code(text), text)


class ReleaseLinkTest(unittest.TestCase):
    def test_a_link_inside_the_docs_is_kept(self) -> None:
        self.assertEqual(save_docs.release_link("cli.md#exit-codes", "design.md", "1.0.0"), "cli.md#exit-codes")
        self.assertEqual(save_docs.release_link("../design.md", "adr/0001-x.md", "1.0.0"), "../design.md")

    def test_a_link_out_of_the_docs_goes_to_github_at_the_tag(self) -> None:
        got = save_docs.release_link("../research/db-spikes", "app-layer-audit.md", "1.0.0")
        self.assertEqual(got, "https://github.com/dodo-mojo/dodo/tree/v1.0.0/research/db-spikes")
        got = save_docs.release_link("../../README.md#roadmap", "adr/0001-x.md", "1.0.0")
        self.assertEqual(got, "https://github.com/dodo-mojo/dodo/blob/v1.0.0/README.md#roadmap")

    def test_web_links_and_anchors_are_kept(self) -> None:
        self.assertEqual(save_docs.release_link("https://x.dev/", "a.md", "1.0.0"), "https://x.dev/")
        self.assertEqual(save_docs.release_link("#top", "a.md", "1.0.0"), "#top")


if __name__ == "__main__":
    unittest.main()
