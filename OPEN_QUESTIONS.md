# Open Questions

Decisions deliberately deferred. Each entry names: the question, what's
deferred, what would resolve it, and current leaning (if any).

These are not "todo items." They are unresolved tradeoffs. Some will
remain unresolved indefinitely; that's fine.

---

## OQ-1 — Personal tooling vs open-source product

**Status:** still deferred. The license question that was conflated
with this OQ has been resolved separately — LICENSE is Apache-2.0
(in fact has been since the P1 merge, commit `3f5d05a`); the README
previously misstated this as "TBD." That is a factual sync, not an
OQ-1 resolution. OQ-1 itself — whether the substrate is a
public-facing product with a maintenance commitment — remains
deferred per [ADR-006](docs/adr/ADR-006-bounded-deployment-scope.md)
(as partially superseded re: §2 by
[ADR-009](docs/adr/ADR-009-consumer-cap-relaxation.md)),
which explicitly rejected resolving OQ-1 prematurely and bounded
the substrate to a named-internal-consumer set (now eight per
ADR-009: codebase-mapper, prix-guesser, arxiv-sanity-mcp,
f1-modeling, epistemic-agency, scholardoc, vigil, and agentic-ops
itself) until the ADR-006 trigger conditions are met.

**Question:** Is `agentic-ops` something the user maintains for their
own repos, or a public-facing product with maintenance commitment to
external users?

**Deferred:** until the M-phase work is complete and the user has
lived with the system long enough to know what's actually load-bearing
vs. accidental. ADR-006 §"Trigger conditions for revisiting" gates
*resolution toward "open-source product"* on all three (OQ-1 signal
conditions met, ADR-007 prerequisites met, new auth model ADR
accepted); resolution toward "personal tooling" remains unconditional
because it merely confirms the existing ADR-006 posture.

**What would resolve:**
- (toward product) external interest emerges organically (issues,
  forks, stars) suggesting real demand
- (toward personal) the system works well for `loganrooks/*` but the
  patterns don't generalize cleanly to other repos' shapes
- (toward personal) maintenance burden of even the user's own consumers
  feels heavy enough that supporting strangers' edge cases would tip
  into untenable

**Current leaning:** personal-tooling-in-public-repo bounded to the
eight named internal consumers per ADR-006 §2 (as partially
superseded by ADR-009). License is Apache-2.0; no support
commitments offered. Forks consumed externally are the forker's
responsibility per ADR-006. Adding a ninth named *internal*
consumer requires a later ADR superseding ADR-009 (the same
named-set discipline); that is distinct from OQ-1 resolution.
OQ-1 resolution toward "open-source product" is the stronger
gate and requires ADR-006's three-prong supersession (OQ-1 signal
conditions met + ADR-007 prerequisites met + new auth-model ADR
accepted) — not a unilateral resolution here.

---

## OQ-2 — Substrate beyond claude-code-action

**Question:** Stay on `anthropics/claude-code-action` indefinitely, or
adopt a richer substrate (OpenCode, custom orchestrator) when patterns
demand it?

**Deferred:** until reviewer-types work in M2 either confirms matrix-
job fan-out is sufficient or surfaces a specific limitation we can't
work around.

**What would resolve:**
- (stay on claude-code-action) M2 succeeds; matrix overhead is acceptable;
  no ergonomic pain that breaks the architecture
- (move to OpenCode) need for in-process child sessions becomes load-
  bearing; willing to accept API-billing for Anthropic models (plan
  auth lost) in exchange for orchestration ergonomics
- (custom orchestrator) neither claude-code-action nor OpenCode fit a
  specific need — likely a sign of premature scope expansion

**Current leaning:** claude-code-action with matrix-job fan-out. Plan
auth is too valuable to give up without clear architectural need.

**Hard constraint:** any substrate that violates Anthropic's Pro/Max
OAuth ToS (third-party clients using `CLAUDE_CODE_OAUTH_TOKEN`) is off
the table. OpenCode community plugins implementing OAuth are a known
ToS violation.

---

## OQ-3 — Plugin API design

**Question:** When does the plugin API become real (vs. specialists
hardcoded into the orchestrator)?

**Deferred:** until 5+ specialists exist and we feel pain from the
hardcoding.

**What would resolve:**
- (build API) third or fourth specialist requires per-repo
  customization that hardcoding can't elegantly support
- (defer further) all specialists fit cleanly into the central
  registry without per-repo variation

**Current leaning:** defer indefinitely. Premature plugin frameworks
are speculative scaffolding. The right plugin API will be obvious
once we feel its absence.

**Constraint:** when an API is built, it must follow the Cloudflare
plugin lifecycle pattern (bootstrap → configure → post-configure)
not because Cloudflare's pattern is sacred but because it has been
validated at production scale and we'd be inventing without reason
to deviate.

---

## OQ-4 — Multi-vendor scope

**Question:** How far does multi-vendor support go? Codex App findings
as synthesizer input only, or actual OpenAI specialists doing
independent reviews?

**Deferred:** until we feel a specific gap that Claude alone doesn't
cover.

**What would resolve:**
- (input only) Claude specialists + Codex App auto-review + synthesis
  layer is enough; reading existing comments suffices
- (independent OpenAI specialists) some category of issue is
  systematically caught better by OpenAI models, justifying the
  cost + complexity of running them ourselves

**Current leaning:** input only. Codex App already runs auto-review
at no cost to us. Synthesizing its findings into Claude's review is
nearly free. Building independent OpenAI specialists triples the
auth/billing/orchestration surface for marginal returns until we
have evidence of a specific gap.

---

## OQ-5 — Coordinator decision-making layer

**Question:** Does the system use a deterministic risk classifier
(Cloudflare's pattern) before invoking the LLM coordinator, or does
the LLM decide everything from the start?

**Deferred:** until M2 reveals whether the LLM coordinator can
reliably pick specialists from prompt instructions alone.

**What would resolve:**
- (deterministic pre-filter) LLM coordinator is unreliable at picking
  specialist composition; explicit rules ("auth/** files force security
  specialist") improve outcomes
- (LLM-only) LLM coordinator is reliable enough; the deterministic
  layer adds maintenance burden without clear value

**Current leaning:** deterministic pre-filter for sensitive paths
(auth, crypto, payment), LLM-driven for everything else. Mirrors
Cloudflare's pattern; conservative for the high-stakes cases.

---

## OQ-6 — How to integrate Codex App findings

**Question:** Two ways to consume Codex App's review:
1. The synthesis-Opus reads CodeRabbit + Codex + Claude specialists
   together and produces a unified review.
2. Each specialist independently reads prior reviews to dedupe before
   adding their own findings.

**Deferred:** until the synthesizer is built and we see whether
Approach 1 produces useful output.

**What would resolve:**
- (Approach 1) Opus synthesis with all three vendors' input is
  qualitatively better than three independent reviews
- (Approach 2) Specialists need vendor-specific deduplication
  (CodeRabbit's findings format vs. Codex's vs. Claude's earlier
  pass) and can't be done at synthesis time

**Current leaning:** Approach 1. Synthesis is the natural place for
cross-vendor reasoning. Adding dedup logic to every specialist
distributes complexity poorly.

---

## OQ-7 — Severity / output format

**Question:** Cloudflare's three-level severity (`critical` /
`warning` / `suggestion`) seems right but is unproven for our use
case. Do we adopt it, or invent something different?

**Deferred:** until we have enough specialists to need a shared format.

**What would resolve:** running M2 with Cloudflare's severity scheme
and seeing whether the levels carve our actual findings cleanly.

**Current leaning:** adopt Cloudflare's scheme. Three levels are
enough; more is over-engineered; fewer (just "blocking" vs "non-
blocking") loses actionable nuance.

---

## OQ-8 — Approval rubric mapping

**Question:** Cloudflare's rubric maps severity to GitLab approval
states (`approved` / `approved_with_comments` / `unapprove` /
`requested_changes`). GitHub's approval API is different (approve /
request changes / comment). What's our rubric?

**Deferred:** until the synthesizer produces enough findings to
need an approval gate beyond just commenting.

**Possible mapping:**
- All `suggestion` only → no approval action; comment only
- Any `warning` → comment only (don't block)
- Any `critical` → request changes (block merge)

**Current leaning:** start by *only commenting*, not gating merge.
Block-merge by AI is a high-stakes promise. Earn the trust before
making it.

---

## OQ-9 — Visibility flip

**Question:** When (if ever) does this repo go from "public but
unannounced" to "public and announced"?

**Deferred:** until M-phase is complete and the user has decided
on OQ-1.

**What would resolve:**
- (announce) external interest exists; the user wants to position;
  M-phase results are good enough to share
- (don't announce) personal tooling that happens to be public is
  fine; no pressure to formalize

**Current leaning:** don't announce until OQ-1 resolves toward
"open-source product."

---

## OQ-10 — Devops self-application discipline

**Question:** This project will itself accumulate ADRs, runbooks,
SLOs, postmortems. How rigorous should that discipline be from
day 1?

**Deferred:** until there's an actual decision to record (first ADR)
or a real failure to postmortem.

**What would resolve:** the first time we make a load-bearing
decision (substrate choice, severity scheme, security mitigation)
or experience a real failure (the system misses something
significant).

**Current leaning:** wait for real artifacts. Don't write process
documentation in advance of process needs.

---

## OQ-11 — Wide-deployment readiness shape

**Question:** When OQ-1 resolves toward "open-source product," what is
the shape of the readiness work? A single spike phase, a full-stack
readiness phase, or piecemeal as need surfaces?

**Deferred:** until OQ-1 resolves. The shape can't be sized
meaningfully before the empirical signal from internal-scale operation
(P7 onboarding of the 7 named internal consumers post-CBM per
[ADR-009](docs/adr/ADR-009-consumer-cap-relaxation.md), plus P8
observability) tells us which TC-7..TC-11 mitigations from
`docs/adr/ADR-007-threat-model-gating.md` are load-bearing in
practice.

**What would resolve:**
- (spike phase) we want concrete artifacts (auth-model comparison,
  prototype deny-list, draft onboarding docs) before committing to
  the shape — early but bounded research
- (full-stack readiness phase) all TC-7..TC-11 mitigations plus
  auth-model ADR plus installer all designed and shipped together as
  one coherent unit — high commitment, high coherence
- (piecemeal) each constraint addressed as it becomes a blocker; no
  pre-committed phase shape — lowest commitment, highest drift risk

**Current leaning:** piecemeal as need surfaces. Premature commitment
to a phase shape before lived experience is exactly what ADR-006
explicitly avoids. The internal-scale operation should surface
which constraints actually bind — *which sizes and sequences the
work, not which TC class is optional*. ADR-007's TC-7..TC-11 are all
mandatory before external rollout regardless of which shape OQ-11
resolves into; the empirical signal determines order, effort, and
deliverable granularity, not inclusion.

**Constraint:** any resolution must respect ADR-006's trigger
conditions and ADR-007's mitigation requirements. The shape of the
work is open; the gates on starting it (and the threat classes that
must be covered before external rollout) are not.

---

## How this list evolves

- New questions go here as they emerge.
- Resolved questions move to ADRs in `docs/adr/` or remain here
  marked `[RESOLVED → ADR-NNN]`.
- Stale questions (no longer relevant) get marked `[STALE]` rather
  than deleted, to preserve the reasoning trail.
