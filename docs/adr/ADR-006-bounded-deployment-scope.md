# ADR-006: Deployment scope bounded to internal consumers until OQ-1 resolves

Status: accepted; partially superseded by ADR-009 (re: §2 consumer cap)
Date: 2026-05-10

## Context

`agentic-ops` is built and operated under two unresolved framings captured
in `OPEN_QUESTIONS.md`:

- OQ-1 ("personal tooling vs open-source product") — deferred until the
  M-phase work is complete and the maintainer has lived with the system
  long enough to know what's load-bearing vs. accidental. Current leaning:
  personal-tooling-in-public-repo.
- OQ-2 ("substrate beyond claude-code-action") — deferred until
  reviewer-types work in M2 either confirms matrix fan-out is sufficient
  or surfaces a specific limitation. Current leaning: stay on
  claude-code-action with matrix fan-out. **Hard constraint inside OQ-2:**
  any substrate that violates Anthropic's Pro/Max OAuth ToS (third-party
  OAuth clients) is off the table.

The proximate forcing function (per `INITIATIVE.md`) is review of
CBM PR `#1`; the strategic frame is reuse across `loganrooks/prix-guesser`,
`arxiv-sanity-mcp`, `f1-modeling`, `epistemic-agency`, `scholardoc`. P7
("Onboard 5 repos") fans the substrate out to those targets.

A separate, broader question has surfaced during P4: should `agentic-ops`
be installable / adoptable by repos outside `loganrooks/*`? That question
is upstream of the install mechanism (CLI vs. agent-driven vs. hybrid) — it
determines whether the install mechanism needs to be discoverable,
deterministic, and turnkey at all. Without a decision, P7 risks
implementing a scale ("wide deployment") that hasn't been authorized, and
P5..P9 risk being designed around an audience that may not exist.

`SECURITY.md` §"Out of scope" already commits the substrate to a
single-principal model: "Multi-tenancy. This is personal-tooling-in-
public-repo; one principal (the maintainer) sets policy." Any expansion
beyond `loganrooks/*` violates that commitment without a corresponding
threat-model revision (see ADR-007).

## Decision

Until OQ-1 resolves toward "open-source product," `agentic-ops` is
**bounded to internal consumers** — defined as repos in the
`loganrooks/*` namespace that the maintainer also operates. No external
adoption work is in scope for P5..P9.

Concretely:

1. **Auth model is plan auth, single principal.** `CLAUDE_CODE_OAUTH_TOKEN`
   is the maintainer's Anthropic Pro/Max OAuth token. The token is
   provisioned per-repo as a secret by the maintainer. No multi-tenant
   secret distribution; no external-adopter onboarding path that
   requires the maintainer's token; no documentation telling external
   adopters to "bring your own token" (which would imply support).

2. **Consumer cap.** The substrate is operated for at most the six
   internal consumers listed in P7 (`cbm`, `prix-guesser`,
   `arxiv-sanity-mcp`, `f1-modeling`, `epistemic-agency`, `scholardoc`).
   Onboarding a seventh consumer — *internal or external* — requires a
   later ADR superseding this one with explicit reasoning. The cap is
   not relaxed by `loganrooks/*` namespace membership alone; the point
   of the cap is to force the conversation about maintenance load
   before scope expands, and that conversation is needed for any
   seventh consumer regardless of provenance.

   > **Note (2026-05-11, partial supersession by ADR-009):** The
   > six-consumer cap stated in this section is withdrawn by
   > [ADR-009](ADR-009-consumer-cap-relaxation.md) §Decision; the
   > consumer set is now eight (six original + vigil + agentic-ops).
   > The named-set discipline (adding a further consumer requires a
   > superseding ADR) is preserved.

3. **No installer for external use.** Install mechanism for the six
   internal consumers may be a `gh` extension, a coded scaffolder, or
   agent-driven from a template — that choice is left to a separate
   ADR if it becomes load-bearing. But no installer is published to a
   marketplace, advertised as a public install path, or documented
   for non-`loganrooks/*` adopters.

4. **Repository visibility unchanged.** The repo stays "public but
   unannounced" per OQ-9. No marketing copy, no marketplace listing,
   no "agentic-ops template" repo for outside use.

5. **Forks are not supported.** A fork of `agentic-ops` consumed by an
   external repo via `loganrooks-fork-name/agentic-ops/...@v1` is the
   forker's responsibility; the maintainer offers no compatibility
   commitment.

## Trigger conditions for revisiting

This ADR is superseded (by a later ADR) when ALL of:

- OQ-1 resolves toward "open-source product" via the signals named in
  `OPEN_QUESTIONS.md` (organic external interest, demonstrated
  generalization to non-`loganrooks/*` shapes, sustainable maintenance
  burden).
- ADR-007 prerequisites are met (threat model revised for wide
  deployment with mitigations implemented for at least the new threat
  classes named there).
- An auth model that does not depend on the maintainer's personal
  Pro/Max OAuth token is designed and accepted in a separate ADR
  (workspace OAuth, API-key billing with consumer-side credentials, or
  another path that respects OQ-2's hard constraint).

Until all three are met, deployment scope stays bounded.

OQ-11 (added with this ADR) tracks the shape of the readiness work
that would happen if/when these trigger conditions are met.

## Alternatives considered

**Defer the scope question entirely; let P7 implicitly define scope.**
Rejected. P7 already commits to onboarding 5 specific internal repos —
that's the same scope this ADR proposes, but implicit. Without the ADR,
P7's scope is incidentally bounded by the table of 5 repos, not
explicitly bounded as a policy. If P5..P9 work begins without an
explicit scope policy, drift is likely (e.g., a future phase could
propose "and let's also onboard one external repo as a demo"; without
this ADR, that's a planning judgment; with it, it's a violation that
forces an ADR supersession).

**Resolve OQ-1 now toward "open-source product" and design accordingly.**
Rejected. OQ-1's signal conditions explicitly require lived experience
(M-phase complete, "long enough to know what's load-bearing"). Resolving
prematurely either commits maintenance to an audience that may not
materialize or designs around constraints (multi-tenancy, public
discoverability, SLAs) that the project hasn't proven it needs. The
honest path is to commit to internal scope now and revisit after lived
experience.

**Resolve OQ-1 now toward "personal tooling" permanently.** Rejected.
The current leaning is "personal tooling, but revisit if demand
emerges" — a permanent decision is stronger than the evidence supports
and forecloses options that may become attractive later. The
conditional nature of this ADR (with explicit trigger conditions for
supersession) is the right shape.

**Cap consumer count higher (e.g., 50 internal repos).** Rejected.
The substrate has six concrete internal consumers identified in P7;
"50" is speculative. Setting a higher cap invites scope creep without
forcing the conversation about whether the maintenance commitment
scales.

## Consequences

**Positive.**
- P5..P9 design discipline is anchored: the audience is six known
  repos, not a hypothetical public. Threat model, eval bar, and
  maintenance contract are all sized for that audience.
- "Personal-tooling-in-public-repo" graduates from informal stance
  (mentioned in INITIATIVE.md non-goals, OPEN_QUESTIONS.md OQ-1, and
  SECURITY.md "Out of scope") to an explicit commitment with named
  trigger conditions for revisiting.
- Future deviation is visible: any PR proposing external adoption,
  a marketplace listing, or a public-facing install path is
  recognizable as ADR-006-superseding work.

**Negative.**
- Forecloses opportunistic external adoption during the bounded
  period. If an external maintainer files an issue saying "I want to
  use this on `coolproject/*`," the answer is "fork it, it's
  Apache-2.0, but no support commitment."
- Adds a step to any future scope-expansion: a separate ADR must
  supersede this one with explicit reasoning. That's the intent, but
  it's also friction.

**Neutral.**
- Six consumers may be too many or too few for the maintainer's
  actual capacity. The cap is set for the current P7 plan; if M-phase
  experience reveals six is unsustainable, this ADR can be
  superseded with a smaller cap rather than abandoning the policy.
- The repo remains public throughout the bounded period. Public
  visibility is independent of adoption support.
