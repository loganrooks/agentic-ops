# Phase P5 — Survey mode L3 (matrix fan-out)

**Goal:** Refactor `survey` into a 3-job pattern: zone-map → matrix-per-zone → synthesis. Standard GHA fan-out via `fromJson(needs.X.outputs.Y)`. Adds an L1-vs-L3 routing input (default 100 files); below it runs L1, above runs L3.

**Status:** pending (CONDITIONAL on EMPIRICAL-GATE decision; may be `skipped`)

**Branch:** `feat/p5-survey-l3`

## Phase entry preconditions

- EMPIRICAL-GATE.md (auto-execution decision file) says L3 is needed for survey
- CHECKPOINT-P4 exists

## Phase exit postconditions

- `review.yml` has 3-job structure for survey (active when diff exceeds threshold)
- Matrix fan-out works correctly (validated by re-running on CBM PR #1 post-merge)
- Zone-output validation script exists and runs in zone-map job
- Failure semantics: partial-zone-failure produces degraded synthesis with note
- CI green, **CodeRabbit reviewed + conversations resolved**, PR merged after maintainer signal, v1 tag bumped

## Tasks

### P5-T1 — Design L1-vs-L3 routing

- Define the routing rule that picks L1 vs L3 by diff size.
- Add input `survey_l3_threshold` (default 100); above runs L3, at-or-below runs L1.
- Wire the threshold into `if:` conditionals so non-L3 invocations short-circuit cleanly.
- Document the routing rule in this phase doc and in `review.yml` comments. Do NOT edit ADR-002 — ADRs are immutable per `docs/adr/README.md` and `AGENTS.md`. ADR-002 already approves the L1 → L3 ladder; the threshold value and routing mechanism are implementation details, not architectural changes. If a substantive architectural change emerges (e.g., abandoning L3 in favor of a different parallelism approach), open a new ADR that supersedes ADR-002.
- Time: ~15 min.

### P5-T2 — Refactor jobs structure

- Restructure `review.yml` into four jobs: `review` (non-survey + L1 survey), `survey-zone-map`, `survey-zone-review` (matrix), `survey-synthesis`.
- Gate the three new jobs on `mode == survey AND diff_size > survey_l3_threshold`.
- Wire `needs:` so zone-review depends on zone-map and synthesis depends on both.
- Verify conditionals skip cleanly on the L1 path or any non-survey mode.
- Time: ~60 min (substantial GHA refactor).

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

### P5-T6 — Update test-dispatcher.sh for L3 routing

- Add fixtures asserting the dispatcher emits the L3 flag above threshold and L1 below it.
- Dispatcher does not change; routing lives in per-job `if:` conditionals — fixtures verify those.
- Confirm existing dispatcher smoke tests stay green.
- Land fixtures in the same commit as the refactor.
- Time: ~15 min.

### P5-T7 — Document L3 implementation details (NOT in ADR-002)

- Document 3-job structure, threshold input, partial-failure semantics, `max-parallel` choice, and zone cap in this phase doc and in `review.yml` inline comments. The phase doc is the canonical implementation-detail home.
- **Do NOT edit ADR-002.** ADRs are immutable per `docs/adr/README.md` and `AGENTS.md`. ADR-002 already approves the L3 architecture at the design level; implementation details are not architectural changes.
- If a substantive architectural deviation emerges (e.g., abandoning the 3-job structure for a different shape, or rejecting matrix fan-out entirely), STOP and open a new ADR that supersedes ADR-002. Do not edit ADR-002 in place.
- Time: ~15 min.

### P5-T8 — Local validation

- Run `act` on a synthetic large-diff fixture; confirm zone-map → matrix → synthesis all execute.
- Force one matrix leg to fail; confirm synthesis still posts with a degraded note.
- Re-run with a small-diff fixture; confirm new jobs are skipped on the L1 path.
- Time: ~30 min.

### P5-T9 — Open PR

- Push `feat/p5-survey-l3`; title PR `feat(survey): L3 matrix fan-out`.
- Include before/after job-graph notes; call out the threshold input.
- Tag the maintainer; reference this phase doc as the implementation detail record (no ADR-002 edit).
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

- Re-run `@claude survey` on CBM PR #1 post-merge; confirm the 3-job structure activates above threshold.
- Verify the synthesis comment posts with expected dedupe and cross-zone integrity notes.
- Only after that real-traffic run succeeds, write the dual checkpoint: per-phase detail at `.planning/auto-execution/checkpoints/CHECKPOINT-P5.md`, and append a summary entry to `.planning/auto-execution/CHECKPOINTS.md` (aggregate index).
- Time: ~30 min.

## Phase total estimate

6-8 hrs, ~2 sessions.

## End-to-end validation

After P5 merges and v1 bumps, re-run `@claude survey` on CBM PR #1 and verify the 3-job structure activates and produces a comment. This validation IS part of the P5 checkpoint — checkpoint is not written until end-to-end runs successfully.

## References

- ADR-002 — Parallelism architecture (3-job structure rationale)
- `phases/EMPIRICAL-GATE.md` — gates this phase
- `phases/P2-survey-mode-l1.md` — the L1 baseline being refactored
- `EXECUTION-MODEL.md` — checkpoint protocol
