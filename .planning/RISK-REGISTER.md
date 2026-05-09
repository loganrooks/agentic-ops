# Risk register

Risks tracked across the initiative, with detection and mitigation.

| Risk | Likelihood | Impact | Detection | Mitigation |
|---|---|---|---|---|
| `claude-code-action` v1.0.x update breaks the workflow | Med | High | CI fails after action update | Pinned SHA on action references; CI catches; rollback via revert-merge |
| Sub-agent (L2) pattern attempted by future contributor and hits permission inheritance bug | Low (we skip L2) | Med | N/A in this initiative | ADR-002 documents the bug references; future contributors warned |
| Cost spike from L3 (~10x sessions per run) | Med | Med | Aggregator (P8) reports trends | Threshold input gates L3 to large PRs only |
| OAuth token revocation by Anthropic for GHA usage | Low | Critical | Auth failures | Use first-party `claude-code-action`; ToS risk on Anthropic, not us |
| L1 produces shallow review on large PR but doesn't trigger L3 | Med | Med | Empirical gate | Manual comparison vs CodeRabbit/Codex; explicit decision logic in `phases/EMPIRICAL-GATE.md` |
| Free-form audit prompt-injected via PR content | Low | Med | N/A (cannot detect from outside) | Wrapper-script discipline + narrow allowlist contains worst case (per SECURITY.md TC-1, TC-2) |
| Audit on issue (not PR) reads main when main is broken | Low | Low | Audit run fails or produces nonsense | Workflow checks out main HEAD with explicit ref; audit prompt warns about base state |
| Empirical gate ambiguous → blocks plan | Med | Low | Gate logic surfaces ambiguity | Escalate to user with raw data per HUMAN-GATE-5 |
| Plan file gets stale during multi-session execution | Med | Med | STATE.md plan-sha mismatch with PLAN-snapshot.md | Plan-sha check at session start (resume protocol) |
| Agent infinite-loops (e.g., ScheduleWakeup forever waiting for CI) | Low | Med | Wall-clock budget per task | Hard timeout per task type defined in phase doc |
| One repo onboarding (P7) breaks somehow | Med | Low | Smoke test fails for that repo | Mark that repo `partial` in checkpoint; continue with others |
| **CodeRabbit review missing or delayed on a PR** | Med | Med | PR open >15 min with CI green and no CodeRabbit review | HUMAN-GATE-6: agent comments `@coderabbitai review`; escalate after 10 more min |
| **CodeRabbit posts findings the agent dismisses too quickly** | Med | Med | Conversation resolved without commit address OR explicit reply | Branch protection requires conversation resolution; maintainer reviews resolution rationale before merge |
| **Branch protection prevents an emergency fix** | Low | Low | Can't merge through normal flow | `enforce_admins: false` lets logan override in emergency; record override in postmortem |
| **GitHub App rate limits during empirical-gate runs** | Low | Med | API errors during CBM PR #1 survey trigger | Backoff + retry; if persistent, escalate |
| **Multi-comment audit posts hit rate limits** | Low | Low | `gh pr comment` errors after first chunk | Wrapper script logs each invocation; agent serializes chunks with delay |
| **Lockstep release of v1 tag with main creates a window of inconsistency** | Low | Low | Caller workflow runs against old v1 SHA right after merge but before tag update | Tag update is the FINAL step in checkpoint; window is <60s; consumers can pin specific SHA if they need stricter |

## Notes on risk-class responses

- **Detection** is mostly empirical / runtime. The initiative does
  not pretend to predict failure modes that haven't been observed.
- **Escalation paths** are documented in `HUMAN-GATES.md`. The
  agent never silently swallows a risk-class trigger.
- **Postmortem discipline.** A risk that materializes (especially
  high-impact) gets a postmortem doc in `.planning/postmortems/`
  per the `devops discipline applied to itself` commitment in
  `AGENTS.md`.
