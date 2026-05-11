# ADR-002: Parallelism architecture — L1 baseline, skip L2, L3 via matrix fan-out

Status: accepted; partially superseded by ADR-008 (re: L3 routing — threshold-based dispatch withdrawn in favor of explicit triggers; L1→L3 ladder and L2 rejection remain in force)
Date: 2026-05-08

## Context

The current PR review workflow at [`.github/workflows/review.yml`](../../.github/workflows/review.yml)
is a single `anthropics/claude-code-action` invocation in one GitHub
Actions job. One agent reads the diff, runs through sequential phases
in a structured prompt, and posts one comment via the wrapper script.
This works for typical PRs (≤50 files, ≤5K added lines) and is the
substrate that Phase S2 of the [ROADMAP](../../ROADMAP.md) extracted.

Two pressures push beyond it:

1. **Large PRs dilute attention.** CBM PR #1 was 353 files. Even with
   1M-context Sonnet, a single agent cannot maintain uniform scrutiny
   across that surface — the prompt's "read at most 15 files" budget
   exists precisely because attention does not scale linearly with
   context window size.
2. **ROADMAP §M2 commits to multi-specialist review.** Specialists
   (security, ai-failure-modes, doc-freshness) plus an Opus synthesizer
   only make sense if they can run independently. M2 explicitly names
   "GitHub Actions matrix fan-out" as the chosen mechanism; this ADR
   ratifies that commitment and explains why the alternative was rejected.

The substrate question is also tracked in [OQ-2](../../OPEN_QUESTIONS.md)
("Substrate beyond claude-code-action") with current leaning
"claude-code-action with matrix-job fan-out." This ADR resolves the
parallelism shape within that substrate; OQ-2 itself remains open until
M2 lands and we see whether the matrix overhead is acceptable in practice.

We name three concrete levels of parallelism so future contributors do
not have to re-derive the taxonomy:

- **L1** — single agent in one GHA job. A structured prompt sequences
  phases (read AGENTS.md, scan diff, draft findings, post comment).
  The current `review.yml` is L1.
- **L2** — `Task()`-spawned sub-agents within one GHA job, using
  claude-code-action's sub-agent capability. Sub-agents share the
  parent's runner, env, and `--allowedTools` allowlist.
- **L3** — GHA matrix fan-out: one job per work unit, joined by a
  downstream synthesis job. State flows through `needs.X.outputs.Y`
  for small values and `actions/upload-artifact` /
  `actions/download-artifact` for larger payloads (zone JSON,
  per-specialist findings).

The decision is which of these to invest in next.

## Decision

Adopt an **L1 → L3 ladder. Skip L2.**

L1 remains the baseline — for typical PRs it is the right shape and the
~30s GHA-job overhead per matrix entry is dead weight. L3 activates
empirically for surfaces where L1's attention budget binds: survey mode
on large PRs (provisional threshold `survey_l3_threshold: 100` files)
and audit mode where lens-per-job parallelism beats sequential coverage.
Routing is per-input and threshold-based; below the threshold the
workflow stays at L1. The threshold is calibrated against existing
CodeRabbit / Codex findings on representative PRs before L3 is enabled
in production for any given mode — the choice is empirical, not a priori.

> **Note (2026-05-11, partial supersession by ADR-008):** The
> threshold-based routing described in this section (`survey_l3_threshold`
> and "routing is per-input and threshold-based") is **withdrawn** by
> [ADR-008](ADR-008-l3-mode-variants.md) Decision §1. L3 dispatch is
> now explicit-trigger only (`@claude survey-matrix`, etc.), not
> automatic. The L1→L3 ladder and the rejection of L2 (below) remain
> in force; only the routing mechanism is replaced.

L2 is rejected for the first iteration of multi-agent review.

## Alternatives considered

### L2 — Task()-spawned sub-agents within one GHA job

Tempting because in-process child sessions skip the per-job overhead and
because claude-code-action already exposes a `Task` tool. Rejected for
three blockers, each independently sufficient:

1. **Sub-agent permission inheritance is broken upstream.**
   anthropics/claude-code-action issues
   [#22665](https://github.com/anthropics/claude-code-action/issues/22665),
   [#14714](https://github.com/anthropics/claude-code-action/issues/14714),
   and [#18950](https://github.com/anthropics/claude-code-action/issues/18950)
   document cases where a sub-agent either inherits the parent's full
   `--allowedTools` allowlist (sub-agent can call tools its role does
   not need, widening blast radius) or inherits nothing usable (sub-agent
   cannot complete its assigned work and silently no-ops). The behavior
   is not consistent across action versions; what works on one minor
   version may regress on the next. Our security posture (see
   [VISION.md §5 "Defense in depth"](../../VISION.md)) depends on the
   allowlist being a tight, predictable contract. A substrate where
   that contract drifts under the agent is not one we can ship on.

2. **Parallelization of `Task()` calls is undocumented.** The action's
   docs do not specify whether sub-agents spawned by `Task()` run
   sequentially, in parallel, or with some scheduler-decided concurrency
   cap. They do not expose a knob to control it. Empirical behavior may
   match expectations on one version and diverge on the next. We would
   be building cost and latency models on undocumented behavior, with
   no commitment from upstream that the behavior is stable.

3. **Cost multiplies per sub-agent without per-agent observability.**
   Each sub-agent consumes its own context window. claude-code-action's
   logs do not surface per-sub-agent token attribution; the run summary
   reports aggregate usage. Cost forecasting against the plan-auth ceiling
   ([VISION.md §3 "Plan-auth-friendly"](../../VISION.md)) becomes blind
   in a way that is hard to recover from after the fact.

### L2 with custom `.claude/agents/<name>.md` definitions per role

A mitigation for blocker 1: each sub-agent role gets its own narrow
allowlist via a per-agent definition file, sidestepping inheritance
ambiguity. Rejected: (a) the underlying inheritance bug is upstream
behavior, not a user-fixable configuration — issues #22665 / #14714 /
#18950 describe inconsistencies that per-agent definitions do not fully
constrain; (b) it adds a new layer of definition files to maintain
without resolving blockers 2 and 3. The complexity does not buy enough
over L3 to justify itself for a first iteration.

### L1-only forever

The minimal-change option. Rejected: large PRs (CBM PR #1 at 353 files
is the standing existence proof) genuinely need spatial decomposition.
Even a 1M-context Sonnet does not maintain uniform attention across
50K+ added lines; the practical budget is much smaller than the context
window suggests. M2's specialist pattern also requires independent
reviewer perspectives, which an L1 single-pass cannot provide.

### L3 always, no L1 path

The maximalist option. Rejected: ~30s per-matrix-job startup plus a
zone-mapping preamble step makes L3 wasteful on the typical PR shape
(small to medium diff, no need for spatial split, no benefit from
multiple lenses). L1 is correct for the common case and stays the
default.

## Consequences

### Positive

- Aligns with [ROADMAP §M2](../../ROADMAP.md), which committed to
  matrix fan-out as the specialist-orchestration mechanism. This ADR
  formalizes that commitment with rationale rather than leaving it
  implicit in the roadmap.
- Avoids the three documented L2 blockers above. Future contributors
  who notice "wait, couldn't we just use `Task()`?" have specific
  issue numbers (#22665, #14714, #18950) and specific failure modes
  (allowlist drift, undocumented concurrency, opaque per-agent cost)
  to evaluate against rather than re-discovering them.
- Per-matrix-job cost is the same as one claude-code-action invocation
  — predictable, with a clear ceiling under plan auth.
- Failure semantics are first-class GHA primitives: `fail-fast: false`
  lets specialists fail independently; per-job `timeout-minutes` caps
  runaway agents; partial-success synthesis is a normal join condition,
  not a custom recovery path inside one agent's prompt.
- Logs and artifacts are per-job by default, so observability comes for
  free — each specialist's run is independently inspectable in the
  Actions UI without needing structured logging inside a parent agent.

### Negative

- ~30s overhead per matrix job (checkout, claude-code-action setup,
  authentication). On a 5-job specialist matrix that is ~2.5 minutes of
  pure overhead before any reviewing happens. L1 remains the default
  precisely to avoid paying this on the common case.
- More state-passing complexity than L2 would have had: zone definitions
  serialize as JSON between the dispatcher job and matrix entries; per-
  specialist findings upload as artifacts and download into the
  synthesis job; the synthesis job needs explicit `needs:` wiring. This
  is more YAML and more failure surface than an in-process `Task()` call
  graph would have been. We accept it because the failure modes are
  GHA-native and documented.
- Future contributors may be tempted to reach for L2 again because the
  in-process model looks simpler. This ADR exists in part to short-
  circuit that — the bug references are explicit so the temptation can
  be resolved by reading rather than re-implementing.

### Neutral

- L2 may become viable if upstream fixes the inheritance bug. If
  anthropics/claude-code-action #22665, #14714, and #18950 all resolve
  with documented, stable sub-agent permission semantics — and the
  action also documents `Task()` parallelism behavior with a concurrency
  knob — this ADR should be revisited. Until then, defer.
- The L1/L3 split means modes can migrate independently as the empirical
  gate clears. `review` mode may stay L1 indefinitely while `survey` and
  `audit` move to L3; this is a feature of the design, not a bug.
- The threshold values (`survey_l3_threshold: 100`, etc.) are starting
  points, not fixed. They tune as M2 produces real comparison data
  against CodeRabbit/Codex baselines.
