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

## OQ-12 — Frictionless install/onboarding shape

**Question:** What does the install/onboarding experience look like
for the eventual product, distinct from the current `/goal`-driven
dev-run recipe in `ONBOARDING.md`? Specifically: which prerequisites
are genuinely human (truly-UI-only operations, policy decisions)
versus which can be agent-applied or scripted; how is standing
consent for canonical-template operations recorded; how does the
system handle an inform-and-approve gate without forcing per-action
friction; whether the deployment surface is a script, an agent, an
installer, a marketplace install, or some combination.

**Deferred:** until either (a) OQ-1 resolves toward "open-source
product" per ADR-006's three-prong gate, or (b) internal-scale
operation (P7 onboarding of the named-consumer set, plus P8
observability) produces enough friction data to design against.
The current dev-run recipe in `ONBOARDING.md` is *not* a product
artifact and should not be treated as one when the product shape is
designed.

**Signal observed during 2026-05-14 prix-guesser P7 dispatch:**

- **Recipe-vs-reality mismatch.** `ONBOARDING.md §Prerequisites`
  treated all listed items as a single class of human-only
  preconditions. The 2026-05-14 prix-guesser dispatch (which
  produced the per-escalation file
  `.planning/auto-execution/escalations/ESCALATION-2026-05-14T08:11:23Z.md`
  — local-only per the `.planning/auto-execution/` blanket
  gitignore; the substantive observation is preserved here because
  the source file is by design not committed) shows the items are
  actually three distinct classes:
  1. **Truly UI-bound on first use.** A GitHub App's *initial*
     installation on an account
     (`https://github.com/apps/<app>/installations/new`) is
     browser-only — there is no token an external API call could
     present as the install-time identity. CodeRabbit App
     first-install falls here.
  2. **API-callable without third-party credential.** Add a repo
     to an *existing* GitHub App installation
     (`PUT /user/installations/{installation_id}/repositories/{repository_id}`
     — caveat: per GitHub's REST docs this endpoint *only* accepts
     a **classic PAT with `repo` scope**; it rejects GitHub App
     user/installation tokens, fine-grained PATs, and the default
     `GITHUB_TOKEN`. A future installer or CI path has to provision
     a classic PAT specifically, not whatever ambient credential
     happens to be available); enable branch protection
     (`PUT /repos/.../branches/.../protection` — accepts classic
     PATs, fine-grained PATs with the right scope, and properly-
     scoped `GITHUB_TOKEN`). Both are API-callable; both expose
     only the actor's own auth plus a setting payload; no
     third-party credential changes hands. The two operations
     differ in *which* actor-credential types the endpoint accepts,
     and that asymmetry is load-bearing for installer design.
  3. **API-callable but credential-bearing.** `gh secret set`
     requires the actor to *hold the plaintext secret value at
     the moment of the call*. The operation is API-callable, but
     the security analysis is different from class (2): designing
     a script or agent path here means designing how the secret
     is captured, kept briefly, and destroyed. The maintainer's
     `claude setup-token` flow plus a careful local-capture
     script (no argv exposure, no shell history, secure tmpfile
     cleanup, `unset` at end) is one such design — but it is a
     design, not a free win, and any product-onboarding shape has
     to take a position on whether class (3) is acceptable for an
     agent path or stays maintainer-only. ADR-006's intent that
     the maintainer provisions secrets is the conservative
     default.

  Implication: a future install/onboarding design cannot collapse
  these three back into "human prereqs" without losing real
  granularity.
- **Dev-run-recipe vs product-recipe conflation.** `ONBOARDING.md`
  was authored as the dev-run recipe for `/goal`-driven internal-
  consumer onboarding. Its naming invited reading it as a
  product-onboarding doc. These are different artifacts and need
  separate naming, scope, and audience when the product shape is
  designed.
- **Standing-consent pattern.**
  [ADR-009](docs/adr/ADR-009-consumer-cap-relaxation.md)
  §Decision §1 names the consumer set. This *could* be the
  artifact via which standing authorization for canonical-template
  operations is recorded (i.e., "membership in the named set
  implies consent to apply the canonical pattern"). Or it could be
  the wrong abstraction (too coarse-grained; needs per-operation
  granularity). Open.
- **Inform-and-approve gate as distinct from halt-on-setting.**
  Two different ways to handle setting changes; conflating them
  produces either too much friction (halt on every setting change,
  forcing the maintainer to scroll through git settings UI) or too
  little safety (any agent action on any setting). A third pattern
  — agent prints the planned action, applies it if pre-authorized,
  escalates only if pre-authorization is missing — is not yet
  expressed anywhere in the docs.
- **`.planning/EXECUTION-MODEL.md` policy on high-stakes escalation.**
  Inside `.planning/EXECUTION-MODEL.md §"Agent-to-agent mailbox channel
  (post-install)"`, the paragraph beginning *"High-stakes
  decisions still route to the maintainer through the normal
  escalation path"* enumerates the escalation territory and
  includes "repo settings, branch protection, force-pushes,
  release tags, ADR creation or supersession, allowlist changes,
  security-impacting changes, and any workflow-contract change
  whose blast radius is unclear." That policy was authored before
  this experience; we now have data points about its friction
  cost for canonical-template operations on named-consumer repos.
  Any resolution that wants `/goal` to apply canonical settings
  without escalation requires deliberate amendment to that
  paragraph (or a superseding ADR), not an inline recipe tweak.
- **Deterministic-script vs agent-applies pattern.** The same
  canonical action (e.g., enable BP with the agentic-ops template)
  can ship as `bin/setup-consumer.sh`, as an agent task with a
  canonical-settings appendix, as both (script-as-source-of-truth,
  agent-calls-script), or as neither (relying entirely on
  manual or marketplace install). No artifact currently says which.

**What would resolve:**

- (toward deterministic script) install/onboarding ships primarily
  as a `bin/setup-<thing>.sh` script suite that is idempotent and
  replayable; agents call the same scripts as humans do; the
  script is the single source of truth for setup operations.
- (toward agent-applies-with-standing-consent) onboarding is an
  agent task that reads a canonical-settings artifact (ADR or
  appendix) and applies it to repos whose membership in a named
  set implies consent; ADR-009-style ADRs are the consent
  mechanism; per-action prompts are reserved for repos outside the
  named set.
- (toward marketplace-install) the substrate becomes a GitHub
  App with a marketplace listing; the maintainer of a consumer
  repo clicks "install" in the UI; the app does the rest. This
  pattern is currently blocked by
  [ADR-006](docs/adr/ADR-006-bounded-deployment-scope.md) §3
  ("no installer is published to a marketplace, advertised as a
  public install path, or documented for non-`loganrooks/*`
  adopters") and §4 ("No marketing copy, no marketplace listing,
  no 'agentic-ops template' repo for outside use"). Unblocking
  requires ADR-006's three-prong supersession (OQ-1 + ADR-007
  prerequisites + new auth-model ADR), not merely a roadmap
  addition. ROADMAP §"What's NOT on the roadmap" excludes
  "Building a TUI / desktop app" — that is a *separate* non-goal,
  not the marketplace-install gate.
- (toward hybrid) different operations route to different
  mechanisms: settings → script, content → agent, app install →
  manual UI, secrets → maintainer-provided then script-applied.

**Constraint:** any resolution must respect ADR-006's bounded-
deployment scope and ADR-007's threat-model gating. Anything
that relaxes those requires a superseding ADR.
`.planning/EXECUTION-MODEL.md`'s high-stakes-escalation enumeration (in
§"Agent-to-agent mailbox channel (post-install)", paragraph
beginning *"High-stakes decisions still route..."*) is also an
active constraint until amended by an ADR or a
directly-justified edit.

**Out of scope for this OQ.** Widening `/goal`'s scope on the
current dev run is a separate decision about `.planning/EXECUTION-MODEL.md`,
not about this OQ. This OQ is about the eventual product
install/onboarding, distinct from how the substrate is currently
being *built* via autonomous execution.

**Cross-references:**
[OQ-1](#oq-1--personal-tooling-vs-open-source-product) (positioning),
[OQ-11](#oq-11--wide-deployment-readiness-shape) (readiness work
shape; mentions "installer" once as part of the full-stack option
without designing it),
ROADMAP §"What's NOT on the roadmap" (TUI/desktop app excluded —
separate non-goal from the marketplace-install gate),
`.planning/EXECUTION-MODEL.md` §"Agent-to-agent mailbox channel
(post-install)", paragraph beginning *"High-stakes decisions still
route..."* (escalation territory),
[ADR-006](docs/adr/ADR-006-bounded-deployment-scope.md) §3 (no
installer / marketplace listing for external use until trigger
conditions met) and §4 (repo visibility / no marketplace listing),
[ADR-009](docs/adr/ADR-009-consumer-cap-relaxation.md) §Decision §1
(consumer set definition; potential standing-consent artifact).

---

## How this list evolves

- New questions go here as they emerge.
- Resolved questions move to ADRs in `docs/adr/` or remain here
  marked `[RESOLVED → ADR-NNN]`.
- Stale questions (no longer relevant) get marked `[STALE]` rather
  than deleted, to preserve the reasoning trail.
