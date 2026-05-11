# Phase P5 — Survey mode L3 (matrix fan-out)

> **Updated 2026-05-11 to align with [ADR-008](../../docs/adr/ADR-008-l3-mode-variants.md):** Original plan added a `survey_l3_threshold` input and auto-promoted `@claude survey` to L3 above the threshold. ADR-008 Decision §1 withdraws threshold-based routing in favor of explicit triggers. P5 now ships L3 as a separate mode `survey-matrix` invoked by `@claude survey-matrix`; the L1 `survey` mode is unchanged. References to `survey_l3_threshold` and size-gated dispatch below have been rewritten accordingly.

**Goal:** Add a new mode `survey-matrix` implemented as a 3-job pattern: zone-map → matrix-per-zone → synthesis. Standard GHA fan-out via `fromJson(needs.X.outputs.Y)`. L1 `survey` mode is unchanged and remains the default; `survey-matrix` is opt-in via explicit trigger.

**Status:** pending (CONDITIONAL on EMPIRICAL-GATE per-family decision per ADR-008; may be `skipped` if the survey L1-vs-L3 comparison produces no material improvement)

**Branch:** `feat/p5-survey-l3`

## Phase entry preconditions

- EMPIRICAL-GATE produces a survey L1-vs-L3 comparison that clears ADR-008's per-family improvement bar (coverage gain, calibration improvement, finding-class addition, or ensemble disagreement) at a defensible cost ratio
- CHECKPOINT-P4 exists

## Phase exit postconditions

- `review.yml` dispatcher handles `@claude survey-matrix` as a distinct mode (`mode=survey-matrix`); L1 `survey` mode is unchanged
- `review.yml` has 3-job structure active when `mode == survey-matrix`
- Matrix fan-out works correctly (validated by `@claude survey-matrix` on CBM PR #1 or equivalent large PR)
- Zone-output validation script exists and runs in zone-map job
- Failure semantics: partial-zone-failure produces degraded synthesis with note
- CI green, **CodeRabbit reviewed + conversations resolved**, PR merged after maintainer signal, v1 tag bumped

## Tasks

### P5-T1 — Add `survey-matrix` dispatcher case

- Per ADR-008 Decision §1, L3 fires on explicit triggers only. No threshold-based routing.
- Add a dispatcher case for `@claude survey-matrix` that sets `mode=survey-matrix` and `model=claude-sonnet-4-6` (worker default; synthesizer may use Opus per ADR-008 Decision §2).
- Add `survey-matrix` to the `enabled_modes` validation logic so consumers must opt in by listing the mode (the default `enabled_modes` is *not* extended per ADR-008).
- L1 `survey` mode dispatcher case is unchanged.
- Time: ~15 min.

### P5-T2 — Refactor jobs structure

- Add three new jobs alongside the existing `review` job: `survey-zone-map`, `survey-zone-review` (matrix), `survey-synthesis`.
- Gate the three new jobs on `mode == survey-matrix` (explicit-mode gate; no size threshold).
- **Gate the existing `review` job to exclude `mode == survey-matrix`** so a `@claude survey-matrix` trigger does NOT also fire the L1 claude-code-action. Add `if: <mode-resolution-output> != 'survey-matrix'` (or equivalent) to the `review` job's step that runs `claude-code-action`.
- Wire `needs:` so zone-review depends on zone-map and synthesis depends on both.
- **Synthesis job must survive partial worker failures.** Use `if: always() && needs.survey-zone-map.result == 'success'` on the synthesis job and inspect `needs.survey-zone-review.result` inside the synthesis prompt/payload to note degraded mode. Otherwise GHA's default behavior (`needs:` job skips on dependency failure) will leave a half-finished run with no comment posted.
- Verify conditionals skip cleanly on any other mode (`review`, `quick`, `deep`, `gates`, `opus`, `survey` L1, `audit`, etc.).
- Time: ~75 min (substantial GHA refactor + degraded-mode plumbing).

### P5-T3 — Implement zone-map job

- Run claude-code-action with `PHASE_1_PROMPT` (extracted from the P2 survey block); agent writes zones JSON to `$GITHUB_WORKSPACE/zones.json`.
- Add `extract-survey-zones.sh`: reads `zones.json`, validates schema (`{id, paths, priority, concern}`), enforces ≤8 zones, writes `zones=<json>` to `$GITHUB_OUTPUT`.
- Make the script executable; fail the job with a clear error on validation failure.
- Smoke-test against valid + malformed fixtures (missing fields, >8 zones).
- Time: ~60 min.

### P5-T4 — Implement matrix zone-review job

- Matrix: `strategy.matrix.zone: ${{ fromJson(needs.survey-zone-map.outputs.zones) }}`, `fail-fast: false`, `max-parallel: 4`.
- Each leg runs claude-code-action with `PHASE_2_PROMPT` scoped to `${{ matrix.zone }}` so the agent reads only its assigned paths.
- Each leg writes `findings/${{ matrix.zone.id }}.md` and uploads it as a workflow artifact.
- Verify matrix expansion via a dry-run with mock zones; confirm artifact upload per leg.
- Time: ~45 min.

### P5-T5 — Implement synthesis job

- Download every zone artifact; run claude-code-action with `PHASE_3_4_PROMPT` (cross-zone integrity + dedupe vs CodeRabbit/Codex + post via wrapper).
- Tolerate missing artifacts so partial-failure runs still synthesize.
- Encode degraded-mode messaging: with fewer artifacts than expected, the comment notes partial coverage and lists missing zones.
- Reuse the existing exfiltration-safe `gh pr comment` wrapper for the post.
- Time: ~45 min.

### P5-T6 — Update test-dispatcher.sh for survey-matrix

- Add fixtures asserting the dispatcher emits `mode=survey-matrix` on `@claude survey-matrix` and `mode=survey` on `@claude survey` (no auto-promotion).
- Add fixtures verifying `survey-matrix` is rejected when not in `enabled_modes` (per the existing override discipline).
- Confirm existing dispatcher smoke tests stay green.
- Land fixtures in the same commit as the refactor.
- Time: ~15 min.

### P5-T7 — Document L3 implementation details (NOT in ADRs)

- Document 3-job structure, partial-failure semantics, `max-parallel` choice, and zone cap in this phase doc and in `review.yml` inline comments. The phase doc is the canonical implementation-detail home.
- **Do NOT edit ADR-002 or ADR-008 bodies.** ADRs are immutable per `docs/adr/README.md` and `AGENTS.md`; only `Status:` lines may be updated, and only to reflect amend/supersede/deprecate relationships per the README convention.
- If a substantive architectural deviation emerges (e.g., abandoning the 3-job structure, rejecting matrix fan-out, or wanting to re-introduce threshold routing), STOP and open a new ADR that supersedes or partially supersedes ADR-008 / ADR-002 as appropriate.
- Time: ~15 min.

### P5-T8 — Local validation

- Run `act` on a synthetic large-diff fixture with `@claude survey-matrix`; confirm zone-map → matrix → synthesis all execute.
- Force one matrix leg to fail; confirm synthesis still posts with a degraded note.
- Re-run with `@claude survey` (L1); confirm the new L3 jobs are skipped and the L1 path is unchanged.
- Time: ~30 min.

### P5-T9 — Open PR

- Push `feat/p5-survey-l3`; title PR `feat(survey): L3 matrix fan-out as survey-matrix mode`.
- Include before/after job-graph notes; call out the new explicit-trigger contract (no threshold).
- Tag the maintainer; reference this phase doc and ADR-008 Decision §2 as the design record (no ADR body edits).
- Time: ~10 min.

### P5-T10 — Wait CI + CodeRabbit

- Watch CI to green; fix failures with new commits (never `--no-verify`).
- Resolve every CodeRabbit conversation; rebase or stack fixups as needed.
- Hold the merge until the maintainer signals approval.
- Time: variable.

### P5-T11 — Merge + tag v1 bump

- Squash-merge; bump the floating `v1` tag to the new SHA.
- Confirm the bumped tag resolves via `git ls-remote`.
- Note the bump in the PR thread for downstream consumers.
- Time: ~10 min.

### P5-T12 — End-to-end checkpoint validation

- Run `@claude survey-matrix` on CBM PR #1 post-merge; confirm the 3-job structure activates. Then run `@claude survey` (L1) on the same PR; confirm L1 path is unaffected.
- Verify the synthesis comment posts with expected dedupe and cross-zone integrity notes.
- Only after that real-traffic run succeeds, write the dual checkpoint: per-phase detail at `.planning/auto-execution/checkpoints/CHECKPOINT-P5.md`, and append a summary entry to `.planning/auto-execution/CHECKPOINTS.md` (aggregate index).
- Time: ~30 min.

## Phase total estimate

6-8 hrs, ~2 sessions.

## End-to-end validation

After P5 merges and v1 bumps, run `@claude survey-matrix` on CBM PR #1 and verify the 3-job structure activates and produces a synthesized comment; also run `@claude survey` (L1) and verify the L1 path is unchanged. This validation IS part of the P5 checkpoint — checkpoint is not written until both end-to-end runs succeed.

## References

- ADR-002 — Parallelism architecture (3-job structure rationale)
- `phases/EMPIRICAL-GATE.md` — gates this phase
- `phases/P2-survey-mode-l1.md` — the L1 baseline being refactored
- `EXECUTION-MODEL.md` — checkpoint protocol
