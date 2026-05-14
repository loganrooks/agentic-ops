# Execution model

This document defines the autonomous-execution machinery: how an
agent given the prompt `GO` runs the initiative from start to finish
without human intervention except at explicitly-marked HUMAN-GATE
checkpoints. State persists to disk in `auto-execution/`.

The model is inspired by snarktank/ralph and OpenAI Codex's
follow-goals — persistent state on disk, atomic tasks with
mechanical postconditions, checkpoint-per-phase, session-end and
session-resume protocols, escalation flow with `RESOLVED:` and
`BLOCKED:` markers, done detection via `DONE.md` contract.

## Agent-to-agent mailbox channel (post-install)

This repo installs `agentic-mail` `v0.1.0` as an advisory mailbox
channel between Claude Code and Codex CLI. The installed protocol spec
is `docs/protocols/AGENT-MAILBOX-v0.md` in
`loganrooks/agentic-mail` at tag `v0.1.0`; the local copied runtime
lives under `.mail/`.

The mailbox is coordination context, not authority. It is appropriate
for peer review notes, handoff questions, implementation context,
smoke-test pings, and low-stakes disagreement. It does not replace
human escalation, PR review, CodeRabbit, CI, branch protection, ADR
discipline, or the explicit HUMAN-GATE checkpoints in this execution
model.

High-stakes decisions still route to the maintainer through the normal
escalation path. That includes credentials and secrets, repo settings,
branch protection, force-pushes, release tags, ADR creation or
supersession, allowlist changes, security-impacting changes, and any
workflow-contract change whose blast radius is unclear.

Sycophancy mitigations are part of the channel contract. Agents should
use mailbox messages to disagree explicitly when evidence conflicts
with a plan, and `kind: answer` messages require an `evidence` field.
Thread and phase message caps remain in force so the mailbox cannot
become an auto-loop that amplifies agreement without fresh evidence.

If a message includes `plan_sha`, recipients compare it with the
current plan or state artifact before relying on the message. A mismatch
is treated as plan-version drift: record the mismatch, avoid acting on
stale instructions as authoritative, and escalate when the drift affects
the current task contract.

For observability, use `.mail/bin/mail-status --workspace <repo>` to
inspect unread counts, active threads, expired messages, audit entries,
and phase budget counters. The runtime audit log is `.mail/.audit.jsonl`;
it is intentionally ignored by git, while the installed CLI scripts and
archive directory placeholders are committed so the repo pins the copied
runtime to `agentic-mail` `v0.1.0`.

Hook delivery is intentionally asymmetric in v0. Codex receives pending
mail through the installed `Stop` hook, which emits a JSON continuation
block. Claude Code receives pending mail through the installed
`SessionStart` hook, which emits mailbox context at session boundaries.
Both hooks are cwd-gated to this repo.

## The `GO` command

### What the user types

```text
GO
```

Or equivalently: read `INITIATIVE.md` plus the relevant
`phases/PN-*.md` and execute autonomously per this document.
Continue until `DONE.md` is written or escalation is required.

### What the agent does first (bootstrap)

On receiving `GO`, the agent's very first action:

1. Read `INITIATIVE.md`, `PHASE-MAP.md`, this file, `GUARDRAILS.md`,
   `HUMAN-GATES.md`, `RISK-REGISTER.md`.
2. Check for state file at `auto-execution/STATE.md`.
3. **If state file does NOT exist** → execute phase P0 (bootstrap).
4. **If state file exists** → read it, identify `current_phase` and
   `current_task_id`, read the relevant `phases/PN-*.md`, then
   proceed with the next task per the driver loop.
5. **If `auto-execution/DONE.md` exists** → halt. Initiative is
   complete; print summary.
6. **If `auto-execution/ESCALATIONS.md` has an unresolved entry**
   (no `RESOLVED:` line) → halt. Print escalation. Wait for user.

### What the agent reads at every task

Every single task (no exceptions):

1. `auto-execution/STATE.md` — verify `current_phase`,
   `current_task_id`
2. The relevant `phases/PN-*.md` — phase definition + task
   definition
3. `GUARDRAILS.md` — for any rule that bears on the task
4. Any task-specific files referenced in the task spec

### What the agent writes at every task

After every task, before declaring it complete:

1. Verify postconditions per task spec
2. Append a one-line entry to `auto-execution/SESSION-LOG.md`
3. Update `auto-execution/STATE.md` (advance `current_task_id`,
   update `task_status`)
4. Append to `auto-execution/ARTIFACTS.md` if a new file was
   produced
5. If the task transitions phases: write
   `auto-execution/checkpoints/CHECKPOINT-PN.md` and append a
   summary block to `auto-execution/CHECKPOINTS.md`

## Driver loop

The agent follows this loop mentally on every task:

```text
while True:
    state = read("auto-execution/STATE.md")
    if state.done:
        halt("DONE.md exists; nothing to do")
    if state.escalated and not state.escalation_resolved:
        halt("ESCALATION pending; user input required")
    if state.context_pressure_high:
        write_session_summary()
        halt("Session ending; resume with GO")
    task = next_task(state)
    if task is None:
        if all_phases_complete(state):
            write_done()
            halt("All phases complete")
        else:
            escalate("No next task identified but not done — investigate")
    verify_preconditions(task)
    if precondition_failed:
        if retries_exhausted: escalate(...)
        else: increment_retry(); continue
    execute_task(task)
    if execution_failed:
        if retries_exhausted: escalate(...)
        else: increment_retry(); continue
    verify_postconditions(task)
    if postcondition_failed:
        if retries_exhausted: escalate(...)
        else: increment_retry(); continue
    advance_state(task)
    if task.is_phase_terminal:
        run_checkpoint(task.phase)
    if waiting_for_external(task):  # e.g., gh pr checks --watch
        schedule_wakeup(seconds=task.poll_interval)
        halt_until_wakeup()
```

## Task state machine

```text
NOT_STARTED → IN_PROGRESS → AWAITING_VERIFICATION → COMPLETE
                ↓                  ↓
              FAILED            VERIFICATION_FAILED
                ↓                  ↓
              [retry up to N]    [retry up to N]
                ↓                  ↓
              ESCALATED         ESCALATED
```

`AWAITING_EXTERNAL` is a special state for tasks that wait on CI,
PR checks, or scheduled events (e.g., CodeRabbit's review of an
open PR — see HUMAN-GATES.md).

## Task atomicity & verification

**Every task is atomic.** A task either completes (postconditions
verified) or it doesn't. No partial credit. Mid-task interruption →
retry the whole task.

**Verification is mechanical.** Postconditions are file-existence
checks, file-content greps, exit-code checks, JSON-schema validation.
The agent runs them via Read/Bash and gets unambiguous yes/no.

**No "judgment" tasks except where explicitly marked.** Tasks that
require qualitative judgment are explicitly tagged `[JUDGMENT]` in
their phase-doc spec, and have an objective fallback (e.g., "if
prompt has all sections X/Y/Z and is non-empty, proceed").

## Checkpoint protocol

At the end of each phase, before advancing to the next:

1. Run all postconditions of all tasks in the phase. ALL must pass.
2. Write `auto-execution/checkpoints/CHECKPOINT-PN.md` with phase
   ID, completion timestamp, list of completed tasks (with
   timestamps), list of artifacts (paths + sha256 short), verified
   postconditions, cost estimate (sessions, tokens, runtime).
3. Append a summary block to `auto-execution/CHECKPOINTS.md`.
4. Update `STATE.md` (`current_phase` advances; `current_task_id`
   resets to the first task of the next phase).
5. **PR-merge gate:** if the phase produced a PR, the PR must be
   merged AND `v1` tag must be force-updated to the merge SHA
   before checkpoint is written. (No PR open; no checkpoint.)
6. **Do NOT skip the checkpoint** — even if the next phase seems
   trivial.

## Session management & context handling

### Context pressure thresholds

The agent self-monitors:

- After every task completion, estimate remaining context budget.
- If context usage exceeds **70%** of total → BEGIN session-end
  procedure.
- If a single upcoming task is estimated to consume **>25%** of
  remaining context → BEGIN session-end procedure before starting it.

### Session-end procedure

1. Write `auto-execution/sessions/SESSION-<ISO8601-timestamp>.md`
   with: what was accomplished this session (task IDs), current
   STATE.md snapshot (mirror), "next task" pointer, any partial
   work needing cleanup, files modified this session (paths + commit
   refs), issues encountered + resolutions.
2. Update STATE.md `last_session_end`.
3. Halt with message:
   ```text
   Session ending due to context pressure.
   Last completed task: <id>
   Next task: <id>
   Resume by running: GO
   ```

### Session-resume procedure

At the start of every non-first session:

1. Read STATE.md.
2. Read most recent file in `auto-execution/sessions/`.
3. Read most recent file in `auto-execution/checkpoints/` if
   applicable.
4. Verify workspace state matches what STATE.md says (e.g., if
   STATE says PR #N is open, run `gh pr view N`).
5. If discrepancy → write ESCALATION, halt.
6. Resume with the next task.

### Hard rule: never lose state

Every state-mutating action commits state to disk before claiming
the action complete. If the agent crashes mid-task, the next
session's resume protocol detects the inconsistency and either
rolls back or escalates.

## Failure handling & escalation

See also `RISK-REGISTER.md` for risk-class-specific responses.

### Retry policy (per task)

- Default `max_retries: 3`.
- Specific tasks may override (defined in phase-doc task spec).
- Between retries: 30-second wait (allows transient issues to
  clear).
- After max retries → escalate.

### Escalation procedure

1. Write `auto-execution/escalations/ESCALATION-<ISO8601>.md` with:
   task ID, what was attempted, error/failure details (verbatim
   output), retry count, hypothesized cause, suggested user actions.
2. Update STATE.md (`status: escalated`,
   `escalation_path: <path>`).
3. Append index entry to `auto-execution/ESCALATIONS.md`.
4. Halt with message indicating escalation file path.

### User-resolved escalation

User adds `RESOLVED: <date> <note>` line to the top of the
escalation file. On next `GO`, the agent reads this, treats the
escalation as resolved, retries the task.

### Permanent escalation

User adds `BLOCKED: <reason>` line. On next `GO`, the agent skips
the task (marks as blocked in STATE.md), continues to next task.
Phase checkpoint will note the blockage.

### Escalation dormancy contract

When the agent writes an
`auto-execution/escalations/ESCALATION-<ts>.md` file per the
escalation procedure, the agent's session enters **DORMANT** state
until the escalation file is resolved. This section defines the
behavior of DORMANT state, exit conditions, and prohibitions.

The motivation: without an explicit dormancy contract, an escalating
agent has two bad defaults — (a) hard-halt the session (loses
context if not re-prompted; the maintainer must remember to GO
again), or (b) start the next thing it thinks is OK to do (collides
with the supervisor or maintainer doing parallel work, creating the
shadow-replacement and re-litigation frictions captured in F-003,
F-004, and F-007 in `FRICTIONS.md`).

#### DORMANT state behavior

While DORMANT, the agent must not:

1. Start the next task in the driver loop.
2. Modify `STATE.md` beyond setting `task_status: AWAITING_HUMAN`,
   bumping `last_updated`, and recording the escalation file path
   under `## Active escalation`.
3. Re-interpret prior `STATE.md` notes or COMPLETE entries. They
   are immutable audit records. If the agent believes a prior entry
   is factually wrong, it must write a new escalation file
   (`ESCALATION-<ts>-clarify.md`) describing the discrepancy as a
   question to the maintainer, not edit the prior entry.
4. Do work that is "ready to do" while waiting. The pause is the
   contract. A supervisor agent (e.g., Claude Code in the
   maintainer's chat) may be drafting a response, surfacing
   context, or syncing other state; concurrent autonomous work
   creates the shadow-replacement anti-pattern.
5. Modify any caller-stub workflow file, kernel surface, or
   consumer repo. Dormant means dormant on the substrate, not just
   on the current task.

#### Exit conditions

The agent exits DORMANT state on either:

- (a) A line at column 0 matching `RESOLVED:` is present in the
  escalation file (per §"User-resolved escalation"), OR
- (b) A line at column 0 matching `BLOCKED:` is present (per
  §"Permanent escalation"), OR
- (c) The maintainer adds a new instruction to the agent's
  conversation context (handled by the agent's normal prompt loop;
  no polling needed for this case).

#### Polling cadence

For exit conditions (a) and (b), the agent polls the escalation
file at this cadence:

- First **10 minutes** after writing the file: every **60 seconds**.
- Next **60 minutes**: every **5 minutes**.
- After the first hour: every **15 minutes**.

The cadence is back-loaded because most escalations resolve while
the maintainer is at-keyboard (the first 10 minutes); after that,
the resolution is async (maintainer in a meeting, etc.) and a
shorter cadence wastes log lines without reducing latency
meaningfully.

#### Resolution-line scope verification

Before resuming on a `RESOLVED:` line, the agent verifies the line
is unambiguously scoped to the escalation file the agent wrote.
Acceptable forms:

- The line is in the agent's own escalation file (the strongest
  signal — file-local resolution).
- The line in another file explicitly names the agent's file by
  path or basename (e.g., `RESOLVED: ... covers
  ESCALATION-2026-05-14T20:47:41Z.md and
  ESCALATION-2026-05-14T20:50:00Z.md`).
- The maintainer-supplied resolution wording in the line is
  "all open escalations resolved" (or equivalent unambiguous
  multi-scope wording).

If the resolution line is ambiguous (e.g., a generic "escalation
resolved" with multiple unresolved escalations open), the agent
must NOT resume. Per F-003 adjudication, ambiguous shortcuts
require a clarification escalation, not unilateral interpretation.

#### Resume protocol

On valid resume:

1. Re-read `STATE.md` from the top.
2. Trust `STATE.md` notes dated AFTER the agent's pause timestamp
   as authoritative supervisor-side updates. If a note's reasoning
   is unclear, escalate clarification rather than re-interpret.
3. Continue from `current_task_id`.
4. Update `STATE.md`: flip `Status` from `escalated (...)` back to
   `active`; flip `## Active escalation` `resolved: false → true`;
   bump `last_updated`.

#### Dormancy timeout

If the agent remains DORMANT for more than **4 hours** without
resolution, it must write a follow-up escalation file
(`ESCALATION-<ts>-timeout.md`) noting the duration and asking
whether the maintainer intends to resume the session at all. The
agent then continues to poll per the cadence above.

The agent does not terminate the session on timeout — terminating
loses the in-context state (conversation history, reasoning chain,
scratchpad) that the agent built up before escalating, and that
state is hard to reconstruct on a fresh session.

#### Supervisor-side companion (informative)

A supervisor agent (Claude Code in the maintainer's chat session)
may also watch the escalations directory. On the supervisor side
the loop is closed via `~/.local/bin/escalation-poller.sh` (a
personal utility, not committed) and the `escalation-watch` Claude
Code skill (also personal). The supervisor's role is to adjudicate
the escalation, draft the `RESOLVED:` line on maintainer signal,
and sync `STATE.md`. The autonomous agent need not coordinate
directly with the supervisor — the escalation file is the only
shared surface.

## Done detection

DONE when ALL of:

- Every reachable phase has a checkpoint file in
  `auto-execution/checkpoints/`
- All checkpoints have `verified: true`
- No unresolved escalations
- Final phase (P9) postconditions all pass
- `v1` tag points at the latest expected merge SHA

When DONE is detected, the agent writes `auto-execution/DONE.md`
with: completion timestamp, summary cross-referencing checkpoints,
total tasks completed, total sessions consumed, total estimated
cost, pointers to artifacts, recommended next steps for the human.

## State schemas

### STATE.md

Single source of truth. Mutated atomically (write-replace; never
append-then-edit). Schema:

```markdown
# Plan execution state

**Plan file:** ~/.claude/plans/<plan-id>.md
**Plan sha256:** <hash>
**Started:** <ISO 8601>
**Last updated:** <ISO 8601>
**Last session end:** <ISO 8601 or null>
**Status:** active | escalated | done | paused

## Current position
- **current_phase:** P<N>
- **current_task_id:** P<N>-T<M>
- **task_status:** NOT_STARTED | IN_PROGRESS | AWAITING_VERIFICATION |
                   AWAITING_EXTERNAL | COMPLETE | FAILED | ESCALATED
- **retry_count:** N
- **awaiting_external:** null | { kind, details }

## Phase progress
- **P0..P9** with status: complete | in_progress | pending | skipped

## Counters
- tasks_completed, tasks_blocked, sessions_used, estimated_cost_usd

## Active escalation
- **path:** null | escalations/ESCALATION-<ts>.md
- **resolved:** false | true

## Recent activity (last 5 tasks)
1. ...
```

### SESSION-LOG.md

Append-only. One line per task execution:

```text
<ISO 8601>\t<task_id>\t<status>\t<one-line summary>\t<duration_seconds>
```

### CHECKPOINTS.md

Append-only summary; one block per phase. Detail in
`checkpoints/CHECKPOINT-PN.md`.

### ESCALATIONS.md

Append-only index; one line per incident. Detail in
`escalations/ESCALATION-<ts>.md`.

### ARTIFACTS.md

Append-only registry of files produced. Used for audit, rollback,
and DONE.md summary. Format: markdown table with columns artifact
path, phase, task, created at, sha256 (first 16).
