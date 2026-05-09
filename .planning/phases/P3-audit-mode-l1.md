# Phase P3 — Audit mode L1

**Goal:** Add `audit` mode to the dispatcher with whole-codebase navigation, lens registry (4 built-in lenses + free-form), and trigger-surface widening for issue comments (not just PR comments).

**Status:** pending

**Branch:** `feat/p3-audit-mode`

## Phase entry preconditions

- CHECKPOINT-P2 exists
- v1 tag updated to P2 result

## Phase exit postconditions

- `audit` mode in dispatcher with lens parsing (bare `@claude audit` accepted; defaults to audit:agential-dx with header note)
- Trigger if-clause widened to allow non-PR issues for audit mode
- `audit_lens_registry` input added (optional, default = 4 built-in lenses)
- audit mode-behavior block in prompt
- `post-claude-review.sh` wrapper extended (or a parallel `post-claude-review-issue.sh` introduced) to handle the `gh issue comment` path for non-PR issue triggers, with the same integer-validated argument + stdin-only body discipline. The two gh subcommands (`gh pr comment`, `gh issue comment`) are distinct; the wrapper(s) must dispatch correctly based on the event payload.
- ADR-001 (mode taxonomy) lens names verified to match the implementation (no edit; ADRs are immutable per `docs/adr/README.md` and `AGENTS.md`)
- CI green, **CodeRabbit reviewed + conversations resolved**, PR merged after maintainer signal, v1 tag bumped

## Tasks

### P3-T1 — Read existing trigger if-clause

- Open `review.yml` and locate the `if:` clause for the review job.
- Identify the line range that gates dispatch on `issue_comment` events.
- Note the current PR-only assumption that audit mode will need to relax.
- Record the insertion point so P3-T2 can produce a minimal diff.
- **Time:** 5 min

### P3-T2 — Widen trigger if-clause

- Edit `review.yml` if-clause to allow audit on non-PR issues:

  ```yaml
  if: |
    github.event_name == 'issue_comment' &&
    startsWith(github.event.comment.body, '@claude ') &&
    contains(fromJson('["OWNER","MEMBER","COLLABORATOR"]'), github.event.comment.author_association) &&
    (
      github.event.issue.pull_request != null ||
      startsWith(github.event.comment.body, '@claude audit')
    )
  ```

- Run `actionlint` on the workflow to confirm the YAML still parses.
- Confirm the widened clause still excludes non-author-associated commenters and that PR comments continue to satisfy it unchanged.
- **Postcondition:** new if-clause valid YAML; actionlint passes.
- **Time:** 5 min

### P3-T3 — Add audit_lens_registry input

- Add `audit_lens_registry` to `inputs:` per template Appendix A.9.
- Default: JSON object with 4 lenses (`agential-dx`, `tech-debt`, `forward-compat`, `discipline`) per ADR-001.
- Mark the input optional (`required: false`) and document the override pattern.
- Validate default JSON parses with `jq` in a smoke step.
- **Postcondition:** input present; default JSON parses; default has 4 keys.
- **Time:** 10 min

### P3-T4 — Add audit case to dispatcher (with target parsing)

- Edit dispatcher case statement:

  ```bash
  "@claude audit"|"@claude audit "*|"@claude audit:"*)
    mode=audit
    model=claude-sonnet-4-6
    audit_target="$(printf '%s' "$cmd" | sed -E 's/^@claude audit:?[[:space:]]*//')"
    echo "audit_target=$audit_target" >> "$GITHUB_OUTPUT"
    ;;
  ```

- Cover three trigger shapes: `@claude audit:agential-dx`, `@claude audit Are we ready?`, `@claude audit` (bare).
- Ensure `audit_target` is emitted on `$GITHUB_OUTPUT` and bare form does not crash the parser (empty target allowed).
- **Postcondition:** new case present; smoke test fixtures cover all three shapes.
- **Time:** 15 min

### P3-T5 — Update dispatcher smoke test for audit

- Update `test-dispatcher.sh` to assert audit fixtures alongside existing review/explain cases.
- Add fixtures for built-in lens, free-form question, and bare audit.
- Assert `mode=audit`, `model=claude-sonnet-4-6`, and expected `audit_target` per fixture.
- Run smoke test locally; confirm pass before committing.
- **Postcondition:** smoke test passes against the new dispatcher.
- **Time:** 10 min

### P3-T6 — Add audit mode-behavior block to prompt

- Insert audit block in prompt template per Appendix A.10 (full template at end of this doc).
- Block covers: navigation strategy, lens registry consumption, free-form lens construction, output format with metadata footer, multi-comment splitting.
- Reference `audit_lens_registry` input wiring and the trigger surface (issue OR PR comment) for posting target.
- **Postcondition:** block present; references audit_lens_registry input correctly; references trigger surface.
- **Time:** 45 min

### P3-T7 — Verify ADR-001 lens names match implementation

- Read ADR-001 (committed in P1) and confirm the documented lens names — `agential-dx`, `tech-debt`, `forward-compat`, `discipline` — match the dispatcher case statement and the audit prompt block exactly.
- **Do NOT edit ADR-001.** ADRs are immutable per `docs/adr/README.md` and the hard rules in `AGENTS.md`; they are superseded by a new ADR if a decision changes.
- If a mismatch is found and the implementation cannot be aligned to the ADR (e.g., a lens name needs to change for a substantive reason), STOP and open a separate PR that supersedes ADR-001 with a new ADR (ADR-006-...). Do not edit ADR-001 in place.
- **Postcondition:** ADR-001 lens names confirmed to match dispatcher and prompt; no edit to ADR-001.
- **Time:** 5 min

### P3-T8 — Local validation

- Run `actionlint`, `shellcheck`, and the dispatcher smoke test against the working tree.
- Re-run pre-commit hooks for workflow changes; confirm no untracked artifacts.
- **Postcondition:** local validation green; ready to push.
- **Time:** 10 min

### P3-T9 — Open PR

- Push `feat/p3-audit-mode`; open PR titled `feat(p3): add audit mode (L1, lens-based whole-codebase)`.
- PR body cites ADR-001, Appendix A.9, A.10; link CHECKPOINT-P2; add planning labels.
- **Postcondition:** PR open against `main`.
- **Time:** 10 min

### P3-T10 — Wait for CI + CodeRabbit

- Watch CI to green; let CodeRabbit complete its automated review.
- Resolve CodeRabbit conversations on substance (do not silently dismiss); re-run CI on each substantive change.
- **Postcondition:** CI green, CodeRabbit conversations resolved.
- **Time:** variable; budget 30-60 min.

### P3-T11 — Merge after maintainer signal

- Wait for explicit maintainer approval; use a squash merge consistent with prior phases.
- Confirm merge lands on `main` cleanly.
- **Postcondition:** PR merged.
- **Time:** 5 min

### P3-T12 — Bump v1 tag and write CHECKPOINT-P3

- Move floating `v1` tag to the new merge commit on `main`.
- Write `.planning/auto-execution/checkpoints/CHECKPOINT-P3.md` (per-phase detail) with merge SHA, tag SHA, artifacts list, decisions, CodeRabbit findings count, follow-ups.
- Append a CHECKPOINT-P3 summary entry to `.planning/auto-execution/CHECKPOINTS.md` (aggregate index) referencing the detail file.
- **Postcondition:** v1 points at P3 merge commit; both CHECKPOINT-P3.md detail and CHECKPOINTS.md aggregate entry exist.
- **Time:** 10 min.

## Phase total estimate

2-3 hours, 12 tasks, ~1 session.

## Audit mode-behavior prompt template

Full text inserted by P3-T6. Critical content artifact — review carefully before merge.

````text
* audit: whole-codebase review against a question or lens. A target
  is recommended but not required — bare `@claude audit` is accepted
  by the dispatcher and runs the default lens (audit:agential-dx)
  with a note in the report header explaining the implicit choice
  and suggesting explicit invocation for future runs.

  Lens parsing (orchestrator):
    - audit_target was extracted from the trigger comment by the
      dispatcher. Read it from steps.mode.outputs.audit_target.
    - If audit_target is empty (bare `@claude audit`) → use the
      default built-in lens audit:agential-dx and note the
      implicit-default in the output header.
    - Else if audit_target starts with a known lens-id (agential-dx,
      tech-debt, forward-compat, discipline) → built-in path.
    - Otherwise → free-form path; treat the entire string as the
      question.

  Workspace context:
    - For PR comment trigger: review pr-head/ (already checked out)
    - For issue comment trigger (non-PR): review main HEAD of the
      caller's repo. Workflow has already checked out main at root.

  Whole-codebase navigation strategy (CRITICAL):
    - DO NOT attempt to read every file. Even with 1M ctx, attention
      dilutes. Sample, don't enumerate.
    - PHASE 1 — Discipline map (read 3-6 files):
        AGENTS.md (or equivalent) at the path inputs.agents_md_path
        README.md (root)
        ROADMAP.md or HORIZONS.md or docs/roadmap.md (probe these)
        ADRs at .planning/decisions/ or docs/adr/ (read TITLES of
          all; read FULL TEXT of ones relevant to the lens)
        CONTRIBUTING.md if present
      Build a "discipline map": what does the repo claim about itself?
    - PHASE 2 — Lens-driven sampling (read 6-12 files):
        Use ` git ls-files ` and `gh api` to enumerate the directory
        tree. Identify load-bearing surfaces relevant to the lens.
        Sample representative files (cap: 12 across all of Phase 2).
        Goal: enough evidence to support specific findings, not
        exhaustive coverage.
    - PHASE 3 — Synthesize against the lens.
    - PHASE 4 — Post on the triggering surface.

  Built-in lenses (selected by audit_target prefix):

    audit:agential-dx
      Lens prompt: "Survey for evidence of conscious workspace
      organization for AI contributors. Indicators (NOT all required;
      multiple valid setups exist): AGENTS.md or equivalent operative-
      discipline doc; .claude/ directory with agents/skills/commands/
      settings; CONTEXT.md or onboarding doc; ADRs in a known location;
      pre-commit hooks specific to AI-authored content; authority-doc
      registry; explicit do-not-do lists. Flag absences but do not
      insist on a specific schema. Report: (a) where discipline lives,
      (b) consistency with code, (c) what an AI contributor would need
      to know to contribute correctly. Severity: critical only for
      missing operative discipline that would prevent safe contribution;
      warning for inconsistencies; suggestion for absences that would
      improve quality."

    audit:tech-debt
      Lens prompt: "Find refactor candidates: TODO/FIXME/HACK density
      and locations (sample, don't enumerate every comment); commented-
      out code blocks (intentional vs. drift); duplicated logic across
      files; speculative scaffolding (declared but unused symbols, code
      paths not exercised by any test); doc-code drift (README claims
      vs. actual behavior; ADR commitments vs. implementation);
      deprecated patterns the repo's own ADRs flag. Distinguish
      'intentional debt to be paid later' (often near a tracking
      reference) from 'accidental drift the repo doesn't know about'.
      Severity: critical for security-relevant debt, warning for
      maintenance burden, suggestion for stylistic."

    audit:forward-compat
      Lens prompt: "Read ROADMAP/HORIZONS. Identify the next phase
      explicitly named (or implied by the current phase's exit
      criteria). For that phase: does the current architecture
      support it without rework? Where will it need refactoring
      before progress is possible? Which ADRs would need revision?
      Identify pre-work that should happen NOW vs. can wait until
      the phase begins. Cite ADRs and roadmap sections by ID.
      Severity: critical for blockers (the next phase cannot start
      without this), warning for likely friction, suggestion for
      nice-to-haves."

    audit:discipline
      Lens prompt: "Read AGENTS.md and any ADRs. Enumerate the
      discipline this repo commits to (forbidden behaviors, required
      patterns, citation formats, claim registers if applicable).
      For each commitment: find code or artifacts that violate it.
      Distinguish hook-enforced vs. discipline-only commitments
      (hook-enforced violations should not exist; discipline-only
      violations are the meaningful audit surface). Output:
      violations grouped by commitment, with citation per finding.
      Severity: critical for hook-bypass evidence, warning for
      discipline-only violations, suggestion for borderline cases."

  Free-form lens (when audit_target is not a known lens-id):
    - Parse the question to identify scope (architecture, debt,
      security, docs, performance, governance, observability).
    - Build an ad-hoc lens mirroring the structure above. Be
      explicit in the report header: "this audit was run against
      a free-form question; consider promoting to a named lens
      if recurrent."

  Output format:
    - Always include metadata footer (illustrative — the agent
      outputs this verbatim wrapped in triple-backticks in the
      comment):

        Mode: audit | Lens: <id-or-"free-form"> | Model: <model>
        Files read: <n> | Directories traversed: <n>
        Runtime: <sec>s | Commit SHA: <sha> | Run: <url>

    - Findings sectioned by severity (Critical/Warning/Suggestion).
    - Each finding: title, evidence (file:line citations), reasoning,
      recommended action.
    - If body exceeds ~50KB:
        - Split into ./.github/scripts/post-claude-review.sh
          invocations, one per chunk, each prefixed with [Audit N/M]
        - Order: critical chunks first, then warnings, then
          suggestions.
        - Wrapper supports multiple invocations within one job.

  Posting target:
    - PR comment trigger (github.event.issue.pull_request != null)
      → post to PR via the wrapper script (which forwards to
      `gh pr comment <pr-number> --body-file -`).
    - Issue comment trigger (github.event.issue.pull_request == null)
      → post to issue via `gh issue comment <issue-number> --body-file -`.
      The wrapper script's allowlist entry must include the
      issue-comment subcommand for this path. NOTE: `gh pr comment`
      and `gh issue comment` are different gh subcommands; do not
      conflate them. The dispatcher selects the correct one based
      on the event payload.

  Budget caps:
    - Max files read total: 18 (Phase 1: 6, Phase 2: 12)
    - Max comment chunks: 5
    - Hard timeout: 60 min (workflow-level; override via
      timeout_minutes input if caller wants longer)
````

## References

- ADR-001 — Mode taxonomy (defines audit + lens registry; verified unchanged in P3-T7 per ADR-immutability rule)
- ADR-005 — Audit output format (single comment, multi-comment split)
- `phases/EMPIRICAL-GATE.md` — runs audit on CBM main after P3+P4 merge
- `phases/P6-audit-mode-l3.md` — conditional follow-up if signal demands fan-out
- `EXECUTION-MODEL.md`, `GUARDRAILS.md`
