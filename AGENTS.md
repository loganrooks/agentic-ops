# AGENTS.md — agentic-ops operative discipline

This file is read by AI agents (and humans) on every contribution to
`agentic-ops`. It captures the discipline this project commits to.
The strategic context lives in `VISION.md`; this file is the operative
counterpart — what you must do (and not do) when contributing here.

## Scope

You are contributing to the centralized AI-led PR review substrate.
Changes here propagate to multiple consumer repos via the floating
`v1` tag. Quality and predictability matter more than velocity.

Before contributing, read:
- This file
- `SECURITY.md` for threat model context
- `docs/adr/README.md` for ADR format
- The ADR most relevant to your change (if any)

## Operative commitments (non-negotiable)

### 1. Multi-vendor by design

See `VISION.md` §3.1. No vendor-locked code paths. Claude is the
primary substrate today, but the architecture must not foreclose
future Codex App input or specialist substrates. When in doubt,
prefer abstraction over hardcoding the current vendor's quirks.

### 2. Plan-auth-friendly

See `VISION.md` §3.3. Anthropic plan auth (`CLAUDE_CODE_OAUTH_TOKEN`)
is the cost ceiling. Do not adopt substrates that violate Anthropic's
Pro/Max OAuth ToS (e.g., third-party clients implementing OAuth
against Anthropic). See `OPEN_QUESTIONS.md` OQ-2.

### 3. Defense in depth

See `VISION.md` §3.5. No single point of failure on prompt injection.
The layers currently in place:

- **Trusted-actor + trigger-phrase gate** in the workflow `if:` clause
- **Wrapper-script for posting** (`post-claude-review.sh`) — closes
  the Comment-and-Control attack class
- **`allowedTools` allowlist** — constrains blast radius of any
  successful injection
- **Quoted heredoc in prompts** (`<<'EOF'`) — prevents shell expansion
  of PR-derived content before the wrapper sees it
- **Pinned action SHAs** — no floating-tag drift on third-party actions

Each layer must be independently sufficient against its threat class.
Adding a layer is fine; removing one requires an ADR.

### 4. Stateless agents, persistent registry

See `VISION.md` §3.6. Each invocation is fresh — no conversation
state survives across runs. Context flows via files (the prompt, the
PR diff, ADRs, AGENTS.md). State that persists belongs to the registry
(missed-signal log, weekly-health aggregations) — not to agent memory.

### 5. Devops discipline applied to itself

See `VISION.md` §3.7. This project gets the same discipline it asks
of others:

- ADRs for load-bearing decisions
- Runbooks for operational procedures
- Postmortems when a missed signal surfaces
- Self-CI (actionlint, shellcheck, yamllint, dispatcher smoke test)

## Hard rules

- **Do not merge without CodeRabbit review.** CI green is necessary
  but not sufficient. CodeRabbit must post its review and any
  actionable findings must be addressed or explicitly resolved.
  Branch protection enforces this via required conversation
  resolution. If you are an autonomous agent executing a plan that
  specifies `gh pr merge --auto` on CI green, OVERRIDE the plan —
  stop after CI green, wait for CodeRabbit, then proceed only after
  CodeRabbit has reviewed AND the maintainer has signaled merge.
- **Do not modify `review.yml`'s `allowedTools` allowlist without an
  ADR.** Adding a tool widens the prompt-injection blast radius.
- **Do not add test runners** (pytest, jest, npm test, cargo test)
  to the `extra_allowed_tools` policy. See `docs/adr/ADR-004-allowlist-policy.md`.
- **Do not bypass CI.** No `--no-verify`, no merging red PRs.
- **Do not edit existing ADR bodies.** Supersede with a new ADR if a
  decision changes, or amend per `docs/adr/README.md` if the change
  is purely additive. ADR `Status:` lines may be updated to reflect
  later amend/supersede/deprecate relationships per the README's
  metadata-only editing exception; no other lines may be edited.
- **Do not commit secrets.** `CLAUDE_CODE_OAUTH_TOKEN`, `GH_TOKEN`,
  PATs, etc. live in repo secrets only.
- **Do not skip the wrapper.** All comment posting goes through
  `.github/scripts/post-claude-review.sh`. Direct `gh pr comment`
  calls are blocked by the allowlist; do not try to add them.
- **Do not force-push branches.** The only force-pushed ref is the
  `v1` tag, per `docs/adr/ADR-003-versioning-and-release.md`. All
  branches (including feature branches and `main`) are append-only
  from the contributor's perspective.

## Soft preferences

- Prefer minimal diffs scoped to one concern per PR
- Prefer named scripts over inline shell when logic exceeds ~5 lines
- Prefer pinned third-party action SHAs over floating tags
- Prefer escalation over guessing when a spec is ambiguous
