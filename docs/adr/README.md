# Architecture Decision Records

This directory holds ADRs for decisions made *within* the `agentic-ops`
project as they land.

ADRs are not the project vision (see [VISION.md](../../VISION.md)).
ADRs are not the roadmap (see [ROADMAP.md](../../ROADMAP.md)). ADRs are
not unresolved tradeoffs (see [OPEN_QUESTIONS.md](../../OPEN_QUESTIONS.md)).

ADRs document **specific architectural choices that have been made**, what
alternatives were considered, and the consequences accepted. Each ADR
is numbered and dated; existing ADRs are not edited (only superseded).

This directory is currently empty. The first ADR will likely emerge from
the substrate choice in Phase S2 (extracting the centralized workflow)
or from the severity/output format decision in M2.

## Format

Each ADR follows roughly:

```markdown
# ADR-NNN: <decision title>

Status: proposed | accepted | superseded by ADR-MMM | deprecated
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
