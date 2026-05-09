# Phase P9 — Final

**Goal:** Write `auto-execution/DONE.md` with a completion summary. Archive auto-execution state. Generate the completion report.

**Status:** pending

**Branch:** `chore/p9-archive-<timestamp>`

## Phase entry preconditions

- All reachable phases (P0..P8) have status `complete` or `skipped`
- All checkpoints exist in `auto-execution/checkpoints/`
- No unresolved escalations
- v1 tag points at the latest expected merge SHA (i.e., post-P8 if P8 ran, else post-P7)

## Phase exit postconditions

- `auto-execution/DONE.md` exists with required summary content
- Archive directory `auto-execution-archive/run-<timestamp>/` contains a copy of the auto-execution state
- STATE.md status updated to `archived`
- Final PR merged: `chore: archive auto-execution run <timestamp>`

## Tasks

### P9-T1 — Verify all reachable phases complete

- **Action:** Read STATE.md; verify P0..P8 status. P5/P6 may be `skipped` per the empirical gate; that counts as reachable-and-resolved.
- **Postcondition:** every phase status is `complete` or `skipped`; no `pending`, `in_progress`, or `escalated`.
- **Time:** ~1 min.

### P9-T2 — Aggregate metrics

- **Action:** Read CHECKPOINTS.md, ARTIFACTS.md, SESSION-LOG.md. Compute:
  - Total tasks completed (sum across phases)
  - Total sessions consumed
  - Estimated cost (USD, rough)
  - Total artifacts produced (count + total size)
  - Wall-clock duration (from STATE.md `started` to current timestamp)
- **Postcondition:** metrics computed and recorded in DONE.md draft.
- **Time:** ~5 min.

### P9-T3 — Write DONE.md

- **Action:** Write `auto-execution/DONE.md`:
  - Completion timestamp
  - Summary of what was built (cross-reference each phase's checkpoint)
  - Phase-by-phase outcomes (status, artifacts, deviations)
  - Final state of agentic-ops (review.yml SHA, ADR list, current v1 tag SHA)
  - Outstanding items (any `BLOCKED` tasks; any conditional phases skipped)
  - Recommended next steps for the human (test commands; "trigger `@claude survey` on CBM PR #1 to validate"; "monitor weekly-health issues for the first 2 weeks")
- **Postcondition:** DONE.md exists per template.
- **Time:** ~15 min.

### P9-T4 — Archive auto-execution state

- **Action:** `cp -r .planning/auto-execution .planning/auto-execution-archive/run-<timestamp>/`. Update STATE.md status to `archived` so future GO commands don't accidentally resume.
- **Postcondition:** archive directory exists; STATE.md status reflects archive.
- **Time:** ~5 min.

### P9-T5 — Final commit + halt

- **Action:** Commit all auto-execution artifacts and the archive directory. Open PR `chore: archive auto-execution run <timestamp>`. Wait for CI + CodeRabbit + maintainer signal. Merge.
- **Postcondition:** archive PR merged; final halt message printed.
- **Time:** ~10 min.

## Phase total estimate

~30 min.

## DONE.md content checklist

When the agent writes DONE.md it must include all of:

- [ ] Completion timestamp (ISO 8601 UTC)
- [ ] One-paragraph summary of what was built
- [ ] Per-phase status table (P0..P9) with checkpoint links
- [ ] Total tasks completed, sessions consumed, estimated cost
- [ ] Wall-clock duration
- [ ] Pointers to all major artifacts (review.yml, ADRs, .planning/, .github/)
- [ ] Current v1 tag SHA
- [ ] Outstanding items (blocked tasks, skipped conditional phases)
- [ ] Smoke-test commands the human can run to validate
- [ ] Any postmortems generated during execution

## Notes on archive

The archive at `.planning/auto-execution-archive/run-<timestamp>/` is a frozen snapshot. Future runs of the initiative (if ever re-executed under a new plan) start fresh; the archive is purely historical.

## References

- `EXECUTION-MODEL.md` §"Done detection" — defines what DONE means
- `INITIATIVE.md` §"Done definition" — same content from the strategic side
- `RISK-REGISTER.md` — any risks that materialized get postmortems referenced from DONE.md
