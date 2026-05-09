# Phase P8 — Observability

**Goal:** Per-run metadata footer is already prescribed in survey/audit prompts (P2/P3). This phase adds the aggregator workflow that scrapes those footers across consumer repos, the missed-signal issue template that contributors file when a reviewer misses something, and the observability documentation.

**Status:** pending

**Branch:** `feat/p8-observability`

## Phase entry preconditions
- CHECKPOINT-P7 exists (multiple repos consuming, so observability has data to aggregate)

## Phase exit postconditions
- `agentic-ops/.github/workflows/weekly-health.yml` exists and passes actionlint
- `agentic-ops/.github/ISSUE_TEMPLATE/missed-signal.md` exists and renders in GitHub UI
- `agentic-ops/docs/observability.md` exists; linked from README.md
- CI green, **CodeRabbit reviewed + conversations resolved**, PR merged after maintainer signal, v1 tag bumped

## Tasks

### P8-T1 — Add aggregator workflow
- **Action:** Create `.github/workflows/weekly-health.yml`:
  - `on: schedule` (weekly, Sundays UTC)
  - `workflow_dispatch` for manual trigger
  - Aggregates artifacts from review runs over the prior 7 days (across all consumer repos with caller stubs)
  - Posts a "Weekly Health" issue per consuming repo with: run count, mode breakdown, cost estimate, missed-signal candidates
- **Postcondition:** workflow exists; actionlint passes; would run if scheduled (verify with `gh workflow list`).
- **Time:** ~90 min.

### P8-T2 — Missed-signal issue template
- **Action:** Create `.github/ISSUE_TEMPLATE/missed-signal.md`. Required fields:
  - Original PR/audit URL
  - Finding that was missed (verbatim from human or external reviewer)
  - Why it should have been caught (which mode + which lens/zone would have surfaced it)
  - Suggested prompt update or pattern addition to prevent recurrence
- **Postcondition:** template exists; renders in GitHub UI when filing issue.
- **Time:** ~15 min.

### P8-T3 — Documentation
- **Action:** Add `docs/observability.md` describing:
  - The metadata footer schema (Mode/Lens/Model/Files-read/Runtime/SHA/Run URL)
  - The aggregator workflow's output format
  - The missed-signal flow (when to file, what to include, how it feeds into prompt updates)
  - Cost-monitoring guidance (how to interpret aggregator output; thresholds for concern)
- Linked from README.md.
- **Postcondition:** doc exists; README.md has a link.
- **Time:** ~30 min.

### P8-T4..T8 — Local validation, PR open, wait CI + CodeRabbit, merge after maintainer signal, v1 tag, checkpoint
- Mirror the standard phase-tail pattern used in P1, P2, P3, P4.

## Phase total estimate
3-4 hrs.

## Aggregator workflow design notes

The aggregator is a single GHA workflow that runs on `agentic-ops` itself but reaches into consumer repos via the GitHub API. Approach:

1. List all PRs and issues across consumer repos with caller stubs (target repos identified by a label or by checking for the caller stub file).
2. For each PR/issue with a Claude review comment in the past 7 days, parse the metadata footer.
3. Aggregate by repo, by mode, by model. Compute totals.
4. Identify missed-signal candidates: PRs where the Claude review's findings did not include items raised in subsequent CodeRabbit/Codex/maintainer comments.
5. Post a "Weekly Health" issue (or update the existing one) on each consumer repo with a structured report.

## Missed-signal flow

When a reviewer (human or automated) catches something the Claude review missed:

1. Contributor files an issue using the missed-signal template on agentic-ops (NOT on the consumer repo).
2. Maintainer triages: is this a prompt update, a mode-budget tweak, or a pattern-detection gap?
3. The fix lands as a PR to agentic-ops, with reference to the missed-signal issue.
4. After the fix merges, the issue closes with the merge commit SHA + a brief explanation.

This creates the registry-of-patterns referenced in VISION.md §3.6.

## References
- ADR-005 — Audit output format (defines the metadata footer)
- VISION.md §3.6 — stateless agents, persistent registry
- `phases/P7-onboarding.md` — must merge first; observability needs multiple consumer repos to be meaningful
