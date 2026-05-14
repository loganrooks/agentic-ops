# ADR-010: extra_allowed_tools — eslint reclassification and wildcard-pattern limits

Status: accepted
Date: 2026-05-14

## Context

[ADR-004](ADR-004-allowlist-policy.md) establishes the
`extra_allowed_tools` policy as **STATIC ANALYSIS ONLY** and gives
the operative threat model in §"Why no test execution": a tool whose
contract is "execute code drawn from this directory" cannot be
hardened against malicious code in that directory; a static-analysis
tool that *parses without executing* has the opposite property and
is safe on hostile input.

Two issues with ADR-004 surfaced during P7 onboarding review:

1. **Internal inconsistency: eslint listed as Acceptable.** ADR-004
   §Decision §Acceptable entries lists `eslint` in the linters /
   type-checkers row. But ESLint's contract — confirmed by upstream
   docs and verified during Codex P1 review on
   `loganrooks/prix-guesser` PR #1 (consumer-side caller stub) — is
   to load `eslint.config.js` / `.eslintrc.js` from the project
   root and *execute* them as JavaScript. Plugins (e.g.
   `@typescript-eslint/parser`) are also `require()`'d as Node
   modules, executing their top-level code. This is the exact threat
   class ADR-004 §"Why no test execution" excludes: an attacker PR
   places a malicious `.eslintrc.js` at root, the workflow invokes
   eslint with `CLAUDE_CODE_OAUTH_TOKEN` in environment, the config
   IIFE exfiltrates the token. The §Acceptable listing is therefore
   inconsistent with ADR-004's own threat model.

2. **Argument-injection defeats in wildcard patterns.** Claude Code's
   `--allowedTools` patterns interpret trailing `*` as "match any
   string." `Bash(tsc --noEmit *)` therefore permits
   `tsc --noEmit false a.ts` because `false a.ts` matches `*`; but
   `tsc --noEmit false` parses as "set the boolean noEmit option
   to *false*," i.e., **do emit**. Codex P2 review on
   `loganrooks/agentic-ops` PR #17 verified the defeat locally with
   tsc 6.0.3: `tsc --noEmit false a.ts` writes `a.js`. The pattern
   is weaker than its name implies. The general class is "permission
   patterns containing a `*` that admits flag tokens are not
   argument-injection-resistant for tools whose semantics depend on
   flag order."

Both issues were caught by Codex review, not by reviewer attention
on the original ADR-004 — consistent with ADR-004's own assessment
that the policy is "discipline-enforced, not gated."

## Decision

### §1 — Eslint reclassified to Forbidden

`eslint` is removed from ADR-004 §Decision §Acceptable entries and
treated as Forbidden, on the same threat-model basis as test
runners: its contract requires loading and executing JavaScript
config files from the PR head, so it cannot be hardened against a
malicious PR. This is a **partial supersession** of ADR-004
§Decision §Acceptable entries; all other entries in that table and
in §Forbidden entries stand unchanged.

Consumer caller stubs (P7 table; CBM stub) must not include
`Bash(eslint:*)` or `Bash(eslint *)`. TS-stack repos rely on
`Bash(tsc --noEmit *)` only — accepting the limitation in §2 below.

A future ADR may re-permit eslint if a parser-only invocation mode
exists that demonstrably does not load `eslint.config.js` /
`.eslintrc.js` / plugins (e.g., a `--parse-only` flag or a wrapper
script that runs eslint with a hardcoded config file outside the PR
head). No such mode exists upstream as of 2026-05-14; the eslint
re-permitting bar is "ship a verified hardening surface," not "argue
the policy."

### §2 — Wildcard pattern limits acknowledged

Permission patterns of the form `Bash(<cmd> <fixed-arg> *)` are
**not** argument-injection-resistant in the general case. The
trailing `*` can match additional flag tokens that change the
command's behavior. For tools where this defeat has security
consequence, prefer one of:

- **Exact-form permissions** with no wildcard (e.g.,
  `Bash(<cmd> <fixed-arg>)`) — restrictive but unambiguous.
- **Wrapper scripts** that hardcode safety-relevant flags and pass
  through only file arguments (e.g.,
  `scripts/safe-tsc.sh` that internally runs
  `tsc --noEmit "$@"` and is allowlisted as
  `Bash(./scripts/safe-tsc.sh:*)`). The wrapper is the
  argument-injection boundary; its `--allowedTools` pattern can
  safely use `*`.

For tools where the defeat has no security consequence at the
review path, the pattern may be retained with the limitation
documented. `Bash(tsc --noEmit *)` is in this category: a defeat
emits JavaScript to the ephemeral workflow workspace, which no
subsequent step in the kernel reusable workflow
(`.github/workflows/review.yml`) reads or executes; the runner is
destroyed at workflow end. Blast radius is "wastes a few KB of
ephemeral disk." This pattern is therefore retained as the
recommended TS-stack allowlist entry pending a future
wrapper-script hardening pass.

### §3 — Enforcement

Per ADR-004 §Decision, enforcement is by documentation and reviewer
attention, not by a regex validator. This ADR extends that
discipline rather than altering it. Specifically:

- ADR-004 §Decision §Acceptable entries — the inline note added per
  the editing-rule exception (see Status line) points readers here.
- [`ONBOARDING.md`](../../ONBOARDING.md) §"Per-repo customization
  checklist" — eslint added to the "Specifically known unsafe
  patterns" list; tsc wildcard limitation noted.
- [`.planning/phases/P7-onboarding.md`](../../.planning/phases/P7-onboarding.md)
  §"Per-repo configuration" Updated header — claim of ADR-004
  incompatibility now cites this ADR.

A future regex validator (rejected by ADR-004 §Alternatives) is not
introduced; the rationale there stands.

## Alternatives considered

**Edit ADR-004 §Decision §Acceptable table directly to remove
eslint.** Rejected per `docs/adr/README.md` §"Editing rule" — ADR
bodies are immutable once accepted, except for Status-line updates
and the single inline-note exception under
`partially superseded by`. The audit-trail discipline is
load-bearing.

**Defer eslint reclassification until a sandboxed-execution path
(ADR-004 §"Path B") exists.** Rejected. ADR-004 already defers
Path B explicitly; predicating eslint inclusion on infrastructure
that doesn't exist preserves the gap. Reclassification under the
existing static-analysis-only contract is the lower-cost,
higher-fidelity move.

**Wrapper-script `safe-tsc.sh` shipped immediately to close the
wildcard defeat.** Rejected for now. The blast radius of the tsc
defeat is academic (emit to ephemeral workspace); the wrapper-script
work is meaningful (cross-repo file distribution, version pinning,
documenting the wrapper's own contract). Capturing the path as a
future option in §2 above is sufficient until a real security
consequence emerges.

**Open a new ADR per finding (two ADRs: one for eslint, one for
wildcard limits).** Rejected. Both findings arose from the same
review trace (prix-guesser PR #1 → agentic-ops PR #17); both
clarify ADR-004's allowlist policy; both share enforcement surface
(ONBOARDING.md, P7 table, ADR-004 inline note). A single ADR keeps
the audit trail compact.

## Consequences

**Positive.** ADR-004's threat model and §Acceptable list become
internally consistent. P7 phase doc's claim of ADR-004
incompatibility for eslint is now backed by a cited ADR rather than
an implicit reading. Future agents evaluating new allowlist
candidates (e.g., `Bash(pytest:*)` for a Python consumer with
test-input findings) have a citable rule covering the
code-execution class. Wildcard-pattern limits are explicit; the tsc
case is documented rather than silent.

**Negative.** TS-stack consumer review loses eslint findings.
prix-guesser and epistemic-agency caller stubs rely on
`tsc --noEmit` only; idiomatic-JS / accessibility / style issues
that eslint would catch are out of scope until a future
sandboxed-execution or parser-only path arrives. The blast-radius
tradeoff in ADR-004 §"Why no test execution" applies: this is the
intended cost of the static-analysis-only contract.

**Neutral.** One more ADR file. The Numbering rule
(`docs/adr/README.md`) means future readers walk N+1 documents
instead of N to understand the allowlist policy — small cost
weighed against the clarity gain.

## Trigger conditions for revisiting

- A parser-only eslint mode is verified to not load
  `eslint.config.js` / `.eslintrc.js` / plugins from the PR head.
- ADR-004 §"Path B" (sandboxed execution) is adopted via a future
  ADR; eslint becomes safe under the no-secrets boundary.
- A wrapper-script discipline for the wildcard-defeat class
  becomes warranted by a concrete security-consequence defeat (not
  the academic tsc case).
- A regex-validator surface emerges that ADR-004 §Alternatives
  would accept (e.g., a typed allowlist schema with named tool
  classes rather than free-form Bash patterns).

## References

- [ADR-004](ADR-004-allowlist-policy.md) §"Why no test execution"
  — the threat model this ADR applies consistently
- [ADR-004](ADR-004-allowlist-policy.md) §Decision §Acceptable
  entries — the table partially superseded here
- Codex P1 review on `loganrooks/prix-guesser` PR #1 — original
  catch (eslint, tsc wildcard form)
- Codex P2 review on `loganrooks/agentic-ops` PR #17 — verified
  the tsc wildcard defeat with tsc 6.0.3; flagged ADR-004 §Decision
  inconsistency
- [`ONBOARDING.md`](../../ONBOARDING.md) §"Per-repo customization
  checklist" — propagation surface
- [`.planning/phases/P7-onboarding.md`](../../.planning/phases/P7-onboarding.md)
  §"Per-repo configuration" — propagation surface
