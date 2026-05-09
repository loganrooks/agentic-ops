# Phase P2 — Survey mode L1

**Goal:** Add `survey` mode to the dispatcher with Phase 1-4 single-agent prompt structure. Single-agent path (L1) baseline; matrix fan-out (L3) deferred to P5 conditional on empirical signal.

**Status:** pending

**Branch:** `feat/p2-survey-mode`

## Phase entry preconditions

- CHECKPOINT-P1 exists (complete)
- CHECKPOINT-P1.5 exists (complete: review discipline + docs restructure)
- v1 tag is at expected SHA
- CBM caller stub still works (verify by reading `cbm/.github/workflows/claude-review.yml`; confirm it points at agentic-ops's v1)

## Phase exit postconditions

- `review.yml` has `survey` mode in dispatcher
- `survey` is in default `enabled_modes` JSON array
- Survey mode-behavior block in prompt (Phase 1-4 spatial decomposition)
- All ADR-001 commitments reflected
- CI green
- **CodeRabbit reviewed and conversations resolved**
- PR merged after maintainer signal
- v1 tag updated to new merge SHA

## Tasks

### P2-T1 — Read existing dispatcher state

- **Precondition:** entered P2; on branch `feat/p2-survey-mode`
- **Action:** Read `agentic-ops/.github/workflows/review.yml` lines 162-193 (mode dispatcher) and 273-311 (mode-behavior block); identify exact insertion points for new mode case + new behavior section.
- **Postcondition:** Agent has memorized line numbers and insertion patterns; recorded in STATE.md `notes` field.
- **Estimated time:** 5 min

### P2-T2 — Add survey to enabled_modes default

- **Precondition:** P2-T1 complete
- **Action:** Edit `review.yml` line ~48: `default: '["review","quick","deep","opus","survey"]'`
- **Postcondition:** Line matches exact pattern; valid JSON when parsed
- **Estimated time:** 1 min

### P2-T3 — Add survey case to dispatcher

- **Precondition:** P2-T2 complete
- **Action:** Edit `review.yml` mode dispatcher case statement; add line:
  ```bash
  "@claude survey"|"@claude survey "*) mode=survey; model=claude-sonnet-4-6 ;;
  ```
  Insert before the catch-all `*)` line.
- **Postcondition:** New line present; immediately followed by existing `*)` line
- **Estimated time:** 2 min

### P2-T4 — Add survey mode-behavior block

- **Precondition:** P2-T3 complete
- **Action:** Edit `review.yml` mode-behavior section in the prompt; insert survey block per the template at the bottom of this doc (also Appendix A.8 of the plan).
- **Postcondition:** Block present; references AGENTS.md / ADRs paths correctly; mentions wrapper script for posting; preserves the verbatim Phase 1-4 structure
- **Estimated time:** 30 min (prompt is detailed)

### P2-T5 — Verify dispatcher smoke test still passes

- **Precondition:** P2-T4 complete
- **Action:**
  1. Update `test-dispatcher.sh` to assert `@claude survey` → mode=survey (already prescribed in P1-T6 fixtures; verify the fixture exists and passes)
  2. Run `bash test-dispatcher.sh`
- **Postcondition:** all test cases pass (exit 0)
- **Estimated time:** 5 min

### P2-T6 — Local actionlint

- **Precondition:** P2-T5 complete
- **Action:** Run `actionlint .github/workflows/review.yml`
- **Postcondition:** exit 0; no diagnostics
- **Estimated time:** 1 min

### P2-T7 — Open PR

- **Precondition:** P2-T6 complete; branch pushed to origin
- **Action:** `gh pr create` with title `feat(p2): add survey mode (L1, Phase 1-4 single-agent)`; body links ADR-001 and ADR-002
- **Postcondition:** PR exists; PR number recorded in STATE.md
- **Estimated time:** 3 min

### P2-T8 — Wait for CI green

- **Precondition:** P2-T7 complete
- **Action:** Poll `gh pr checks <pr>` until all required checks succeed
- **Postcondition:** all checks green; no failures recorded
- **Estimated time:** ~5 min (CI runtime)

### P2-T9 — CodeRabbit review and resolution

- **Precondition:** P2-T8 complete
- **Action:** Wait for CodeRabbit pass; address each conversation (fix or reply with rationale); resolve all conversations
- **Postcondition:** CodeRabbit summary on PR; zero unresolved conversations; any follow-up commits also CI-green
- **Estimated time:** 15-30 min (depends on findings)

### P2-T10 — Merge PR and bump v1 tag

- **Precondition:** P2-T9 complete; maintainer signal received
- **Action:** Merge PR (squash); fetch the new merge SHA; force-push the `v1` tag to point at it; push tag to origin
- **Postcondition:** PR merged; `v1` tag now resolves to the merge SHA; CBM caller still works against `v1`
- **Estimated time:** 3 min

### P2-T11 — Write CHECKPOINT-P2

- **Precondition:** P2-T10 complete
- **Action:** Append CHECKPOINT-P2 entry to `.planning/auto-execution/CHECKPOINTS.md` with: merged PR URL, merge SHA, v1 tag SHA, test-dispatcher pass/fail, CodeRabbit findings count, any deviations from plan
- **Postcondition:** CHECKPOINT-P2 present; STATE.md `current_phase` advanced to P3
- **Estimated time:** 5 min

## Phase total estimate

1.5 hours, 11 tasks, ~1 session.

## Survey mode-behavior prompt template

The full text inserted by P2-T4. This is the critical content artifact of the phase — review carefully before merge.

```text
* survey: spatial-decomposition review for large PRs (>50 files or
  >5K changed lines). Single-agent path (L1) — Phase 1-4 sequential.

  PHASE 1 — Zone map.
  Run `gh pr diff ${{ github.event.issue.number }} --name-only` to
  list changed files. Run `gh pr diff ${{ github.event.issue.number }}
  --stat` to size them. Build internally a list of 3-8 zones, each
  with: (a) zone-id (kebab-case), (b) path globs covered, (c) suspected
  concern category (auth/contract/scaffolding/docs/test/infra/data),
  (d) priority (P1/P2/P3) based on apparent load-bearing-ness.
  Cap zones at 8. DO NOT post yet.

  PHASE 2 — Per-zone deep read.
  For each P1 then P2 zone, in turn:
    - Read at most 6 files within that zone (prefer most-changed
      files per the --stat output).
    - Pattern-match for AI-failure modes specific to the zone's
      category:
        auth zones → secret leaks, missing input validation,
                     hardcoded credentials, weak crypto choices
        contract zones → reader/writer field-name mismatch,
                         schema drift, breaking API changes
        scaffolding zones → declared-but-unused symbols, code paths
                            with no test coverage, speculative
                            abstractions
        docs zones → claims that contradict code, stale references,
                     forgotten TODO/FIXME, outdated examples
        test zones → tests asserting on absent code, fragile
                     mocks, bare-except swallowing, flaky timing
        infra zones → unpinned deps, missing timeouts, broad
                      shell injection, missing concurrency guards
        data zones → missing migration backwards-compat, unindexed
                     queries on hot path, schema-vs-validation drift
    - Note findings inline in scratchpad with: file:line, severity
      (critical/warning/suggestion), one-sentence concern.
    - DO NOT post per-zone.

  PHASE 3 — Cross-zone integrity.
  Read pr-head/${{ inputs.agents_md_path }} and any ADRs at
  pr-head/.planning/decisions/ADR-*.md or pr-head/docs/adr/ADR-*.md.
  Identify:
    - ADR violations introduced by this diff (cite ADR# + line)
    - Vocabulary drift between writer (e.g., template generator)
      and reader (e.g., parser) within the diff
    - Gate-script changes whose downstream readers were not updated
    - Hook-enforced commitments (per AGENTS.md) violated by the diff

  PHASE 4 — Synthesis + post.
  Run `gh pr view ${{ github.event.issue.number }} --comments` to
  see existing CodeRabbit / Codex / Claude findings. Dedupe yours
  against theirs (skip findings already raised; note dupes briefly).
  Order findings: P1 first, then P2, then P3. Within each priority,
  group by zone. Prepend a metadata footer:
      ```
      Mode: survey | Model: claude-sonnet-4-6
      Zones: <count> | Files read: <count>
      Runtime: <approx-seconds>s | Run: <run_url>
      ```text
  Post ONE comment via the wrapper script:
      ./central/.github/scripts/post-claude-review.sh <pr> <<'EOF'
      <body>
      EOF
  If body exceeds ~50KB, prioritize critical/warning over suggestion;
  cap and add a "[truncated; N more findings omitted]" note.

  Budget caps:
    - Max files read in Phase 2: 6 per zone × 8 zones = 48 max
    - Max files read in Phase 3: 6 (AGENTS.md + ADRs)
    - Hard timeout: 45 min (workflow-level)
```

## References

- ADR-001 — Mode taxonomy (defines survey as a mode)
- ADR-002 — Parallelism architecture (L1 baseline, L3 deferred)
- `phases/P5-survey-mode-l3.md` — conditional follow-up if empirical signal demands fan-out
- `EXECUTION-MODEL.md` — task atomicity, checkpoint protocol
- `GUARDRAILS.md` — review discipline (CodeRabbit-required before merge)
