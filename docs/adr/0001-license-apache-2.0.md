# ADR-0001: License dodo under Apache-2.0

- Status: accepted
- Date: 2026-10-26

## Context

dodo is meant for production use by companies, and it reuses MIT-licensed code from Lightbug. The Mojo standard library is Apache-2.0 with LLVM exceptions.

## Decision

dodo is licensed under Apache-2.0. Reused MIT code keeps its notice in `THIRD_PARTY_NOTICES.md`.

## Consequences

- Users get an explicit patent grant, which legal teams prefer.
- Every source file we copy from an MIT project keeps that project's copyright notice.
- Contributions are accepted under the same license (inbound = outbound). No CLA for now.

## Alternatives considered

- MIT: simpler, but has no patent grant.
- Dual MIT/Apache: common in Rust. It adds explanation overhead with no clear benefit for us.
