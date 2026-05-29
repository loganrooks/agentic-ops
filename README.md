# agentic-ops

> Agentic devops for AI-led development — onboards new projects, reviews changes, and evolves with the codebase.

_Part of the `agentic-*` family — see the `agentic-ecosystem` repo
(`ECOSYSTEM.md`) for what this repo owns and how it composes with its siblings._

## Status

L1 review substrate (review / quick / deep / gates / opus / survey / audit
modes per [ADR-001](docs/adr/ADR-001-mode-taxonomy.md)) is merged on
`loganrooks/agentic-ops` `main` and exposed via the floating
[`v1`](https://github.com/loganrooks/agentic-ops/releases/tag/v1) tag
([ADR-003](docs/adr/ADR-003-versioning-and-release.md)). One consumer is
live: `loganrooks/codebase-mapper` via its caller stub.

L3 matrix-fan-out variants (`survey-matrix`, `audit-matrix`, `audit-all`)
are specified in [ADR-008](docs/adr/ADR-008-l3-mode-variants.md) and
gate-pending per-family empirical comparison; not implemented.

Deployment scope is bounded to internal consumers per
[ADR-006](docs/adr/ADR-006-bounded-deployment-scope.md). External use of
the public repo is permitted under Apache-2.0 but no external-onboarding
path is offered.

## What this is

A devops platform for solo developers who lead with AI agents. Three things,
working together, growing with the consuming repos:

1. **Onboarding** — bootstraps proper devops on a new project: CI workflows,
   PR review, dependency management, observability hooks, secrets discipline.
   Software-type-aware (game vs SaaS vs static site need different scaffolding).

2. **Review** — multi-specialist PR review tuned for AI-failure modes
   (hallucinated references, silent fallbacks, contract drift, speculative
   scaffolding). Mode-disciplined (review / quick / deep / opus). Multi-vendor
   composable (Claude primary; Codex App findings as input; OpenAI compute as
   future option).

3. **Evolution** — detects when the codebase has outgrown its devops setup.
   New `Dockerfile` but no container build workflow? New database driver but
   no backup workflow? Surfaces these the moment they're introduced, drafts
   the missing piece, and lets the developer apply it.

## Why this exists

The user behind this project ([loganrooks](https://github.com/loganrooks))
maintains eight personal repos where most code is AI-authored (the
named internal-consumer set per ADR-006 / ADR-009). AI ships
plausible-but-wrong code at a velocity human review can't keep up with;
existing tools (CodeRabbit, Codex, Diamond) catch patterns but don't compose
across vendors, don't span lifecycle stages, and don't evolve with the
codebase. This is the missing piece.

## Architecture sketch

- **Orchestrator**: a coordinator that decides which specialists to spawn,
  composes their findings, and posts a single synthesized review.
- **Specialists**: small focused agents (security, AI-failure-modes, drift,
  doc-freshness, prod-readiness) that run in parallel.
- **Substrate**: shared scaffolding — auth (plan-auth via Claude Code OAuth),
  prompt sanitization (Comment-and-Control defense), comment posting via
  hardened wrapper, allowedTools allowlist.
- **Registry**: patterns to detect, missed-signal log, drift triggers. Grows
  from postmortems of what the system missed.
- **Per-repo overlay**: each consumer repo names its contract surfaces and
  picks which specialists run. Central owns discipline; consumers own their
  contract surfaces.

## Pointers

- [VISION.md](./VISION.md) — the guiding vision, problem framing, and
  philosophical commitments.
- [ROADMAP.md](./ROADMAP.md) — short / medium / long-term horizons with
  concrete phases.
- [OPEN_QUESTIONS.md](./OPEN_QUESTIONS.md) — explicit deferrals, tradeoffs
  not yet resolved, and the criteria that would resolve each one.
- [docs/adr/](./docs/adr/) — architecture decisions
  (ADRs 001-009 cover mode taxonomy, parallelism architecture, versioning,
  allowlist policy, audit output format, bounded deployment scope,
  threat-model gating, L3 mode variants, and consumer cap relaxation).
- [AGENTS.md](./AGENTS.md) — operative discipline for contributors
  (human or agentic).
- [ONBOARDING.md](./ONBOARDING.md) — recipe for adding a named
  internal consumer (bounded by ADR-006; external use out of
  scope per ADR-006 §3).
- [SECURITY.md](./SECURITY.md) — threat model and reporting.

## Who this is for

Eight internal consumers per
[ADR-006](docs/adr/ADR-006-bounded-deployment-scope.md) (as
partially superseded by
[ADR-009](docs/adr/ADR-009-consumer-cap-relaxation.md) re: §2):
[codebase-mapper](https://github.com/loganrooks/codebase-mapper),
prix-guesser, arxiv-sanity-mcp, f1-modeling, epistemic-agency,
scholardoc, vigil, and agentic-ops itself (self-consumer pattern;
see ADR-009 §Decision). ADR-006 (as partially superseded by
ADR-009) caps the consumer set at eight; relaxing the cap further
requires a superseding ADR.

External use of the public repo is permitted under Apache-2.0 but no
support commitment is offered and no external-onboarding path is
documented per ADR-006. Forks consumed externally are the forker's
responsibility. Adding a ninth named internal consumer requires a
later ADR superseding ADR-009 (the same named-set discipline ADR-006
§2 established). Moving beyond bounded-internal-consumer scope —
toward open-source-product framing — is the stronger gate and
requires ADR-006's three-prong supersession (OQ-1 resolved toward
open-source product + ADR-007 prerequisites met + new auth-model
ADR accepted). See [OPEN_QUESTIONS.md](./OPEN_QUESTIONS.md) OQ-1
and OQ-11.

## License

Apache License 2.0 — see [LICENSE](./LICENSE).
