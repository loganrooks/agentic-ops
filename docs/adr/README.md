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

This project uses five status values. Four are canonical (per Nygard's
original ADR pattern + MADR); the fifth (`amended by`) is a local
convention documented below.

- **`proposed`** — under discussion; not yet adopted.
- **`accepted`** — adopted; in force.
- **`superseded by ADR-MMM`** — replaced by a later ADR that occupies
  the same decision space. The prior decision is no longer authoritative;
  the new ADR is.
- **`deprecated`** — no longer applicable; no replacement chosen.
- **`accepted; amended by ADR-MMM`** *(local convention)* — the
  decision in this ADR remains in force, but a later ADR has extended
  the decision space additively. The original ADR is still canonical
  for its scope; the amending ADR is canonical for the extension.

## When to amend vs. supersede

The distinction matters because future readers need to know whether to
read both ADRs or only the new one.

**Use `supersedes` when** the new ADR replaces the prior decision —
either contradicting it or rendering it inapplicable. Example: "we
chose substrate X; we now choose substrate Y." Readers should consult
the new ADR; the old one is preserved for historical context only.

**Use `amends` when** the new ADR extends the prior decision additively
without contradicting it. Example: "ADR-001 defined seven modes; ADR-NNN
adds three matrix-variant modes that compose with the original seven."
Both ADRs are canonical for their respective scopes. Readers should
consult both.

**Use `deprecates`** when the decision no longer applies and no
replacement is needed.

A useful test: if a reader could safely ignore the old ADR after reading
the new one, use `supersedes`. If they still need the old ADR to
understand the system, use `amends`.

## Editing rule

ADR bodies are immutable once `accepted`. Substantive edits — adding
context, changing the decision, expanding consequences — require a new
ADR (either superseding or amending).

**Exception:** the `Status:` line may be updated to reflect a later
ADR's relationship to this one. Specifically:

- `accepted` → `superseded by ADR-MMM` when a later ADR supersedes it
- `accepted` → `accepted; amended by ADR-MMM` when a later ADR amends it
- `accepted` → `deprecated` when the decision no longer applies

These edits are metadata-only and preserve the original decision text
intact. No other line may be edited after acceptance.

## Numbering

ADRs are numbered sequentially. Numbers are never reused, even if an
ADR is superseded or deprecated. Look at the highest existing number
when creating a new ADR.

## Cross-references

When one ADR references another in its body, link explicitly:
`see [ADR-NNN](ADR-NNN-kebab-case-title.md)`. The Status-line
relationship is the formal record; in-body references are the
narrative record.
