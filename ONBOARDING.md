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
a reading aid. The working reference instance is CBM's caller stub at
[`loganrooks/codebase-mapper/.github/workflows/claude-review.yml@f6fe379`](https://github.com/loganrooks/codebase-mapper/blob/f6fe379/.github/workflows/claude-review.yml)
(permalink to the exact workflow file at commit `f6fe379`, as of
2026-05-11).

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

> **The example shows the kernel default `enabled_modes`** — six
> modes (`review`, `quick`, `deep`, `opus`, `survey`, `audit`).
> `gates` is supported by the kernel but is *not* in the default
> array; it must be opted into explicitly per-repo (and requires
> `gates_paths`). Do not copy the example verbatim during
> onboarding. Per-repo onboarding *overrides* this with the row
> from [`.planning/phases/P7-onboarding.md`](.planning/phases/P7-onboarding.md)
> §"Per-repo configuration", which is typically more conservative
> (`["review","quick","deep"]` plus a single audit lens or
> `survey`). Over-enabling adds cost and review surface without
> the rollout plan opting the consumer in.

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
   static-analysis stack. **Before copying any `extra_allowed_tools`
   value verbatim, audit it against
   [ADR-004](docs/adr/ADR-004-allowlist-policy.md) §"Forbidden
   entries" *and* the broader class of plugin-loading tools
   identified in [OQ-13](OPEN_QUESTIONS.md) — ADR-004 §Acceptable
   has not yet been amended to capture this class.** Until OQ-13
   resolves, the conservative defaults below apply:
   - **`Bash(eslint:*)` or `Bash(eslint *)` — never include.**
     ESLint loads `eslint.config.js` / `.eslintrc.js` from the PR
     head as executable JavaScript. Same threat class as test
     runners (ADR-004 §"Why no test execution"). The P7 table
     drops eslint from all rows pending OQ-13.
   - **`Bash(mypy:*)` or `Bash(mypy *)` — never include.** mypy
     loads `plugins` from `mypy.ini` / `pyproject.toml` as
     importable Python. Same threat class. P7 Python rows
     (`arxiv-sanity-mcp`, `scholardoc`) keep `Bash(ruff:*)` only.
   - **`Bash(flake8:*)`, `Bash(pylint:*)` — never include.** Both
     load local plugins from project config (`[flake8:local-plugins]`,
     `load-plugins`). Not currently in any P7 row but listed in
     ADR-004 §Acceptable; do not re-introduce.
   - **`Bash(tsc:*)` and `Bash(tsc --noEmit *)` wildcards — never
     include.** `Bash(tsc:*)` permits emit. `Bash(tsc --noEmit *)`
     is argument-injection-defeatable: `tsc --noEmit false --outFile
     central/.github/scripts/post-claude-review.sh a.ts` overwrites
     the privileged wrapper with attacker-controlled JavaScript
     (executable bit preserved by Node's `fs.writeFile`); next
     wrapper invocation runs attacker code as bash via JS-shell
     polyglot. The P7 table drops tsc from TS-stack rows entirely
     until OQ-13 resolves with a wrapper-script or
     sandboxed-execution path.
   - **Any wildcard `Bash(<tool>:*)` for a compile-capable tool**
     (cargo, npm build, make, cmake) — pin to non-emitting flags
     only via wrapper script (deferred to OQ-13). Until then,
     omit.

   **Currently-safe set** (verified no plugin/code-loading surface):
   `ruff` (Rust binary), `shellcheck`, `actionlint`, `yamllint`,
   `pyright` (bundled binary), `rg`, `jq`, `yq`, `ast-grep`. Other
   tools require independent verification before allowlisting.

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
  matching gate, writing the escalation file at the canonical
  EXECUTION-MODEL path
  `.planning/auto-execution/escalations/ESCALATION-<ISO8601>.md`
  (timestamp e.g. `2026-05-12T01:30:00Z`) and appending to the
  `ESCALATIONS.md` index per
  [`.planning/EXECUTION-MODEL.md`](.planning/EXECUTION-MODEL.md)
  §"Escalation procedure". An agent that writes to a
  non-canonical path will not be seen by `GO`-resume checks and
  the gate will be bypassed instead of halting on it:
  - **HUMAN-GATE-3** — caller stub edits on a target repo
    requiring maintainer eyes beyond the standard onboarding
    shape.
  - **HUMAN-GATE-4** — `CLAUDE_CODE_OAUTH_TOKEN` validation
    fails or sustained API errors.
  - **HUMAN-GATE-6** — CodeRabbit review pending or stuck
    (>15 min CI-green without CodeRabbit review;
    `@coderabbitai review` does not unstick within 10 min).

  Gate triggers and resolution prose are in
  [`.planning/HUMAN-GATES.md`](.planning/HUMAN-GATES.md); the
  actual write/update/index steps for an escalation (where to
  write the escalation file, how to index it, when to mark
  resolved) are in
  [`.planning/EXECUTION-MODEL.md`](.planning/EXECUTION-MODEL.md)
  §"Escalation procedure". An agent that hits a gate consults
  both — HUMAN-GATES.md for "which gate is this and how do I
  describe the situation"; EXECUTION-MODEL.md for "where do I
  write it and what comes next." When a gate fires, the agent
  records the escalation per EXECUTION-MODEL.md, moves to the
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
first-run validation with substantive review output. The
"benign no-op" smoke-test convention is specified in
[`.planning/phases/P7-onboarding.md`](.planning/phases/P7-onboarding.md)
§Notes (bullet beginning "The smoke-test comment in P7-T<n>-5
should be a benign no-op…"). `P7-T<n>-5` is the templated form
of the smoke-test subtask (one per consumer; `<n>` is the
per-repo position, indexed across the consumer set defined in
P7's per-repo configuration table).

A successful smoke test means: workflow fires, Claude posts a
short comment via `post-claude-review.sh`, no `allowedTools`
denials in the run log, total wall-clock under the configured
`timeout_minutes` value in
[`.github/workflows/review.yml`](.github/workflows/review.yml).

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
