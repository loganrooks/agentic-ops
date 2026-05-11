# Phase P6 — Audit mode L3 (matrix fan-out)

> **Updated 2026-05-11 to align with [ADR-008](../../docs/adr/ADR-008-l3-mode-variants.md):** Original plan refactored bare `@claude audit` into a single matrix-per-lens shape with `audit:tech-debt` for a single-lens degenerate matrix. ADR-008 Decision §2/§3 splits audit L3 into two distinct modes: `audit-matrix` (depth fan-out — one lens decomposed into N sub-questions) and `audit-all` (breadth fan-out — all four built-in lenses run in parallel). Bare `@claude audit` is unchanged (it remains the L1 audit mode). Trigger contract sections rewritten; matrix mechanism (planner → matrix → synthesizer) is reusable but the matrix axis differs between the two new modes.

**Goal:** Add two new modes implementing audit L3:
- **`audit-matrix`** — 3-job pattern: sub-question-plan → matrix-per-sub-question → synthesis. Trigger: `@claude audit-matrix:<lens>` or `@claude audit-matrix <free-form>`. Lens (or free-form target) is decomposed by the plan job into N sub-questions (target 3–6); each matrix entry handles one sub-question.
- **`audit-all`** — 3-job pattern: lens-list-plan → matrix-per-built-in-lens → synthesis. Trigger: `@claude audit-all`. Plan job enumerates the four built-in lenses from ADR-001's registry; each matrix entry runs one lens as L1.

Synthesis uses Opus for both modes (per ROADMAP M2's "Opus synthesizer" commitment); matrix workers use Sonnet for cost. L1 `audit` mode is unchanged.

**Status:** pending (CONDITIONAL — each L3 audit mode needs its own EMPIRICAL-GATE comparison per ADR-008's per-family gating; `audit-matrix` and `audit-all` may ship together or separately based on which comparisons clear the bar)

**Branch:** `feat/p6-audit-l3`

## Phase entry preconditions

- EMPIRICAL-GATE produces a per-mode L1-vs-L3 audit comparison that clears ADR-008's per-family improvement bar at a defensible cost ratio. `audit-matrix` needs depth-fan-out evidence (one lens with non-trivial sub-question decomposition); `audit-all` needs breadth-fan-out evidence (across-lens sweep). Each mode is gated independently.
- CHECKPOINT-P5 exists (or P5 was `skipped` per gate)

## Phase exit postconditions

- `review.yml` dispatcher handles `@claude audit-matrix[:lens|<free-form>]` and `@claude audit-all` as distinct modes; L1 `audit` mode is unchanged
- `review.yml` has separate 3-job structures for `audit-matrix` and `audit-all` (sharing the synthesizer job pattern where practical)
- `audit-matrix` plan job emits JSON array of `{sub-question-id, sub-question-prompt}`
- `audit-all` plan job emits JSON array of `{lens-id, lens-prompt}` from ADR-001 registry
- Matrix workers run claude-sonnet-4-6; synthesizer runs claude-opus-4-7 for both modes
- CI green, **CodeRabbit reviewed + conversations resolved**, PR merged after maintainer signal, v1 tag bumped

## Architecture

Two 3-job structures, sharing the planner→matrix→synthesizer shape but differing in matrix axis:

**`audit-matrix` (depth fan-out):**

| Job | Purpose | Model |
|---|---|---|
| `audit-matrix-plan` | Decompose `audit_target` (lens or free-form) into N sub-questions (target 3–6) | claude-sonnet-4-6 |
| `audit-matrix-worker` (matrix over sub-questions) | One entry per sub-question; reads codebase narrowed to that sub-question | claude-sonnet-4-6 |
| `audit-matrix-synthesis` | Reconcile sub-question findings into one lens-level report; dedup vs CodeRabbit/Codex; post via wrapper | claude-opus-4-7 |

**`audit-all` (breadth fan-out):**

| Job | Purpose | Model |
|---|---|---|
| `audit-all-plan` | Enumerate the four built-in lenses from ADR-001 registry | claude-sonnet-4-6 |
| `audit-all-worker` (matrix over lenses) | One entry per built-in lens; each worker runs essentially L1 audit for that lens | claude-sonnet-4-6 |
| `audit-all-synthesis` | Cross-lens reasoning (clusters, contradictions, priorities); group findings by lens in output; dedup vs CodeRabbit/Codex; post via wrapper | claude-opus-4-7 |

Synthesis runs on Opus for both because cross-cutting reasoning (within sub-questions of a single lens, or across all four lenses) needs more than per-worker scanning. Matrix workers use Sonnet for cost.

## Tasks

Structurally similar to P5 (T1..T12). Differences from P5:
- Matrix is over `lenses` not `zones`
- Synthesis uses opus-4-7 instead of sonnet-4-6
- Lens-plan resolves audit_target dispatch (built-in lens-id vs free-form)

### P6-T1 — Design plan-output schemas (two contracts)

- **`audit-matrix-plan` output:** JSON array of `{sub-question-id, sub-question-prompt, focus-paths?}` derived from a single lens or free-form `audit_target`. Cap matrix size (target 3–6 sub-questions; hard cap 8).
- **`audit-all-plan` output:** JSON array of `{lens-id, lens-prompt}` enumerated from ADR-001's lens registry (currently 4 entries: `agential-dx`, `tech-debt`, `forward-compat`, `discipline`). No free-form; for free-form lenses use `audit-matrix <free-form>` instead.
- Both schemas validated in their respective plan jobs; empty/malformed output fails fast.

### P6-T2 — Refactor jobs structure (two 3-job pipelines)

- Add six new jobs alongside the existing audit L1 job: `audit-matrix-plan`, `audit-matrix-worker` (matrix), `audit-matrix-synthesis`; and `audit-all-plan`, `audit-all-worker` (matrix), `audit-all-synthesis`.
- Gate each pipeline on its mode: `audit-matrix-*` jobs on `mode == audit-matrix`; `audit-all-*` jobs on `mode == audit-all`.
- Wire `needs:` and matrix outputs the same way P5 wires zones.
- Reuse P5's artifact-passing pattern; keep existing dispatch and mode guards for the L1 path unchanged.
- The two synthesizer jobs may share helper scripts but have distinct prompts (within-lens vs across-lens reasoning).

### P6-T3 — Implement plan jobs (two jobs)

- **`audit-matrix-plan`:** claude-sonnet-4-6 with a prompt that decomposes `audit_target` (built-in lens or free-form) into sub-questions. Emit JSON via `outputs.sub_questions`. **Validate each `sub-question-id` against an ASCII-slug pattern** (`^[a-z][a-z0-9-]{0,40}$`) and **enforce uniqueness** before the matrix step expands; reject the plan output and fail the job on slash, newline, dot, or duplicate ids. This prevents artifact-name collisions or path-traversal from prompt-injected planner output.
- **`audit-all-plan`:** enumerate the effective lens registry from the `audit_lens_registry` workflow input (defaults to ADR-001's four built-in lenses but is overridable per-repo). If a repo registers additional lenses, `audit-all` picks them up automatically — this preserves ADR-008 Decision §3's "additive lens registry" property. Free-form ad hoc targets are NOT enumerated; for those use `audit-matrix <free-form>` instead. Same slug-pattern + uniqueness validation as above applies to `lens-id`.

### P6-T4 — Implement matrix worker jobs (two jobs)

- **`audit-matrix-worker`:** `strategy.matrix.sub_question` reads from `audit-matrix-plan` output. Each entry runs claude-sonnet-4-6 with the sub-question's prompt narrowed by `focus-paths` if provided.
- **`audit-all-worker`:** `strategy.matrix.lens` reads from `audit-all-plan` output. Each entry runs essentially the L1 audit prompt for that lens.
- Both: per-entry findings written to artifact named with the validated entry id (slug pattern enforced upstream in the planner; double-check on consume); `fail-fast: false`; surface per-entry token/cost in job summary.
- **Worker `allowedTools` is artifact-only.** Do NOT include `post-claude-review.sh` in the worker `claude_args` allowlist. Workers may have static-analysis tools (`Bash(rg:*)`, `Bash(ruff:*)`, etc., per ADR-004 and the consumer's `extra_allowed_tools`) and must write findings to disk for the synthesizer to pick up — they must NOT post comments directly. A prompt-injected worker (TC-3) cannot publish unsynthesized findings if the wrapper isn't in its allowlist. Only the two synthesis jobs include `post-claude-review.sh` in their allowlists.

### P6-T5 — Implement Opus synthesis jobs (two jobs)

- **`audit-matrix-synthesis`:** download per-sub-question artifacts; feed to claude-opus-4-7 with a within-lens reconciliation prompt. Output is one cohesive lens-level report.
- **`audit-all-synthesis`:** download per-lens artifacts; feed to claude-opus-4-7 with a cross-lens reasoning prompt. Output is grouped by lens with cross-lens clusters surfaced.
- Both: dedup vs CodeRabbit/Codex; apply ADR-005 multi-comment split when output exceeds threshold; post via `post-claude-review.sh` (synthesis jobs are the ONLY jobs in either pipeline that have the wrapper in their allowlist; see P6-T4).
- **Synthesis must survive partial worker failures.** Use `if: always() && needs.<plan-job>.result == 'success'` on both synthesizer jobs; inspect `needs.<worker-job>.result` in the synthesis payload and note degraded mode in the output if some workers failed. Without `always()`, a single matrix worker failure cascades to skip the synthesizer and lose all completed workers' findings.

### P6-T6 — Update prompt templates per worker shape

- **Sub-question worker prompt:** for `audit-matrix-worker`. Bounds scope to one sub-question; defers cross-sub-question patterns to synthesis. Store under `prompts/audit-matrix/worker.md`.
- **Lens worker prompt:** for `audit-all-worker`. Essentially the L1 audit prompt for a single lens. Store under `prompts/audit-all/worker.md`.
- Keep ADR-001 lens identities intact; do not redefine them.
- Version prompts so we can A/B against L1.

### P6-T7 — Synthesis prompts (two, distinct shapes)

- **Within-lens synthesis prompt** (for `audit-matrix-synthesis`): reconcile sub-question findings into one lens-level report. Identify findings that span sub-questions; surface tensions where sub-questions disagree.
- **Across-lens synthesis prompt** (for `audit-all-synthesis`): cross-lens reasoning. Surface clusters (e.g., "tech-debt findings cluster in the same module that forward-compat flags as a Phase B blocker"), contradictions, and priority ranking.
- Both: dedup directive against CodeRabbit/Codex; output conforms to ADR-005; include a token-budget hint.

### P6-T8 — Add audit-matrix and audit-all dispatcher cases + widen issue-comment gate

- Dispatcher cases:
  - `@claude audit-matrix:<lens>` → `mode=audit-matrix, audit_target=<lens>`, then plan job decomposes into sub-questions
  - `@claude audit-matrix <free-form>` → `mode=audit-matrix, audit_target=<free-form>`, plan job derives sub-questions from free-form text
  - `@claude audit-all` → `mode=audit-all`, plan job enumerates effective lens registry (no audit_target)
  - Bare `@claude audit` and `@claude audit:<lens>` → unchanged (L1 `audit` mode)
- Add `audit-matrix` and `audit-all` to `enabled_modes` validation logic so consumers must opt in by listing each mode separately; the default `enabled_modes` is *not* extended (cost discipline per ADR-008 Decision §2).
- **Widen the trusted-actor `if:` clause to admit the new L3 audit triggers on non-PR issues.** The existing P3 widening (review.yml lines 132–141) only allows non-PR issue comments for bare `@claude audit`, `@claude audit `, `@claude audit:`, and `@claude audit<newline>`. Without extending it, `@claude audit-matrix:<lens>` and `@claude audit-all` posted on a plain issue (the canonical audit-on-main path) would be rejected before reaching the dispatcher. Add equivalent branches for `audit-matrix:`, `audit-matrix `, `audit-matrix<newline>`, `audit-matrix` (bare), and `audit-all` to the issue-comment-only branch of the `if:` clause.
- Do NOT edit ADR-001 or ADR-008 bodies; the mode contracts are already specified in ADR-008 Decision §2.

### P6-T9 — Empirical metrics capture

- Per-lens wall-clock, token usage, finding count in job summary
- Synthesis metrics: dedup ratio, comments posted, cross-lens cluster count
- Append a row to the EMPIRICAL-GATE log; flag if cost >3x P3 L1 baseline

### P6-T10 — Local dry-run + CI smoke

- Add a workflow_dispatch input that prints the matrix without invoking Claude
- Smoke test on a fixture PR with deliberate findings across 2+ lenses
- Exercise the multi-comment split path; capture PR-thread screenshots

### P6-T11 — Docs, ADR updates, CodeRabbit pass

- Update README's mode table: **add separate rows for `audit-matrix` and `audit-all` (each marked L3)**; leave the existing `audit` row marked L1. Bare `@claude audit` and `@claude audit:<lens>` remain L1; treating the existing row as L3 would teach users the wrong trigger for the L1 path.
- Cross-reference ADR-002 (parallelism, partial-supersession of routing), ADR-005 (output format, footer enum extension), and ADR-008 (mode contracts).
- Run CodeRabbit; resolve every conversation; address Codex review if present.

### P6-T12 — Tag, checkpoint, end-to-end validate

- Bump v1 tag (backward-compatible feature for callers)
- Write `.planning/auto-execution/checkpoints/CHECKPOINT-P6.md` (per-phase detail) with model versions, costs, metric deltas, artifacts list, CodeRabbit findings count
- Append a CHECKPOINT-P6 summary entry to `.planning/auto-execution/CHECKPOINTS.md` (aggregate index) referencing the detail file
- Run both `@claude audit-matrix:tech-debt` and `@claude audit-all` on CBM main; record numbers for the L3-vs-L1 retrospective. Also verify `@claude audit:tech-debt` (L1) still produces the same output it did pre-P6 (L1 path unchanged).

## Phase total estimate

6-10 hrs, ~2 sessions (larger than P5 because two pipelines must be implemented; the second pipeline reuses synthesis-job mechanics but has distinct planner and prompt templates).

## End-to-end validation

After P6 merges, run `@claude audit-matrix:tech-debt` on CBM main and verify the 3-job within-lens pipeline activates (sub-question plan → matrix → synthesis posts). Then run `@claude audit-all` and verify the 3-job across-lens pipeline activates (lens-list plan → matrix → synthesis groups by lens). Finally verify `@claude audit:tech-debt` (L1) is unchanged from pre-P6 behavior.

## References

- ADR-001 — Mode taxonomy (lens registry definitions)
- ADR-002 — Parallelism architecture
- ADR-005 — Audit output format (multi-comment split spec)
- `phases/EMPIRICAL-GATE.md` — gates this phase
- `phases/P3-audit-mode-l1.md` — the L1 baseline being refactored
- `phases/P5-survey-mode-l3.md` — architectural sibling (jobs structure pattern)
