# Guardrails

The cross-cutting rules an autonomous executor must obey. These
override individual task specs in conflict.

## Hard rules (NEVER violate)

1. **Never edit a file outside `agentic-ops/` or the consumer repos
   the plan explicitly targets.** The single canonical plan file at
   `~/.claude/plans/luminous-hopping-lemon.md` is read-only from the
   agent's perspective; only the user edits it.

2. **Never push directly to main.** Every change goes through a PR.

3. **Never force-push branches other than tags.** The `v1` tag is
   force-updated per `docs/adr/ADR-003-versioning-and-release.md`.
   Branches (including `main`) are append-only.

4. **Never bypass CI.** PRs cannot be merged unless their CI is green.
   No `--no-verify`, no `--no-gpg-sign`, no other hook-bypass flags.

5. **Never merge without CodeRabbit review.** CI green is necessary
   but not sufficient. CodeRabbit must post its review and any
   actionable findings must be addressed or explicitly resolved
   (resolving the conversation is the technical signal). If a phase
   doc specifies `gh pr merge --auto` on CI green, OVERRIDE the
   phase doc — wait for CodeRabbit first. Branch protection on
   `main` enforces this via required conversation resolution.

6. **Never skip a checkpoint.** Each phase ends with a
   `checkpoints/CHECKPOINT-PN.md` file before the next phase
   starts.

7. **Never invent state.** STATE.md is single source of truth. If
   reality contradicts STATE, escalate.

8. **Never silently fall back.** If a task can't complete as
   specified, retry → escalate. No "make it work somehow."

9. **Never expand scope mid-plan.** If something useful surfaces,
   log it as a future-work item but do not implement during this
   initiative. (P1.5 is the exception that proves the rule — added
   after P1 merged, with explicit course-correction approval from
   the user.)

10. **Never skip postcondition verification.** Even if a task
    "feels done," verify postconditions explicitly.

11. **Never commit secrets.** No `CLAUDE_CODE_OAUTH_TOKEN`,
    `GH_TOKEN`, PATs, etc., in any committed file. Use repo
    secrets only.

## Soft rules (escalate if unclear)

1. **Prefer minimal diffs** scoped to one phase per PR.
2. **Prefer parallel agent calls** for independent work (e.g., 5
   ADRs, 5 caller stubs).
3. **Prefer reusing existing patterns** in `review.yml` over
   inventing new ones.
4. **Prefer pinned action SHAs** to floating tags.
5. **Prefer named scripts** to inline shell when logic exceeds
   ~5 lines.
6. **Prefer ScheduleWakeup** for waiting on external events (CI,
   PR merge, CodeRabbit review) over busy polling.
7. **Prefer escalation over guessing** when a task spec is
   ambiguous.

## Forbidden behaviors

- Running `pytest`, `npm test`, `cargo test`, `pip install`,
  `npm install`, `cargo build`, etc. against PR-head content. (Per
  `docs/adr/ADR-004-allowlist-policy.md` threat model.)
- Reading or exfiltrating `~/.ssh/`, `~/.aws/`, `/proc/self/environ`,
  `.env` files.
- Calling `gh pr comment` directly. All comment posting goes through
  `.github/scripts/post-claude-review.sh`.
- Using `--no-verify`, `--no-gpg-sign`, or other hook-bypass flags.
- Modifying repo settings (branch protection, secrets, auto-merge
  configuration). Those are HUMAN-GATEs (see `HUMAN-GATES.md`).
