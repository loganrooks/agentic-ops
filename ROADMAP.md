# Roadmap

This is a living document. Phases are sequenced; sequencing may shift as
we learn from the consuming repos.

## Short-term (next 1–2 weeks)

**Goal:** validate the substrate on one repo, with security holes closed.

### Phase S1 — Land security hardening upstream

In `loganrooks/codebase-mapper`, merge PR #5 (`fix/claude-review-allowed-tools`)
which:
- Replaces broad `Bash(gh pr comment:*)` allowlist with a wrapper script
- Wrapper takes integer PR number + reads body from stdin only (refuses
  `--body-file <path>` to close the Comment-and-Control attack class)
- Updates the prompt to instruct Claude to pipe via `<<'EOF'` (quoted
  heredoc, no shell expansion)

Why first: the centralized version cannot be born vulnerable. PR #5 is
the security baseline.

### Phase S2 — Extract centralized reusable workflow

Move the post-fix workflow into `agentic-ops/.github/workflows/review.yml`
exposing `on: workflow_call` with parameterized inputs:
- `focus_paths` (per-repo contract surfaces)
- `agents_md_path` (where the AGENTS.md lives)
- Mode discipline preserved: review / quick / deep / gates / opus

Central owns: mode dispatcher, prompts, allowedTools, wrapper script,
sanitization, trusted-actor gate.

Per-repo overlays own: contract surfaces, mode preferences, repo-specific
prompt fragments.

### Phase S3 — Migrate codebase-mapper to consume centralized version

Replace CBM's `claude-review.yml` with a ~15-line caller:
```yaml
uses: loganrooks/agentic-ops/.github/workflows/review.yml@v1
```

Validate: trigger phrases work, comments post correctly, security wrapper
does its job, focus paths route correctly.

**Phase end-state:** one repo (CBM) consuming a centralized PR review
system. Working proof of substrate.

---

## Medium-term (next 1–3 months)

**Goal:** prove the architecture on multiple repos and add the first
capability beyond PR review.

### Phase M1 — Onboard remaining repos

Add `agentic-ops` consumer stubs to (the named internal-consumer
set per [ADR-009](docs/adr/ADR-009-consumer-cap-relaxation.md)
which partially supersedes ADR-006 §2):
- `loganrooks/prix-guesser`
- `loganrooks/arxiv-sanity-mcp`
- `loganrooks/f1-modeling`
- `loganrooks/epistemic-agency`
- `loganrooks/scholardoc`
- `loganrooks/vigil` (added per ADR-009)
- `loganrooks/agentic-ops` itself — self-consumer pattern, added
  per ADR-009; kernel reusable workflow at
  `.github/workflows/review.yml` is consumed by a distinct caller
  stub at `.github/workflows/claude-review.yml` via `@v1`

Each gets a thin overlay naming its contract surfaces. Surfaces vary
significantly across these repos (CLI, MCP server, data-sci notebook,
philosophy reading tool, doc workflow, monitoring substrate,
review-substrate self-consumer), which is the point — the
overlay model has to handle this divergence.

### Phase M2 — Reviewer-types experiment

Validate the multi-specialist + Opus synthesizer pattern, on CBM first.
Initial specialists:
- **security** — auth, secrets, injection, crypto
- **ai-failure-modes** — hallucinated refs, silent fallbacks, speculative
  scaffolding, overclaim language
- **doc-freshness** — stale docstrings, READMEs that contradict code,
  ADR drift

Implementation: GitHub Actions matrix fan-out. Each specialist runs in
its own job; synthesis job depends on all and runs Opus to dedup +
synthesize. Trade-off: ~30s per matrix job overhead vs. in-process child
sessions. Acceptable at our volume.

Decision point at end: is reviewer-types better than single-pass? If not,
revert to single-pass and don't pay the matrix overhead.

### Phase M3 — Drift detection specialist

Fires on every PR. Detects when introduced patterns mean the existing
devops setup is incomplete:
- New `Dockerfile` → suggest container build workflow
- New `package.json` / `requirements.txt` / `Cargo.toml` → suggest CI
  language workflow
- New database driver in deps → suggest backup + migration workflows
- New deploy workflow → suggest error monitoring + status page
- First `auth/`, `crypto/`, or payment library → escalate security review

Output: comment with drafted file (soft mode), or auto-PR with the file
(hard mode, opt-in per repo).

### Phase M4 — Scheduled health audit

Weekly cron generates a "devops health" issue per repo. Catches drift
that wasn't tied to a specific PR (stale deps, README untouched in 6
months, missing CODEOWNERS, etc.).

**Phase end-state:** the centralized system serves 8 internal
repos (the ADR-009 named-consumer set), has 3+ specialists, runs
drift detection, generates weekly health reports.
Architecture (orchestrator + specialists + registry + per-repo overlays)
is validated.

Decision point: is this clearly working well? Or are there friction
points to fix before expanding to lifecycle stages beyond CI?

---

## Long-term (6+ months, exploratory)

**Goal:** lifecycle-spanning, multi-vendor, potentially public.

### Phase L1 — Prod-readiness checklist specialist

Fires on release events (`release` tag push). Audits whether the repo
is ready for what it's about to become. Production deploy? Need error
monitoring + status page + rollback plan + on-call setup.

### Phase L2 — Deploy-time review

Fires on deploy events (varies by deploy substrate). Analyzes diff vs
production for risky patterns: schema changes without backwards-compat
shims, removed feature flags that callers still reference, breaking
API changes, new required env vars not yet provisioned in prod.

### Phase L3 — Production observability integration

The first thing that breaks the CI substrate. Reads from Sentry, Datadog,
PagerDuty. Surfaces post-deploy signals back into the review system:

> "Your last deploy increased error rate 30%. Diff that caused it: PR #N.
> Specific change suspected: line X of file Y."

Different substrates per consumer (a CLI doesn't have Sentry; a SaaS does).
Plugin per integration target.

### Phase L4 — Multi-vendor expansion

Codex App findings as input to the synthesizer (cheap, easy — `gh pr view
--json reviews` and feed into Opus). OpenAI specialists via OpenCode
(harder — requires API auth, only worthwhile if Codex App alone isn't
enough). Don't expand vendor surface unless the value is clear.

### Phase L5 — Software-type awareness

Different scaffolding for game vs SaaS vs static site vs ML. Likely
emerges naturally as consumer repos diverge — `prix-guesser` (browser
game) and `arxiv-sanity-mcp` (MCP server) need different specialists.

### Phase L6 — Plugin API

For domain-specific specialists: game dev (asset pipelines, multiplayer
state), ML (data leakage, train/eval split, reproducibility), frontend
(a11y, bundle size, design system tokens), mobile (iOS/Android
divergence). Defer until specialists multiply enough that an API is
justified — premature plugin frameworks are speculative scaffolding.

### Phase L7 — Public positioning decision

Stay personal-tooling-in-public-repo, or formalize as an open-source
product with maintenance commitment. The technology doesn't differ
much; the maintenance commitment is the actual fork in the road.

See [OPEN_QUESTIONS.md](./OPEN_QUESTIONS.md) for the criteria.

---

## What's NOT on the roadmap

To stay disciplined, explicit non-goals:

- **Replacing CodeRabbit.** They auto-review on PR open with a different
  pattern-matching focus. We compose with them, not against them.
- **Replacing Sentry / Datadog / PagerDuty.** We integrate with these in
  L3; we don't build observability infrastructure ourselves.
- **Building a TUI / desktop app.** This is GitHub Actions + Markdown
  config + scheduled jobs. No client-side surface area.
- **Selling this.** Path L7 is about open-source positioning, not
  commercialization. The user does not have a thesis about a sustainable
  business model around this.

---

## Sequencing principles

1. **Security first.** Phase S1 before any extraction.
2. **Validate before propagating.** S3 (CBM migration) before M1
   (other repos).
3. **One unfamiliar thing at a time.** M2 (specialists) and M3 (drift)
   are independent; introduce them sequentially.
4. **Lifecycle expansion only after CI mastery.** L1+ doesn't start
   until M-phase has been stable for at least 4 weeks.
5. **Public positioning is the last decision, not the first.** L7
   waits until we know what we have.
