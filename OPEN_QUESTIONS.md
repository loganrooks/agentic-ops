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

## OQ-13 — `extra_allowed_tools` policy gap (plugin-loading tools)

**Surfaced.** 2026-05-14, by Codex automatic re-review on closed
PR #17 (`docs(adr): ADR-010 — eslint Forbidden + wildcard limits`).
PR #17 attempted to fix `Bash(eslint:*)` after Codex's P1 finding on
`loganrooks/prix-guesser` PR #1; Codex's re-review surfaced that the
fix was incomplete — the same code-execution-from-PR-head pattern
applies to multiple linters in [ADR-004](docs/adr/ADR-004-allowlist-policy.md)
§Decision §Acceptable, plus the `Bash(tsc --noEmit *)` wildcard
chains into a wrapper-overwrite attack.

**The gap.** ADR-004's "STATIC ANALYSIS ONLY" framing conflates two
different properties: (a) the tool parses target code without
compiling/executing it, and (b) the tool itself does not execute
code from PR-controlled config files. (a) is true for all linters.
(b) is false for any linter with a plugin system. ADR-004 §Decision
§Acceptable was built on (a) alone; tools currently listed
acceptable that violate (b):

| Tool | Plugin/code-loading surface | Verified |
|---|---|---|
| `eslint` | `eslint.config.js` / `.eslintrc.js` (JavaScript) | Codex P1 on prix-guesser PR #1 |
| `mypy` | `mypy.ini` / `pyproject.toml` `plugins` (Python) | Codex P1 on agentic-ops PR #17 (mypy 1.20.2) |
| `pylint` | `.pylintrc` `load-plugins` (Python) | Codex P2 on agentic-ops PR #17 (docs) |
| `flake8` | `setup.cfg` `[flake8:local-plugins]` (Python) | Codex P2 on agentic-ops PR #17 (docs) |

`Bash(tsc --noEmit *)` is a separate wildcard-defeat issue:
`tsc --noEmit false --outFile <wrapper-script-path>` overwrites the
privileged wrapper script (`central/.github/scripts/post-claude-review.sh`)
with attacker-controlled JavaScript; executable bit preserved by
Node's `fs.writeFile`; next wrapper invocation runs attacker code as
bash via JS-shell polyglot. Codex P1 verified locally with tsc 6.0.3.

**Initial "safer set" claim — withdrawn.** PR #18's first draft
listed `ruff`, `shellcheck`, `actionlint`, `yamllint`, `pyright`,
`rg`, `jq`, `yq`, `ast-grep` as "verified safe (no plugin/code-loading
surface)." Codex review on PR #18 (4× P1 findings) demonstrated that
this framing was wrong: the safe-set claim only addressed
plugin-loading defeats, but a parallel defeat class exists —
**arbitrary file write or code execution under wildcard arguments**:

| Tool | Wildcard-defeat surface | Verified |
|---|---|---|
| `ruff` | `--output-file <path>`, `--fix`, `format` (truncates files) | Codex P1 on agentic-ops PR #18 (`ruff check --help`) |
| `pyright` | `--pythonpath <FILE>` executes the file | Codex P1 on agentic-ops PR #18 (smoke test) |
| `yq` (mfarah) | `-i / --inplace` | Codex P1 on agentic-ops PR #18 (yq README) |
| `ast-grep` | `--rewrite`, `-U / --update-all` | Codex P1 on agentic-ops PR #18 (ast-grep run reference) |
| `actionlint` | `-shellcheck=PATH` invokes path as external tool | Identified during PR #18 disposition |
| `rg` | `--pre <COMMAND>` runs command on each file | Identified during PR #18 disposition |

**Restated insight.** No `Bash(<tool>:*)` wildcard is verifiably
safe in general. Almost every CLI has at least one defeat surface
under sufficient args. The defeats fall into two classes:

1. **Plugin/config code-loading.** `eslint`, `mypy`, `pylint`,
   `flake8`, `pyright`. The tool's *default* invocation loads
   PR-controlled code from auto-discovered config files. Worst
   class — exploit requires no special args.
2. **Arbitrary file write or `--exec`-equivalent under args.**
   `ruff`, `tsc`, `yq`, `ast-grep`, `actionlint`, `rg`, and
   likely many more. The defeat requires Claude to be tricked
   into invoking the tool with specific args. Practically
   harder to exploit but structurally still a hole.

**The structural answer is wrapper scripts** (Option 2 below) for
both classes. The two classes have different practical-exploit
difficulty but identical wrapper-script remediation.

**Tools without plugin-loading surfaces** (still subject to
class 2 wildcard defeats): `ruff`, `shellcheck`, `actionlint`,
`yamllint`, `rg`, `jq` — these are the *least-bad* candidates for
interim wildcard allowlisting if a wrapper script isn't yet
available, but should be tightened to wrapper-script form per
OQ-13.

**Interim fix (PR #18).** P7 phase-doc table reduced: `prix-guesser`
and `epistemic-agency` rows go to empty `extra_allowed_tools`
(TS-stack consumers lose tsc findings until OQ-13 resolves);
`arxiv-sanity-mcp`, `f1-modeling`, and `scholardoc` rows drop
`Bash(mypy:*)` where present and keep only `Bash(ruff:*)` as the
*least-bad pragmatic interim* (residual class-2 wildcard-defeat
risk accepted with documented mitigation pending OQ-13 wrapper
scripts). ONBOARDING.md §"Per-repo customization checklist"
mirrors this with the broader-class explanation; the
"verified-safe set" framing is withdrawn (see above). ADR-004
itself is **not** amended in PR #18 — the architectural decision
below determines the right shape of the codifying ADR. CR's
adjacent finding (audit:`<lens>` entries should be bare `audit`
since lens is selected at trigger time via `audit_target`) is
also addressed in PR #18 as a pre-existing inconsistency cleanup.

**Production state at the time of capture.** `loganrooks/prix-guesser`
PR #1 (merged at `42dc911`) ships with the vulnerable
`Bash(tsc --noEmit *)` wildcard. `loganrooks/arxiv-sanity-mcp` PR #2
(open, /goal paused) ships with the vulnerable `Bash(ruff:*),Bash(mypy:*)`
caller stub. Both require consumer-side follow-up patches after PR
18 lands (mypy dropped from arxiv-sanity-mcp; tsc wildcard dropped
from prix-guesser; ruff retained as the least-bad interim default).
The practical exploit risk today is nil because the named-consumer
set (per ADR-009 §Decision §1) is private and only the maintainer
authors PRs against these repos, but the substrate's discipline
assumes hostile PR-head input per ADR-007.

**Architectural decision space (the real OQ).**

**Option 1 — Accept reduced allowlist permanently.** Drop all
plugin-loading tools from §Acceptable; reclassify as Forbidden under
the existing threat model. Genuinely-safe tools only.

| Pros | Cons |
|---|---|
| No infrastructure work | Significant capability loss for review |
| Honest about the threat model | Doesn't fix the structural problem (next tool we add might also have plugin loading; whitelist needs continual filtering) |
| Defensible to senior security engineer | Python consumers get only ruff (style/import-order), no type checking; TS consumers get nothing in `extra_allowed_tools` |

**Option 2 — Wrapper-script discipline.** Add `central/scripts/safe-<tool>.sh`
for each affected tool; hardcode safe flags (e.g., mypy `--config-file
/dev/null --no-incremental`; tsc refusing `--outFile`/`--outDir`/`--build`/
`--noEmit false`); allowlist `Bash(./central/scripts/safe-<tool>.sh:*)`.

| Pros | Cons |
|---|---|
| Preserves review capability | 1-2 weeks per tool to verify "safe flags" actually disable plugin loading and other escape hatches |
| Single audited boundary per tool (wrapper is the argument-injection boundary; allowlist wildcard is safe inside it) | mypy has no `--disable-plugins` flag; requires `--config-file /dev/null` + env hygiene; needs verification |
| Wrapper is reusable across consumers via central checkout | tsc safe-form must refuse multiple defeat patterns (`--outFile`, `--outDir`, `--build`, `--noEmit false`, `--noEmit=false`, etc.) — multiple ways to slip through |
| Aligns with ADR-004's existing wrapper-script discipline for `post-claude-review.sh` | Wrapper itself is a new attack surface (bugs in the wrapper = full compromise); maintenance burden ongoing as upstream tools change |

**Option 3 — Sandboxed execution (ADR-004 §"Path B").** Second
workflow (`workflow_run`-triggered) with `permissions: read-only`
and no `CLAUDE_CODE_OAUTH_TOKEN`. Runs PR-head tools. Surfaces
results as artifacts to the reviewer.

| Pros | Cons |
|---|---|
| Structurally correct | Substantial implementation work (new workflow + artifact protocol) |
| Any tool becomes safe under no-secrets boundary | Per ADR-004, "empirical value of test-results-as-reviewer-input is unproven" |
| Removes whitelist-maintenance burden | Risk of creating a new exfiltration path if done wrong |
| Future-compatible with adding test runners (`pytest`, `jest`) | Doubles workflow surface area |

**Option 4 — Threat-model reframe for internal consumers.** New ADR
establishing that named-consumers per ADR-009 use a relaxed threat
model: PR authors are trusted (maintainer + collaborators + agents
under maintainer control). ADR-004's untrusted-input model applies
only to a future external-onboarding context.

| Pros | Cons |
|---|---|
| Honest about deployment reality (current PR-author pool is nil hostile) | Sets dangerous precedent ("relax when inconvenient") |
| No infrastructure work | Erodes substrate's security posture for future external onboarding |
| Restores all current capability | Automated PR authors (Codex, Claude in autonomous mode) may inadvertently include unsafe patterns; "trusted internal" claim weakens when agents are in the loop |
| Aligns with bounded-scope intent of ADR-006 | ADR-007's threat-model gating becomes inconsistent with the new ADR |

**Recommendation captured at time of surface (not committing).**
Option 2 (wrapper-script discipline) is the right structural fix
because (a) it preserves review capability, (b) the wrapper is a
stable audited boundary, (c) it composes with the existing
wrapper-script discipline (`post-claude-review.sh`). But the work
is meaningful (1-2 weeks careful per-tool research + design + test).
Option 3 is structurally cleanest but ADR-004 itself rates
value-to-cost as unproven at current scale. Option 4 is dangerous.
Option 1 is the fallback if Options 2/3 prove infeasible.

**Trigger conditions for resolution.**
- A consumer has a concrete review need that the reduced allowlist
  cannot serve (e.g., "we shipped a regression that mypy with
  plugins would have caught"); forces the conversation about
  Option 2 vs 3.
- External onboarding is reopened (per ADR-006 §"Trigger conditions
  for revisiting"); forces the wider threat-model decision and
  obviates Option 4.
- A peer substrate (CodeRabbit, Anthropic's review action) ships
  Path B and demonstrates feasibility; weighted toward Option 3.

**See also.** [ADR-004](docs/adr/ADR-004-allowlist-policy.md)
§Decision §Acceptable (the table this OQ identifies as needing
filtering), §"Why no test execution" (the threat model that already
covers this class but wasn't applied consistently), §"Path B
(sandboxed execution) — explicitly deferred" (Option 3 in this OQ).
[`.planning/phases/P7-onboarding.md`](.planning/phases/P7-onboarding.md)
§"Per-repo configuration" (the table reduced in PR #18; Updated
header carries the rationale). [`ONBOARDING.md`](ONBOARDING.md)
§"Per-repo customization checklist" (the propagation surface).

---

## How this list evolves

- New questions go here as they emerge.
- Resolved questions move to ADRs in `docs/adr/` or remain here
  marked `[RESOLVED → ADR-NNN]`.
- Stale questions (no longer relevant) get marked `[STALE]` rather
  than deleted, to preserve the reasoning trail.
