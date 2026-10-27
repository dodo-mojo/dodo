# Engineering standards

These apply to everyone working on dodo, human or agent. Change them through a PR like any other code.

## 1. Code

Readable code is the goal. The best code is the easiest to read and still does the job just as well.

- **Write it plainly.** Use a normal `if`/`else` instead of a dense conditional expression. Use named intermediate variables instead of long chains. Don't squeeze logic into one-liners.
- **One function, one job.** If a function needs a comment to explain its sections, split it.
- **Names say what things are.** Use `header_end`, not `he`. Use `is_chunked`, not `flag`.
- **No cleverness without a measurement.** A faster but harder-to-read version is allowed only with a benchmark showing it matters, and a comment linking to that benchmark.
- **Comments explain why, not what.** The code already says what it does.
- **Never crash on input.** Bad bytes, bad clients and bad load return an error. They never take down the process.
- **Every bug fix ships with a regression test** that fails before the fix.

Example:

```mojo
# Don't
var t = cfg.body_timeout if cfg.body_timeout > 0 else (cfg.idle if cfg.idle > 0 else DEFAULT)

# Do
var timeout = DEFAULT
if cfg.body_timeout > 0:
    timeout = cfg.body_timeout
elif cfg.idle > 0:
    timeout = cfg.idle
```

## 2. Tests

- Unit tests for every module. Conformance tests for protocol behavior. Fuzzing for every parser.
- Every user-facing input field and button is tested in a real browser against its edge cases: empty, whitespace only, very long, Unicode and emoji, HTML and script injection, SQL-like strings, negative and huge numbers, paste, double-submit, slow network, and keyboard-only use. Claude runs these in its built-in browser before calling UI work done.
- Performance claims need a reproducible benchmark committed in `bench/`.

## 3. Performance

dodo aims to be fast, so speed is reviewed like correctness.

- **Measure first.** Profile before optimizing, and before removing something for speed. Any PR that touches the request hot path shows benchmark numbers from before and after.
- **The hot path stays lean.** No allocation per request on the plaintext path, no needless copies, and as few syscalls per request as possible. A feature that isn't in use costs nothing.
- **Cut what we don't need.** Code with no user on the roadmap is deleted, not kept "just in case".
- **Benchmark on bare-metal Linux.** WSL2 is fine for development, but its clock and network distort results.
- **Simple stays the default.** A faster version that's hard to read needs numbers that justify it, and a comment saying why.

## 4. Documentation

- Everything is documented in `docs/`. Plain Markdown, one topic per file.
- **ADRs** (`docs/adr/`) are only for major decisions: architecture, dependencies we build on, public API shape, licensing, and protocol scope. Use [the template](adr/0000-template.md). Small changes and follow-ups go in `TODO.md` or the issue tracker, not in ADRs.
- `CLAUDE.md` is the agent's map of the repo. Update it whenever a decision, layout or command changes. Keep it short: it links to docs and doesn't copy them.

## 5. Commits and PRs

- Commit message format: `type: one line, straight to the point`.
  - Types: `feat`, `fix`, `docs`, `test`, `refactor`, `perf`, `build`, `ci`, `chore`.
  - Lowercase after the colon, no trailing period, and **no em dashes, ever**.
  - No commit body. The extended description goes in the PR.
- Never add AI co-author trailers (no `Co-Authored-By: Claude`).
- PRs: a title in the same format, plus a description covering what changed, why, how it was tested, and any follow-ups.

## 6. Working with the human

An LLM can plan and reason about many things at once. A human can't. Protect the human's attention:

- Ask **one decision at a time**. Give a recommendation, wait for the answer, then move to the next.
- Planning can be big. Decisions and iterations put to the human stay small.
- Lead with the outcome. Keep everything else short.
