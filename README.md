# agentic-ops

> Agentic devops for AI-led development — onboards new projects, reviews changes, and evolves with the codebase.

## Status

Early. Scope captured, kernel design agreed, no implementation yet. The first
working version will be an extracted PR review orchestrator from
`loganrooks/codebase-mapper`.

This repo currently holds the project's vision, roadmap, and open questions.
Implementation lands once the security hardening for the source workflow ships
in `codebase-mapper` (PR #5).

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
maintains six personal repos where most code is AI-authored. AI ships
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
- [docs/adr/](./docs/adr/) — architecture decisions as they land within
  this project (currently empty; the project itself is too young to have
  internal decisions yet).

## Who this is for

Initially, the [loganrooks/](https://github.com/loganrooks) repos:
[codebase-mapper](https://github.com/loganrooks/codebase-mapper),
prix-guesser, arxiv-sanity-mcp, f1-modeling, epistemic-agency, scholardoc.

Whether this expands beyond personal tooling to a public-facing product is
deferred (see [OPEN_QUESTIONS.md](./OPEN_QUESTIONS.md)).

## License

TBD. Not yet relevant — no code to license.
