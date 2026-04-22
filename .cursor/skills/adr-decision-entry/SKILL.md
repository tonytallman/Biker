---
name: adr-decision-entry
description: >-
  Adds or updates Architecture Decision Records (ADRs) under docs/adr/ using the
  project’s filename, template, and status workflow. Use when recording a design
  decision, superseding an old ADR, onboarding ADR practice, or when the user
  mentions ADRs, architecture decisions, trade-offs, or the docs/adr/README.
---

# Architecture Decision Records (ADR)

This file is the procedural source of truth for ADR entries. Read [docs/adr/README.md](../../../docs/adr/README.md) only when background on ADR purpose in this repo is useful.

## When to add an ADR

Add one when a decision is significant, stable enough to document, and costly to rediscover later. Examples: dependency boundaries, persistence strategy, concurrency model, module layout, or a rejected alternative likely to come up again.

Skip an ADR for trivial refactors, one-line fixes, or choices already obvious from code alone.

## File location and naming

- **Directory**: `docs/adr/` at the repository root.
- **Name**: `NNNN-short-title-in-kebab-case.md` where `NNNN` is zero-padded decimal order (for example `0001`, `0002`). Use the next free number in `docs/adr/`.
- **One decision per file** unless superseding requires explicit linkage.

## Document template

Create a new file with this structure:

```markdown
# N. Short title

- **Status**: Proposed | Accepted | Deprecated | Superseded
- **Date**: YYYY-MM-DD
- **Supersedes**: (optional) link to older ADR filename, e.g. `0001-original-choice.md`
- **Superseded by**: (optional) leave empty until replaced

## Context

Problem, constraints, and relevant options.

## Decision

Chosen approach in plain language.

## Consequences

**Positive**: Benefits.

**Negative**: Trade-offs or accepted costs.

**Risks / follow-ups**: Things to monitor or do next.
```

## Status workflow

1. **Proposed** — under review or not yet reflected fully in code.
2. **Accepted** — team agrees; implementation may still be in progress.
3. **Deprecated** — no longer recommended; keep file for history.
4. **Superseded** — another ADR replaces this one; link both ways (`Supersedes` / `Superseded by`).

When superseding, create a new numbered file for the new decision. Update the old file’s status and links rather than rewriting history.

## Process checklist

1. Confirm an ADR is appropriate.
2. Allocate the next `NNNN` in `docs/adr/`.
3. Copy the template and fill **Context**, **Decision**, and **Consequences** with concrete terms.
4. Set **Status** and **Date**.
5. Land it with the related change when practical, or in a small follow-up if discovered late.

## Cross-references

- Link related ADRs, issues, or PRs in **Context** or **Consequences**.
