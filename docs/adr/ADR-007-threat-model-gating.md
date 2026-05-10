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
2. The `extra_allowed_tools` deny-list (forbidden literal strings:
   `pytest`, `curl`, `wget`, `npm test`, `cargo test`, etc.) is
   enforced at runtime by the `Assemble allowlist` step, not
   discipline-only. ADR-004 §"Regex-validate ... Rejected" remains in
   force for *complex* validation, but a literal-string deny-list of
   known-forbidden categories does not have ADR-004's false-positive
   problem.
3. JSON inputs (`audit_lens_registry`, `enabled_modes`) are
   `jq`-validated for structure before interpolation into the prompt
   or dispatcher.

Note: dispatcher-level input handling (CRLF tolerance, first-line
length cap, bidi/control unicode filtering) was hardened in a
bounded-scope follow-up commit; that work is orthogonal to TC-7 and
remains a precondition only for the schema/deny-list/json-validation
items above.

### TC-8 — Supply-chain attacks on the central repository (REQUIRED FOR WIDE)

An attacker compromises `loganrooks/agentic-ops` (account compromise,
maintainer-machine compromise, or social-engineering a malicious PR
through review) and pushes a malicious commit that consumers
automatically pick up via the floating `@v1` tag.

Mitigation requirements:
1. `v1` tag is signed (`git tag -s`, GPG/SSH).
2. CodeRabbit is required (already enforced by branch protection per
   AGENTS.md) AND a second human reviewer is required for any change
   to: `.github/workflows/review.yml`, `.github/scripts/`, or any
   ADR-001/004/006/007/etc.
3. `v1` tag updates only happen after CI green AND human review AND
   a 24-hour cooldown ("delayed-update window") during which any
   consumer can pin to a specific SHA if they want to opt out of an
   imminent v1 bump.
4. Optional: a `v1-stable` and `v1-canary` split (canary moves on each
   merge, stable moves on a clock or after canary is exercised).

### TC-9 — Fork-substitution / typosquatting (REQUIRED FOR WIDE)

An attacker publishes `loganrooks-mirror/agentic-ops` or
`logan-rooks/agentic-ops` and tricks consumers (or external adopters)
into pinning their caller stubs against the fork via copy-paste error
or social engineering.

Mitigation requirements:
1. Public-facing onboarding documentation explicitly names the
   canonical repository URL and warns against forks.
2. The central workflow includes a runtime self-check: at job start,
   read `github.workflow_ref`, parse the repository portion, fail
   the run if it's not `loganrooks/agentic-ops` (modulo explicit
   allowlisted forks). This catches the case where a consumer
   accidentally points at a fork — the fork would have to actively
   strip the self-check to be useful, raising the bar.

  Caveat: this self-check has a footgun in the org-rename scenario
  (renaming `loganrooks` would brick all consumers until the
  allowlist is updated). Mitigation: define an org-rename runbook
  before enabling the self-check; the self-check itself is SHOULD,
  not MUST, until that runbook exists.

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

Note: TC-3 partially covers this for PR-comment content. TC-11
extends it to repo-content-as-prompt-context, which is qualitatively
different (PR comment is one line; AGENTS.md can be 1000+ lines of
attacker-controlled prose).

Mitigation requirements:
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

**Neutral.**
- TC-1..TC-6 are unchanged and remain the canonical threat model
  for bounded deployment. ADR-007 does not modify SECURITY.md; it
  declares preconditions for any future modification.
- The "wide deployment" boundary is defined by ADR-006 (consumer
  cap, auth model, repo-namespace scope). TC-7..TC-11 inherit that
  boundary; they apply when the boundary is crossed, not when the
  consumer count grows within it.
