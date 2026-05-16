---
name: escalation-watch
description: |
  Supervisor-side companion to the escalation dormancy contract. The Codex /goal agent escalates HUMAN-GATEs and task failures by writing `ESCALATION-<ts>.md` files; this skill makes you (Claude Code in the maintainer's chat) the active reasoning agent during /goal's DORMANT state. You watch the escalations directory, adjudicate each escalation, draft the `RESOLVED:` line on maintainer authorization, and keep STATE.md / FRICTIONS.md in sync. The framing: /goal is using you as a higher-reasoning supervisor — not just a notifier.

  TRIGGERS: /goal escalation, escalation watch, escalation poller, monitor escalations, /goal is dormant, /goal is paused, awaiting maintainer signal, ESCALATION-*.md, .planning/auto-execution/escalations, resolve escalation, RESOLVED line, supervisor proxy for /goal, /goal handoff, /goal coordination loop, executor-orchestrator coordination, higher reasoning supervisor.

  Does NOT do: write production code on /goal's behalf (the discipline note in STATE.md forbids shadow-replacement); make policy decisions without maintainer authorization (escalate clarification instead); modify STATE.md unilaterally without explicit user authorization (state mutations require authorization, observations that state should change are themselves escalations).
---

# Escalation Watch (Supervisor side)

When /goal escalates and goes DORMANT, you are not just a passive notifier — you are the **active reasoning agent** on that escalation. /goal has handed off the case to you because:

- You have access to the maintainer's signal-channel (the chat).
- You have full repo context, including FRICTIONS.md, OPEN_QUESTIONS.md, ADRs, and prior escalation history.
- You can do the harder reasoning that /goal might not be able to do in its limited execution loop (e.g., adjudicating bot-vs-bot review conflicts, weighing policy options, drafting clarifying questions).
- You can produce a structured, scoped `RESOLVED:` line that lets /goal resume cleanly.

The Codex-side companion lives at `.agents/skills/escalation-dormancy/SKILL.md`. The two skills together close the supervisor↔executor loop.

## The three moments of engagement

### 1. Detection

/goal writes a new `ESCALATION-<ts>.md` file in `.planning/auto-execution/escalations/`. You learn about it via:

- `scripts/escalation-poller.sh` running in a separate terminal with macOS osascript notifications (preferred).
- `scripts/escalation-poller.sh --once` between turns (when running headless).
- Maintainer mention in chat ("/goal just escalated").

Once notified, read the escalation file in full. Don't skim — the failure context, suggested action, and observed-state details are usually load-bearing.

### 2. Adjudication

Bucket the escalation into one of three:

**(a) Maintainer-only.** Surface to maintainer with a 1-2 sentence summary + the relevant URL/path + /goal's suggested signal. Don't draft a response yourself. Examples: PR merge gates, branch-protection bypass requests, architectural reframes, license/legal questions.

**(b) Policy-on-file.** You can respond per existing ADR, EXECUTION-MODEL.md section, GOVERNANCE NOTE in STATE.md, or established friction adjudication (e.g., F-003 chat-shortcut rule). Draft the RESOLVED line; surface to maintainer for confirmation before writing.

**(c) Ambiguous.** Per F-003 protocol, write a follow-up clarification escalation. Do not guess.

The "higher reasoning" framing matters here. /goal escalated *because* it couldn't decide. Your value-add is doing the deliberation /goal punted on, then giving /goal a clean, scoped resolution it can resume from without re-deliberating.

### 3. Resolution

Per `.planning/EXECUTION-MODEL.md` §"User-resolved escalation":

After maintainer signal received, append to the escalation file at column 0:

```
RESOLVED: 2026-05-15T14:00:00Z maintainer signal "Merge arxiv-sanity-mcp PR #2" received in chat at 2026-05-15T13:58Z; scope is explicit (one PR named); /goal proceeds with merge per P7-T2-5.
```

The line should:

- Cite the **exact maintainer wording** (in quotes).
- State the **scope** unambiguously (which file/PR/task this resolves).
- Reference the **next action** /goal will take on resume.

Per F-003, multi-gate resolutions need explicit per-gate signal or explicit "all open escalations resolved" wording. Don't proxy a generic chat shortcut when multiple escalations are open — write a clarifying question instead.

## State sync after resolution

Update STATE.md in this order:

1. `## Active escalation` block — flip `resolved: false → true`, add the resolution timestamp.
2. `## Notes` — append the resolution note to the existing per-task line (e.g., `P7-T2-5 ... ESCALATED ...` becomes `P7-T2-5 ... RESOLVED <ts> ...`).
3. `**Last updated**` — bump to current UTC timestamp.
4. `**Status:**` — flip from `escalated (...)` back to `active`.

**Do not** retroactively modify task COMPLETE entries based on a re-interpretation of prior chat shortcuts. The GOVERNANCE NOTE in STATE.md (2026-05-14T19:30Z) is the binding precedent here. State mutations require authorization; observations that state should change are themselves escalations.

## Bundled tooling

This skill is shipped with one supervisor-side script:

- `scripts/escalation-poller.sh` — directory watcher. Notifies via macOS osascript when a new escalation appears or when an existing one's status changes. Run once per session in a separate terminal:

  ```
  scripts/escalation-poller.sh --dir .planning/auto-execution/escalations --interval 30
  ```

  Or `--once` for polling-between-turns when running headless. Logs to `/tmp/escalation-poller.log`.

The Codex /goal side has its own bundled script: `.agents/skills/escalation-dormancy/scripts/wait-for-resolution.sh`. Don't run that one yourself — that's /goal's wake mechanism, not the supervisor's.

## Friction-tracking responsibilities

Each escalation cycle is a chance to capture systemic friction:

- If /goal could have handled the escalation but punted (e.g., a CR finding with a documented response template), consider whether to capture as F-NNN.
- If you noticed a coordination problem (context gap, ambiguous shortcut, premature escalation), capture as F-NNN.
- If the same escalation pattern recurs across PRs (e.g., template-level CR findings — see F-002), the systemic fix likely belongs in ONBOARDING.md or kernel-side template change.

## Future: agentic-mail integration

Currently the escalation file is the only coordination channel; chat is the maintainer signal-channel. When `agentic-mail` v0.2+ ships urgent/blocking message types (per design intent — see agentic-mail issue #9), the supervisor↔executor loop may carry coordination via the mailbox in addition to the file. The contract (RESOLVED line on the escalation file as source of truth) is invariant; the wake/notify mechanism becomes pluggable.

## Cross-references

- **Source of truth for contract:** `.planning/EXECUTION-MODEL.md` §"Escalation dormancy contract"
- **Per-file resolution protocol:** same file §"User-resolved escalation"
- **Discipline note:** `.planning/auto-execution/STATE.md` §"Discipline note for /goal resume"
- **Governance note:** `.planning/auto-execution/STATE.md` §"GOVERNANCE NOTE (2026-05-14T19:30Z, retroactive)"
- **Codex-side companion skill:** `.agents/skills/escalation-dormancy/SKILL.md`
- **Friction inventory:** `FRICTIONS.md` (F-003 chat-shortcut ambiguity, F-004 context gaps, F-007 coordination loop, F-009 agentic-mail framing)
- **Poller script:** `scripts/escalation-poller.sh` (this repo)
