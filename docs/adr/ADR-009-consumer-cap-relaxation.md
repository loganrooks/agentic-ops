# ADR-009: Consumer cap relaxation — extend the named-internal-consumer set from six to eight

Status: accepted
Date: 2026-05-11

Partially supersedes [ADR-006](ADR-006-bounded-deployment-scope.md)
re: §2 consumer cap (set raised from six to eight; vigil and
agentic-ops itself are added to the named set). All other sections
of ADR-006 — §1 single-principal plan auth, §3 no installer for
external use, §4 repository visibility unchanged, §5 forks not
supported — remain in force. ADR-006's §"Trigger conditions for
revisiting" continues to govern any further movement beyond the
named-internal-consumer scope; this ADR does not relax those
trigger conditions.

## Context

ADR-006 §2 capped the consumer set at six named repos (`cbm`,
`prix-guesser`, `arxiv-sanity-mcp`, `f1-modeling`,
`epistemic-agency`, `scholardoc`) and stated that "onboarding a
seventh consumer — *internal or external* — requires a later ADR
superseding this one with explicit reasoning. The cap is not
relaxed by `loganrooks/*` namespace membership alone; the point of
the cap is to force the conversation about maintenance load before
scope expands, and that conversation is needed for any seventh
consumer regardless of provenance."

This ADR *is* that conversation. Two specific consumer additions
have surfaced as maintainer-confirmed needs since ADR-006 landed:

**vigil.** A maintainer-active project in the `loganrooks/*`
namespace that has the same AI-failure-mode review needs the
substrate was designed to address. vigil was excluded from
ADR-006's original six because it was less active at the time
ADR-006 was drafted; it has since become a primary maintainer
workstream. The case for inclusion is straightforward: vigil meets
ADR-006's namespace + single-principal + plan-auth predicates that
the original six meet; the only blocker was the numeric cap.

**agentic-ops itself.** The substrate has accumulated enough
internal contract surface — kernel workflow, dispatcher, allowlist
policy, eight ADRs spanning mode taxonomy through L3 gating — that
its own PRs benefit from substrate review. The pattern is novel
(the kernel reviewing its own changes) but bounded: review fires
only on explicit `@claude` triggers on PRs or issues, never
autonomously, so there is no infinite-loop risk. The reviewer-
trigger surface is the same as any consumer's, and the kernel
reference uses `@v1` (the last-released floating tag), not
`@main` — so a substrate-change PR is reviewed against the
previously-released kernel, not against its own in-flight
changes. The motivation is dogfooding: routine substrate PRs
catch ADR drift, AGENTS.md commitment violations, and
vocabulary mismatches that CodeRabbit and Codex don't model
(CodeRabbit's strength is pattern-matching general code-review
findings; Codex catches grounded issues but doesn't carry the
substrate's ADR-derived constraints). The substrate is the only
reviewer that *knows* the substrate's ADRs.

The named-set discipline ADR-006 §2 protects is honored by this
ADR: maintenance load is the load-bearing concern, this ADR makes
the case explicitly, and the cap remains a named set (no numeric
ceiling above the named members), so a ninth consumer would
require yet another ADR.

## Decision

**1. Consumer cap raised from six to eight.** The named-internal-
consumer set becomes:

- `codebase-mapper` (existing; first onboarded)
- `prix-guesser` (existing)
- `arxiv-sanity-mcp` (existing)
- `f1-modeling` (existing)
- `epistemic-agency` (existing)
- `scholardoc` (existing)
- `vigil` (new)
- `agentic-ops` itself (new; self-consumer pattern)

**2. agentic-ops self-consumer pattern.** The kernel reusable
workflow at `.github/workflows/review.yml` continues to be the
authoritative substrate. Agentic-ops's own caller stub lives at a
distinct path — `.github/workflows/claude-review.yml` — and
references the kernel via `loganrooks/agentic-ops/.github/workflows/review.yml@v1`,
identical to any other consumer. The two files are not the same
file; the kernel is consumed, not invoked directly. Review fires
only on explicit `@claude` triggers on agentic-ops PRs and issues.
No autonomous self-triggering; no infinite-loop surface.

**3. ADR-006 §§1, 3, 4, 5 retained verbatim.** This ADR
relaxes only the numeric cap in §2. The auth model (single-
principal plan auth), the no-installer-for-external-use
commitment, the repo-visibility-unchanged commitment, and the
forks-not-supported commitment are unchanged and continue to
govern.

**4. Named-set discipline preserved.** Onboarding a ninth
consumer — *internal or external* — requires a later ADR
superseding this one with explicit reasoning. The cap is not
relaxed by `loganrooks/*` namespace membership alone; the
named-set requirement is the conversation-forcing mechanism, and
it remains in force at eight as it did at six.

## What this does not do

This ADR is intentionally narrow. It does NOT:

- **Resolve OQ-1.** Personal-tooling-vs-open-source-product
  remains deferred per ADR-006 and OPEN_QUESTIONS.md.
- **Open an external-onboarding path.** ADR-006 §3 is unchanged.
  No installer, no marketplace listing, no public install recipe.
- **Change the auth model.** ADR-006 §1 single-principal plan
  auth is unchanged. Adding vigil and agentic-ops does not
  introduce additional principals; both repos operate under the
  same maintainer's `CLAUDE_CODE_OAUTH_TOKEN`.
- **Relax ADR-007's wide-deployment gating prerequisites.** Any
  movement to wide deployment still requires the threat-model
  revision and mitigations named in ADR-007.
- **Relax ADR-006's three-prong gate for full supersession.**
  Moving beyond the named-internal-consumer scope (to
  open-source-product positioning) still requires (a) OQ-1
  resolution toward open-source-product, (b) ADR-007
  prerequisites met, (c) a new auth-model ADR. All three remain
  required.

## Trigger conditions for revisiting

This ADR is superseded (by a later ADR) under either of:

- A ninth consumer is proposed. Same shape as ADR-006 §2's
  requirement: the new ADR names the consumer, makes the
  maintenance-load case, and either fits the named-set discipline
  (raise to nine, name the consumer, preserve discipline) or
  abandons it (replace named set with a different boundary
  condition, requiring justification).
- ADR-006's three-prong gate clears — at which point a full
  supersession of ADR-006 replaces both ADR-006 and this ADR
  with the open-source-product framing.

Until one of these fires, the cap stands at eight.

## Alternatives considered

**Onboard a seventh / eighth consumer informally, without ADR.**
Rejected. ADR-006 §2 explicitly requires a later ADR for any
seventh consumer regardless of provenance. Bypassing that
requirement would be a violation, not a planning judgment.

**Raise the cap speculatively to a higher round number (e.g.,
ten, fifteen).** Rejected for the same reason ADR-006 rejected
"fifty internal repos": "Setting a higher cap invites scope
creep without forcing the conversation about whether the
maintenance commitment scales." A named set is the
conversation-forcing mechanism; numeric headroom undermines it.

**Withdraw the cap entirely (no numeric ceiling for internal
consumers).** Rejected. The cap discipline is not numeric, it's
conversational. The cap's purpose is to force an ADR-level
discussion before each addition; withdrawing the cap would let
maintenance load grow silently.

**Full supersession of ADR-006 (move to open-source-product
positioning now).** Rejected. ADR-006's three-prong gate is not
satisfied: OQ-1 has not resolved toward open-source-product,
ADR-007 prerequisites are not yet met, and no new auth-model ADR
exists. Full supersession would skip the gate that ADR-006
deliberately erected.

**Add only vigil (cap to seven, defer agentic-ops self-consumer
pattern).** Rejected. The two cases are independent in
substance and can be argued separately, but the maintenance-
load conversation is the same conversation either way — and the
agentic-ops self-consumer pattern has its own value (dogfooding;
substrate-aware review of substrate PRs) that warrants
ratification now rather than later. Splitting into two ADRs
would mean two cap-relaxation conversations within weeks; one
conversation covers both adequately.

## Consequences

**Positive.**

- vigil gets the substrate review it needs without violating
  ADR-006. The maintenance-load case is made explicitly rather
  than smuggled in via "namespace membership."
- The agentic-ops self-consumer pattern is ratified. Substrate
  PRs get substrate-aware review (the only reviewer that knows
  the substrate's ADRs); this is qualitatively different from
  what CodeRabbit and Codex catch.
- The named-set discipline scales: ADR-006 §2's
  conversation-forcing mechanism continues to apply at the new
  cap of eight. Future additions remain ADR-gated.

**Negative.**

- Maintenance load grows roughly one-third (6 → 8 consumers).
  Each onboarded consumer adds a caller stub, a `@v1`
  contract surface, and reviewer-feedback load. The maintainer
  has confirmed this is sustainable; if it proves not to be,
  this ADR can be superseded with a smaller cap.
- The self-consumer pattern is novel and introduces edge cases
  worth surfacing for future readers: (a) substrate-change PRs
  are reviewed against the previously-released `@v1`, not
  in-flight changes — intentional, but means substrate authors
  cannot rely on substrate review to catch issues in the very
  changes that bump `@v1`; (b) the kernel and the agentic-ops
  caller stub coexist in the same repo, which is structurally
  different from any other consumer's setup; future contributors
  should not confuse the two files.
- Adds a second ADR to read for anyone trying to understand the
  scope policy. Future readers of ADR-006 will follow the
  Status-line marker to this ADR; the additional indirection is
  the cost of preserving ADR immutability.

**Neutral.**

- The cap remains a named set; the new cap of eight is not a
  numeric ceiling but a set boundary. Future additions are
  evaluated by the same conversation-forcing mechanism.
- This ADR does not commit to a specific onboarding order for
  vigil vs. agentic-ops; that is a phase-doc concern (P7) and
  may be sequenced by the maintainer based on the immediate
  utility of each onboarding.

## References

- [ADR-006](ADR-006-bounded-deployment-scope.md) — the partially-
  superseded ADR; §1, §3, §4, §5 remain canonical; §2 is
  withdrawn and replaced here.
- [ADR-007](ADR-007-threat-model-gating.md) — wide-deployment
  threat-model gating; unchanged by this ADR.
- [OPEN_QUESTIONS.md](../../OPEN_QUESTIONS.md) — OQ-1 remains
  deferred; this ADR does not resolve it.
- [.planning/phases/P7-onboarding.md](../../.planning/phases/P7-onboarding.md)
  — per-repo configuration table updated to include the two new
  consumers.
