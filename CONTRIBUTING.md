# Contributing to agentic-ops

`agentic-ops` is the centralized substrate for AI-led PR review across
`loganrooks/*`. Changes here propagate to consumer repos via the
floating `v1` tag, so quality and predictability matter more than
velocity. This document captures the contribution flow.

## Project layout

- `.github/workflows/` — reusable workflows (`review.yml` is the kernel
  consumed by caller stubs in other repos via `workflow_call`)
- `.github/scripts/` — wrapper scripts (`post-claude-review.sh`) and
  CI helpers (`test-dispatcher.sh`)
- `docs/adr/` — architecture decision records (numbered, immutable; see
  `docs/adr/README.md` for format)
- `VISION.md`, `ROADMAP.md`, `OPEN_QUESTIONS.md` — strategic docs
- `AGENTS.md` — operative discipline for AI contributors (read on every
  contribution)
- `SECURITY.md` — threat model and reporting flow

## Contribution workflow

1. Branch from `main` (`feat/<short-description>` or
   `fix/<short-description>`).
2. Make changes. Keep PRs focused on one feature or fix; do not bundle
   unrelated work.
3. Run local validation before pushing:
   - `actionlint .github/workflows/*.yml`
   - `shellcheck .github/scripts/*.sh`
   - `yamllint .github/workflows/`
   - `bash .github/scripts/test-dispatcher.sh`
4. Commit with conventional-commit-style messages
   (`feat:`, `fix:`, `chore:`, `docs:`, `refactor:`).
5. Open a PR against `main`.
6. **Wait for CI green AND CodeRabbit review.** CI green is necessary
   but not sufficient. CodeRabbit must post its review (a `COMMENTED`
   review is its normal output) and any actionable findings must be
   either addressed by a follow-up commit or explicitly explained in
   a reply that resolves the conversation thread.
7. **Resolve all CodeRabbit conversations** before merge. Branch
   protection on `main` requires conversation resolution — unresolved
   threads block the merge button. This is the technical enforcement
   of the discipline.
8. Merge via squash. Auto-merge with `--auto` is acceptable AFTER
   CodeRabbit has reviewed and conversations are resolved (auto-merge
   then waits only on remaining required signals). Do NOT use
   `--auto` immediately on PR open — it bypasses CodeRabbit review.

## Review discipline

The substrate is security-sensitive (workflows, dispatcher, allowlist
composition). CI green covers syntactic and structural correctness;
CodeRabbit covers semantic patterns CI cannot detect — vocabulary
drift, contract mismatches, AI-failure-mode patterns, allowlist
policy drift. Both signals are required.

A typical PR lifecycle:

1. Open PR → CI runs (`lint`, `dispatcher-smoke`)
2. CodeRabbit reviews the diff (usually within 2–5 min of open)
3. Author addresses findings (push fixup commits) or explains why a
   finding doesn't apply (resolve the conversation with a reply)
4. Maintainer reviews — confirms findings addressed, approves merge
   intent
5. Merge (squash, with `--auto` or direct, after gates clear)

If CodeRabbit doesn't review within ~10 min of PR open (rare,
usually a queue or config issue), comment `@coderabbitai review` to
trigger explicitly. Do not merge without CodeRabbit's pass.

## Architecture decision records

Load-bearing decisions warrant an ADR per `docs/adr/README.md`. Examples
of changes that require an ADR:

- New review modes
- Threat model changes (new attack class or mitigation)
- Output format changes
- Versioning policy changes
- Allowlist policy changes (especially `extra_allowed_tools` shape)

ADRs are numbered (`ADR-NNN-kebab-case.md`) and their bodies are not
edited once accepted; they are superseded, amended, or partially
superseded by a new ADR per the relationship conventions in
[`docs/adr/README.md`](docs/adr/README.md). The `Status:` line is the
one exception — it may be updated to record a later ADR's
relationship (and a single inline body note may be added when a
later ADR amends or partially supersedes a portion; the note format
is specified in `docs/adr/README.md` §"Editing rule"). No other body
edits are permitted.

## Tag and release protocol

Per `docs/adr/ADR-003-versioning-and-release.md`:

- `v1` is a floating major-version tag; minor/patch updates land
  transparently.
- After any merge to `main` that touches workflow contracts:
  ```
  git checkout main && git pull
  git tag -f v1 <merge-sha>
  git push origin v1 --force
  ```
- Breaking changes (mode removal, contract change, required-input
  addition) cut `v2`; `v1` preserves prior behavior for existing
  consumers.

## Style

- All workflow files must pass `actionlint` clean before merge.
- All shell scripts must pass `shellcheck` clean before merge.
- All YAML files must pass `yamllint` clean before merge.
- Pin `uses:` references to commit SHAs (not floating tags) for any
  third-party action; first-party `actions/*` may use SHA + `# v4.x.x`
  comment for clarity.

## Security issues

Do **not** open public issues for security findings. Use GitHub's
private security advisory feature:
https://github.com/loganrooks/agentic-ops/security/advisories/new

See `SECURITY.md` for the threat model, scope, and what to include in
a report.
