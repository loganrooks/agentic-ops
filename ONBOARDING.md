# Onboarding a consumer repo

This is the internal-consumer onboarding recipe for `loganrooks/agentic-ops`.

## Scope

This document covers adding a caller stub to a repo so that it consumes
the `agentic-ops` kernel workflow via the floating `v1` tag.

The consumer set is bounded by
[ADR-006](docs/adr/ADR-006-bounded-deployment-scope.md): an internal
named set under single-principal plan-auth. **External use is out of
scope per ADR-006 §3.** No installer, marketplace path, or fork
recipe (ADR-006 §5). Adding a consumer beyond the named set
requires a new ADR per ADR-006 §"Trigger conditions for revisiting".
Anyone reading this who is not a named consumer should stop here
and read ADR-006 §3 first.

## Prerequisites

The target consumer repo must have all four before onboarding can begin:

- `CLAUDE_CODE_OAUTH_TOKEN` secret set (Anthropic plan-auth token).
  Absence escalates per HUMAN-GATE-4.
- **CodeRabbit GitHub App installed.** Per
  [AGENTS.md](AGENTS.md) §"Hard rules", do not merge without
  CodeRabbit review. The discipline propagates with the substrate;
  the consumer repo also needs CodeRabbit. Absence escalates per
  P7 §Notes (HUMAN-GATE-3 equivalent).
- Branch protection on the consumer repo's main branch: PR
  required, required status checks, conversation resolution
  required, linear history.
- Maintainer has merge rights on the consumer repo.

## The minimal caller stub

The canonical source is the `Consumer caller stub` block in the
header comment of
[`.github/workflows/review.yml`](.github/workflows/review.yml).
If that header changes, it is authoritative; the snippet below is
a reading aid. The working reference instance is CBM's caller stub
([`loganrooks/codebase-mapper`](https://github.com/loganrooks/codebase-mapper)
at SHA `f6fe379` as of 2026-05-11).

```yaml
on:
  issue_comment:
    types: [created]
permissions:
  contents: read
  pull-requests: write
  issues: write
  id-token: write
jobs:
  review:
    uses: loganrooks/agentic-ops/.github/workflows/review.yml@v1
    with:
      enabled_modes: '["review","quick","deep","opus","survey","audit"]'
      review_focus_paths: |
        src/important.py
    secrets:
      claude_code_oauth_token: ${{ secrets.CLAUDE_CODE_OAUTH_TOKEN }}
```

Per-repo customizable inputs (defaults in `.github/workflows/review.yml`):

- `enabled_modes` — modes from the central registry; out-of-list
  modes are rejected at dispatch. See
  [ADR-001](docs/adr/ADR-001-mode-taxonomy.md).
- `review_focus_paths` — globs prioritized in `review` mode.
- `gates_paths` — required if `gates` is in `enabled_modes`.
- `extra_allowed_tools` — static-analysis-only additions (e.g.
  `Bash(ruff:*),Bash(mypy:*)`). Per
  [ADR-004](docs/adr/ADR-004-allowlist-policy.md), no test
  runners, installers, build tools, network fetchers, or
  code-execution surfaces. Compile-capable tools must be pinned
  to non-emitting invocations (e.g. `tsc --noEmit`, not bare
  `tsc:*`); see ADR-004 §"Forbidden entries".
- `agents_md_path` — default `AGENTS.md`; missing file tolerated.
- `repo_label` — default `github.event.repository.name`.

Pin the kernel reference to `@v1` (floating major tag per
[ADR-003](docs/adr/ADR-003-versioning-and-release.md)), not
`@main`, so consumer reviews run against the last-released kernel.

## Per-repo customization checklist

Each consumer onboarding makes the following per-repo decisions.
Values for the named consumers are tabled in
[`.planning/phases/P7-onboarding.md`](.planning/phases/P7-onboarding.md)
§"Per-repo configuration"; this checklist is the *procedural* side.

1. **Legacy workflow handling.** Check the consumer repo for an
   existing `.github/workflows/claude-review.yml` (or similar).
   If found, decide: delete (fully superseded), or rename to
   `claude-review-legacy.yml` and disable triggers (unique
   behavior worth preserving for inspection during rollout).
2. **AGENTS.md path detection.** Check whether the consumer repo
   has `AGENTS.md` at root. If present, no override needed. If
   absent or at a non-default path, set `agents_md_path`
   explicitly or escalate (no AGENTS.md means Claude proceeds
   without operative discipline; this is tolerated but worth
   flagging).
3. **`repo_label` naming.** Default is the GitHub repo name; set
   explicitly if the repo's GitHub name is not the
   human-friendly name (e.g. `loganrooks/cbm` →
   `repo_label: codebase-mapper`).
4. **`enabled_modes` selection.** Use the P7 table for the named
   consumers, with one normalization: audit-mode entries in
   `enabled_modes` must be bare `audit`, not `audit:<lens>`. The
   dispatcher (`.github/workflows/review.yml`) sets `mode=audit`
   for any `@claude audit:...` trigger and validates `mode`
   against `enabled_modes`, so lens-prefixed entries fail
   dispatch. Lens selection happens at trigger time via the
   `audit_target` argument, not at enable time. New consumers
   should start with a conservative subset
   (`["review","quick","deep"]`) and expand based on maintainer
   judgment.
5. **`review_focus_paths`, `extra_allowed_tools`.** Use the P7
   table; values reflect the consumer's contract surfaces and
   static-analysis stack. Review each `extra_allowed_tools` entry
   against [ADR-004](docs/adr/ADR-004-allowlist-policy.md) — in
   particular, compile-capable tools (e.g., `tsc`, `cargo`,
   `tsc:*` wildcards) must be pinned to non-emitting invocations
   only.

## Per-repo agent brief

For autonomous P7-T<n> execution, the brief handed to a
fresh-context agent must include all of the following:

- **Target repo URL** (`https://github.com/loganrooks/<repo>`).
- **Configuration row** from
  [`.planning/phases/P7-onboarding.md`](.planning/phases/P7-onboarding.md)
  §"Per-repo configuration". The P7 table has four columns —
  `Repo`, `enabled_modes`, `review_focus_paths`,
  `extra_allowed_tools`. `agents_md_path` and `repo_label` are
  not table-provided; they use the workflow defaults (`AGENTS.md`
  and `github.event.repository.name` respectively) unless the
  customization checklist above identified a per-repo override.
- **Branch name**: `feat/agentic-ops-onboarding` in the target
  repo.
- **PR title**: `chore: onboard to agentic-ops centralized review`
  (mirrors CBM's onboarding PR shape).
- **PR body**: link back to agentic-ops, list of enabled modes,
  brief security note (trusted-actor gate, wrapper-script
  discipline, allowlist).
- **Success criteria**: CI green; CodeRabbit reviewed +
  conversations resolved; maintainer signal; smoke-test
  succeeds (next §).
- **Escalation triggers** — agent halts and escalates per the
  matching gate, recording the escalation in
  `.planning/auto-execution/escalations/`:
  - **HUMAN-GATE-3** — caller stub edits on a target repo
    requiring maintainer eyes beyond the standard onboarding
    shape.
  - **HUMAN-GATE-4** — `CLAUDE_CODE_OAUTH_TOKEN` validation
    fails or sustained API errors.
  - **HUMAN-GATE-6** — CodeRabbit review pending or stuck
    (>15 min CI-green without CodeRabbit review;
    `@coderabbitai review` does not unstick within 10 min).

  Canonical wire format and resolution paths are in
  [`.planning/HUMAN-GATES.md`](.planning/HUMAN-GATES.md). When a
  gate fires, the agent records the escalation, moves to the
  next consumer if one is queued, and resumes the gated repo
  when the gate clears.

## Smoke test

After the onboarding PR merges, validate the wiring with a benign
trigger in the target repo:

- **For `review` mode** — use a tiny doc-only PR. The dispatcher's
  `if:` clause restricts non-audit modes to PR contexts
  (`github.event.issue.pull_request != null`), so `@claude review`
  on a plain issue won't fire.
- **For `audit` mode** — a plain issue thread is acceptable
  (`audit` is the one mode the dispatcher's `if:` allows on
  non-PR comments).

Do not smoke-test on a real review-bearing PR — that conflates
first-run validation with substantive review output. Per
P7-T<n>-5 §"Notes."

A successful smoke test means: workflow fires, Claude posts a
short comment via `post-claude-review.sh`, no `allowedTools`
denials in the run log, total wall-clock under the
`timeout_minutes` default (45).

## What this is not

- **Not a marketplace install path.** No GitHub Marketplace, npm,
  or pip packaging.
- **Not a public-facing recipe.** Per ADR-006 §3, external
  onboarding is out of scope.
- **Not a substitute for ADR-006 supersession.** Moving beyond the
  named-consumer set requires a new ADR per ADR-006 §"Trigger
  conditions for revisiting".
- **Not a script.** No installer is documented or supported; a
  shell-script fallback (`bin/onboard.sh`) is a separately scoped
  future initiative, not part of this recipe.
- **Not a substitute for [AGENTS.md](AGENTS.md) hard rules.**
  Consumer onboarding PRs follow the substrate's review
  discipline — CodeRabbit + CI + maintainer signal + no ADR body
  edits.

## References

- [ADR-001](docs/adr/ADR-001-mode-taxonomy.md) — mode taxonomy
- [ADR-003](docs/adr/ADR-003-versioning-and-release.md) — `v1`
  floating-tag versioning
- [ADR-004](docs/adr/ADR-004-allowlist-policy.md) —
  `extra_allowed_tools` policy
- [ADR-006](docs/adr/ADR-006-bounded-deployment-scope.md) —
  bounded deployment scope
- [`.github/workflows/review.yml`](.github/workflows/review.yml)
  header — canonical caller-stub exemplar (the `Consumer caller
  stub` block in the header comment)
- [`.planning/phases/P7-onboarding.md`](.planning/phases/P7-onboarding.md)
  — per-repo configuration table, full P7 task graph
- [`.planning/HUMAN-GATES.md`](.planning/HUMAN-GATES.md) —
  escalation surface
- [AGENTS.md](AGENTS.md) — operative discipline
