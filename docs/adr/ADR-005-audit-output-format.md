# ADR-005: Audit and survey output format

Status: accepted (provisional); amended by ADR-008 (extends Mode footer enum)
Date: 2026-05-08

## Context

ADR-001 introduced an audit mode that reviews a whole codebase against
a question or lens, distinct from review mode (which scopes to a diff).
Survey mode shares the same shape: free-form, potentially large, and not
tied to specific lines.

Output volume is highly variable. A focused `audit:agential-dx` run on a
small repo may produce ~10KB of findings. A `audit:tech-debt` run on a
50K-line repo can produce 80KB+. Survey mode, when triggered on a large
PR, can balloon similarly. We need a default output target that:

1. Is **discoverable** — the user should see findings without an extra
   click. PR / issue comments are the most-engaged GitHub surface
   (notifications fire, mobile UI shows them inline).
2. Is **convention-free** — does not assume a `.planning/` directory or
   any per-repo file layout. CBM has `.planning/`; prix-guesser,
   scholardoc, and arxiv-sanity-mcp do not.
3. Survives GitHub's soft size limits — comment rendering visibly
   degrades past roughly 50KB, even though the hard cap is higher.
4. Carries enough metadata for downstream tooling. M2's weekly health
   audit and any future aggregator must be able to scrape `Mode`,
   `Lens`, `Commit SHA`, and timing fields out of historical comments
   without re-running the audit.
5. Does not lock in a severity scheme. OQ-7 defers Cloudflare-style
   `critical` / `warning` / `suggestion` semantics until M2 produces
   evidence about whether those levels carve our findings cleanly.

The output-format question is small in surface but consequential in
lock-in: once consumer repos have audit comments threaded through their
PR history, changing the shape rewrites discoverability and breaks any
scraper built against the footer.

## Decision

Audit and survey modes post their findings as **GitHub comments on the
triggering surface**, using the existing `post-claude-review.sh` wrapper.

**1. Posting target inferred from event.** If
`github.event.issue.pull_request` is non-null, the trigger is on a PR
and the comment posts to the PR. Otherwise, the trigger is on an issue
and the comment posts to that issue. Both paths use `gh pr comment`,
which GitHub accepts on issues as well as PRs (issues and PRs share a
unified number-space).

**2. Default: a single comment.** If the rendered body is at or under
roughly 50KB, post once. No prefix, no chunk markers.

**3. Multi-comment split when the body exceeds ~50KB.** The wrapper
script supports being invoked multiple times in a single job. The audit
prompt is responsible for producing chunked output; the workflow loops
over chunks and pipes each via a quoted heredoc.

Chunking algorithm:

   a. The model emits findings grouped into priority buckets. The
      working vocabulary is `Critical` / `Warning` / `Suggestion`,
      mirroring the audit prompt's existing language. This is a
      *vocabulary*, not a committed scheme — see point 5.

   b. Pack findings into chunks of ~50KB, in priority order: all
      `Critical` first, then `Warning`, then `Suggestion`. A single
      finding never spans chunks; if a finding is itself >50KB, the
      chunk holding it is allowed to exceed the soft limit rather than
      be split mid-narrative.

   c. Each chunk after the first is prefixed with `[Audit N/M]` on the
      first line, where `N` is the 1-indexed sequence and `M` is the
      total chunk count. The first chunk has no prefix (so the most
      important comment looks clean in a notification preview).
      Survey mode uses `[Survey N/M]` with the same rules.

   d. Hard cap: 5 chunks (~250KB total). If packing would require a
      sixth chunk, the workflow drops remaining findings and appends
      `[truncated; N more findings omitted]` to the last chunk's body
      before the metadata footer. Truncation prefers dropping
      `Suggestion` first, then `Warning`; `Critical` is never dropped.

**4. Always include a metadata footer.** The footer goes on the
**last** comment posted (chunk M of M, or the only comment in the
single-chunk case). It is a fenced code block at the very bottom:

```
Mode: <audit|survey> | Lens: <id-or-"free-form"> | Model: <model-id>
Files read: <n> | Directories traversed: <n>
Runtime: <seconds>s | Commit SHA: <sha> | Run: <run-url>
```

> **Note (2026-05-11, amended by ADR-008):** The `Mode:` enum is
> extended; see [ADR-008](ADR-008-l3-mode-variants.md) Decision §5.

Field semantics:

- `Mode`: literal string `audit` or `survey`.
- `Lens`: the lens identifier (e.g. `agential-dx`, `tech-debt`) for
  named lenses, or the literal string `free-form` for unnamed runs.
- `Model`: the resolved Claude model id used for the run.
- `Files read` / `Directories traversed`: counts emitted by the agent
  at the end of its session. Best-effort; `?` is acceptable if the
  agent did not report counts.
- `Runtime`: wall-clock seconds for the agent invocation, integer.
- `Commit SHA`: full 40-char SHA of `github.sha` at trigger time.
- `Run`: URL of the workflow run, for traceability back to logs.

The footer is the contract surface for M2's weekly-health aggregator.
Any future tool that reads historical audits parses these lines.

**5. Severity scheme: deferred per OQ-7.** The audit prompt suggests
`Critical` / `Warning` / `Suggestion` as a working vocabulary used by
the chunking algorithm above. This ADR does **not** commit those
labels as a formal scheme. Mode prompts are free to evolve their
severity language, and a future ADR will lock semantics once M2 has
produced evidence. Until then, the chunking algorithm tolerates any
priority labels the prompt emits as long as it can rank them.

## Alternatives considered

**Always write findings to an artifact and post a short link comment.**
Rejected. Linked artifacts add a click and reduce engagement. The
comment surface fires notifications, renders inline on mobile, and
threads naturally with reviewer discussion. Artifacts also obscure the
review from anyone who later reads the PR history. Revisit if multi-
comment splits prove noisy in practice.

**Always create a draft PR with audit findings as
`.planning/audits/<date>.md`.** Rejected. CBM has `.planning/`;
prix-guesser, scholardoc, arxiv-sanity-mcp, f1-modeling, and
epistemic-agency do not. Forcing the convention via the central
workflow imports CBM-specific layout into every consumer. The point of
the central substrate is that consumers do not need to adopt CBM's
folder shapes. A consumer that wants this can build it as an overlay.

**Inline review comments on specific lines.** Rejected. Audit findings
are usually cross-file or codebase-level — e.g. *"your AGENTS.md
commits to X but the implementation in lib/auth.py violates X"* spans
a doc and a module. Pinning that to a single line in either file
obscures the structural nature of the finding. Top-level comments
preserve narrative flow and let the model reference multiple files
within one finding.

**Multiple top-level comments split by severity (one per level).**
Rejected. Creates fragmented threads that are hard to scan together.
A single comment with `## Critical` / `## Warning` / `## Suggestion`
sections preserves coherence, and the multi-comment split (when it
fires at all) is keyed on size, not severity — readers see Critical
first because it is packed first, not because it lives in a separate
thread.

## Consequences

**Positive.**
- Simplest possible default. Works on any repo with no convention. No
  per-repo configuration to opt into the comment surface.
- Comment is the most-engaged GitHub surface — notifications fire,
  mobile renders inline, the comment lives in PR history forever.
- The metadata footer is a stable contract for M2's weekly-health
  aggregator. Future tooling can scrape audit history without
  re-running anything.
- Severity-priority chunking degrades gracefully: even a 5-chunk
  truncated audit shows the most important findings first.
- Re-uses the existing `post-claude-review.sh` wrapper. No new
  surface for prompt-injection attacks.

**Negative.**
- Long audits create comment-thread noise. A 5-chunk split on a busy
  PR adds visible weight; reviewers may scroll past Warning and
  Suggestion chunks. Mitigation: severity-priority ordering ensures
  the first chunk is always the most actionable. Readers can stop
  after the first.
- The 50KB / 5-chunk caps are guesses informed by GitHub's rendering,
  not measurement. We may discover empirically that 30KB is the real
  threshold, or that 7 chunks is fine. The thresholds are tuneable
  in the workflow without an ADR rewrite.
- The metadata footer is parser-fragile. Anything reading it depends
  on exact field names and pipe separators. Compensating: the format
  is a fenced code block (visually stable), and the field set is
  small enough to version-bump cleanly if needed.

**Neutral.**
- Status is `accepted (provisional)`. This is the first iteration.
  Revisit triggers, in priority order:
  1. Multi-comment splits become noisy. If >30% of audit runs split
     across consumer repos, the UI cost exceeds the discoverability
     benefit and we should move to artifact-with-link or hybrid.
  2. A consumer repo asks for an artifact-based path (e.g.
     `.planning/audits/<date>.md` in a draft PR). When this happens
     we add it as an opt-in overlay rather than changing the default.
  3. OQ-7's severity scheme lands. A formal severity vocabulary may
     change chunking priority order (e.g. introduces a fourth level)
     and force a footer field for severity counts.
- The decision is intentionally narrow: it specifies the output
  contract for audit and survey modes only. Review mode (diff-scoped)
  continues to use its existing single-comment behavior; this ADR
  does not retroactively reshape it.
