# Vision

## Guiding statement

**Devops infrastructure for AI-led solo development.** A self-evolving system
that catches AI failure modes pre-deploy, escorts a codebase up the maturity
curve, and scales from one repo to many — without locking the developer into
a specific vendor or stage of their project's lifecycle.

## The problem

Three things are simultaneously true:

1. **Most of the user's code is AI-authored.** Across eight active personal
   repos (the named internal-consumer set per ADR-006 / ADR-009), AI
   agents do most of the coding. Human review is the safety layer,
   but humans can't keep up with AI velocity, and what humans miss is exactly
   the kind of subtle wrongness AI produces — plausible-but-wrong references,
   silent fallbacks, contract drift, speculative scaffolding, overclaim
   language in commit messages.

2. **Existing AI review tools are siloed and limited.** CodeRabbit catches
   pattern-level issues across files but is single-pass and can't compose.
   Codex auto-reviews but offers shallow customization (AGENTS.md only).
   Claude via custom GitHub Actions is configurable but ships as a single
   workflow per repo with no inheritance, no orchestration, no lifecycle
   awareness.

3. **Devops setup drifts as codebases evolve.** The CI pipeline that was
   right for a 500-line script isn't right for a 5000-line app with a
   database, a Dockerfile, and a payment integration. Drift is silent
   until something breaks in production. Solo devs don't have time to
   audit their devops weekly; the audit needs to happen automatically as
   changes are introduced.

The intersection of these three forms a real gap: **a system that catches
AI failure modes, composes multiple AI reviewers, and keeps devops setup
in step with codebase evolution.** That's what `agentic-ops` is.

## Core commitments

These are non-negotiable design principles:

### 1. Multi-vendor by design

Claude is the primary substrate today (plan auth via Claude Code OAuth, mature
GitHub Action). But the architecture must not lock to one vendor. Codex App
findings are input to synthesis. OpenAI compute is a future option for
non-Claude specialists. Future models become specialists, not rewrites.

### 2. Lifecycle-spanning

The same kernel — auth, sanitization, comment posting, agent orchestration —
serves PR review (today), drift detection (next), prod-readiness checks
(later), deploy review (later still), and production observability
integration (eventually). The kernel is designed for the full lifecycle
even when we're only using it for one stage.

### 3. Plan-auth-friendly

The cost ceiling matters. Anthropic's plan auth (`CLAUDE_CODE_OAUTH_TOKEN`)
keeps spending bounded for the use cases where it works. We do not foreclose
this by adopting substrates (like OpenCode) that Anthropic's ToS prohibits
from using plan auth.

### 4. Evolutionary architecture

Build small, composable, evolvable. Don't ship Phase 4 before Phase 1 has
proven itself. Each phase unlocks when consuming repos signal demand for it.
Refactor at the edges as the system grows; avoid big rewrites.

### 5. Defense in depth

No single point of failure on prompt injection. Tag-stripping for untrusted
content (Cloudflare-style boundary tags), wrapper-script for tool invocation
(closes the Comment-and-Control class), allowedTools allowlist (constrain
the blast radius), least-privilege secret scoping. Each layer is independent.

### 6. Stateless agents, persistent registry

Each agent invocation is fresh. Context flows via files (CONTEXT.md,
AGENTS.md, prior reviews). State that persists belongs to the registry —
patterns to detect, missed-signal log, drift triggers — and is the basis
for the system's improvement over time.

### 7. Devops discipline applied to itself

This project is itself a piece of infrastructure that will be maintained.
It gets ADRs, SLOs, runbooks, postmortems. When the system misses something,
that's a postmortem-worthy event with action items, not a vague
disappointment.

## What success looks like

A consuming repo gets, in priority order:

1. **A useful PR review within 5 minutes of a trigger comment.**
   Catches the AI-failure modes humans would catch on careful read.
2. **A drift comment when a PR introduces something the devops setup
   doesn't account for.** With a draft of the missing piece.
3. **A weekly health summary** highlighting devops drift the per-PR
   detector missed.
4. **Pre-release readiness check** when tagging a major version.
5. **Deploy-time review** flagging risky diffs before production.
6. **Post-deploy signal integration** correlating production errors
   with the diff that introduced them.

A solo dev consuming this should feel like they have a platform team
on call — not because the platform is full-featured, but because the
guardrails get tighter as their projects get more important, without
the dev having to remember to add them.

## What this is NOT

To prevent scope creep, explicit non-goals:

- **Not a SaaS replacement.** Datadog, Sentry, PagerDuty are still the
  right tools for production observability and incident management.
  This system *integrates* with them; it does not replace them.
- **Not a single-vendor wrapper.** Building "yet another Claude PR
  reviewer" is uninteresting. Composability is the point.
- **Not a venture-scale product** (not yet, anyway). Personal-tooling-
  in-public-repo is the current shape. Whether it productizes is
  deferred (see OPEN_QUESTIONS).
- **Not a code-completion tool.** This is the safety layer, not the
  generation layer.
- **Not language-locked.** The patterns it detects are mostly
  language-agnostic; specialists for specific stacks are plugins,
  not core.

## Philosophical posture

The user is not building this *to* productize it. The user is building
this because they need it, and because the act of building it teaches
them what good AI-agential devops looks like. If it ends up valuable to
others, that's a downstream decision. The forcing function is fitness
for purpose on `loganrooks/*`, not market validation.

This means: when in doubt, build for the user's actual repos. Generality
emerges from solving real problems, not from designing for hypothetical
ones.
