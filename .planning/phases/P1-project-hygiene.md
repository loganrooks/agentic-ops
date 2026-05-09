# Phase P1 — A0 Project hygiene

**Goal:** Stand up baseline project hygiene for agentic-ops: LICENSE, CONTRIBUTING, AGENTS, SECURITY, CI workflow, dispatcher smoke test, 5 ADRs.

**Status:** complete (2026-05-09)

**Branch:** `feat/p1-project-hygiene` (merged via squash at 3f5d05a)

**PR:** [#1](https://github.com/loganrooks/agentic-ops/pull/1)

## Phase entry preconditions

- P0 checkpoint exists
- `agentic-ops/.git` clean (no uncommitted changes that could collide)
- `agentic-ops/.github/workflows/review.yml` exists (already shipped in S3)
- `agentic-ops/.github/scripts/post-claude-review.sh` exists

## Phase exit postconditions

- All 16 task postconditions pass
- PR is merged into agentic-ops main
- v1 tag is reachable from the merged commit (force-update)

## Tasks

### P1-T1 — Create LICENSE

- **Precondition:** `agentic-ops/LICENSE` does NOT exist
- **Action:** Write Apache-2.0 license text (canonical, full text from Appendix A.1)
- **Postcondition:** file exists; the canonical Apache License header is present (the first non-blank line is the centred string `Apache License` per the canonical text); contains "Version 2.0, January 2004"; size > 10000 bytes
- **Retry:** 3
- **Time:** 1 min

### P1-T2 — Create CONTRIBUTING.md

- **Precondition:** `agentic-ops/CONTRIBUTING.md` does NOT exist
- **Action:** Write CONTRIBUTING.md per template Appendix A.2 with sections: Project layout, Contribution workflow (fork, branch, PR, CI required, ADR for load-bearing), Tag-update protocol, Security-issue reporting (link to SECURITY.md), Style (actionlint + shellcheck + yamllint clean before merge)
- **Postcondition:** file exists; contains all 5 section headers
- **Retry:** 3
- **Time:** 5 min

### P1-T3 — Create AGENTS.md

- **Precondition:** `agentic-ops/AGENTS.md` does NOT exist
- **Action:** Write AGENTS.md per template Appendix A.3 with 5 commitments: multi-vendor by design, plan-auth-friendly (no Anthropic OAuth ToS violations), defense in depth, stateless agents + persistent registry, devops discipline applied to itself
- **Postcondition:** file exists; contains all 5 commitment statements; references VISION.md
- **Retry:** 3
- **Time:** 5 min

### P1-T4 — Create SECURITY.md

- **Precondition:** `agentic-ops/SECURITY.md` does NOT exist
- **Action:** Write SECURITY.md per template Appendix A.4 with sections: Threat model (Comment-and-Control, prompt injection via PR content, allowlist breakage, OAuth token handling, secrets in PR runners), Mitigations in place (wrapper script, narrow allowlist, quoted heredoc, trusted-actor gate, pinned action SHAs), Reporting flow (private security advisory), Out-of-scope (sandboxed-execution path, deferred per ADR-004)
- **Postcondition:** file exists; contains all 4 section headers; reporting flow uses GitHub private advisory
- **Retry:** 3
- **Time:** 10 min

### P1-T5 — Create CI workflow

- **Precondition:** `agentic-ops/.github/workflows/ci.yml` does NOT exist
- **Action:** Write CI workflow per Appendix A.5: triggers on `pull_request` and `push: { branches: [main] }`; pinned-SHA `actions/checkout`; steps actionlint + shellcheck + yamllint + dispatcher-smoke-test; `fail-fast: false`; 10 min timeout
- **Postcondition:** file exists; passes `actionlint .github/workflows/ci.yml` locally; pinned SHA for actions/checkout (no @v4 floating ref)
- **Retry:** 3
- **Time:** 10 min

### P1-T6 — Create dispatcher smoke test

- **Precondition:** `agentic-ops/.github/scripts/test-dispatcher.sh` does NOT exist
- **Action:** Write smoke-test script per Appendix A.6 covering review/gates/survey/audit happy paths, near-miss negatives (`@claude reviewing`, `@claude gatesomething`), free-form audit, empty body, mention-not-first-line, and disallowed-mode rejection
- **Postcondition:** script is executable (`chmod +x`); `bash test-dispatcher.sh` exits 0; all 13 test cases assert correctly
- **Retry:** 3
- **Time:** 30 min

### P1-T7 — ADR-001 mode-taxonomy

- **Precondition:** `agentic-ops/docs/adr/` exists
- **Action:** Spawn parallel general-purpose agent to write `docs/adr/ADR-001-mode-taxonomy.md` capturing D1 (mode taxonomy decision) per Appendix C template; length 800–1500 words
- **Postcondition:** file exists at expected path; contains required sections (title, Status: accepted, Date: today, Context, Decision, Alternatives, Consequences positive/negative/neutral)
- **Retry:** 3
- **Time:** 30 min total (shared with T8–T11, parallel)

### P1-T8 — ADR-002 parallelism-architecture

- **Precondition:** `docs/adr/` exists
- **Action:** Spawn parallel agent to write `docs/adr/ADR-002-parallelism-architecture.md` capturing D2 per Appendix C; length 800–1500 words
- **Postcondition:** file exists; required sections; Status: accepted; Date: today
- **Retry:** 3
- **Time:** parallel with T7/T9–T11

### P1-T9 — ADR-003 versioning-and-release

- **Precondition:** `docs/adr/` exists
- **Action:** Spawn parallel agent to write `docs/adr/ADR-003-versioning-and-release.md` capturing D3 per Appendix C; length 800–1500 words
- **Postcondition:** file exists; required sections; Status: accepted; Date: today
- **Retry:** 3
- **Time:** parallel

### P1-T10 — ADR-004 allowlist-policy

- **Precondition:** `docs/adr/` exists
- **Action:** Spawn parallel agent to write `docs/adr/ADR-004-allowlist-policy.md` capturing D4 (sandboxed-execution deferral, narrow allowlist policy) per Appendix C; length 800–1500 words
- **Postcondition:** file exists; required sections; Status: accepted; Date: today
- **Retry:** 3
- **Time:** parallel

### P1-T11 — ADR-005 audit-output-format

- **Precondition:** `docs/adr/` exists
- **Action:** Spawn parallel agent to write `docs/adr/ADR-005-audit-output-format.md` capturing D5 per Appendix C; length 800–1500 words
- **Postcondition:** file exists; required sections; Status: accepted; Date: today
- **Retry:** 3
- **Time:** parallel

### P1-T12 — Local validation

- **Precondition:** P1-T1..T11 all complete
- **Action:** Run `actionlint .github/workflows/*.yml` (exit 0), `shellcheck .github/scripts/*.sh` (exit 0), `bash .github/scripts/test-dispatcher.sh` (exit 0), `yamllint .github/workflows/*.yml` (skip with warning if not installed)
- **Postcondition:** all checks pass
- **Retry:** 1 (read failing output, edit offending file, retry; escalate after 1 retry)
- **Time:** 5 min

### P1-T13 — Open PR

- **Precondition:** P1-T12 complete; on branch `feat/p1-project-hygiene`
- **Action:** `git add` new files; commit with `feat(p1): project hygiene — license, contributing, agents, security, CI, ADRs`; `git push -u origin feat/p1-project-hygiene`; `gh pr create` per Appendix A.7; capture PR number
- **Postcondition:** PR exists; PR number recorded in STATE.md
- **Retry:** 3 (network errors)
- **Time:** 2 min

### P1-T14 — Wait for CI to pass

- **Precondition:** P1-T13 complete
- **Action:** `gh pr checks <PR-number> --watch` in background; ScheduleWakeup at 5-min intervals (max 30 min total); on failure read `gh run view <run-id> --log-failed`, diagnose, fix, push (max 2 fix iterations); else escalate
- **Postcondition:** all CI checks on PR are green
- **State during task:** `AWAITING_EXTERNAL`
- **Retry:** 2 fix-iterations
- **Time:** 5–30 min wait

### P1-T15 — Auto-merge PR + tag v1

- **Precondition:** P1-T14 complete (CI green); auto-merge enabled in repo settings (HUMAN-GATE-1)
- **Action:** `gh pr merge <PR-number> --squash --auto --delete-branch`; poll `gh pr view --json mergedAt` every 30s (max 5 min); checkout main; pull; capture merge SHA; `git tag -f v1 <merge-sha>`; `git push origin v1 --force`; verify via `git ls-remote origin refs/tags/v1`
- **Postcondition:** PR merged; v1 tag points to merge commit
- **Retry:** 3 (transient errors)
- **Time:** 3 min

### P1-T16 — Phase checkpoint

- **Precondition:** P1-T1..T15 all complete
- **Action:** Run §2.4 checkpoint protocol for P1
- **Postcondition:** `CHECKPOINT-P1.md` exists; STATE.md advances to P2
- **Time:** 2 min

## Phase total estimate

1.5–2 hours, 16 tasks, 1 session.

## Outcome (retrospective)

- Completed: 2026-05-09T03:15:40Z
- All 16 tasks complete; checkpoint at `auto-execution/checkpoints/CHECKPOINT-P1.md`
- Artifacts produced: 12 files (LICENSE, CONTRIBUTING.md, AGENTS.md, SECURITY.md, .yamllint.yml, .github/workflows/ci.yml, .github/scripts/test-dispatcher.sh, docs/adr/ADR-001..005)
- CI run: https://github.com/loganrooks/agentic-ops/actions/runs/25590130338 (lint 8s + dispatcher-smoke 3s, both SUCCESS)
- v1 tag force-updated 46410dc → 3f5d05a
- Cost estimate: ~0.6 sessions

## Deviations and post-merge corrections

- The phase doc as originally specified merged on CI green via `gh pr merge --auto` without waiting for CodeRabbit review. CodeRabbit was not installed on agentic-ops at the time. This was identified post-merge as a process violation and corrected in P1.5: CodeRabbit installed, branch protection applied, GUARDRAILS.md and AGENTS.md updated to require CodeRabbit review before merge.
- All future phase PRs (P2 onward) will wait for CodeRabbit review and conversation resolution before merge.
