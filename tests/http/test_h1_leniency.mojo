"""Tests for ``dodo.http.proto._ExperimentalH1LeniencyConfig``.

The struct is the public API contract; parser plumbing for each
flag is not wired yet. These tests pin the public surface so
the contract can't drift before the plumbing lands.
"""

from std.testing import assert_equal, assert_false, assert_true

from dodo.http.proto import _ExperimentalH1LeniencyConfig


def test_default_is_strict() raises:
    var c = _ExperimentalH1LeniencyConfig()
    assert_false(c.allow_lf_only_line_endings)
    assert_false(c.allow_mixed_case_method)
    assert_false(c.allow_ows_around_colon)
    assert_false(c.allow_obs_fold)
    assert_false(c.allow_oversized_request_uri)
    assert_false(c.allow_oversized_header_list)
    assert_false(c.accept_empty_chunk_extensions)
    assert_false(c.allow_multiple_content_length)
    assert_false(c.allow_te_chunked_when_cl_present)
    assert_false(c.accept_obs_text_in_field_value)
    assert_false(c.accept_invalid_chunk_extension_chars)
    assert_false(c.allow_leading_whitespace_before_request_line)
    assert_false(c.any_enabled())


def test_strict_factory() raises:
    var c = _ExperimentalH1LeniencyConfig.strict()
    assert_false(c.any_enabled())


def test_individual_flags_toggle() raises:
    # Spot-check that each flag is independently settable and
    # surfaces through ``any_enabled``.
    var c0 = _ExperimentalH1LeniencyConfig(allow_lf_only_line_endings=True)
    assert_true(c0.allow_lf_only_line_endings)
    assert_false(c0.allow_mixed_case_method)
    assert_true(c0.any_enabled())

    var c1 = _ExperimentalH1LeniencyConfig(allow_mixed_case_method=True)
    assert_true(c1.allow_mixed_case_method)
    assert_true(c1.any_enabled())

    var c2 = _ExperimentalH1LeniencyConfig(allow_ows_around_colon=True)
    assert_true(c2.allow_ows_around_colon)
    assert_true(c2.any_enabled())

    var c3 = _ExperimentalH1LeniencyConfig(allow_obs_fold=True)
    assert_true(c3.allow_obs_fold)
    assert_true(c3.any_enabled())

    var c4 = _ExperimentalH1LeniencyConfig(allow_oversized_request_uri=True)
    assert_true(c4.allow_oversized_request_uri)
    assert_true(c4.any_enabled())

    var c5 = _ExperimentalH1LeniencyConfig(allow_oversized_header_list=True)
    assert_true(c5.allow_oversized_header_list)
    assert_true(c5.any_enabled())

    var c6 = _ExperimentalH1LeniencyConfig(accept_empty_chunk_extensions=True)
    assert_true(c6.accept_empty_chunk_extensions)
    assert_true(c6.any_enabled())

    var c7 = _ExperimentalH1LeniencyConfig(allow_multiple_content_length=True)
    assert_true(c7.allow_multiple_content_length)
    assert_true(c7.any_enabled())

    var c8 = _ExperimentalH1LeniencyConfig(
        allow_te_chunked_when_cl_present=True
    )
    assert_true(c8.allow_te_chunked_when_cl_present)
    assert_true(c8.any_enabled())

    var c9 = _ExperimentalH1LeniencyConfig(accept_obs_text_in_field_value=True)
    assert_true(c9.accept_obs_text_in_field_value)
    assert_true(c9.any_enabled())

    var c10 = _ExperimentalH1LeniencyConfig(
        accept_invalid_chunk_extension_chars=True
    )
    assert_true(c10.accept_invalid_chunk_extension_chars)
    assert_true(c10.any_enabled())

    var c11 = _ExperimentalH1LeniencyConfig(
        allow_leading_whitespace_before_request_line=True
    )
    assert_true(c11.allow_leading_whitespace_before_request_line)
    assert_true(c11.any_enabled())


def test_combined_flags_compose() raises:
    var c = _ExperimentalH1LeniencyConfig(
        allow_lf_only_line_endings=True,
        allow_mixed_case_method=True,
    )
    assert_true(c.allow_lf_only_line_endings)
    assert_true(c.allow_mixed_case_method)
    assert_false(c.allow_ows_around_colon)
    assert_true(c.any_enabled())


def test_copy_and_move() raises:
    var c = _ExperimentalH1LeniencyConfig(allow_obs_fold=True)
    var copied = c.copy()
    assert_true(copied.allow_obs_fold)
    var moved = c^
    assert_true(moved.allow_obs_fold)


def main() raises:
    test_default_is_strict()
    test_strict_factory()
    test_individual_flags_toggle()
    test_combined_flags_compose()
    test_copy_and_move()
    print("test_h1_leniency: OK")
