# ADR-010: Effort level — orthogonal dial across modes

Status: accepted
Date: 2026-05-15
Related: ADR-001 (mode taxonomy), ADR-003 (versioning and release), ADR-008 (L3 mode variants)

## Context

ADR-001 defined seven review modes — `review`, `quick`, `deep`, `gates`,
`opus`, `survey`, `audit` — each with its own per-mode budgets and a
model selected by the dispatcher case statement (most default to
`claude-sonnet-4-6`; `opus` selects `claude-opus-4-7`).

Empirical experience on `loganrooks/codebase-mapper` PR #1 (the H1
close, 354 files, ~52K additions) surfaced a load-bearing limitation:
`survey` mode, designed exactly for this PR shape, missed a P1
gate-correctness bug (a missing scope-match check in
`checkpoint_pass_claim_issues`) that `chatgpt-codex-connector` caught
inline. Diagnosis: the survey prompt's Phase 2 budget caps file
attention at "≤6 files per zone" and the model gave the 6353-line
`cli.py` surface attention without drilling to the specific function.
The mode was correct for the PR shape; the per-file attention was what
bound.

The natural remediation paths are:

1. **Switch to `gates` or `opus`** for the specific failure mode. This
   works but requires the caller to know which mode catches which class
   of bug, and to chain multiple reviews. It also fails the
   "what-mode-for-which-PR" mapping that consumers are still building
   intuition for.
2. **Bump per-mode budgets globally.** Rejected by ADR-001 as
   structural ("a 15-file cap that keeps focus becomes a 60-file cap
   that does not"). Pure cap-bumping does not change attention shape.
3. **Add a model override on individual modes.** Adds N inputs (one
   per mode) and creates a combinatorial matrix of mode × model
   selections without a clean default. Hard to document, hard to
   reason about.
4. **Add an orthogonal effort dial** that scales model selection and
   the prompt's per-mode caps together. Mode keeps its prompt structure
   (the right axis for "what kind of review"); effort scales the
   intensity of that review. One input, three values, clear semantics.

This ADR adopts path 4.

## Decision

Add a new optional input `effort_level: "default" | "high" | "max"` to
`review.yml`. Default preserves existing behavior — this is additive
per ADR-003 and lands on `v1`.

### Semantics

**`default`** (existing behavior).

- Model: per the mode dispatcher case statement.
- Budgets: as written in the per-mode prompt.

**`high`**.

- Model: `claude-opus-4-7` for every mode **except** `quick`. `quick`
  stays on `claude-sonnet-4-6` because its purpose is the routine
  low-friction sanity scan; promoting it would defeat the mode.
- Budgets: the per-mode file caps are interpreted as ~1.5x. Survey
  zones may grow to 10 (vs 8 default); per-zone files to 9 (vs 6).
  Audit total files may grow to 27 (vs 18). The model is told to
  spend up to 1.5x time on known load-bearing files.
- Use case: high-stakes PRs where the cost of a missed finding is
  worse than the marginal compute.

**`max`**.

- Model: `claude-opus-4-7` for **all** modes including `quick`.
- Budgets: per-mode caps are removed in the prompt directive. The
  workflow `timeout_minutes` becomes the only hard cap.
- The prompt explicitly lowers the bar for surfacing findings:
  low-confidence findings are included with confidence flags;
  false-positive findings are preferred over false-negative misses.
- Pattern-match list expanded: missing checks in newly-added gate
  functions, reader/writer field-name drift, ADR contradictions,
  silent-fallback branches, durable-side-effect-before-validation
  ordering, off-by-one in cap logic, scope-of-checkpoint-vs-scope-of-gate
  mismatches, any new "skip" / "tolerate" / "fallback" branch.
- Use case: horizon closeouts, large diffs, post-incident audits,
  one-off "spend the budget" passes when the user has compute headroom.

### Implementation

The dispatcher step in `review.yml` adds an `effort` output computed
from the validated input. The model selection is overridden in the
same step (after the mode case picks the per-mode model). A new
`effort_block` is assembled in the prompt-fragments step and injected
near the top of the main prompt so the model reads the effort directive
before the per-mode caps in the mode-behavior section.

Validation: unknown `effort_level` values fail the step with an
explanatory error. The closed-set check is in the same dispatcher step
so an invalid value never reaches the model.

Observability: survey and audit prompts now print `Effort: <level>` in
their metadata headers so reviewers can see which level a posted
review ran at without inspecting the workflow run.

## Alternatives considered

**Per-mode `opus` flag (`use_opus_for_review: true`)**. Rejected: adds
N inputs in the matrix, creates per-mode configuration drift across
consumer repos, and does not give the model a directive about
budget interpretation. Effort is the right unit of grouping —
"do more thinking" is one decision, not seven.

**Auto-escalation by diff size**. Rejected on the same debuggability
grounds ADR-001 rejected mode auto-selection. Effort is a deliberate
choice with a deliberate cost; the caller should make it explicitly.
Auto-escalation can return later as a *suggestion* layer if the
explicit-choice cost is measurably high.

**Per-mode budget overrides as separate inputs
(`survey_files_per_zone: 12`, `audit_total_files: 30`)**. Rejected:
unbounded matrix, no single dial, and the model still selects the
default model. Effort gives one knob that pulls in the right
direction across all dimensions.

**Modifying the per-mode prompts directly to be more aggressive**.
Rejected: changes the default behavior every consumer sees. The
additive contract requires that callers who do not opt in see no
behavior change.

## Consequences

**Positive**.

- One dial covers the "do more" axis across all seven modes. The
  caller does not need to learn which mode catches which bug class
  before opting up; they pick a mode based on PR shape and crank
  effort based on stakes.
- Additive contract preserved (ADR-003): existing callers omitting
  the input see byte-identical behavior. CBM-style callers can adopt
  `max` for horizon closeouts without affecting routine reviews.
- The pattern-match expansion under `max` is documented as part of
  the dial rather than hidden in a free-form prompt change. Future
  bug classes that should be aggressively scanned for can be added
  to the `max` prompt directive in one place.

**Negative**.

- `max` is expensive. A 354-file PR at `survey` `max` reads many
  more files at Opus rates than `survey` `default`. The cost
  must be justified by the PR's stakes; the dial does not enforce
  that.
- The model interprets "remove the cap" softly — it still has to
  budget within the workflow timeout. On extreme diffs, `max` may
  not actually cover everything and the truncation may be silent.
  Survey/audit posting rules already cap output to ~50KB; the same
  truncation risk extends to read coverage at `max`.
- Three effort levels is fewer dimensions than per-mode tuning but
  more than one. The next pressure (e.g. "what about `max` for
  audit only?") may surface a mode × effort matrix request. That
  is deferred until empirical need; for now, callers who want a
  specific mode at high effort can fire `@claude <mode>` with
  `effort_level: high` set globally for that workflow run.

**Neutral**.

- The dial is orthogonal to ADR-008's L3 matrix fan-out variants.
  An `effort_level: max` survey is still a single-agent run; a
  future L3 `survey-matrix` variant would fan out per-zone agents
  regardless of effort. Once L3 lands, `survey-matrix` plus `max`
  effort would compose (more agents, each at higher effort).

## Migration

No migration required for existing consumers. The default
preserves byte-identical behavior. Consumers wanting the new dial:

```yaml
uses: loganrooks/agentic-ops/.github/workflows/review.yml@v1
with:
  enabled_modes: '["review","quick","deep","gates","opus","survey","audit"]'
  effort_level: high   # or "max" for horizon closeouts
  timeout_minutes: 90  # recommended bump when running at high/max effort
```
