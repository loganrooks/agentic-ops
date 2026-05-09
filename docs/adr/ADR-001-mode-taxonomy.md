# ADR-001: Mode taxonomy — seven modes spanning diff, survey, and audit

Status: accepted
Date: 2026-05-08

## Context

The dispatcher in `.github/workflows/review.yml` currently exposes five
diff-scoped review modes — `review`, `quick`, `deep`, `gates`, `opus` —
selected by the first line of the triggering `@claude` comment and
gated against a per-repo `enabled_modes` JSON array. Each mode encodes
a different attention budget: `quick` reads at most 5 files, `review`
at most 15, `gates` only files matching configured matchers, `opus`
at most 3 with explicit-targeting required, and `deep` is uncapped.

Two pressures have made this taxonomy insufficient.

The first pressure is large diffs. CBM PR #1 (the H1 closeout) is 353
files, ~52K additions, 311 deletions. The `review` 15-file cap cannot
read this PR attentively; raising the cap dilutes attention without
giving the model a way to organize what it has read. `deep` removes
the cap but does not change the prompt structure — the model still
treats the diff as a flat file list rather than a layered structure
to navigate. Neither is right for a PR whose surface is large enough
that *spatial decomposition* is itself the reviewing strategy.

The second pressure is questions that do not map to a diff. Repo-level
questions like "are we organized to proceed in Phase B?" or "where is
our worst tech debt?" or "are we honoring our AGENTS.md commitments?"
are answered by reading the codebase as a whole against a lens. There
is no PR to trigger from; the right surface is the repo at a commit,
the right entry point is an issue comment, and the right output is a
structured assessment, not a PR review.

The taxonomy must compose with the existing per-repo override model
(`enabled_modes` JSON array — see `.github/workflows/review.yml`
lines 41–48) so each consumer chooses which modes are live. It must
also keep explicit triggers — modes selected by literal first-line
phrase, validated against the consumer's allowlist, with a clear
error when the trigger is rejected.

Related open questions: OQ-2 (substrate), OQ-5 (deterministic
pre-filter vs. LLM-driven dispatch), OQ-7 (severity scheme). This
ADR resolves none of them; it sets up the surface those questions
will eventually answer against. ADR-002 (parallelism architecture)
addresses how `survey` scales when the L1 single-agent path binds
on attention budget.

## Decision

Adopt a seven-mode taxonomy.

The five existing diff-scoped modes are kept as-is:

- `review` — focused pass on the PR diff, ≤15 files, optional priority paths.
- `quick` — AI-failure-mode scan, ≤5 files, one short comment.
- `deep` — uncapped pass when depth is wanted.
- `gates` — review only files matching configured `gates_paths`.
- `opus` — targeted Opus pass, ≤3 files, explicit targeting required.

Two new modes are added.

`survey` — spatial-decomposition review for large PRs (default
trigger threshold: >50 files or >5K changed lines, configurable
per-repo). The prompt structure is four phases: (1) build a zone map
from the diff — group changed files into logical zones using path
prefixes, module structure, and AGENTS.md framing; (2) per-zone deep
read — for each zone, read the most representative changed files and
note what the zone is doing; (3) cross-zone integrity — check
invariants that span zones (vocabulary alignment between reader and
writer, contract drift between caller and callee, ADR contradictions);
(4) synthesis — produce a layered review comment (zone-level summary
first, then per-zone findings, then cross-zone findings). The L1
implementation is single-agent: one Claude invocation walks all four
phases. ADR-002 (parallelism architecture) covers the L3 matrix
fan-out variant where each zone gets its own agent and a synthesis
job composes them; that is added later if and only if the L1
attention budget binds in practice.

`audit` — whole-codebase review against a question or lens. NOT
diff-scoped. The trigger is `@claude audit <lens-or-question>`. A
built-in lens registry covers the common cases:

- `audit:agential-dx` — workspace organization for AI contributors
  (CLAUDE.md, AGENTS.md, ADR coverage, runbook presence,
  context-file freshness).
- `audit:tech-debt` — refactor candidates by signal density
  (TODO/FIXME concentration, files exceeding size heuristics,
  modules with high churn, duplicated logic).
- `audit:forward-compat` — readiness for the next phase against
  ROADMAP.md (what's needed for Phase M2 that doesn't exist yet,
  what's brittle that the next phase will exacerbate).
- `audit:discipline` — AGENTS.md commitment violations (places the
  code drifted from its stated commitments).

Plus free-form: `@claude audit <free-form question>` constructs an
ad-hoc lens from the question and proceeds. The free-form path is
more variance-prone than a registered lens but is necessary because
the registry will always lag actual needs.

Audit must trigger on issue comments, not only PR comments. The
existing `if:` clause in `.github/workflows/review.yml` (lines
107–111) currently requires `github.event.issue.pull_request != null`
— that has to widen for `audit` to fire on plain issues. The widening
is gated behind a mode check so non-`audit` modes still require a PR.

Both new modes compose with `enabled_modes`: a consumer that does
not list `survey` or `audit` rejects the trigger at dispatch with the
existing explanatory error path. Consumers opt in per repo as they
need the mode, in line with the evolutionary-architecture commitment
in `VISION.md` (commitment 4).

## Alternatives considered

**A separate `review-large` mode without spatial decomposition.**
Rejected: this would be `review` with a higher cap and the same
flat-diff prompt. The attention-dilution problem is structural, not
numeric — a 15-file cap that keeps focus becomes a 60-file cap that
does not. Spatial decomposition (zone map plus per-zone reads) is the
mechanism that lets the model handle a large surface without
dilution. Without it, "review-large" is a new name for a known
failure mode.

**Audit as a flag on existing review modes (`@claude review --audit
<lens>`).** Rejected: whole-codebase navigation is materially
different from diff review. Prompt structure differs (no diff anchor;
lens drives reading order), file-budget caps differ (audit needs to
read structurally important files even when unchanged), output format
differs (structured assessment vs. PR comment), and trigger surface
differs (issue comments, not just PR comments). Encoding that as a
flag would force the prompt to branch sharply on the flag and obscure
which budget applies. Modes are the right unit of separation.

**A single "smart" mode that auto-selects based on diff size and
comment text.** Rejected on debuggability grounds. Explicit triggers
are predictable: `@claude survey` selects `survey`, full stop.
Auto-selection introduces a wrong-mode-picked-silently failure mode
that is hard to notice and hard to fix without instrumenting
selection rationale. Reviewers also lose the ability to force a
smaller mode on a large PR (e.g. `quick` on a 200-file mostly-
generated PR). This aligns with OQ-5's conservative leaning:
deterministic dispatch for high-stakes routing, LLM-driven only where
the deterministic layer's cost outweighs its value. Auto-selection
can return later as a *suggestion* layer on top of explicit modes;
that is out of scope here.

## Consequences

**Positive.**

- Clear taxonomy with per-mode budgets makes cost predictable. A
  caller who enables `quick`, `review`, `deep`, `survey`, and
  `audit` knows which modes are cheap, which are bounded, and which
  are uncapped.
- The lens registry is an extension point that is additive by
  construction. Adding `audit:security-posture` later does not
  modify any existing lens; it just registers a new key. Lenses are
  the natural granularity for the kind of repo-level inquiry
  consumers actually want.
- Explicit triggers stay debuggable. The existing dispatcher's
  pattern in `.github/workflows/review.yml` (lines 176–193) extends
  cleanly to two more cases — same exact-or-trailing-whitespace
  match, same `enabled_modes` validation, same explanatory error.
- `survey` gives CBM PR #1 (and any future H-closeout-sized PR) a
  mode that can read it attentively. Without `survey`, the substrate
  effectively cannot review its own author's largest PRs.
- `audit` opens lifecycle stages beyond per-PR review (Phase M4
  health audit, Phase L1 prod-readiness checklist) without needing
  a separate workflow surface. The same dispatcher serves all of
  them; only the lens varies.

**Negative.**

- Two more modes mean two more sets of prompts to maintain, two
  more rows in the dispatcher case statement, and two more entries
  in per-repo override docs. The maintenance cost is real and
  scales linearly with mode count.
- Audit on issue-comment trigger requires widening the workflow's
  `if:` clause, which is the central trusted-actor gate. The
  widening must preserve the existing trusted-actor check
  (OWNER/MEMBER/COLLABORATOR) and must not allow non-`audit` modes
  to fire on plain issues.
- `survey`'s L1 single-agent path may bind on attention budget for
  the largest diffs. ADR-002 covers the L3 fan-out path; the cost
  there is matrix-job overhead and synthesis complexity, taken on
  only when measured need justifies it.
- Free-form audit (`@claude audit <question>`) is more
  variance-prone than registered lenses. Output quality will
  depend on question framing. Documenting good question shapes is
  a follow-up.

**Neutral.**

- The lens registry will grow over time as consumer repos surface
  new questions. Some lenses will be repo-specific (a lens that
  makes sense for `arxiv-sanity-mcp` may be noise for
  `prix-guesser`); the override model handles this — repos enable
  the lenses they want via their `enabled_modes` extension.
- The taxonomy may eventually compress (two modes collapse, or a
  third decomposition mode emerges between `survey` and `audit`).
  ADRs are not edited; a future ADR supersedes this if so.
