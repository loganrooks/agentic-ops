# Human-attention triggers

Points where the autonomous agent halts and waits for the user.
Listed in expected order of encounter.

## HUMAN-GATE-1 — Auto-merge enabled in agentic-ops repo settings

**When.** Before P1-T15 (first PR auto-merge). **Status as of
P1.5: confirmed enabled.** The first invocation of
`gh pr merge --auto` on PR #1 succeeded, indicating auto-merge is
already enabled in repo settings.

**What user did:** enabled "Allow auto-merge" in
https://github.com/loganrooks/agentic-ops/settings.

## HUMAN-GATE-1.5 — CodeRabbit installed + branch protection

**Added in P1.5 as a hardening of HUMAN-GATE-1.** Status: complete.

**What user did:**

1. Installed CodeRabbit GitHub App on `loganrooks/agentic-ops`.
2. Asked the agent to apply branch protection on `main` via gh CLI:
   PR required, required status checks (`lint`,
   `dispatcher-smoke`), strict (up-to-date), conversation resolution
   required, linear history, no force-push to main, no deletion,
   admin (logan) NOT enforced (emergency escape hatch retained).

**Effect.** All subsequent phase PRs (P2 onwards) get CodeRabbit
reviews automatically and cannot merge until conversations are
resolved. The technical enforcement now matches the plan's
discipline.

## HUMAN-GATE-2 — First v1 tag creation

**When.** Before P1-T15 if `git ls-remote origin refs/tags/v1`
returns nothing.

**Status as of P1.5: complete.** The v1 tag pre-existed at an
earlier SHA; P1-T15 force-updated it to the P1 merge SHA `3f5d05a`.

**Subsequent v1 updates** (after P1.5, P2, P3, ... merges) are
performed by the agent automatically — `git tag -f v1 <merge-sha>
&& git push origin v1 --force` after CI green AND CodeRabbit
review.

## HUMAN-GATE-3 — CBM caller stub edits

**When.** Each phase that updates CBM's caller stub to add new
modes (P2 adds `survey`, P3 adds `audit`, P4 adds
`extra_allowed_tools`).

**Note.** These are PRs to CBM, not direct edits. They follow CBM's
own review discipline (CodeRabbit + Codex + maintainer). The agent
opens the PR; the user merges after CBM CI passes and reviews
complete.

## HUMAN-GATE-4 — OAuth token / API issues

**When.** Anytime `CLAUDE_CODE_OAUTH_TOKEN` validation fails or
sustained API errors occur.

**What user does.** Rotate token if expired; investigate Anthropic
dashboard.

## HUMAN-GATE-5 — Empirical gate decisions

**When.** Between P4 and P5 (and again before P6).

**Note.** The agent's decision logic in `phases/EMPIRICAL-GATE.md`
is automated. But if metrics are ambiguous (e.g., "2 distinct
findings; 3 zones — borderline"), the agent escalates with raw data
and asks for human judgment.

## HUMAN-GATE-6 — CodeRabbit review pending or stuck

**When.** A PR has been open for >15 minutes with CI green but no
CodeRabbit review posted. The agent does NOT proceed to merge in
this case.

**Resolution paths.**

1. The agent comments `@coderabbitai review` to manually trigger.
2. If still no response after another 10 minutes → escalate to user
   (CodeRabbit may be down, rate-limited, or the App may have been
   disabled for the repo).

This gate is implicit in the discipline; it manifests as an
`AWAITING_EXTERNAL` state on the merge task, not a separate
escalation, unless the wait exceeds the threshold.
