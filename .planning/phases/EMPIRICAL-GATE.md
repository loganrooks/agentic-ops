# Empirical gate (between P4 and P5)

> **Updated 2026-05-11 to align with [ADR-008](../../docs/adr/ADR-008-l3-mode-variants.md):** Original gate logic was binary per mode ("L1 is sufficient → skip L3; else run L3"). ADR-008 Decision §2 replaces that with a per-family gate ("does L3 materially improve at defensible cost?") evaluated against a hand-rolled L1-vs-L3 comparison per family. The decision logic, procedure, and skip semantics below have been rewritten accordingly. Current per-family gate state is tracked authoritatively in [.planning/auto-execution/EMPIRICAL-GATE.md](../auto-execution/EMPIRICAL-GATE.md); this phase doc specifies the procedure.

**Goal:** Validate that each L3 mode-family (`survey-matrix`,
`audit-matrix`, `audit-all`) clears ADR-008's per-family improvement
bar at a defensible cost ratio, against the corresponding L1
baseline. Each family is gated independently and can clear, fail,
or remain pending without affecting the others.

**Status:** pending (depends on CHECKPOINT-P4)

**Output:** [.planning/auto-execution/EMPIRICAL-GATE.md](../auto-execution/EMPIRICAL-GATE.md) (decision file written by the agent during execution; records L1 baselines and per-family gate state)

## Trigger conditions

- CHECKPOINT-P4 exists
- v1 tag includes audit + survey + extra_allowed_tools (i.e., agentic-ops main has the full L1 platform)

## Procedure (autonomous)

The procedure has two stages. Stage 1 (L1 baseline capture) is
mostly complete: three of five baselines were captured in T1-T6
and recorded in the decision file; two `audit-all` lens runs
(`audit:tech-debt`, `audit:discipline`) remain. Stage 2
(hand-rolled L1-vs-L3 comparison per family) proceeds per family
once its required Stage 1 baselines are complete: the
survey-matrix and audit-matrix comparisons can start now;
audit-all waits on the two remaining L1 lens runs.

### Stage 1 — L1 baseline capture (mostly complete)

The L1 baselines for `survey`, `audit:agential-dx`, and
`audit:forward-compat` are captured in the decision file
([.planning/auto-execution/EMPIRICAL-GATE.md](../auto-execution/EMPIRICAL-GATE.md) §"L1 baseline metrics"). Each baseline names the
run URL, model, files read, runtime, finding count, and lens
alignment.

Two L1 lens runs remain uncaptured for the `audit-all` baseline:
`audit:tech-debt` and `audit:discipline` against CBM issue #9. Per
ADR-008 §2, the `audit-all` comparison requires all four built-in
lenses run individually as L1 before the ensemble L3 path can be
fairly compared. Capturing those two completes the L1 baseline for
the cross-lens fan-out family.

### Stage 2 — Hand-rolled L1-vs-L3 comparison per family

Per ADR-008 §2, each L3 mode-family clears its gate via a
hand-rolled L1-vs-L3 comparison evaluated against the corresponding
L1 baseline. The comparisons are independent and run as separate
sub-phases. Per ADR-008, the comparison is not gated on dispatcher
implementation — it is orchestrated manually by firing multiple L1
invocations with non-overlapping seeds and synthesizing offline.

The three required comparisons, per ADR-008 §"EMPIRICAL-GATE
refinement", are:

1. **survey-matrix** (gates P5; *zone fan-out*). Fire one L1
   `@claude survey` against CBM PR #1 to obtain the zone map.
   Then fire N narrower triggers — one per zone from the planner
   output — using `@claude review` or `@claude survey` with
   manually narrowed paths scoped to each zone. N is the
   planner-reported zone count (8 for the captured CBM L1
   baseline; typically 5-10 for survey-sized PRs). Assemble the
   per-zone outputs offline with a synthesizer-equivalent prompt.
   Compare the L1 `@claude survey` output against the assembled
   zone-parallel result.
2. **audit-matrix** (gates P6, *within-lens sub-question fan-out*).
   Pick ONE lens (e.g., `audit:tech-debt`). Manually decompose
   the lens into 3-6 sub-questions. Fire one L1 audit trigger per
   sub-question using `@claude audit <free-form>` with each
   sub-question as the free-form target. (Per ADR-008: repeating
   `@claude audit:<lens>` does NOT test this shape — it tests
   `audit-all`'s shape instead.) Assemble the per-sub-question
   outputs offline with a within-lens synthesizer prompt. Compare
   the single L1 `@claude audit:<lens>` baseline against the
   assembled sub-question-parallel result.
3. **audit-all** (gates P6, *across-lens breadth fan-out*).
   Complete the missing L1 baselines (`audit:tech-debt`,
   `audit:discipline`) per Stage 1 so all four built-in lenses
   have a captured L1 run on the same subject. Aggregate the four
   sequential L1 lens outputs as the L1 baseline (the L1 sweep).
   Assemble the same four outputs offline with an across-lens
   synthesizer prompt as the prospective `audit-all` L3 result.
   Compare the aggregated L1 sweep against the assembled
   across-lens-parallel result.

Each comparison produces a verdict appended to the decision file's
per-family gate section: `CLEARED`, `NOT CLEARED`, or `INSUFFICIENT
EVIDENCE`. `INSUFFICIENT EVIDENCE` escalates per HUMAN-GATE-5.

## Decision logic

Per ADR-008 §"EMPIRICAL-GATE refinement", each family's gate has
its own criterion and its own cost cap. A family clears its gate
when the comparison demonstrates at least one of four named
dimensions, *at or above its predeclared numerical threshold*:

- **Coverage gain** — L3 reads files L1 declined to read, and
  those files contain content that materially changes findings.
  Threshold: ≥20% more files read with non-trivial content.
- **Calibration improvement** — L3 corrects a severity
  miscalibration L1 produced. Threshold: ≥1 severity correction
  or new high-severity finding L1 missed. (The survey-L1 S1
  miscalibration noted in the decision file is the reference
  case.)
- **Finding-class addition** — L3 surfaces a category of finding
  that L1's spatial-budget prompt cannot reach. Threshold: ≥1
  finding in a class L1's output structurally cannot reach.
- **Ensemble disagreement** — L3 workers disagree in a way that
  reveals genuine ambiguity, where L1's single-perspective output
  hides it. Threshold: ≥1 productive disagreement surfaced that
  L1 hid.

The cost cap is **token-based**, not wall-clock: `L3_total_tokens
/ L1_baseline_tokens` (L3 total includes planner + workers +
synthesizer). Wall-clock is captured as baseline metadata but
does not enter the gate decision — ADR-008 explicitly acknowledges
hand-rolled comparisons lack true in-workflow parallelism, so a
token-efficient L3 simulation must not be rejected for serial
wall-clock.

Per-family cost caps (from ADR-008):

| Family | Token-ratio cap | Baseline | N (fan-out factor) |
|---|---|---|---|
| survey-matrix | `L3 tokens ≤ N × L1 tokens` | Single L1 `@claude survey` run on the same PR | zone count from the planner output (8 for CBM L1; typically 5-10 for survey) |
| audit-matrix | `L3 tokens ≤ N × L1 tokens` | Single L1 `@claude audit:<lens>` run for the same lens | sub-question count (target 3-6) |
| audit-all | `audit-all tokens ≤ 1.2 × aggregate-L1 tokens` | **Aggregate** of four sequential L1 audit lens runs (the L1 sweep) | not applicable — baseline is already aggregate; 1.2× allows 20% synthesis overhead, no parallel-budget premium |

For survey-matrix and audit-matrix the N multiplier applies because
the L1 baseline is a single run and the L3 fan-out is genuinely
parallel work N agents wouldn't otherwise do. For audit-all the
baseline is already aggregate, so the multiplier does not apply —
the cap is tighter because the comparison is L3-vs-aggregate-L1,
not L3-vs-single-L1.

Exceeding the acceptable ratio requires the improvement dimensions
to scale proportionally; the gate artifact must justify the higher
ratio explicitly. ADR-008's numerical thresholds are starting
values; they may be loosened or tightened in a follow-up ADR if
the first comparison shows them mis-calibrated.

If a comparison's metrics are ambiguous (e.g., one finding-class
addition borderline; cost ratio at cap), the agent escalates per
HUMAN-GATE-5 with raw comparison data.

## If skipping P5 and/or P6

Skipping is per-family. P5 implementation begins only when the
survey-matrix comparison `CLEARED`s. P6 implementation begins
per-mode: `audit-matrix` ships if the audit-matrix comparison
clears; `audit-all` ships if the audit-all comparison clears. The
two P6 modes may ship together or separately.

For each family that does NOT clear:

- Record the verdict and rationale in the decision file's
  per-family gate section.
- Mark the corresponding phase (or sub-mode within P6) as
  `skipped` in [`.planning/auto-execution/STATE.md`](../auto-execution/STATE.md).
- Proceed to the next phase. P5/P6 do not block P7 (onboarding) —
  per the decision file's "Phase implications" table, P7 is
  unblocked regardless of P5/P6 outcomes.

A `NOT CLEARED` verdict for a family means that family is
*skipped*, not deferred: per ADR-008 §"EMPIRICAL-GATE refinement",
the family's reserved mode name(s) are not added to the taxonomy.
Resuming L3 work for that family later requires a follow-up ADR
narrowing this ADR's Decision §2 — the reservation is not
backlog. Each skip decision is itself an artifact worth preserving;
null results matter.

## Estimated time

Stage 1 was 30-90 min wall clock (depending on GHA queue + CI
duration per run). Stage 2 per family is 6-10 hr including
orchestration, synthesis, and write-up.

## Notes on the empirical method

- "No critical findings missed" is judged by reading the existing
  CodeRabbit and Codex review output on CBM PR #1 (already in the
  PR's review history) and comparing against L1 output. The L1
  baseline cleared this bar in T3 (verified in the decision file's
  "Open considerations" §); L3 must meet or beat the same bar.
- "Out of attention budget" surfaces in the L1 baseline as:
  attention concentrated in only 1-2 zones / lenses out of the
  full set (suggests it ran out of context after reading too
  widely). This is the strongest signal that an L3 family
  comparison may clear.
- The cost caps are derived from ADR-008 §2 but are unvalidated.
  The first real comparison should also produce calibrated cost
  numbers; if a cap is wrong, a successor ADR adjusts it.
- Comparison ordering. Per the decision file §"Open
  considerations", the three Stage-2 comparisons can run either
  before P7 (sequential, original ordering) or after P7 (allows
  real onboarded-repo workloads to strengthen the comparison's
  evidence base). This phase doc does not fix the ordering; that
  is a plan-level call.

## References

- [ADR-008 — L3 mode variants](../../docs/adr/ADR-008-l3-mode-variants.md) — governing ADR; §2 names the per-family gate criteria and cost caps
- [ADR-002 — Parallelism architecture](../../docs/adr/ADR-002-parallelism-architecture.md) — L1 baseline / L3 conditional framing (partially superseded by ADR-008 re: routing)
- [.planning/auto-execution/EMPIRICAL-GATE.md](../auto-execution/EMPIRICAL-GATE.md) — canonical source of current per-family gate state, L1 baselines, and per-comparison verdicts
- [phases/P5-survey-mode-l3.md](P5-survey-mode-l3.md) — runs if survey-matrix comparison clears
- [phases/P6-audit-mode-l3.md](P6-audit-mode-l3.md) — runs per-mode if audit-matrix and/or audit-all comparisons clear
- HUMAN-GATE-5 in [`HUMAN-GATES.md`](../HUMAN-GATES.md) — ambiguous gate metrics escalate to user
