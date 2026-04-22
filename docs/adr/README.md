# Architecture Decision Records (ADRs)

This folder holds **Architecture Decision Records** for the Biker project: short, durable write-ups of important design choices and their trade-offs.

## What

An ADR is a single Markdown file in this directory that captures **one** decision: the problem, what we chose, and what we gain or accept as a cost. Files are ordered with a numeric prefix (`0001-…`, `0002-…`) so history stays readable.

**Source of truth for format and process:** [.cursor/skills/adr-decision-entry/SKILL.md](../../.cursor/skills/adr-decision-entry/SKILL.md). Use that skill when creating or updating entries so naming, sections, and status workflow stay consistent.

## Why

- **Shared memory** — New contributors (and future you) see *why* something is the way it is, not only *what* the code does.
- **Fewer repeat debates** — Rejected options stay documented so the same discussion does not restart every quarter.
- **Safer evolution** — Superseding a decision means adding a new ADR and linking old and new, instead of silently overwriting intent.

## How

1. Decide that a choice is worth recording (meaningful trade-offs, boundaries, or long-lived constraints).
2. Open [.cursor/skills/adr-decision-entry/SKILL.md](../../.cursor/skills/adr-decision-entry/SKILL.md) and follow the checklist: next number in `docs/adr/`, template, status, and links.
3. Commit the new or updated file with the related code change when possible.

The project also includes a Cursor rule that **recommends** capturing an ADR when a conversation surfaces a significant architectural decision—see [.cursor/rules/adr-recommend-decision.mdc](../../.cursor/rules/adr-recommend-decision.mdc).
