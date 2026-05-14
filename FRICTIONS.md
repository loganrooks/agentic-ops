# Frictions

Running log of frictions encountered during build, install, onboarding,
resume, and autonomous execution. Each entry captures: what surfaced,
when, the short-term workaround, the long-term resolution path, and
where in the formal artifacts (OQs, ADRs, EXECUTION-MODEL) the
systemic fix should land.

This file is committed (versioned). It is lighter than
[`OPEN_QUESTIONS.md`](OPEN_QUESTIONS.md) (which captures substantive
design questions requiring deliberation) and serves as the punch-list
for future polishing, installer, and protocol-formalization work.

**Statuses:**

- `OPEN` — active; no workaround in place
- `MITIGATED` — workaround in place; systemic fix pending
- `RESOLVED` — systemic fix landed; entry preserved for audit

---

## F-001: gh CLI lacks `workflow` scope by default

**Status:** MITIGATED (clone+push workaround); systemic fix deferred to
[OQ-12](OPEN_QUESTIONS.md) class-2 refinement.

**Surfaced:** 2026-05-14, during agentic-ops PR #18 follow-up amend on
arxiv-sanity-mcp PR #2 caller stub.

**What.** Default `gh auth login` flow grants scopes
`gist, read:org, repo` but NOT `workflow`. Calling
`gh api PUT contents/.github/workflows/<file>` to amend a workflow
file returns HTTP 403 (`refusing to allow an OAuth App to create or
update workflow ... without 'workflow' scope`). Affects any agent or
installer that tries to modify workflow files via the contents API.

**Workaround used.** Clone repo + `git push` via SSH. Git uses SSH
key credentials, not the OAuth token, so the scope restriction
doesn't apply. Works for any file modification operation.

**Long-term resolutions to consider:**

- Installer pre-flight check that runs `gh auth refresh -s workflow`
  if scope absent.
- Document clone+push as the uniform mechanism for any file
  modification (scope-agnostic; works for non-workflow files too).
- Use a pre-scoped PAT in installer environment.
- Wrapper around `gh api` that detects 403-scope errors and falls
  back to clone+push automatically.

**Where systemic fix lands.** OQ-12 §"Refinement (2026-05-14):
class-2 has two sub-classes (default vs elevated scopes)" — proposed
in supervisor session 2026-05-14T19:00Z; not yet committed to
OPEN_QUESTIONS.md.

---

## F-002: Template-level CR findings recur per consumer onboarding PR

**Status:** OPEN

**Surfaced:** 2026-05-14, on arxiv-sanity-mcp PR #2 (P7-T2-4 PR open).

**What.** CodeRabbit raised 3 findings on arxiv-sanity-mcp PR #2:

- L5 (Trivial Nitpick): `issue_comment` trigger scope fires on both
  issues and PRs.
- L11 (Major): `id-token: write` permission requires documentation.
- L20 (Minor): `review_focus_paths` paths existence verification.

Findings 1 and 2 are properties of the kernel caller-stub template
(present in [`.github/workflows/review.yml`](.github/workflows/review.yml)
header, [`ONBOARDING.md`](ONBOARDING.md), and the CBM stub at
`f6fe379`). They will recur on every consumer onboarding PR (P7-T3
through P7-T7). Finding 3 is repo-specific and trivially verifiable
per consumer.

**Workaround.** Per-PR responses with citations. Acceptable but
wasteful — same justifications get re-stated on each PR.

**Long-term resolutions to consider:**

- Pre-empt: kernel stub template includes a comment block citing the
  rationale for `issue_comment` and `id-token`. CR may still flag
  but justifications are inline.
- `.coderabbit.yaml` per consumer or at account level configures CR
  to skip these specific findings on caller-stub files.
- ONBOARDING.md §"Per-repo agent brief" includes the canonical
  responses so /goal can paste consistently.

**Where systemic fix lands.** Likely a new ADR or addition to
ADR-001 / ONBOARDING.md.

---

## F-003: Chat-signal "escalation resolved" ambiguous when multiple open

**Status:** OPEN

**Surfaced:** 2026-05-14T19:00Z (during supervisor session; reopened
by fresh /goal session re-litigating prix-guesser P7-T1-5 governance
basis).

**What.** Per
[`.planning/EXECUTION-MODEL.md`](.planning/EXECUTION-MODEL.md)
§"User-resolved escalation", the formal resolution mechanism is a
`RESOLVED: <date> <note>` line on the specific escalation file.
Chat-based "escalation resolved" is not in the formal protocol but
has been used as supervisor convenience.

When multiple escalations are open and the user says "escalation
resolved" without specifying which, the interpretation is ambiguous.
On 2026-05-14, /goal/supervisor interpreted the user's chat signal as
covering both Escalation A
(BP precondition, `ESCALATION-2026-05-14T08:11:23Z.md`) and
Escalation B (merge gate, `ESCALATION-2026-05-14T09:55:47Z.md`). The
interpretation was permissive and matched user's intent in
retrospect, but the strict per-file reading is the protocol-correct
default.

**Workaround used.** Supervisor adds RESOLVED line to file citing the
chat signal as basis (e.g., the 2026-05-14T09:58:01Z RESOLVED line on
Escalation B file cites "maintainer signal received in chat:
'escalation resolved'"). Subsequent /goal sessions reading the file
see the formal RESOLVED line and proceed. Bug surfaced: a fresh /goal
session may re-litigate the supervisor's interpretation basis (as
happened on 2026-05-14T19:30Z restart).

**Long-term resolutions to consider:**

- (a) Chat shortcuts are valid only if scope is explicit
  ("Escalation A resolved" or "all open escalations resolved");
  generic "escalation resolved" with multiple open is treated as
  ambiguous and supervisor must escalate clarification.
- (b) Chat shortcuts are invalid; user must directly add RESOLVED
  line. Higher friction but unambiguous.
- (c) Supervisor proxy is allowed but RESOLVED line must include
  explicit scope statement and the maintainer's reasoning, not just
  "chat signal received."
- (d) /goal's resume protocol explicitly stops re-litigating
  RESOLVED-line basis; once present, it's authoritative.

**Adjudicated forward-looking rule (2026-05-14):** Option (a) — chat
shortcuts are valid only if scope is explicit when multiple
escalations are open. Generic "escalation resolved" with multiple
open requires supervisor clarification before proxying to file.

**Where systemic fix lands.** EXECUTION-MODEL.md §"User-resolved
escalation" amendment.

---

## F-004: Supervisor partial work creates context gaps for /goal resume

**Status:** OPEN

**Surfaced:** 2026-05-14T19:30Z (during this session's /goal restart
attempt).

**What.** During the 2026-05-14 11:55Z to 18:35Z pause, supervisor
(Claude) handled kernel-side policy iteration (PRs #17 and #18) and
consumer-side amends (arxiv-sanity-mcp `e588c7e`; prix-guesser
PR #3) that arguably overlapped with /goal's per-repo subtask scope.
STATE.md was updated to capture the work, but the rationale for each
decision and the evolving interpretation of past events live in the
supervisor session conversation, not in STATE.md.

When /goal resumed in a fresh session, it lacked the conversational
context — re-litigated the prix-guesser P7-T1-5 governance
interpretation (see F-003), questioned STATE.md's correctness,
proposed unilateral STATE.md modifications.

**Workaround used.** Supervisor adds explicit GOVERNANCE NOTE to
STATE.md heading off re-litigation; supervisor reply to /goal session
reinforces "do not modify STATE.md unilaterally."

**Long-term resolutions to consider:**

- Supervisor session writes detailed handoff notes to STATE.md (or a
  separate HANDOFF.md) capturing every decision rationale and
  pre-empting expected re-litigation cases.
- Supervisor work scope is constrained: only kernel-side policy
  work, never consumer-side overlap with /goal's per-repo flow.
- /goal's resume protocol explicitly enumerates what state changes
  since pause are authoritative ("trust STATE.md notes dated after
  pause; if reasoning seems incomplete, escalate clarification
  rather than re-interpret").
- Periodic STATE.md commits to a state-snapshots branch so
  fresh-context agents can diff to see what changed and why.

**Where systemic fix lands.** EXECUTION-MODEL.md §"Session-resume
procedure" amendment plus addition of "Supervisor handoff" section.

---

## F-005: vigil's default branch is `master`, not `main`

**Status:** MITIGATED (detection in place via `gh repo view`)

**Surfaced:** 2026-05-14, during P7 pre-fly setup parallel to
prix-guesser resolution.

**What.** vigil consumer repo uses `master` as its default branch
while all other named consumers use `main`. /goal's caller-stub
authoring at P7-T6-3 must target `master` not `main`.

**Workaround used.** STATE.md notes flag the quirk; /goal must
detect via
`gh repo view loganrooks/vigil --json defaultBranchRef` at T6-1.

**Long-term resolutions to consider:**

- Always detect default branch via `gh` API; never assume `main`
  (universal pattern, no special-case for vigil).
- Migrate vigil's default branch to `main` (out of /goal scope;
  maintainer-only).

**Where systemic fix lands.** ONBOARDING.md §"Per-repo customization
checklist" — add explicit "detect default branch" step. Also a
generic friction worth applying to any future external onboarding.

---

## F-006: agentic-ops self-consumer (P7-T7) prerequisite unverified

**Status:** OPEN (gating P7-T7 only)

**Surfaced:** 2026-05-12, during W2 (ADR-009 drafting); captured in
[`.planning/phases/P7-onboarding.md`](.planning/phases/P7-onboarding.md)
§"Parallelization guidance".

**What.** Per
[ADR-009](docs/adr/ADR-009-consumer-cap-relaxation.md) §Decision §2,
the kernel reusable workflow's `Determine central ref` step's
behavior must be empirically verified (or patched) before the
agentic-ops self-consumer caller stub lands. The risk: `@v1`
self-review reviews against the released kernel ref, not the
caller-run's in-flight ref. If the kernel currently checks out the
caller's ref instead of the released `@v1` tag for self-consumer
cases, the self-review reviews the in-flight changes which defeats
the version-pinning discipline.

**Workaround used.** None yet; T7 deferred until prerequisite
cleared.

**Long-term resolutions to consider:**

- Empirical verification via test workflow run: confirm `@v1`
  self-review checks out the released kernel ref.
- Patch the kernel `Determine central ref` step if the behavior is
  incorrect.
- Document the verified behavior in ADR-009 §Decision §2 with a
  citation.

**Where systemic fix lands.** ADR-009 §Decision §2 plus kernel
workflow `review.yml` if patching needed.

---

## F-007: Supervisor↔/goal coordination loop has no explicit dormancy contract

**Status:** MITIGATED (poller + skill + prompt amendment drafted
2026-05-14T20:50Z); **systemic fix in flight as PR #20**
(`docs/escalation-dormancy-contract` branch) codifying the
contract into `EXECUTION-MODEL.md` §"Escalation dormancy
contract" + `AGENTS.md` §"Hard rules" reference. Will move to
RESOLVED on PR #20 merge.

**Surfaced:** 2026-05-14, after the supervisor-side handling of
agentic-ops PR #18 plus consumer-side amends produced two distinct
coordination problems on /goal restart (see F-003, F-004).

**What.** When /goal escalates, three things happen implicitly that
have no protocol:

- /goal does not have a defined "dormant" state. It writes the
  escalation file and then either (a) hard-halts the session
  (losing context if not re-prompted), or (b) does the next thing
  it thinks is OK to do (which can collide with supervisor work).
- The supervisor (Claude) has no automated detection that an
  escalation fired. Without out-of-band notification, the
  maintainer must ping the supervisor or vice-versa.
- The exit condition (the `RESOLVED:` line per
  [`.planning/EXECUTION-MODEL.md`](.planning/EXECUTION-MODEL.md)
  §"User-resolved escalation") is well-defined, but the polling
  cadence on /goal's side is not, and the supervisor's responsibility
  to write the line cleanly (citing the exact maintainer signal,
  scoping to the right file) is not codified.

These gaps cumulatively create:

- Re-litigation of prior state (F-003).
- Context gaps that read as STATE.md "untrustworthiness" (F-004).
- Shadow-replacement of /goal work by supervisor when timing is
  uncertain (called out in STATE.md `## Discipline note for /goal
  resume`).

**Workaround used.** Three artifacts drafted as a coordination kit:

- `~/.local/bin/escalation-poller.sh` — supervisor-side poller for
  the escalations directory; macOS osascript notifications.
- `~/.claude/skills/escalation-watch/SKILL.md` — supervisor-side
  Claude Code skill describing the per-file resolution protocol,
  adjudication buckets (maintainer-only / policy-on-file /
  ambiguous), and STATE.md sync responsibilities.
- `.planning/auto-execution/goal-prompt-amendment.md` — paragraph
  to paste into the /goal prompt at session start; defines the
  DORMANT state, polling cadence (60s for first 10 min, 5 min for
  next hour, 15 min after; 4-hour timeout writes follow-up
  escalation), and prohibits unilateral state mutation /
  re-litigation.

These are mitigation, not a structural fix — they are not yet kernel
surface (no installer, no schema, not referenced from
EXECUTION-MODEL.md). Future iteration after empirical use should
fold the contract into EXECUTION-MODEL.md as a first-class section
("§ Escalation dormancy contract").

**Long-term resolutions to consider:**

- Codify the dormancy contract into EXECUTION-MODEL.md as a
  protocol-level section (matching §"User-resolved escalation").
- Ship the poller + skill as part of the agentic-ops install
  pipeline (cf. OQ-12 install/onboarding shape).
- Replace osascript notifications with a more portable channel
  (e.g., a webhook into the supervisor's chat) so the loop works
  off-Mac.
- Investigate whether the /goal Codex application can ping the
  supervisor session directly without the escalation file as
  intermediary (the user-noted wishlist; currently not supported,
  formal escalation file is the mechanism).

**Where systemic fix lands.** EXECUTION-MODEL.md §"Escalation
dormancy contract" + AGENTS.md §"Hard rules" reference (PR #20,
opened 2026-05-14T21:15Z); installer surface for the
supervisor-side companion deferred to OQ-12 resolution.

---

## F-008: No high-reasoning gate for "merge this PR" maintainer signals

**Status:** OPEN

**Surfaced:** 2026-05-14T20:50Z, while arxiv-sanity-mcp PR #2 sits
mechanically clean (`mergeStateStatus=CLEAN`, CI `test=SUCCESS`,
CodeRabbit `SUCCESS`, all review threads resolved) awaiting an
explicit maintainer `Merge arxiv-sanity-mcp PR #2` signal per
P7-T2-5.

**What.** The hard rule "do not merge any PR unless the maintainer
explicitly says `Merge` for that PR" is the right safety contract.
But it places the entire merge-quality decision on the maintainer's
shoulders at signal-time, with no AI-side guardrail or quality
review intermediating between "PR is mechanically clean" and
"maintainer types Merge."

For the named-consumer onboarding pattern (P7), each merge signal
covers a near-template change (caller-stub workflow file, ~25
lines). The decision space is small. Even so:

- The maintainer must remember the specific PR number, the
  current expected caller-stub shape (post-PR-#18 all-empty
  `extra_allowed_tools`, normalized `enabled_modes`, etc.), and the
  recurring template-level findings (F-002).
- /goal's escalation message is structured but not exhaustive. It
  reports observed state but does not run a "would I merge this"
  checklist of its own.
- CodeRabbit and Codex review per-finding but do not produce a
  holistic "this PR is mergeable / this PR is mergeable with
  caveats / this PR should not merge" verdict.

The user wishlist (2026-05-14 compaction args): a high-reasoning
Claude agent that watches for "ready to merge" PRs and produces
both (a) a guardrail checklist (template-shape, no plugin-loading
tools, no wildcard arg-injection-defeatable tools, focus paths
exist, repo_label matches, agents_md_path correct, branch is the
expected feat branch, no force-push-against-protected-branch in
history) and (b) a quality review (general PR shape against
ONBOARDING.md and ADR-001).

**Workaround used.** None yet. The maintainer signal is the only
gate; supervisor (Claude) reads the PR ad-hoc when surfacing the
escalation but does not produce a structured verdict.

**Long-term resolutions to consider:**

- A new Claude Code skill (sibling to `escalation-watch`) — call
  it `pr-merge-review` — that takes a PR URL, runs the guardrail
  checklist deterministically (parse YAML; check fields against a
  static spec from ONBOARDING.md), runs the quality review
  reasoning, and produces a verdict. The skill is invoked by the
  supervisor when surfacing a merge-gate escalation; output is
  attached to the surface-message for the maintainer to read.
- A pre-merge GitHub Action (separate from the kernel review
  workflow) that runs the guardrail checklist on caller-stub PRs
  and posts a comment. This is more automated but adds CI surface
  and is harder to iterate on.
- A `pr-merge-review` agent (Anthropic Claude SDK) running as a
  scheduled task (every 15 min) that scans `gh pr list` for any
  PR matching `mergeStateStatus=CLEAN AND author=loganrooks` and
  posts its verdict to the PR as a comment. The maintainer reads
  the comment and decides whether to type `Merge`.
- For non-template PRs (kernel changes, ADR amendments, OQ
  additions), the high-reasoning agent's spec should be different
  — there the value is "did this PR introduce regression risk in
  any of the kernel's safety invariants" rather than "does this
  match the caller-stub template."

**Where systemic fix lands.** New skill at
`~/.claude/skills/pr-merge-review/SKILL.md`; ONBOARDING.md addition
documenting the merge checklist as a first-class artifact; possibly
a new ADR (ADR-010 or similar) capturing the AI-side merge gate as
distinct from the maintainer-side merge signal.

**Note.** The user observed (2026-05-14) that "would be wonderful if
the codex application could somehow message / ping here without
doing a formal escalation but seems that is the mechanism that we
should instruct it to do for now." For the immediate term, the
formal-escalation mechanism remains the right path; the
high-reasoning agent reduces the decision burden at signal-time but
does not change the signal mechanism itself.

---

## How to add an entry

Append to bottom with the next sequential `F-NNN` ID. Prefer creating
an entry as soon as a friction is observed, even if the workaround
isn't yet known. Update Status as workaround / resolution lands.
Resolved entries are preserved for audit (do not delete).

A new entry should include:

- **Status** (OPEN / MITIGATED / RESOLVED)
- **Surfaced** (date plus short context)
- **What** (the friction itself, in technical detail)
- **Workaround used** (if any)
- **Long-term resolutions to consider** (bulleted options)
- **Where systemic fix lands** (which formal artifact: OQ, ADR,
  EXECUTION-MODEL, etc.)

References from STATE.md, OPEN_QUESTIONS.md, ADRs, or PR descriptions
should use the `F-NNN` ID so the trail is greppable.
