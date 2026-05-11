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

The procedure has two stages. Stage 1 (L1 baseline capture) was
completed during T1-T6 and is recorded in the decision file. Stage
2 (hand-rolled L1-vs-L3 comparison per family) is the work that
remains.

### Stage 1 — L1 baseline capture (complete)

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

The three required comparisons are:

1. **survey-matrix** (gates P5). Orchestrate ≥3 L1 `@claude survey`
   invocations against CBM PR #1 with non-overlapping zone seeds
   (e.g., comment-prompt each invocation to focus on a disjoint
   subset of the 8 zones identified in the L1 baseline). Synthesize
   the outputs offline. Compare findings + severity + coverage
   against the single-shot L1 baseline.
2. **audit-matrix** (gates P6, within-lens fan-out). Orchestrate
   ≥3 L1 `@claude audit:<lens>` invocations of one lens (e.g.,
   `agential-dx`) with non-overlapping seed prompts that bias each
   run toward a different subset of the lens's coverage. Synthesize
   offline. Compare against the corresponding single-lens L1
   baseline.
3. **audit-all** (gates P6, cross-lens fan-out). Complete the
   missing L1 baselines (`audit:tech-debt`, `audit:discipline`)
   per Stage 1, then synthesize all four lens outputs offline as
   the prospective `audit-all` ensemble. Compare against each
   individual lens's L1 output to test for ensemble disagreement
   or finding-class addition that single-lens audits miss.

Each comparison produces a verdict appended to the decision file's
per-family gate section: `CLEARED`, `NOT CLEARED`, or `INSUFFICIENT
EVIDENCE`. `INSUFFICIENT EVIDENCE` escalates per HUMAN-GATE-5.

## Decision logic

Per ADR-008 §2, each family's gate has its own criterion and its
own cost cap. A family clears its gate when the comparison
demonstrates at least one of:

- **Coverage gain** — L3 surfaces findings the L1 baseline missed,
  not just rephrases them.
- **Calibration improvement** — L3 rates severities the L1
  baseline mis-rated (e.g., the survey-L1 S1 miscalibration noted
  in the decision file is a candidate datum for survey-matrix
  calibration improvement).
- **Finding-class addition** — L3 surfaces a class of finding the
  L1 baseline structurally cannot reach (e.g., cross-zone
  invariants for `survey-matrix`).
- **Ensemble disagreement** — L3's synthesizer surfaces
  contradictions between worker outputs that single-lens or
  single-zone L1 cannot. Specific to `audit-all`.

Each family's cost cap is fixed by ADR-008 §2:

| Family | Cost cap |
|---|---|
| survey-matrix | `N × L1` (N = matrix width, typically 3-6 workers) |
| audit-matrix | `N × L1` |
| audit-all | `1.2 × aggregate-L1` (4 lens runs + 20% synthesis overhead) |

`L1` is the corresponding single-shot L1 baseline cost (claude
wall-clock + token spend). A comparison that exceeds the cost cap
without compensating coverage/calibration/class/ensemble gain does
NOT clear the gate, even if it produces nominally "better" output.

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
  `skipped` in STATE.md.
- Proceed to the next phase. P5/P6 do not block P7 (onboarding) —
  per the decision file's "Phase implications" table, P7 is
  unblocked regardless of P5/P6 outcomes.

A `NOT CLEARED` verdict does not foreclose later L3 work; ADR-008's
cost caps may need successor ADRs if real comparison data shows
them mis-calibrated.

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
