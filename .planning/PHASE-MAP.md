# Phase map

The initiative is broken into ten phases (P0..P9). Phases land as
separate PRs, each with its own checkpoint file in
`auto-execution/checkpoints/CHECKPOINT-PN.md` after merge. Per-phase
task definitions live in `phases/PN-*.md`.

## Sequence

```text
P0  Bootstrap (auto-execution infra setup)
  ↓
P1  A0 — Project hygiene (LICENSE, CONTRIBUTING, AGENTS, SECURITY, CI, ADRs)
  ↓                    [HUMAN-GATE-1: enable auto-merge in repo settings]
                       [P1.5: docs restructure + CodeRabbit + branch protection]
P2  A — Survey mode L1 (single-agent Phase 1-4 prompt)
  ↓
P3  B — Audit mode L1 (whole-codebase, lens-based)
  ↓
P4  C — extra_allowed_tools input (static-analysis extension)
  ↓                    [EMPIRICAL-GATE: trigger survey on CBM PR #1,
                        audit on CBM main; collect data]
P5  D — Survey mode L3 (matrix fan-out) — conditional on empirical signal
  ↓
P6  E — Audit mode L3 (matrix fan-out per lens) — conditional on D succeeding
  ↓
P7  F — Onboarding 7 internal consumers (per ADR-009)
  ↓
P8  G — Observability + cost monitoring
  ↓
P9  Final — DONE.md, summary, archive
```

## Per-phase summary

| Phase | Goal | Branch | Detail |
|---|---|---|---|
| **P0** | Stand up `.planning/auto-execution/` state files | n/a (no PR; state init) | `phases/P0-bootstrap.md` |
| **P1** | LICENSE, CONTRIBUTING, AGENTS, SECURITY, CI, dispatcher smoke, 5 ADRs | `feat/p1-project-hygiene` | `phases/P1-project-hygiene.md` |
| **P1.5** | Docs restructure into reviewable units, `.coderabbit.yaml`, branch protection | `chore/p1.5-docs-restructure` | `phases/P1.5-docs-restructure.md` |
| **P2** | `survey` mode L1 (Phase 1-4 single-agent spatial decomposition) | `feat/p2-survey-mode` | `phases/P2-survey-mode-l1.md` |
| **P3** | `audit` mode L1 + trigger-surface widening for issue comments | `feat/p3-audit-mode` | `phases/P3-audit-mode-l1.md` |
| **P4** | `extra_allowed_tools` input + allowlist composition step | `feat/p4-extra-allowed-tools` | `phases/P4-extra-allowed-tools.md` |
| EMPIRICAL-GATE | Run survey + audit on CBM artifacts; decide whether L3 is needed | n/a (decision file) | `phases/EMPIRICAL-GATE.md` |
| **P5** | `survey` L3: zone-map → matrix per zone → synthesis (conditional) | `feat/p5-survey-l3` | `phases/P5-survey-mode-l3.md` |
| **P6** | `audit` L3: lens-plan → matrix per lens → opus synthesis (conditional) | `feat/p6-audit-l3` | `phases/P6-audit-mode-l3.md` |
| **P7** | Onboard 7 internal consumers (prix-guesser, arxiv-sanity-mcp, f1-modeling, epistemic-agency, scholardoc, vigil, agentic-ops self-consumer) per [ADR-009](../docs/adr/ADR-009-consumer-cap-relaxation.md) via per-repo caller stubs | one branch per target repo | `phases/P7-onboarding.md` |
| **P8** | Aggregator workflow, missed-signal template, observability docs | `feat/p8-observability` | `phases/P8-observability.md` |
| **P9** | DONE.md, archive auto-execution state, final commit | `chore/p9-archive-<timestamp>` | `phases/P9-final.md` |

## Dependency rules

- **P1 must complete before P2.** CI workflow needs to exist to gate
  later PRs. (Done.)
- **P1.5 must complete before P2.** Review discipline (CodeRabbit +
  branch protection) must be in place before security-sensitive PRs
  (P2/P3/P4 touch `review.yml` and the dispatcher).
- **P2 must complete before P3.** P2 validates the mode-addition
  mechanics; P3 builds on the same shape.
- **P3 must complete before P4.** Audit mode may want to consume
  static-analysis tools, so it makes sense to land audit first then
  add `extra_allowed_tools` once the consumption pattern is clear.
- **P5/P6 are conditional.** Run only if the EMPIRICAL-GATE produces
  signal that L1 isn't enough.
- **P7 can start in parallel with P5/P6** — onboarding is
  independent of the L3 work.
- **P8 starts after P7** — needs multiple repos consuming for
  observability to be meaningful.
- **P9 only when all reachable phases COMPLETE** (where "reachable"
  includes phases marked `skipped` per the empirical gate).

## Notes on the unplanned P1.5

P1.5 was added after P1 merged. It captures the docs restructure
into reviewable per-phase docs, the addition of `.coderabbit.yaml`
to enable CodeRabbit reviews on this repo, and the application of
branch protection on `main`. This phase is not part of the original
plan; it is a course-correction toward harder review discipline
before the security-sensitive P2/P3/P4 phases land.

The decimal-numbering convention (P1.5) signals "inserted between
P1 and P2 without renumbering downstream phases" — the original
plan's numbering and detail are preserved.

## Conditional future phases (post-OQ-1 resolution)

The roadmap above (P0..P9) is bounded by `docs/adr/ADR-006-bounded-
deployment-scope.md` to internal `loganrooks/*` consumers. **No
phases beyond P9 are planned at present.**

If/when `OPEN_QUESTIONS.md` OQ-1 resolves toward "open-source
product" — and ADR-006's trigger conditions for revisiting are met
— wide-deployment-readiness work will be planned. The shape of that
work is itself an open question tracked as OQ-11 ("Wide-deployment
readiness shape"); possible shapes are a spike phase, a full-stack
readiness phase, or piecemeal-as-need-surfaces. The current leaning
in OQ-11 is piecemeal.

TC-7..TC-11 mitigations named in `docs/adr/ADR-007-threat-model-
gating.md` (schema validation on workflow_call inputs, an
`extra_allowed_tools` deny-list, `v1` tag ruleset, delayed-update
window, canary split, identity verification, per-consumer
credentials, adversarial-content markers in audit/survey prompts)
are **preconditions for external rollout / adoption**, not for the
readiness work that creates them. A future readiness phase whose
purpose is to *implement* TC-7..TC-11 is not gated on TC-7..TC-11
already shipping; it is the phase doing the shipping. What is gated
is any phase that *exposes* the substrate beyond bounded scope:
onboarding announcements, marketplace listings, public install docs,
external-adopter onboarding flows. Those phases require TC-7..TC-11
already merged.

None of the mitigations themselves are in scope for P0..P9 — the
P0..P9 roadmap is bounded by ADR-006 to internal `loganrooks/*` and
does not need them.

The shape of the auth model under wide deployment (workspace OAuth,
API-key billing, BYO-token, or other) is reserved for a separate
ADR if/when needed; ADR-006 commits the substrate to plan auth +
single principal until that ADR exists.

This section will be replaced (not edited in place) when a concrete
wide-deployment phase is added.
