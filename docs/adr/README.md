# Architecture Decision Records

This directory holds ADRs for decisions made *within* the `agentic-ops`
project as they land.

ADRs are not the project vision (see [VISION.md](../../VISION.md)).
ADRs are not the roadmap (see [ROADMAP.md](../../ROADMAP.md)). ADRs are
not unresolved tradeoffs (see [OPEN_QUESTIONS.md](../../OPEN_QUESTIONS.md)).

ADRs document **specific architectural choices that have been made**, what
alternatives were considered, and the consequences accepted. Each ADR
is numbered and dated.

## Format

Each ADR follows roughly:

```markdown
# ADR-NNN: <decision title>

Status: <status string — see "Status values" below>
Date: YYYY-MM-DD

## Context

What forced this decision? What constraints were active?

## Decision

What was chosen.

## Alternatives considered

What else was evaluated, and why each was rejected.

## Consequences

Positive: what this enables.
Negative: what this costs or forecloses.
Neutral: what changes but isn't clearly better/worse.
```

Filenames: `ADR-NNN-kebab-case-title.md` where `NNN` is zero-padded
to three digits.

## Status values

The status field captures (a) the ADR's lifecycle state and (b) any
relationship to a later ADR. The canonical Nygard / MADR statuses are
extended with three locally-defined conventions: `(provisional)`,
`amended by`, and `partially superseded by`. Each is documented below.

Lifecycle states (the part before any `;`):

- **`proposed`** — under discussion; not yet adopted.
- **`accepted`** — adopted; in force.
- **`accepted (provisional)`** *(local convention)* — adopted but
  explicitly subject to revision based on near-term evidence. Used
  when the ADR documents a working decision the team wants to revisit
  before committing to immutability.
- **`deprecated`** — no longer applicable; no replacement chosen.

Relationship clauses (optional, appended after `;`):

- **`superseded by ADR-MMM`** — replaced entirely by a later ADR. The
  prior decision is no longer authoritative; the new ADR is. Use this
  when a reader could safely ignore the old ADR after reading the new
  one.
- **`amended by ADR-MMM`** *(local convention)* — a later ADR extends
  this one additively without contradicting any of its decisions. The
  original ADR remains canonical for its scope; the amending ADR is
  canonical for the extension. Use this when readers still need the
  old ADR to understand the system.
- **`partially superseded by ADR-MMM (re: <named portion>)`** *(local
  convention)* — a later ADR contradicts and replaces a specific
  named portion of this one, but the remaining decisions stay in
  force. Use this when an ADR contains multiple sub-decisions and
  only some are replaced; the parenthetical names which portion.
  Mark the affected portion clearly in the body via inline note
  pointing at the superseding ADR.

Any relationship clause may optionally append a brief reason in
parentheses: `; amended by ADR-MMM (brief reason)`. Keep the
parenthetical short (≤80 chars) so the Status line stays scannable.
Longer rationale belongs in the amending/superseding ADR's body.

## When to amend, partially supersede, or supersede

The distinction matters because future readers need to know whether to
read both ADRs or only the new one.

**Use `supersedes` when** the new ADR fully replaces the prior
decision — contradicting it or rendering it inapplicable. Example:
"we chose substrate X; we now choose substrate Y." Readers should
consult the new ADR; the old one is preserved for historical context
only.

**Use `amends` when** the new ADR extends the prior decision
additively *without contradicting any portion of it*. Example:
"ADR-001 defined seven modes; ADR-NNN adds three matrix-variant
modes that compose with the original seven." Both ADRs are canonical
for their respective scopes. Readers should consult both.

**Use `partially superseded by` when** the new ADR contradicts one or
more named portions of the prior ADR but the rest stays in force.
Example: "ADR-002 had three decisions — L1→L3 ladder, reject L2,
threshold-based routing. ADR-NNN withdraws the routing decision but
the other two stand." Both ADRs are canonical for their respective
scopes, but the *amending* portion of the prior ADR is no longer
authoritative. Readers should consult both, but treat the named
portion of the prior ADR as historical.

**Use `deprecates`** when the decision no longer applies and no
replacement is needed.

A useful decision tree:

- Could a reader safely ignore the old ADR after reading the new
  one? → `supersedes`
- Are *all* prior decisions still in force, with the new ADR adding
  to them? → `amends`
- Are *some* prior decisions still in force but *others* contradicted
  by the new ADR? → `partially superseded by`
- Is the decision no longer applicable, with no replacement? →
  `deprecates`

## Editing rule

ADR bodies are immutable once `accepted`. Substantive edits — adding
context, changing the decision, expanding consequences — require a new
ADR (either superseding or amending).

**Exception:** the `Status:` line may be updated to reflect a later
ADR's relationship to this one. Specifically:

- `accepted` → `superseded by ADR-MMM`
- `accepted` → `accepted; amended by ADR-MMM`
- `accepted` → `accepted; partially superseded by ADR-MMM (re: <portion>)`
- `accepted` → `deprecated`
- `accepted (provisional)` may transition to any of the above on the
  same rules.

Additionally, when a `partially superseded by` relationship is added,
a single inline note may be added to the body of the superseded ADR
*adjacent to the affected portion* (pointing at the superseding ADR
section). This is the only body edit permitted. No other line may be
edited after acceptance.

## Numbering

ADRs are numbered sequentially. Numbers are never reused, even if an
ADR is superseded or deprecated. Look at the highest existing number
when creating a new ADR.

## Cross-references

When one ADR references another in its body, link explicitly:
`see [ADR-NNN](ADR-NNN-kebab-case-title.md)`. The Status-line
relationship is the formal record; in-body references are the
narrative record.
