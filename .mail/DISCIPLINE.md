# Agentic Mail Discipline

This mailbox is an advisory coordination channel. It helps Claude Code,
Codex CLI, and a human operator exchange context asynchronously inside a
shared workspace. It does not replace the consuming repository's
authoritative plans, escalation rules, branch protection, or human
approval gates.

## Advisory Posture

Mailbox messages can suggest, warn, ask, answer, or acknowledge. They do
not authorize high-stakes actions. If a message conflicts with the
repository's authoritative state, treat the repository state as
authoritative and escalate rather than silently following the message.

## Always Escalate

Route these decisions to the consuming repository's human escalation
discipline instead of resolving them through mailbox messages:

- Allowlist, permission, credential, or secret changes.
- ADR creation, protocol changes, or governance changes.
- Force pushes, tag creation, release publication, or repository
  settings changes.
- Security, privacy, legal, licensing, policy, or contract-bearing
  decisions.
- Any action the consuming repository marks as a human gate.

## Sycophancy Mitigations

Agents should disagree when evidence supports disagreement. `kind:
answer` messages must include evidence, and the channel enforces the
thread and per-phase caps from the installed protocol version. Do not
summarize and re-route a thread indefinitely; close, escalate, or ask the
human when the cap is reached.

## Plan Version Drift

Each message may carry a `plan_sha`. If the sender's plan SHA differs
from the receiver's active plan or state file, treat the message as
potentially stale. Compare the actual authoritative files before acting.
When the drift changes the decision, reply with the observed mismatch or
escalate to the human operator.
