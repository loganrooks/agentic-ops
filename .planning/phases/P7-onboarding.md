# Phase P7 — Onboarding 7 internal consumers

> Updated 2026-05-12: aligns with [ADR-009](../../docs/adr/ADR-009-consumer-cap-relaxation.md) (consumer set extended to 8 — vigil + agentic-ops self-consumer added) and [`ONBOARDING.md`](../../ONBOARDING.md) (executable onboarding recipe; replaces the deferred Appendix A.12 reference).
>
> Updated 2026-05-14: `extra_allowed_tools` for `prix-guesser`, `arxiv-sanity-mcp`, `epistemic-agency`, and `scholardoc` rows reduced to drop tools with plugin/code-loading surfaces from PR-head config files. Specifically: `Bash(eslint:*)` (loads `eslint.config.js` / `.eslintrc.js` as JS), `Bash(mypy:*)` (loads `plugins` from `mypy.ini` as importable Python), and `Bash(tsc:*)` / `Bash(tsc --noEmit *)` wildcards (the `*` is argument-injection-defeatable via `tsc --noEmit false --outFile <wrapper-script-path>`, chaining into a JS-shell-polyglot wrapper-overwrite attack on `central/.github/scripts/post-claude-review.sh`). The class identified by Codex review on agentic-ops PRs #17 (closed) and #18 covers (a) tools that auto-discover a config file from CWD where that config can reference executable code, and (b) tools whose wildcard permission patterns admit args that enable arbitrary file write or code execution; ADR-004 §Acceptable lists `eslint`, `mypy`, `pylint`, `flake8`, `pyright` (class-a) and effectively any wildcard pattern (class-b) — but doesn't yet codify the rule. The Python rows keep `Bash(ruff:*)` as the *least-bad pragmatic interim* (ruff has no plugin loading, but wildcard defeats via `--output-file` / `--fix` exist; residual risk accepted with documented mitigation pending OQ-13 wrapper scripts); the TS rows go to empty `extra_allowed_tools` until the architectural decision in **OQ-13** lands (wrapper scripts vs sandboxed Path B vs threat-model reframe vs accept reduced allowlist). Tools at the *safer* end of the spectrum (no plugin loading): `ruff`, `shellcheck`, `actionlint`, `yamllint`, `rg`, `jq` — still subject to class-b wildcard defeats; OQ-13's wrapper-script discipline is the structural fix. Adjacent cleanup: `audit:<lens>` entries in `enabled_modes` normalized to bare `audit` (lens is selected at trigger time via `audit_target`; lens-prefixed entries fail dispatch validation per ONBOARDING.md §Per-repo customization checklist item 4).

**Goal:** Add caller stubs to prix-guesser, arxiv-sanity-mcp, f1-modeling, epistemic-agency, scholardoc, vigil, and agentic-ops itself (self-consumer pattern per [ADR-009](../../docs/adr/ADR-009-consumer-cap-relaxation.md) §Decision §2) — each consuming the agentic-ops `v1` reusable workflow with per-repo configuration.

**Status:** pending

**Branches:** one per target repo; standard convention `feat/agentic-ops-onboarding` in each repo.

## Phase entry preconditions

- CHECKPOINT-P4 exists (audit + survey L1 stable; L3 may or may not be done)
- [ADR-009](../../docs/adr/ADR-009-consumer-cap-relaxation.md) merged (vigil + agentic-ops are members of the named-internal-consumer set per §Decision §1; agentic-ops self-consumer additionally requires the workflow-correctness verification per §Decision §2 before its caller stub lands)
- [`ONBOARDING.md`](../../ONBOARDING.md) exists at repo root (executable caller-stub recipe consumed by P7-T<n>-3)
- Each target repo has `.github/workflows/` directory or can have one created
- Each target repo has `CLAUDE_CODE_OAUTH_TOKEN` available as a secret (if not, HUMAN-GATE — agent escalates)

## Phase exit postconditions

- All 7 target repos have caller stubs merged
- Each repo's `@claude review` (or first enabled mode) triggers successfully on a benign comment
- Per-repo `enabled_modes` reflects the table below

## Per-repo configuration

| Repo | enabled_modes | review_focus_paths | extra_allowed_tools |
|---|---|---|---|
| prix-guesser | `["review","quick","deep","audit"]` | `src/**/*.ts`, `package.json` | _(empty — see OQ-13 note)_ |
| arxiv-sanity-mcp | `["review","quick","deep","audit"]` | `mcp_server.py`, `tools/*.py` | `Bash(ruff:*)` |
| f1-modeling | `["review","quick","deep","audit"]` | `notebooks/*.ipynb`, `src/**/*.py` | `Bash(ruff:*)` |
| epistemic-agency | `["review","quick","deep","audit"]` | `src/**/*.ts`, `docs/` | _(empty — see OQ-13 note)_ |
| scholardoc | `["review","quick","deep","survey","audit"]` | `src/**/*.py`, `docs/` | `Bash(ruff:*)` |
| vigil | `["review","quick","deep","audit"]` | _(empty — see note)_ | _(empty — see note)_ |
| agentic-ops | `["review","quick","deep","opus","survey","audit","gates"]` | `.github/workflows/review.yml`, `.github/scripts/`, `docs/adr/` | _(empty — see note)_ |

**Note on agentic-ops `enabled_modes`.** The row reflects the full
ADR-001 seven-mode taxonomy. `gates` is enabled but the P7 table
has no `gates_paths` column; per the kernel workflow input
contract (`.github/workflows/review.yml` input `gates_paths`
description), an empty `gates_paths` causes the `gates` mode to
post a single "not configured for this repo" comment instead of
running — graceful degradation, not a dispatch failure.
`@claude gates` is therefore *permitted* on agentic-ops but not
*useful* until a follow-up populates `gates_paths`.

**Note on agentic-ops `extra_allowed_tools`.** The self-consumer
row is intentionally empty because the kernel reusable workflow
(`.github/workflows/review.yml`) does not install `actionlint`,
`shellcheck`, or `yamllint` — these are run by agentic-ops's CI
workflow on each PR, not by the `@claude` review path. Populating
`extra_allowed_tools` with those entries would widen Claude's
allowlist without making the binaries available at runtime
(command-not-found at invocation). Self-review for agentic-ops is
therefore intentionally limited to semantic review (Claude reads
workflow/script/ADR files and reasons about them); deterministic
linting stays in CI. If a future kernel-workflow change adds
install steps for those tools, this row should be revisited.

**Note on `_(empty — see note)_` cells.** Where a table cell is
shown as `_(empty — see note)_`, the caller stub should *omit*
that input entirely, or set it to an empty/missing YAML value
(e.g., `review_focus_paths: ""` is acceptable, but **do not paste
the literal marker text into the YAML**). The kernel handles
empty/whitespace-only inputs via two guards: the `Assemble prompt
fragments` step (`.github/workflows/review.yml`
`render_paths_block` function,
`if [[ -z "${content//[[:space:]]/}" ]]`) renders "(none
configured)" for empty `review_focus_paths`; the `Assemble
allowlist` step (`if [[ -n "${EXTRA//[[:space:]]/}" ]]`) appends
nothing for empty `extra_allowed_tools`. Refine before or during
P7-T<n>-3 if vigil's contract surfaces and static-analysis stack
become known. The same guards apply to the agentic-ops row's
empty `extra_allowed_tools` (the allowlist is not widened).

**Note on `_(empty — see OQ-13 note)_` cells (prix-guesser,
epistemic-agency).** These are the TS-stack consumer rows. Per
the 2026-05-14 Updated header, both rows previously listed
`Bash(eslint:*)` and/or `Bash(tsc:*)` / `Bash(tsc --noEmit *)`,
all of which are unsafe under the current threat model:
ESLint loads `eslint.config.js` / `.eslintrc.js` from PR head as
JavaScript; `Bash(tsc:*)` permits emit; `Bash(tsc --noEmit *)`'s
trailing `*` is argument-injection-defeatable (`tsc --noEmit
false --outFile <wrapper-script-path>` chains into a wrapper-overwrite
attack). Until [OQ-13](../../OPEN_QUESTIONS.md) resolves with an
architectural decision (wrapper-script discipline / sandboxed
Path B / threat-model reframe / accept reduced allowlist), TS-stack
consumers run with empty `extra_allowed_tools` — review remains
semantic (Claude reads source files and reasons about them) but
loses tsc/eslint findings. This is the conservative default until
the policy gap closes.

## Per-repo subtasks (7x; n in {1..7})

### P7-T<n>-1 — Verify repo state

- Read repo's existing `.github/workflows/` directory
- Check if any review workflow already exists (e.g., legacy claude-review.yml)
- Check for AGENTS.md / equivalent discipline doc
- Note state in STATE.md

### P7-T<n>-2 — Determine per-repo configuration

- Use the table above for the target repo

### P7-T<n>-3 — Write caller stub

- Branch: `feat/agentic-ops-onboarding` in target repo
- Use [`ONBOARDING.md`](../../ONBOARDING.md) §"The minimal caller stub" as the executable recipe. The canonical inline exemplar lives in the Consumer caller stub block of [`.github/workflows/review.yml`](../../.github/workflows/review.yml) header; CBM's caller stub at `f6fe379` is the working reference instance.
- Caller stub mirrors CBM's pattern; uses `loganrooks/agentic-ops/.github/workflows/review.yml@v1`
- Includes per-repo enabled_modes, review_focus_paths, extra_allowed_tools, agents_md_path, repo_label

### P7-T<n>-4 — Open PR in target repo

- Title: `chore: onboard to agentic-ops centralized review`
- Body: link to agentic-ops, list of enabled modes, brief security note (CodeRabbit-style trusted-actor gate, wrapper-script discipline)

### P7-T<n>-5 — Wait CI, CodeRabbit (if installed), maintainer signal, merge

- Wait for any pre-existing CI to pass
- If CodeRabbit installed on target repo: wait for review and conversation resolution
- Maintainer (logan) merges
- Smoke-test: trigger `@claude review` on a benign comment to validate

## Phase total estimate

30 min × 7 repos = ~3.5 hrs serialized. Can be parallelized across the 7 repos via concurrent agent calls; in parallel, wall-clock approximates a single-repo onboarding plus a small coordination overhead. The agentic-ops self-consumer case may be slightly faster since the kernel and the caller stub are both in this repo (no cross-repo coordination for stub authoring). Per-repo CI + CodeRabbit wait time dominates the critical path; agent-side stub authoring is roughly 5–10 min per repo.

## Parallelization guidance

- Six of the seven per-repo subtask streams (prix-guesser, arxiv-sanity-mcp, f1-modeling, epistemic-agency, scholardoc, vigil) are independent once P4 has merged. Spawn one agent call per repo with a self-contained brief (target repo, enabled_modes row, review_focus_paths, extra_allowed_tools, agents_md_path, repo_label).
- **The seventh stream — agentic-ops self-consumer — has a prerequisite** beyond P4: [ADR-009](../../docs/adr/ADR-009-consumer-cap-relaxation.md) §Decision §2 requires that the kernel's `Determine central ref` step's behavior be empirically verified (or patched) before the agentic-ops caller stub lands, to ensure `@v1` self-review actually reviews against the released kernel rather than the caller-run's in-flight ref. Do NOT spawn the agentic-ops stream in parallel with the other six until this prerequisite is cleared.
- Cross-repo dependencies are limited to the shared `v1` tag in `loganrooks/agentic-ops`. Do not advance the `v1` tag mid-phase — pin to the tag that was current at phase entry to prevent caller stubs racing against unrelated workflow updates.
- Aggregate results back into STATE.md keyed by repo so downstream phases (P8 observability, P9 missed-signal) can enumerate onboarded callers programmatically.

## Notes

- **If a target repo doesn't yet have CodeRabbit installed, escalate via HUMAN-GATE before opening the onboarding PR.** Same handling pattern as the `CLAUDE_CODE_OAUTH_TOKEN` case: record the gate, move on to the next repo, resume that repo when CodeRabbit is provisioned. Do NOT merge the onboarding PR on CI + maintainer review alone — the hard rule "do not merge without CodeRabbit review" in `AGENTS.md` applies to every repo this initiative touches, not just `agentic-ops`. Discipline propagates with the substrate.
- If a target repo doesn't have `CLAUDE_CODE_OAUTH_TOKEN` set as a secret, escalate per HUMAN-GATE (the secret must be added by repo admin before the workflow can run). The agent must not block the rest of the phase on a single repo's missing secret — record the gate, move on, and resume that repo when the secret is provisioned.
- Some target repos may have legacy `.github/workflows/claude-review.yml` files. Decide per-repo whether to delete (if the legacy stub is fully superseded) or rename to `claude-review-legacy.yml` and disable on triggers (if it has unique behavior worth preserving for inspection during the rollout).
- The smoke-test comment in P7-T<n>-5 should be a benign no-op like `@claude review` on a tiny doc-only PR or an existing issue thread; do not smoke-test on a real review-bearing PR, since that conflates first-run validation with substantive review output.

## References

- `phases/P4-extra-allowed-tools.md` — must merge first (input is consumed by per-repo `extra_allowed_tools` entries)
- ADR-001 — mode taxonomy (per-repo `enabled_modes` scope)
- [ADR-009](../../docs/adr/ADR-009-consumer-cap-relaxation.md) — consumer cap relaxation (named-internal-consumer set extended to 8; §Decision §2 workflow-correctness prerequisite for the agentic-ops self-consumer stream)
- HUMAN-GATE-3 in `HUMAN-GATES.md` — CBM caller stub edits (analogous flow per repo)
- AGENTS.md — operative discipline this phase propagates to each onboarded repo
- [`ONBOARDING.md`](../../ONBOARDING.md) — executable onboarding recipe consumed by P7-T<n>-3 (replaces the deferred Appendix A.12 reference)
- [`.github/workflows/review.yml`](../../.github/workflows/review.yml) — kernel reusable workflow; the header's Consumer caller stub block is the canonical caller-stub exemplar
