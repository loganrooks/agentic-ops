# ADR-008: L3 mode variants — explicit-trigger routing and naming for matrix fan-out

Status: accepted
Date: 2026-05-11

Amends [ADR-001](ADR-001-mode-taxonomy.md) (mode taxonomy extended with
three matrix-variant modes) and [ADR-002](ADR-002-parallelism-architecture.md)
(L3 routing refined from threshold-based to explicit-trigger).

## Context

Two prior ADRs scope the L1/L3 design space:

- [ADR-001](ADR-001-mode-taxonomy.md) defines seven L1 single-agent
  modes (`review`, `quick`, `deep`, `gates`, `opus`, `survey`, `audit`)
  and explicitly rejects auto-selection on debuggability grounds:
  "Auto-selection introduces a wrong-mode-picked-silently failure
  mode that is hard to notice and hard to fix without instrumenting
  selection rationale."
- [ADR-002](ADR-002-parallelism-architecture.md) ratifies the
  L1→L3 ladder via GitHub Actions matrix fan-out, rejects L2
  (`Task()`-spawned sub-agents) for upstream-permission and isolation
  reasons, and proposes that L3 "activates empirically for surfaces
  where L1's attention budget binds" with a provisional threshold
  `survey_l3_threshold: 100` files.

These two ADRs are in tension. ADR-001 rejects auto-selection
unconditionally; ADR-002's threshold-based routing is auto-selection
by another name. The conflict has not surfaced because L3 is not yet
implemented (P5 and P6 in the phase map). It must be resolved before
those phases begin.

The empirical context is the in-progress EMPIRICAL-GATE on CBM. Three
L1 samples have been collected:

- `survey` on `loganrooks/codebase-mapper` PR #1
  ([run 25638955721](https://github.com/loganrooks/codebase-mapper/actions/runs/25638955721),
  comment posted 2026-05-10T20:35:33Z): 8 zones, 28 of 357 files
  read, 4 findings (W1 schema duplication, W2 `loop_status_config`
  family scope, S1 PR #1 workflow regression, S2 AGENTS.md schema
  path drift).
- `audit:agential-dx` on CBM main commit
  [f7f105c](https://github.com/loganrooks/codebase-mapper/commit/f7f105c)
  ([run 25655224283](https://github.com/loganrooks/codebase-mapper/actions/runs/25655224283),
  comment posted 2026-05-11T07:07:01Z): 10 files / 6 directories,
  9 findings (W1 no root CONTRIBUTING.md, W2 no ADRs, W3 no builder
  guide, W4 absent `platform/codex/`, plus S1–S5).
- `audit:forward-compat` on CBM main commit f7f105c
  ([run 25655799321](https://github.com/loganrooks/codebase-mapper/actions/runs/25655799321),
  comments posted 2026-05-11T07:20:25Z and 07:20:46Z as `[Audit 1/2]`
  + `[Audit 2/2]`): 14 files / 6 directories, 8 findings (W1–W5
  + S1–S3) plus a noted false-positive risk on W1 itself (caller
  stub's forward-looking paths).

Supervisor evaluation of those three samples (captured in
`.planning/auto-execution/STATE.md` under EMPIRICAL-GATE-T3/T5/T6
notes) graded the outputs as substantively useful — most findings
hold up against the code — and calibrated within their visible
scope. But the same evaluation flagged structural limits in what
those samples can prove:

- **No ground truth.** The findings were graded by reading the output;
  there is no oracle for what *should* have been found. The evaluator
  (Claude) shares blind spots with the producer (Claude).
- **Selection bias on findings.** The model can report what it found,
  not what it missed. The survey read 28 of 357 files in PR #1; the
  agential-dx audit read 10 of CBM main; the forward-compat audit
  read 14. Unread file content is invisible to evaluation.
- **n=1 per mode/lens.** Variance is uncharacterized.
- **One finding may be a false positive.** The forward-compat audit's
  W-1 flagged the caller stub's `review_focus_paths`/`gates_paths` as
  referencing non-existent paths — true on current CBM main, but those
  are deliberately forward-looking targets for Phase A merge, so the
  framing as a Warning may be miscalibrated. The supervisor previously
  praised this finding as "meta-elegant"; on closer reading it may be
  a calibration miss propagated into the evaluation.

The right bar for shipping L3 is not "L1 fails." That bar is too high
and the empirical sample cannot meet it. The right bar is **"L3
materially improves"** — improves findings, calibration, coverage
proof, or ensemble disagreement signal — at a defensible cost ratio.

A separate question raised by the EMPIRICAL-GATE results: the original
roadmap framing of P6 ("audit L3: lens-plan → matrix per lens →
synthesis") elides two distinct fan-out shapes:

- **Within-lens depth fan-out** — one lens, decomposed into N
  sub-questions, one parallel agent per sub-question, synthesizer
  reconciles. Useful when a single lens is complex and rewards
  decomposition.
- **Across-lens breadth fan-out** — all built-in lenses run in
  parallel as L1, synthesizer merges. Useful when a comprehensive
  multi-lens sweep is wanted and the user doesn't want to fire four
  separate triggers.

These are different operations serving different use cases. Conflating
them under one mode name buries the distinction.

## Decision

Three coordinated decisions:

### 1. L3 routing is explicit-trigger, not threshold-based

Resolve the ADR-001 / ADR-002 tension in favor of ADR-001's
debuggability stance. L3 modes fire only on explicit user triggers
(`@claude survey-matrix`, `@claude audit-matrix:<lens>`,
`@claude audit-all`). The substrate does not auto-promote L1
invocations to L3 based on diff size, file count, or any other
heuristic. (Note on naming: `audit-matrix` is the *mode*; the lens is
a trigger argument parsed into `audit_target`, mirroring the existing
L1 `audit` dispatcher. See Decision §2 for the parsing contract.)

The `survey_l3_threshold` mechanism named in ADR-002 is withdrawn.
Per-input threshold-based routing introduces exactly the
wrong-mode-picked-silently failure mode ADR-001 named: a reviewer who
fires `@claude survey` on a 99-file PR gets L1; on a 101-file PR they
get L3 — different output shapes, different costs, no visible
signaling of which path ran except in the output header. Reviewers
also lose the ability to force L1 on a large PR for cost reasons.

Auto-suggestion ("this PR is large; consider `survey-matrix`") may be
added later as a separate, advisory layer that does not alter dispatch.
That is out of scope here.

### 2. Three L3 modes reserved in the taxonomy (addition contingent on EMPIRICAL-GATE)

This ADR reserves the names, semantics, and contracts for three new
modes. **Actual taxonomy expansion is gated by EMPIRICAL-GATE per the
"EMPIRICAL-GATE refinement" section below.** If the gate clears for a
mode family, the corresponding mode(s) ship as defined here. If the
gate produces a null result for a family, those modes are not added,
and a follow-up ADR narrows the reservation. Until the gate clears,
the names are reserved (no other ADR or implementer may use them for
different purposes) but the dispatcher does not yet handle them.

The three reserved modes:

- **`survey-matrix`** — L3 spatial decomposition of a large PR.
  Two-stage workflow: a *zone planner* produces a JSON zone map
  (mirroring the L1 survey's zone identification); GitHub Actions
  matrix fan-out instantiates one job per zone, each running
  claude-code-action with a narrowed prompt scoped to its zone; a
  *synthesizer* job reads all per-zone outputs and posts the final
  unified review. Trigger: `@claude survey-matrix`. Model: workers and
  planner `claude-sonnet-4-6`; synthesizer `claude-sonnet-4-6` by
  default, `claude-opus-4-7` if the worker count or output volume
  exceeds a yet-to-be-named threshold (this *is* a threshold, but on
  the synthesizer model choice within the L3 mode, not on dispatch to
  the mode itself).

- **`audit-matrix`** — L3 within-lens depth fan-out for a single
  audit lens. The mode name in `enabled_modes` is the stable string
  `audit-matrix`; the lens is the trigger argument, parsed into
  `audit_target` exactly as the L1 `audit` dispatcher does today
  (`ADR-001` §"Decision" wires `audit` mode + dynamic `audit_target`,
  not a lens-suffixed mode name). Triggers:
  `@claude audit-matrix:agential-dx` parses to
  `mode=audit-matrix, audit_target=agential-dx`;
  `@claude audit-matrix <free-form>` parses to
  `mode=audit-matrix, audit_target=<free-form>`. Consumers list
  `audit-matrix` once in `enabled_modes`, independent of which
  lenses they want triggerable.

  Implementation: two-stage workflow — a *lens-plan agent* decomposes
  `audit_target` into N sub-questions (N target: 3–6); matrix fan-out
  runs one worker per sub-question; synthesizer reconciles. Free-form
  targets are permitted but increase variance (the lens-plan agent
  has to derive sub-questions from arbitrary text rather than a
  registered lens prompt).

- **`audit-all`** — L3 across-lens breadth fan-out. Runs every
  built-in lens (currently `agential-dx`, `tech-debt`, `forward-compat`,
  `discipline`) in parallel as four L1 worker jobs; synthesizer merges
  into one report grouped by lens. Trigger: `@claude audit-all`.
  Useful for a comprehensive sweep without firing four separate
  triggers. Free-form lenses are not included; the user adds them by
  separately invoking `@claude audit:<free-form>` if desired.

All three modes are gated by `enabled_modes` per ADR-001's existing
override discipline. The default `enabled_modes` array is *not*
extended to include L3 modes — they are opt-in per repo via explicit
extension. Rationale: cost. A repo enabling L3 modes accepts an Nx
cost ratio for those triggers and should declare that explicitly.

### 3. Audit L3 ships as two modes, not one

`audit-matrix` and `audit-all` are conceptually distinct. They serve
different use cases (depth on one lens vs. breadth across all lenses),
have different planner stages (sub-question decomposition vs. lens
enumeration), and produce differently-structured output (one-lens
unified report vs. multi-lens grouped report).

Shipping them as separate modes preserves the lens-as-extension-point
property from ADR-001: adding a new lens later automatically expands
`audit-all`'s sweep without modifying any other mode. Collapsing them
into one mode that switches behavior based on argument shape (e.g.,
bare `@claude audit-matrix` runs across-lens, `@claude audit-matrix:X`
runs within-lens X) would require special-casing the argument parser
and would obscure which shape ran from the trigger alone.

The naming distinction is also load-bearing for cost predictability:
`audit-all` is exactly *L (lenses) × T (per-lens-token-cost)*;
`audit-matrix` is exactly *N (sub-questions) × T*. The two have
different cost profiles and should not be hidden behind a single name.

### 4. `deep-matrix` deferred

`deep` is uncapped-budget L1; the question is whether a `deep-matrix`
variant adds value. Deferred: no `deep` consumer has reported binding
on attention budget, and `deep` is rarely invoked. Add `deep-matrix`
only if EMPIRICAL-GATE-style evidence emerges that `deep` binds.

## Alternatives considered

**Threshold-based auto-routing (ADR-002 original proposal).** Rejected
per Decision §1. ADR-001's reasoning about wrong-mode-picked-silently
applies symmetrically to threshold-based L3 promotion. The substrate
already burns one round-trip on a mode rejection if a consumer hasn't
enabled a mode in `enabled_modes`; that's an acceptable cost for
explicit routing. Silent routing trades visibility for one round-trip,
and visibility is the more valuable resource.

**L3 replaces L1 silently** once L3 is implemented. Rejected. Same
debuggability failure mode as auto-routing. Also forecloses on the
L1-as-cheap-default property that lets reviewers fire `@claude review`
or `@claude survey` without thinking about cost. L1 staying default
preserves the cheap path; L3 is the explicit upgrade.

**Single `audit-matrix` mode handling both depth and breadth.**
Rejected per Decision §3. The two use cases have different planner
stages and different cost profiles. Collapsing them obscures
intent and complicates the dispatcher.

**No L3 modes at all — EMPIRICAL-GATE verdict "L1 sufficient."**
Rejected. The empirical sample is insufficient to claim sufficiency
(n=1 per mode/lens, no oracle, no L3 comparison). The verdict bar is
"L3 materially improves," not "L1 fails," and that bar can only be
tested empirically with at least one side-by-side L1/L3 comparison.

**Add `deep-matrix` now alongside the survey and audit variants.**
Rejected per Decision §4. No observed demand. Add later if `deep` is
shown to bind on attention budget; otherwise the maintenance cost
isn't justified.

**Naming: `survey-l3` / `audit-l3:lens` / `audit-l3-all`** instead
of `*-matrix`. Considered. `l3` is the more accurate term (it names
the architectural level from ADR-002) but is also more
implementation-leak — a user who has not read ADR-002 sees `l3` and
must look it up. `matrix` is implementation-leak too but more
self-explanatory at the GHA level. Either is defensible; `matrix`
chosen because it's the term used in the phase map (P5 "survey L3
(matrix per zone)", P6 "audit L3 (matrix per lens)") and in
informal discussion. If a future ADR finds the naming confusing in
practice, this can be revisited (a renaming ADR would supersede,
not amend, the relevant section).

## EMPIRICAL-GATE refinement

The empirical gate's purpose is unchanged: validate L1 quality on a
real consumer before committing implementation effort to L3. But the
*bar* this ADR sets is more specific than the original phase-map
framing ("conditional on empirical signal that L1 isn't enough").

The gate is **per mode family**, not blanket. Each L3 mode needs its
own evidence; one mode's comparison does not authorize another.
Specifically:

- **P5 (`survey-matrix`)** lands if an L1-vs-L3 comparison on `survey`
  clears the improvement bar below. Canonical candidate PR: CBM PR #1.
- **P6 (`audit-matrix`)** lands if an L1-vs-L3 comparison on at least
  one audit lens with non-trivial sub-question decomposition clears
  the bar. The depth-fan-out shape must be the one being tested
  (lens-plan agent → matrix → synthesizer), not a different audit
  shape.
- **P6 (`audit-all`)** lands if an L1-vs-L3 comparison on the
  across-lens sweep clears the bar. L1 baseline is four separate
  L1 audit lenses run sequentially; L3 is one across-lens run with
  parallel workers and a unified synthesizer. The breadth-fan-out
  shape must be the one being tested.

Neither audit shape authorizes the other; they have different planner
stages, different worker prompts, and different cost profiles. Both
need evidence to ship.

A comparison "clears the improvement bar" by demonstrating one or
more of:

- **Coverage gain** — L3 reads files L1 declined to read, and those
  files contain content that materially changes findings.
- **Calibration improvement** — L3 corrects a severity miscalibration
  L1 produced (the survey's S-1 finding in EMPIRICAL-GATE-T3 is the
  reference case: rated P3, operationally P1).
- **Finding-class addition** — L3 surfaces a category of finding
  (architectural, cross-zone, schema-graph) that L1's spatial-budget
  prompt cannot reach.
- **Ensemble disagreement** — L3 workers disagree in a way that
  reveals genuine ambiguity, where L1's single-perspective output
  hides it.

…at a cost ratio of ≤Nx tokens for ≥0.5N improvement in any of the
above. (Cost ratio is approximate; the exact factor depends on
synthesizer model choice and per-mode N. The point is: L3 doesn't
have to break even on every dimension, but the integrated improvement
must be commensurate with the cost.)

If the comparison shows none of those gains, P5 and P6 are *skipped*
(not deferred); the modes are not added; this ADR's Decision §2 is
narrowed in a follow-up ADR. The skip decision is itself an artifact
worth preserving — null results matter.

## Consequences

**Positive.**

- The ADR-001 / ADR-002 routing tension is resolved cleanly in favor
  of ADR-001's debuggability stance. Future readers of either ADR see
  this one in the Status line and don't have to re-derive the
  resolution.
- The taxonomy growth (7→10 modes) is bounded and explicit. Each new
  mode has a distinct shape; none silently overlap or auto-promote.
- The audit L3 within-lens / across-lens distinction is named in the
  taxonomy, not buried in implementation. This keeps the lens-as-
  extension-point property additive: a new lens registered in
  `audit_lens_registry` is automatically picked up by `audit-all`
  without further ADR work.
- The EMPIRICAL-GATE bar is concrete enough to test: any of four
  named improvement dimensions, at a defensible cost ratio. Both the
  experiment design and the skip path are explicit.
- The default `enabled_modes` is not extended to include L3 modes,
  preserving the cost-discipline property: a repo opts in per mode
  and per ADR-006's bounded consumer policy.

**Negative.**

- Three more modes mean three more dispatcher case-statement branches,
  three more sets of prompt templates (planner, worker, synthesizer
  per mode), and three more rows in per-repo override docs. The
  maintenance cost is real and lands in P5 and P6.
- GHA YAML complexity grows. Each L3 mode needs a multi-job workflow
  with matrix expansion, `needs:` dependencies, and artifact passing
  for planner-to-worker and worker-to-synthesizer data flow. The
  central `review.yml` doubles or more in size.
- Synthesizer prompt injection is a new threat surface. Worker
  outputs are model-generated text that the synthesizer reads as
  context; a worker compromised via the existing TC-3 (prompt
  injection from comment-body) path could inject instructions into
  the synthesizer. This composes with ADR-007's TC-3 mitigation
  posture but does not yet have a dedicated mitigation; a TC-class
  addition may be warranted in a future ADR-007 amendment.
- Cost ratio of approximately Nx for L3 invocations, variable per
  mode. `survey-matrix` cost scales with zone count (typically 5–10);
  `audit-matrix` with sub-question count (typically 3–6);
  `audit-all` with built-in-lens count (currently 4). Plus synthesizer
  overhead. A single `audit-all` run is roughly 5× the cost of a
  single L1 audit.
- The deferred `deep-matrix` adds a small documentation debt: future
  ADRs may need to reference this one's "deferred" reasoning rather
  than re-deriving it.

**Neutral.**

- The "amends" relationship to ADR-001 and ADR-002 is the first
  application of the locally-defined `amends` status convention
  (see `docs/adr/README.md`, "When to amend vs. supersede"). If the
  convention proves unwieldy in practice, a future meta-ADR can revise
  it; for now this ADR is the precedent.
- The L3 mode names use `-matrix` rather than `-l3`. Either is
  defensible; the choice is reversible via a renaming ADR.
- The EMPIRICAL-GATE bar may turn out to be too lenient or too strict
  in practice. The four named improvement dimensions are a best-effort
  starting point; revising them after running the first comparison is
  expected.
