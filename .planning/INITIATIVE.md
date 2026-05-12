# Initiative: Multi-mode AI code review and audit platform

This document captures the strategic context for the autonomous build
of the multi-mode platform on top of `agentic-ops`. It is the entry
point for anyone joining the initiative — start here, then read
`PHASE-MAP.md` for the sequence and the relevant `phases/PN-*.md`
for execution-level detail.

The autonomous-execution machinery (driver loop, state schema,
checkpoint protocol, session management) lives in
`EXECUTION-MODEL.md`. The cross-cutting rules an executor must obey
live in `GUARDRAILS.md` and `HUMAN-GATES.md`. Risks are tracked in
`RISK-REGISTER.md`.

The single canonical plan file is snapshotted at
`auto-execution/PLAN-snapshot.md` for historical reference; this
directory's docs are the living, reviewable presentation of the
same content.

## Why this exists

`loganrooks/agentic-ops` is the centralized substrate for AI-led PR
review across `loganrooks/*`. As of the start of this initiative it
has one capability: focused-pass diff review (`@claude review` and
four siblings: `quick`, `deep`, `gates`, `opus`). Two needs are not
covered:

1. **Large-PR review.** CBM PR #1 is 353 files / 52,125 additions /
   311 deletions — the H1 / Phase A closeout. The single-shot
   reviewer cannot read it attentively. The current `review` mode
   caps at 15 files. A spatial-decomposition mode (`survey`) is
   needed.
2. **Whole-codebase auditing.** Questions like "are we set up well
   to proceed in Phase B?", "what tech debt should we refactor?",
   "is the workspace organized for agential development?" don't
   map to a diff. A mode that reads codebase + roadmap + ADRs +
   AGENTS.md and returns a structured assessment is needed
   (`audit`).

## Forcing functions

- **Proximate.** Judge whether CBM PR #1 is a defensible base for
  Phase B. The audit modes need to surface tech-debt / structural
  problems before more work piles on.
- **Strategic.** Build a generic platform reusable across
  `loganrooks/prix-guesser`, `arxiv-sanity-mcp`, `f1-modeling`,
  `epistemic-agency`, `scholardoc`, plus `vigil` and `agentic-ops`
  itself per [ADR-009](../docs/adr/ADR-009-consumer-cap-relaxation.md).
  The forcing function is not CBM-specific; multi-vendor and
  multi-repo are first-class requirements.
- **Quality bar.** Senior software engineers, AI researchers, and
  AI systems developers will review this work. That sets
  requirements for ADRs, threat models, pinned action SHAs,
  self-CI, and empirical validation gates.

## Non-goals

- Not a CodeRabbit replacement. The platform composes WITH
  CodeRabbit (and Codex) — different reviewers catch different
  failure modes; running both on the same PR is the discipline.
- Not a SaaS product. This is personal-tooling-in-public-repo. See
  `OPEN_QUESTIONS.md` OQ-1.
- Not a code-execution sandbox. "Path B" — sandboxed test execution
  on PR head — is deferred. See `docs/adr/ADR-004-allowlist-policy.md`.
- Not a replacement for the existing `review`/`quick`/`deep`/`gates`/
  `opus` modes. Additive only.

## Pre-resolved decisions

These were decided up front and do not require human input during
autonomous execution:

| Decision | Choice |
|---|---|
| License | Apache-2.0 |
| Parallelism approach | L1 → L3 ladder (skip L2 — see ADR-002) |
| Default model for survey/audit lens jobs | `claude-sonnet-4-6` (1M ctx) |
| Default model for audit synthesis | `claude-opus-4-7` |
| Tag policy | `v1` floating + additivity contract; breaking → `v2` |
| Severity scheme | deferred per OQ-7 |
| Output format | comment by default, multi-comment split for long; artifact path deferred |

## Architectural decisions captured as ADRs

| ID | Decision | Status |
|---|---|---|
| ADR-001 | Mode taxonomy: 5 existing + `survey` + `audit`; audit has lens registry | accepted; amended by ADR-008 |
| ADR-002 | Parallelism via GHA matrix fan-out (skip L2) | accepted; partially superseded by ADR-008 (re: L3 routing) |
| ADR-003 | Versioning: `v1` floating + additivity; `v2` for breaking | accepted |
| ADR-004 | Allowlist: narrow now; `extra_allowed_tools` for static analysis only | accepted |
| ADR-005 | Audit/survey output: comment + multi-comment split if needed | accepted (provisional); amended by ADR-008 |
| ADR-006 | Deployment scope bounded to internal consumers until OQ-1 resolves | accepted; partially superseded by ADR-009 (re: §2 consumer cap) |
| ADR-007 | Threat-model gating for wide deployment | accepted |
| ADR-008 | L3 mode variants — explicit-trigger routing + naming | accepted |
| ADR-009 | Consumer cap relaxation — named-internal-consumer set raised from 6 to 8 | accepted |

For the canonical, always-current list, see [`docs/adr/`](../docs/adr/).

Cross-cutting commitments (defense-in-depth guardrails, self-CI) are
documented in `SECURITY.md` and the CI workflow itself, not as
dedicated ADRs.

## Done definition

The initiative is DONE when ALL of:

- Every reachable phase (P0..P9) has a checkpoint file in
  `auto-execution/checkpoints/`
- All checkpoints are verified
- No unresolved escalations
- `agentic-ops` main has `v1` tag pointing at the latest expected
  merge SHA
- `auto-execution/DONE.md` exists with a completion summary

DONE.md is the contract. If it doesn't exist, the initiative isn't
done.
