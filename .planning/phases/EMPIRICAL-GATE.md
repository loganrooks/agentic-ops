# Empirical gate (between P4 and P5)

**Goal:** Validate L1 survey + audit on real CBM artifacts. Decide whether L3 (matrix fan-out) is needed for survey (gates P5) and/or audit (gates P6).

**Status:** pending (depends on CHECKPOINT-P4)

**Output:** `.planning/auto-execution/EMPIRICAL-GATE.md` (decision file written by the agent during execution)

## Trigger conditions
- CHECKPOINT-P4 exists
- v1 tag includes audit + survey + extra_allowed_tools (i.e., agentic-ops main has the full L1 platform)

## Procedure (autonomous)
1. Agent posts `@claude survey` comment on CBM PR #1 from the maintainer's gh auth.
2. Wait for the GHA run to complete (poll workflow runs in cbm repo). State: AWAITING_EXTERNAL.
3. Read the posted comment. Capture: zone count, finding count, runtime, model used.
4. Post `@claude audit:agential-dx` on a CBM tracking issue (create issue if needed; suggested title: "Audit: workspace organization for agential development").
5. Wait for run to complete; read output; capture metrics.
6. Post `@claude audit:forward-compat` on the same or new issue.
7. Wait, read, capture.

## Decision logic

Recorded in the auto-execution decision file. For each mode (survey, audit), apply:

```
If (mode produced >=3 distinct findings AND covered >=4 zones/lenses
    AND no critical findings missed vs. existing CodeRabbit/Codex):
  L3 not needed for this mode. Skip the corresponding L3 phase.

Else if (mode ran out of attention budget OR missed obvious findings
         OR runtime > 30 min):
  L3 needed. Run the corresponding L3 phase.

Else if metrics ambiguous (e.g., 2 distinct findings; 3 zones):
  Escalate per HUMAN-GATE-5 with raw data.
```

The decision is recorded for survey (gates P5) and audit (gates P6) independently. They can have different outcomes.

## If skipping P5 and/or P6

- Record decision in the auto-execution gate-decision file.
- Mark the skipped phase(s) as `skipped` in STATE.md.
- Move to P7 (onboarding); P5/P6 do not block.

## Estimated time
30-90 min wall clock (depends on GHA queue + CI duration of each survey/audit run).

## Notes on the empirical method
- "No critical findings missed" is judged by reading the existing CodeRabbit and Codex review output on CBM PR #1 (already in the PR's review history) and comparing against survey output. If survey produced findings that materially overlap with the human-curated set, attention budget is sufficient.
- "Out of attention budget" surfaces as: survey reads many files but findings cluster in only 1-2 zones (suggests it ran out of context after reading too widely).
- The 30-min runtime threshold is empirical; if survey routinely takes >30 min on CBM-sized PRs, fan-out provides cost-predictability and observability benefits even if quality is acceptable.

## References
- ADR-002 — Parallelism architecture (L1 baseline, L3 conditional)
- `phases/P5-survey-mode-l3.md` — runs if survey gate triggers
- `phases/P6-audit-mode-l3.md` — runs if audit gate triggers
- HUMAN-GATE-5 in `HUMAN-GATES.md` — ambiguous gate metrics escalate to user
