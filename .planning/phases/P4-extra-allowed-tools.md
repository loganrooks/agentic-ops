# Phase P4 — extra_allowed_tools input

**Goal:** Add caller-extensible `extra_allowed_tools` input for static-analysis tools. Document policy: STATIC ANALYSIS ONLY. No test runners, installers, build tools, or network fetchers.

**Status:** pending

**Branch:** `feat/p4-extra-allowed-tools`

## Phase entry preconditions

- CHECKPOINT-P3 exists
- v1 tag updated to P3 result
- agentic-ops main is clean (no in-flight allowlist edits from P3)
- ADR-004 already committed (from P1); this phase implements its policy without editing it

## Phase exit postconditions

- `extra_allowed_tools` input present in `review.yml`
- Allowlist composition logic correctly merges base + extra (separate "Assemble allowlist" GHA step writing to `$GITHUB_OUTPUT`)
- ADR-004 contents verified to match the implemented input shape (no edit; ADRs are immutable per `docs/adr/README.md` and `AGENTS.md`)
- CI green, **CodeRabbit reviewed + conversations resolved**, PR merged after maintainer signal, v1 tag bumped
- Separate PR opened against CBM caller stub adding `extra_allowed_tools: 'Bash(ruff:*),Bash(mypy:*),Bash(rg:*)'`

## Tasks

### P4-T1 — Add extra_allowed_tools input

- **Precondition:** `review.yml` `inputs:` block does not yet contain `extra_allowed_tools`
- **Action:** Edit the `inputs:` block of `.github/workflows/review.yml` to add the new key
- **Required fields:** `description` (must include "STATIC ANALYSIS ONLY" and "DO NOT add test runners"), `required: false`, `type: string`, `default: ""`
- **Postcondition:** input present; description includes both warnings verbatim
- **Time:** 5 min

### P4-T2 — Modify allowlist composition

- **Precondition:** P4-T1 complete; existing `claude_args` line uses a hardcoded allowlist string
- **Action:** Add a separate `Assemble allowlist` step (preserve the YAML snippet below verbatim) that writes the merged value to `$GITHUB_OUTPUT`
- **Action (cont'd):** Update the `claude-code-action` step's `claude_args` to read `${{ steps.allowlist.outputs.tools }}` instead of inlining the allowlist
- **Postcondition:** new step exists; allowlist composes correctly; smoke test for empty extra and a sample extra both produce well-formed strings
- **Time:** 30 min (careful YAML/string handling; verify no quoting drift)

### P4-T3 — Smoke-test allowlist composition locally

- **Precondition:** P4-T2 complete; `act` or equivalent shell harness available
- **Action:** Exercise the composition shell block with `EXTRA=""` (default path) and `EXTRA='Bash(ruff:*),Bash(mypy:*)'` (caller path); confirm both produce a single comma-joined string with no leading/trailing comma
- **Action (cont'd):** Confirm whitespace-only `EXTRA` (e.g. `"  "`) is treated as empty by the `${EXTRA//[[:space:]]/}` guard
- **Postcondition:** local run captures both branches; output matches expected `tools=` line
- **Time:** 10 min

### P4-T4 — Verify ADR-004 matches the implemented input shape

- **Precondition:** P4-T1 and P4-T2 staged in the working tree
- **Action:** Read ADR-004 (committed in P1) and confirm it already documents the input name `extra_allowed_tools`, the "STATIC ANALYSIS ONLY" policy, and the forbid-list (test runners, installers, build tools, network fetchers). Confirm cross-references to SECURITY.md TC-4 and TC-6 are present.
- **Do NOT edit ADR-004.** ADRs are immutable per `docs/adr/README.md` and the hard rules in `AGENTS.md`. If a substantive deviation between ADR-004 and the implementation is found and the implementation cannot be aligned to the ADR (e.g., the input name needs to differ), STOP and open a separate PR that supersedes ADR-004 with a new ADR. Do not edit ADR-004 in place.
- **Postcondition:** ADR-004 contents confirmed to match implementation; no edit to ADR-004.
- **Time:** 5 min

### P4-T5 — Open PR against agentic-ops main

- **Precondition:** P4-T1..T4 complete; branch pushed to origin
- **Action:** Open PR titled `feat(p4): add extra_allowed_tools input for static analysis`
- **Action (cont'd):** PR body cites ADR-004, links SECURITY.md TC-4/TC-6, and includes the smoke-test transcript from P4-T3
- **Postcondition:** PR open; CodeRabbit review triggered; CI started
- **Time:** 5 min

### P4-T6 — Wait for CI and CodeRabbit

- **Precondition:** PR open
- **Action:** Monitor CI (`actionlint`, `shellcheck`, `yamllint`, dispatcher smoke); wait for CodeRabbit walkthrough
- **Action (cont'd):** Resolve every CodeRabbit conversation (either fix or explicit "won't fix" justification on the thread)
- **Postcondition:** CI green; all CodeRabbit conversations resolved; no unresolved review comments
- **Time:** 15-25 min depending on CodeRabbit latency

### P4-T7 — Maintainer merge signal and squash-merge

- **Precondition:** P4-T6 complete; maintainer has issued the merge signal
- **Action:** Squash-merge with the PR title as the commit subject; delete the feature branch on remote
- **Postcondition:** PR merged into main; head SHA recorded for tag bump
- **Time:** 2 min

### P4-T8 — Bump v1 tag and write CHECKPOINT-P4

- **Precondition:** P4-T7 merge SHA known
- **Action:** Force-update `v1` to point at the merge commit (`git tag -f v1 <SHA> && git push --force-with-lease origin v1`)
- **Action (cont'd):** Write `.planning/auto-execution/checkpoints/CHECKPOINT-P4.md` (per-phase detail file) with merge SHA, tag SHA, CI run URL, CodeRabbit findings count, artifacts list, and any deviations from plan
- **Action (cont'd):** Append a CHECKPOINT-P4 summary entry to `.planning/auto-execution/CHECKPOINTS.md` (the aggregate index) referencing the detail file; pattern matches CHECKPOINT-P0/P1 already on main and the P2/P3 entries from earlier phases
- **Postcondition:** `v1` resolves to the P4 merge; both CHECKPOINT-P4.md detail file and CHECKPOINTS.md aggregate entry exist
- **Time:** 5 min

### P4-T9 — Open CBM caller-stub PR

- **Precondition:** P4-T8 complete; agentic-ops `v1` now exposes `extra_allowed_tools`
- **Action:** In the cbm repo's `.github/workflows/claude-review.yml` (the local clone path is environment-specific; resolve via `git -C <cbm-repo-path>`), add `extra_allowed_tools: 'Bash(ruff:*),Bash(mypy:*),Bash(rg:*)'` under the `with:` block of the reusable-workflow call
- **Action (cont'd):** Open PR against `cbm` main; this is HUMAN-GATE-3 (user reviews and merges separately)
- **Postcondition:** CBM PR open and linked from CHECKPOINT-P4; agentic-ops side requires no further action
- **Time:** 10 min

## Phase total estimate

~1-1.5 hrs.

## Allowlist composition step

```yaml
- name: Assemble allowlist
  id: allowlist
  env:
    EXTRA: ${{ inputs.extra_allowed_tools }}
  run: |
    base='Bash(gh pr view:*),Bash(gh pr diff:*),Bash(./.github/scripts/post-claude-review.sh:*)'
    if [[ -n "${EXTRA//[[:space:]]/}" ]]; then
      full="${base},${EXTRA}"
    else
      full="${base}"
    fi
    echo "tools=$full" >> "$GITHUB_OUTPUT"
```

Then in the action step:

```yaml
claude_args: '--model ${{ steps.mode.outputs.model }} --add-dir pr-head --allowedTools "${{ steps.allowlist.outputs.tools }}"'
```

## CBM caller stub update (separate PR)

After agentic-ops P4 merges and v1 tag bumps, open a PR in cbm to add:

```yaml
extra_allowed_tools: 'Bash(ruff:*),Bash(mypy:*),Bash(rg:*)'
```

This is a HUMAN-GATE-3 path (CBM PR; user reviews + merges separately).

## References

- ADR-004 — Allowlist policy (canonical statement of what's acceptable)
- SECURITY.md TC-4 (allowlist breakage threat class)
- SECURITY.md TC-6 (test/build execution from PR head — explicitly forbidden in extra_allowed_tools)
- `phases/EMPIRICAL-GATE.md` — runs after P4 merges
