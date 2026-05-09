# ADR-003: Versioning and release of the reusable workflow

Status: accepted
Date: 2026-05-08

## Context

`agentic-ops` exists as a centralized GitHub Actions reusable-workflow
substrate. Multiple consumer repos under `loganrooks/*` (today: cbm,
prix-guesser, arxiv-sanity-mcp, f1-modeling, epistemic-agency, scholardoc)
will consume it via thin caller stubs of the form:

```yaml
uses: loganrooks/agentic-ops/.github/workflows/review.yml@<ref>
```

The whole point of the substrate model (per VISION.md and ROADMAP.md
Phase S2/S3/M1) is that a fix made in one place propagates to all
consumers. If consumers had to manually bump a version pin in every
repo for every patch — including security patches to the wrapper script
or sanitization layer — the central-substrate model loses most of its
value. The substrate would degrade into "yet another vendored
boilerplate," which is the failure mode S2 was designed to escape.

At the same time, breaking the consumer caller stubs without warning is
unacceptable. Consumers need a stable contract: the inputs they pass,
the modes they invoke, and the outputs they read must continue to work
across non-breaking changes. There has to be a way to make a deliberately
breaking change without silently breaking six repos at once.

The active constraints when this decision was made:

- The substrate is small (one workflow, a wrapper script, a prompt body).
  Heavy release tooling would be over-engineering.
- The consumer count is small (six repos, all owned by the same user).
  Coordinating a breaking-change migration is tractable today; it will
  not always be.
- The consumers are all caller stubs invoked by `workflow_call`. The
  contract surface is just the inputs/secrets/outputs declared in
  `review.yml`'s `on: workflow_call` block.
- CI on `agentic-ops` already blocks merges that fail validation, so
  any commit on `main` after CI green is, by construction, a known-good
  state.

## Decision

`v1` is a floating major-version Git tag. Minor and patch updates land
on it transparently. Breaking changes cut a new major (`v2`) and
require explicit consumer migration.

### The additivity contract on v1

A change is **additive** (lands on `v1`) if it does not change the
behavior of an existing caller stub that does not opt in. Specifically:

- Adding a new optional input with a non-breaking default → v1
- Adding a new mode (e.g. a new `@claude` trigger phrase) → v1
- Adding a new optional secret → v1
- Adding a new internal step that callers do not directly observe → v1
- Tightening a default in a way that does not break callers passing the
  input explicitly → v1

A change is **breaking** (requires `v2`) if it changes the behavior of
an existing caller stub that has not opted in. Specifically:

- Removing a mode
- Removing or renaming an input
- Changing an input's default in a way that changes behavior for
  callers relying on the default
- Adding a required input
- Changing the output schema of any step a caller might consume

### Release process

After every merge to `main`, once CI is green on the merge commit:

```
git checkout main && git pull
git tag -f v1 <merge-sha>
git push origin v1 --force
```

The CI gate is what makes this safe: `v1` only ever points at a commit
that has passed validation. The tag move is mechanical and
deterministic — it is not a judgment call about whether the change
"deserves" to be released.

For `v2` cuts (breaking changes), the process is:

1. Land the breaking change behind a feature flag or in a parallel file
   when feasible, so v1 stays alive.
2. When ready to cut over, tag `v2` at the breaking-change merge SHA.
3. Stop force-updating `v1` at that point. Open issues against each
   consumer to migrate from `v1` to `v2` on their own schedule.
4. Keep `v1` as a frozen tag at the last pre-break commit so consumers
   that have not migrated are unaffected.

### Pinning options for consumers

Consumers choose where on the stability/transparency spectrum they want
to sit:

- `@v1` — floating tag. Gets fixes (including security fixes)
  transparently. Recommended default. This is what the cbm caller stub
  uses today.
- `@<merge-sha>` — pinned to a specific commit. Maximum stability; no
  surprises. Trades transparent fixes for explicit upgrade control.
  Appropriate for a consumer that is in a sensitive freeze window or
  does not want the substrate to change underneath them without a PR.
- `@v2` (when it exists) — same floating-tag semantics as v1, just the
  next major.

Consumers do not pin to `@main`. See alternatives.

### Third-party action SHAs inside the substrate

Inside `agentic-ops` itself, every third-party `uses:` reference is
pinned to a full commit SHA with a comment naming the version
(e.g. `actions/checkout@de0fac... # v6.0.2`). This is independent of the
v1/v2 question — it is a defense-in-depth measure against compromised
upstream actions. The cbm caller stub already follows this discipline
and the substrate inherits it.

## Alternatives considered

**Strict semantic versioning (v1.2.3) with explicit consumer pinning.**
Rejected. Consumers would have to manually bump `@v1.2.3` to `@v1.2.4`
for every patch. With six consumers, that is six PRs per fix — including
six PRs to roll out a security patch. This defeats the substrate's core
value proposition: a fix in one place propagates everywhere.
Semantic-version *tags* still exist implicitly (a v1 cut is a major
bump), but consumers do not pin to minor or patch.

**No floating tag — always pin SHA in consumers.** Rejected for the same
reason. Worse, actually: consumers must update for every fix, and the
update is not even mechanically derivable (it is a fresh SHA each time).
Makes the central-substrate model worthless. The SHA-pinning option
remains available to individual consumers who want it on a per-repo
basis.

**Branch-as-version (`uses: ...@main`).** Rejected. `main` can briefly
be in an inconsistent state between merge and CI completion: the merge
commit appears on `main` instantly, but CI takes minutes to validate it.
A consumer firing during that window picks up a possibly-broken
substrate. The floating tag, by contrast, only moves after CI green, so
it is always pointing at a known-good commit.

**Semantic-release / automated changelog generation.** Deferred. The
project is small enough that manual changelog discipline (commit
messages on the substrate side, release notes attached to v2 cuts) is
adequate. Revisit if the consumer count grows past about 10 or if
ROADMAP M-phase introduces enough specialists that release notes
become genuinely informative rather than ceremonial.

**A `next` / pre-release tag for risky changes.** Considered and
deferred. The CBM scratch-PR smoke test (see Consequences) covers the
"is this change safe to release" question well enough at current scale.
A `next` tag adds a coordination surface without clear value yet.

## Consequences

### Positive

- Consumers get fixes — including security fixes to the wrapper script,
  sanitization layer, and prompt-injection defenses (per VISION
  commitment 5, "defense in depth") — transparently, with no per-repo
  PR. This is exactly the substrate value the project exists to deliver.
- One-step release process. After CI green, `git tag -f v1 && git push
  --force` is the entire ceremony. Low cognitive load means it actually
  happens reliably, which means consumers actually get fixes promptly.
- Aligns with how widely-used GHA reusable workflows operate
  (`actions/setup-node@v4`, `actions/checkout@v6`, etc.). Consumers
  encountering the `@v1` pattern in caller stubs will recognize it and
  not need to learn a project-specific convention.
- The v1/v2 boundary forces a deliberate moment when making a breaking
  change. There is no path to "accidentally break six consumers at
  once" — that requires explicitly cutting v2, which surfaces the
  decision.
- Pinned third-party action SHAs inside the substrate close the
  upstream-compromise channel that floating-tag references would open.

### Negative

- A regression that slips through CI propagates immediately to all
  consumers. The substrate's strength is also its blast radius.
  Mitigation: smoke-test on a CBM scratch PR before any non-trivial
  merge. The empirical gate at the project's mid-execution checkpoint
  (the M-phase decision points in ROADMAP) catches survey/audit
  regressions specifically. CI has to actually catch what matters; if
  it does not, that is a postmortem-worthy event under VISION
  commitment 7.
- Requires force-pushing the `v1` tag, which is generally an
  antipattern. This is the **only** documented exception to the
  project's "no force-push" rule. Force-pushing `v1` is allowed and
  expected; force-pushing any branch (including `main`), or any other
  tag, is not.
- Breaking changes are expensive at the moment they happen: cutting v2
  means six consumer migrations. This pressure is desirable — it
  discourages frivolous breaking changes — but it does mean that a
  legitimately-needed breaking change will sit longer than it would
  under stricter SemVer.
- The additivity contract has to be enforced by reviewer judgment. There
  is no automated check that "this PR does not change an input's
  default in a behavior-changing way." A reviewer auditing a substrate
  PR has to read the diff against this ADR. Mitigation: the contract
  surface is small (the `inputs:`, `secrets:`, and `outputs:` blocks of
  `review.yml`), so a diff against those blocks is the audit.

### Neutral

- The `v1` force-update step can be semi-automated by a GHA workflow
  that fires on push-to-main and waits for CI green. Doing this
  manually for now is fine; revisit when the friction is observable
  (likely after M1 onboards the remaining five consumers and merge
  cadence picks up).
- This ADR does not address how `v2` is announced to consumers. At
  current scale (one user, six repos) a verbal/issue-based announcement
  is sufficient. If this project moves toward OQ-1's "open-source
  product" branch, a release-notes discipline tied to v2 cuts will
  need to be formalized, but that is downstream of this decision.
- Consumers retain the ability to pin a SHA. This is documented and
  supported, not discouraged. Different consumers can sit at different
  points on the stability/transparency tradeoff without the substrate
  needing to know.
