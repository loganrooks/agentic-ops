# Phase P6 — Audit mode L3 (matrix fan-out per lens)

**Goal:** Refactor `audit` mode into a 3-job pattern mirroring P5: lens-plan → matrix-per-lens → opus synthesis. Synthesis uses Opus (per ROADMAP M2's "Opus synthesizer" commitment); matrix uses Sonnet for per-lens runs.

**Status:** pending (CONDITIONAL on EMPIRICAL-GATE decision OR explicit user enable; may be `skipped`)

**Branch:** `feat/p6-audit-l3`

## Phase entry preconditions

- EMPIRICAL-GATE.md says L3 needed for audit (or user explicitly enables)
- CHECKPOINT-P5 exists (or P5 was `skipped` per gate)

## Phase exit postconditions

- `review.yml` has 3-job structure for audit mode
- Lens-plan job emits JSON array of {lens-id, lens-prompt}
- Matrix runs each lens with claude-sonnet-4-6
- Synthesis uses claude-opus-4-7 for cross-lens reasoning
- CI green, **CodeRabbit reviewed + conversations resolved**, PR merged after maintainer signal, v1 tag bumped

## Architecture

Mirrors P5's 3-job structure but the matrix is over `lenses` instead of `zones`:

| Job | Purpose | Model |
|---|---|---|
| `audit-lens-plan` | Resolve audit_target → list of {lens-id, lens-prompt} | claude-sonnet-4-6 |
| `audit-lens-review` (matrix) | One matrix entry per lens; reads codebase against the lens prompt | claude-sonnet-4-6 |
| `audit-synthesis` | Cross-lens reasoning, dedup vs CodeRabbit/Codex, post via wrapper | claude-opus-4-7 |

Synthesis runs on Opus because cross-lens reasoning (e.g., "tech-debt findings cluster in the same module that forward-compat flags as a Phase B blocker") needs more than per-lens scanning. Matrix uses Sonnet for cost.

## Tasks

Structurally similar to P5 (T1..T12). Differences from P5:
- Matrix is over `lenses` not `zones`
- Synthesis uses opus-4-7 instead of sonnet-4-6
- Lens-plan resolves audit_target dispatch (built-in lens-id vs free-form)

### P6-T1 — Design lens-plan output schema

- JSON contract: array of `{lens-id, lens-prompt, focus-paths?}`
- Built-in ids resolve from ADR-001 registry; free-form `audit_target` yields one synthetic entry
- Cap matrix size (e.g., max 4 lenses) and cross-link schema in ADR-002

### P6-T2 — Refactor jobs structure (mirror P5)

- Split monolithic audit job into `audit-lens-plan`, `audit-lens-review`, `audit-synthesis`
- Wire `needs:` and matrix outputs the same way P5 wires zones
- Reuse P5's artifact-passing pattern; keep existing dispatch and mode guards unchanged

### P6-T3 — Implement lens-plan job

- Run claude-sonnet-4-6 with a prompt that resolves audit_target → lens list
- Emit JSON via `outputs.lenses`; validate shape; fail fast on empty/invalid output
- Inline lens registry definitions so the job is self-contained

### P6-T4 — Implement matrix lens-review job

- `strategy.matrix.lens` reads from `audit-lens-plan` output
- Each entry runs claude-sonnet-4-6 with that lens's prompt
- Per-lens findings written to artifact named with the lens-id
- `fail-fast: false`; surface per-lens token/cost in the job summary

### P6-T5 — Implement Opus synthesis job

- Download all per-lens artifacts; feed to claude-opus-4-7
- Cross-lens dedup (same hunk across lenses) and cross-source dedup vs CodeRabbit/Codex
- Apply ADR-005 multi-comment split when output exceeds threshold
- Post via the existing `gh pr comment` wrapper

### P6-T6 — Update prompt templates for per-lens scoping

- Each lens prompt bounds its scope; cross-cutting findings deferred to synthesis
- Keep ADR-001 lens identities; do not redefine them
- Version prompts so we can A/B against L1; store under `prompts/audit/<lens-id>.md`

### P6-T7 — Synthesis prompt for cross-lens reasoning

- Dedicated synthesis prompt distinct from per-lens prompts
- Instruct Opus to surface clusters, contradictions, and priority across lenses
- Dedup directive against CodeRabbit/Codex comments already on the PR
- Output conforms to ADR-005; include a token-budget hint

### P6-T8 — Update audit dispatch parsing

- `audit:tech-debt` → single-lens matrix (built-in resolution)
- `audit` (bare) → all lenses enabled for the repo via `enabled_modes`
- `audit:<free-form>` → single synthetic lens; plan job generates the prompt
- Preserve label/slash-command compatibility from P3; document grammar in ADR-001

### P6-T9 — Empirical metrics capture

- Per-lens wall-clock, token usage, finding count in job summary
- Synthesis metrics: dedup ratio, comments posted, cross-lens cluster count
- Append a row to the EMPIRICAL-GATE log; flag if cost >3x P3 L1 baseline

### P6-T10 — Local dry-run + CI smoke

- Add a workflow_dispatch input that prints the matrix without invoking Claude
- Smoke test on a fixture PR with deliberate findings across 2+ lenses
- Exercise the multi-comment split path; capture PR-thread screenshots

### P6-T11 — Docs, ADR updates, CodeRabbit pass

- Update README's mode table to show audit as L3
- Cross-reference ADR-002 (parallelism) and ADR-005 (output format)
- Run CodeRabbit; resolve every conversation; address Codex review if present

### P6-T12 — Tag, checkpoint, end-to-end validate

- Bump v1 tag (backward-compatible feature for callers)
- Write CHECKPOINT-P6 with model versions, costs, and metric deltas
- Run `@claude audit:tech-debt` on CBM main; record numbers for any L3-vs-L1 retrospective

## Phase total estimate

4-6 hrs, ~1-2 sessions (smaller than P5 because the architecture is established by P5).

## End-to-end validation

After P6 merges, re-run `@claude audit:tech-debt` on CBM main and verify the 3-job structure activates, lens-plan produces sensible matrix entries, synthesis posts a single (or multi-comment) review.

## References

- ADR-001 — Mode taxonomy (lens registry definitions)
- ADR-002 — Parallelism architecture
- ADR-005 — Audit output format (multi-comment split spec)
- `phases/EMPIRICAL-GATE.md` — gates this phase
- `phases/P3-audit-mode-l1.md` — the L1 baseline being refactored
- `phases/P5-survey-mode-l3.md` — architectural sibling (jobs structure pattern)
