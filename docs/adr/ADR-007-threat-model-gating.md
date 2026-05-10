# ADR-007: Threat model is scoped to bounded deployment; wide deployment requires revision

Status: accepted
Date: 2026-05-10

## Context

`SECURITY.md` documents threat classes TC-1 through TC-6:

- TC-1 — Comment-and-Control (mitigated by wrapper-script discipline)
- TC-2 — Shell expansion of untrusted PR content (mitigated by quoted
  heredoc + stdin-only wrapper)
- TC-3 — Prompt injection via PR content (mitigated by narrow
  allowlist + trusted-actor gate + wrapper)
- TC-4 — Allowlist breakage (mitigated by ADR-004 + reviewer attention)
- TC-5 — OAuth token compromise (mitigated by workflow-context-only
  token access + Anthropic dashboard alerts + rotation runbook)
- TC-6 — Test/build execution against PR head (mitigated by ADR-004's
  test-runner prohibition)

`SECURITY.md` §"Out of scope" explicitly excludes multi-tenancy:
"This is personal-tooling-in-public-repo; one principal (the
maintainer) sets policy."

ADR-006 commits the substrate to bounded internal deployment until OQ-1
resolves. The current threat model (TC-1..TC-6) is calibrated for that
scope: it assumes one principal, trusted consumer caller stubs, and a
single shared OAuth token.

The question this ADR resolves: **what is required of the threat model
before any wide-deployment work begins, and what is already in scope?**

If the substrate ever expands beyond bounded internal deployment — via
ADR-006 supersession or otherwise — additional threat classes become
load-bearing that are not currently modeled or mitigated. Without an
explicit gating commitment, wide-deployment work could ship before
those threats are addressed.

## Decision

The threat model in `SECURITY.md` (TC-1..TC-6) is the **canonical and
sufficient** threat model for the bounded deployment scope established
by ADR-006. Wide deployment beyond bounded scope **requires** a threat
model revision before any wide-deployment infrastructure ships.

The minimum threat-class additions required for wide deployment are:

### TC-7 — Untrusted consumer caller-stub inputs (REQUIRED FOR WIDE)

A consumer caller stub, controlled by a maintainer outside the agentic-
ops principal, supplies adversarial values via the workflow_call
`with:` block. Specific vectors:

- `enabled_modes` containing values that crash the dispatcher's
  `jq` validation
- `extra_allowed_tools` containing forbidden categories (test
  runners, network fetchers, code execution) per ADR-004
- `audit_lens_registry` containing JSON that breaks the prompt
  template's interpolation (e.g., unescaped `}}`)
- `review_focus_paths` / `gates_paths` containing values that
  exploit shell expansion if the substrate's render_paths_block
  function has any bug

Mitigation requirements (must be in place before wide deployment):
1. The central workflow validates every workflow_call input against a
   schema (input shape, type, enum membership where applicable) and
   fails fast on violation with a clear error.
2. The `extra_allowed_tools` deny-list is enforced at runtime by the
   `Assemble allowlist` step, not discipline-only. The deny-list MUST
   cover ADR-004's Forbidden-entries table to the extent possible
   with literal-string matching: test runners (`pytest`, `jest`,
   `vitest`, `mocha`, `npm test`, `cargo test`, `go test`), installers
   (`pip install`, `npm install`, `yarn`, `cargo install`, `apt`,
   `brew`), build tools (`cargo build`, `npm build`, `cmake`, `make`),
   network fetchers (`curl`, `wget`, `http`), and direct code-execution
   interpreters (`python`, `node`, `ruby`, `sh`, `bash`).

   Explicit deny-list exclusion: **`tsc` cannot be reduced to a
   literal-string match.** ADR-004 allows `tsc` only with `--noEmit`
   (static-analysis posture) and forbids `tsc` with emit (build-tool
   posture); a literal string deny-list cannot distinguish the two
   forms, so deny-listing `tsc` would block the allowed P7 TypeScript
   onboarding (`Bash(tsc:*)`) and not deny-listing it allows the
   forbidden emitting form. `tsc` therefore remains discipline-only
   per ADR-004 even at wide deployment, OR a future ADR introduces a
   command/flag-aware validator for this specific tool. The deny-list
   does not need to cover `tsc` as a precondition; the broader
   forbidden categories above remain literal-string matchable.

   ADR-004 §"Regex-validate ... Rejected" remains in force for
   *complex* validation. The literal-string deny-list above does not
   have ADR-004's false-positive problem precisely because it stops at
   the matchable categories and explicitly excludes the ambiguous
   `tsc` case.
3. JSON inputs (`audit_lens_registry`, `enabled_modes`) are
   `jq`-validated for structure before interpolation into the prompt
   or dispatcher.

Note: dispatcher-level input handling (CRLF tolerance, first-line
length cap, bidi/control unicode filtering) was hardened in commit
`af0b2f2` (PR #6, `fix(dispatcher): harden against CRLF / length /
bidi unicode in triggers`), which landed in bounded scope as a
suggestion-severity fix. That commit addresses *trigger comment*
parsing; it is orthogonal to TC-7's *workflow_call input* validation
and remains a precondition only for the schema/deny-list/json-
validation items above.

### TC-8 — Supply-chain attacks on the central repository (REQUIRED FOR WIDE)

An attacker compromises `loganrooks/agentic-ops` (account compromise,
maintainer-machine compromise, or social-engineering a malicious PR
through review) and pushes a malicious commit that consumers
automatically pick up via the floating `@v1` tag.

Mitigation requirements (defense-in-depth — signing alone is
insufficient because GitHub Actions does not verify tag signatures
at `workflow_call` resolution time; a compromised account that can
force-push `v1` overwrites a signed tag with an unsigned or
adversary-signed one and consumers silently pick it up):

1. **Tag ruleset** targeting `v1` (and any other floating release
   tags) in the repository's Rulesets configuration, per current
   GitHub docs at
   https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-rulesets/available-rules-for-rulesets
   (the older "Tag protection rules" feature has been superseded by
   rulesets). The ruleset MUST enable: "Restrict updates" (only
   bypass actors named in the ruleset can push to `v1`), "Restrict
   deletions," and "Block force pushes." Bypass-actor allowlist is
   the maintainer's account only. This is the primary defense — it
   prevents the force-push that signing alone cannot detect on the
   consumer side.
2. `v1` tag is signed (`git tag -s`, GPG/SSH) as a forensic-trail
   defense. Signature presence is checked by maintainer tooling
   (release runbook) on each bump; mismatched or unsigned tags are an
   incident signal. Consumer-side verification is not assumed — see
   the floating-tag/SHA-pinning tradeoff under Consequences below.
3. CodeRabbit is required (already enforced by branch protection per
   AGENTS.md) AND a second human reviewer is required for any change
   to: `.github/workflows/review.yml`, `.github/scripts/`, or any
   ADR-001/004/006/007/etc.
4. `v1` tag updates only happen after CI green AND human review AND
   a 24-hour cooldown ("delayed-update window") during which any
   consumer can pin to a specific SHA if they want to opt out of an
   imminent v1 bump.
5. `v1-stable` and `v1-canary` split (canary moves on each merge,
   stable moves on a clock or after canary is exercised without
   incident). Originally listed as optional; promoted to required at
   wide deployment because the per-consumer canary surface is the
   only mitigation that bounds blast radius when (1)-(4) all fail.

### TC-9 — Fork-substitution / typosquatting (REQUIRED FOR WIDE)

An attacker publishes `loganrooks-mirror/agentic-ops` or
`logan-rooks/agentic-ops` and tricks consumers (or external adopters)
into pinning their caller stubs against the fork via copy-paste error
or social engineering.

Mitigation requirements:
1. Public-facing onboarding documentation explicitly names the
   canonical repository URL and warns against forks. MUST.
2. Identity verification of the called workflow. Note the mechanism
   constraint: in a reusable workflow called via `workflow_call`,
   the `github` context (including `github.workflow_ref` and
   `github.workflow`) is associated with the **caller**, not the
   called workflow, per
   https://docs.github.com/en/actions/reference/workflows-and-actions/reusing-workflow-configurations#github-context
   — so parsing `github.workflow_ref` from inside the called
   workflow would see the consumer's stub path, not
   `loganrooks/agentic-ops`, and would either reject every legitimate
   consumer or be useless. The mitigation that actually works:

   (a) **Consumer-side SHA pinning** for wide-deployment consumers
       (`uses: loganrooks/agentic-ops/.github/workflows/review.yml@<commit-sha>`
       instead of `@v1`). The pin itself is the verification; an
       attacker's fork URL doesn't resolve to the canonical SHA.
       Onboarding documentation MUST present SHA pinning as the
       recommended pattern for wide deployment, with the `@v1`
       floating-tag pattern explicitly deprecated to "internal
       consumers only." This shifts some burden to consumers but is
       the only mechanism that bounds fork-substitution at the
       `uses:` resolution layer.

   (b) **Marker-file check on the `central/` checkout** as a
       defense-in-depth layer that catches the consumer who used `@v1`
       anyway. The central workflow already checks out
       `loganrooks/agentic-ops` at `path: central` (review.yml ~lines
       145-150). After that checkout, read a known-good identity
       marker file (e.g., `central/.identity-marker` with a
       repository-bound SHA-256 sum of a published manifest) and
       fail the run if the marker is missing or mismatched. This is
       strippable by a sophisticated fork (the attacker controls the
       called workflow file and can simply remove the marker check),
       but raises the bar against casual copy-paste typosquatting.

   Both (a) and (b) ship together for wide deployment. Neither alone
   is sufficient; (a) only protects consumers who actually pin SHAs,
   (b) only protects against forks too lazy to strip the marker.

  Prerequisite: an org-rename runbook exists in operational runbooks
  before mitigation (b) is enabled. The runbook covers the one known
  footgun (renaming `loganrooks` would brick all consumers using
  hard-coded canonical-repo checks until the marker is updated) —
  operational procedure: stage the rename with a PR that adds the
  new identity marker, merge, bump `v1`, then perform the rename.
  Mitigation (b) ships WITH the runbook, not without it.

### TC-10 — Shared-credential blast radius (REQUIRED FOR WIDE)

If wide deployment involves consumers sharing a single OAuth token
(e.g., a hypothetical "agentic-ops App" that uses one Anthropic
account for all consumers), one compromised consumer can drain the
shared quota or trigger ToS violations affecting all consumers.

Mitigation requirements:
1. Wide deployment auth model (per the ADR that supersedes ADR-006)
   uses per-consumer credentials (BYO token model) or a multi-tenant
   architecture with explicit per-tenant rate limiting.
2. No "shared key" model for wide deployment, even with rate
   limiting, because plan auth (Anthropic Pro/Max OAuth) is
   non-commercial-use-only and cannot be lawfully shared across
   tenants.

### TC-11 — Adversarial agent prompts in audit/survey modes (REQUIRED FOR WIDE)

Audit and survey modes read repo content (AGENTS.md, ADRs, README)
and incorporate it into prompt context. Wide deployment increases the
attack surface: an external consumer's repo could deliberately craft
an AGENTS.md that prompt-injects the audit agent into producing
misleading findings or exfiltrating substrate-side context (e.g., the
audit_lens_registry JSON that the consumer didn't override).

Note on bounded-scope coverage: TC-3 already covers PR-head
AGENTS.md as prompt-injection surface at bounded scope. The current
mitigation chain (narrow allowlist + trusted-actor commenter gate +
wrapper-script discipline) bounds the worst case to "agent posts a
weird PR comment" even when AGENTS.md is attacker-controlled — for
example when an external contributor PRs a malicious AGENTS.md to one
of the six internal consumers and a trusted maintainer triggers
review/survey/audit. That is TC-3's job, and TC-3's mitigations are
deemed sufficient at bounded scope because the principal is one
maintainer who trusts the consumers and the consumers' contributors
are gated by repo-level review of PRs that change AGENTS.md.

TC-11 names the **wide-scope ratchet**: external consumers maintain
their own AGENTS.md outside the central principal's trust boundary,
and the attacker surface grows from "trusted contributor's PR to a
known consumer" to "any consumer-repo content at any commit the
consumer's `@v1` happens to reach." At that point the markers
(mitigation #1 below) move from "nice to have on top of TC-3" to
"hard requirement," because TC-3's mitigation chain alone no longer
bounds the worst case to a single weird comment when consumer
configuration and consumer content are both attacker-controllable.

Mitigation requirements (for wide deployment only — bounded scope
relies on TC-3):
1. Repo content read for audit/survey context is wrapped in
   "untrusted content" markers in the prompt (similar to the
   existing `>>>BEGIN_COMMENT ... >>>END_COMMENT` pattern), with
   explicit prompt instructions to treat content between markers as
   data, not instructions.
2. Audit findings posted to consumer PRs/issues are reviewed by a
   second pass before posting if `audit_target` was free-form
   (already partially addressed by audit's metadata-header
   discipline; this elevates it to a hard requirement for wide
   deployment).

## Trigger conditions

This ADR is in force as of acceptance. Its operational consequence:

- For bounded deployment (per ADR-006), TC-1..TC-6 remain canonical;
  no new mitigation work is required as a precondition for P5..P9.
- For any wide-deployment work (per a hypothetical ADR-006-superseding
  ADR), the mitigations named in TC-7..TC-11 above must ship as
  preconditions to that work, not as follow-ups.

## Alternatives considered

**Don't bound the threat model; expand TC-1..TC-6 to cover wide
deployment now.** Rejected. The substrate isn't deployed widely yet
and may never be (per ADR-006). Modeling threats for a deployment
shape that hasn't been authorized either (a) commits maintenance
effort to mitigations that may turn out to be unnecessary, or (b)
ships mitigations now and lets them rot if wide deployment doesn't
materialize. Conditional, gated commitment is the right shape.

**Treat the threat-model revision as just a checklist in the
hypothetical wide-deployment ADR, not a separate ADR.** Rejected.
Wide-deployment ADR will be one document making one decision (the
auth/scope expansion); requiring threat-model additions inside that
same document conflates two concerns. Naming the specific threat
classes here, in advance, gates the wide-deployment ADR on concrete
deliverables rather than vague "and also revise SECURITY.md."

**Add even more threat classes (e.g., TC-12 deceptive-consumer-
caller-stub, TC-13 audit-mode-result-poisoning).** Rejected for now.
TC-7..TC-11 cover the load-bearing classes a panel-style review
surfaced. More can be added in a future ADR if specific gaps are
identified during empirical-gate work or threat-model review. The
intent is "minimum bar," not "exhaustive list."

## Consequences

**Positive.**
- The "earn the right to wide-deploy" path is explicit. No
  wide-deployment work begins without TC-7..TC-11 mitigations
  shipped — that's now a hard gate, not a planning preference.
- SECURITY.md remains tight and accurate for current scope. No
  speculative threat classes pollute the threat model that's
  actively in force.
- ADR-006 + ADR-007 form a coherent gating package: ADR-006 says
  "no wide deployment until conditions met"; ADR-007 names the
  security conditions. Together they make wide deployment costlier
  and safer, in that order.

**Negative.**
- Five additional threat classes are real engineering work to
  mitigate (~1-2 phases of work). The cost is borne only if wide
  deployment is later authorized — but it raises the bar to be
  authorized.
- The "delayed-update window" mitigation in TC-8 has operational
  cost: a 24-hour cooldown between v1 promotion and consumer pickup
  slows down hot fixes. Acceptable for wide-deployment scale; would
  be friction in current bounded scope.
- TC-8 carries an unresolved tension between the floating-tag
  contract (per ADR-003: consumers pin `@v1` and pick up additive
  changes automatically) and signed-tag verification (only effective
  if consumers verify the signature, which they do not under the
  floating-tag model). Tag protection rule + delayed-update window +
  canary split are the substitute defenses, but a residually-risk-
  averse consumer at wide scope may want to pin a specific SHA
  instead of `@v1`. Documentation will need to name this as an
  available trade-off when wide deployment is authorized, even
  though it changes ADR-003's update-propagation model.

**Neutral.**
- TC-1..TC-6 are unchanged and remain the canonical threat model
  for bounded deployment. ADR-007 does not modify SECURITY.md; it
  declares preconditions for any future modification.
- The "wide deployment" boundary is defined by ADR-006 (consumer
  cap, auth model, repo-namespace scope). TC-7..TC-11 inherit that
  boundary; they apply when the boundary is crossed, not when the
  consumer count grows within it.
