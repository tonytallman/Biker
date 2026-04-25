# Sensors Implementation Plan

Phased plan to implement the target architecture described in
[docs/architecture/Sensors.md](../../architecture/Sensors.md) against the
requirements in [docs/srs/Sensors.md](../../srs/Sensors.md) and the
decisions in [docs/adr/](../../adr/).

Each phase is a self-contained unit of work that produces a buildable,
testable increment. Every phase file contains:

- **Goal** — one-line purpose.
- **Scope (in / out)** — what's included and what's explicitly deferred.
- **SRS / ADR coverage** — requirement and decision IDs addressed.
- **Deliverables** — files, protocols, types, tests to add or change.
- **Acceptance criteria** — observable, testable outcomes.
- **Risks & follow-ups**.
- **Depends on** — prior phases that must land first.

Each phase will be **individually planned and executed in a separate
Cursor session**. This document is only the breakdown; detailed API
shapes and naming are finalized inside each phase.

## Dependency graph

```
01 ──► 02 ──► 03 ──► 04 ──► 05 ──► 06 ──► 07 ──► 08 ──► 09 ──► 10
         │            │       │
         └────────────┴───────┘  (03, 04 build on 02; 05 requires 01 + 04)
```

## Phases

1. [Phase 01 — Core sensor abstractions in `SettingsVM`](phase-01-core-abstractions.md)
2. [Phase 02 — CSC first-class per-peripheral type + manager split](phase-02-csc-first-class.md)
3. [Phase 03 — Per-manager typed persistence (CSC) + legacy migration](phase-03-csc-persistence.md)
4. [Phase 04 — `BluetoothAvailability` + permission/power UI behavior](phase-04-bluetooth-availability.md)
5. [Phase 05 — `CompositeSensorProvider` at the composition root](phase-05-composite-provider.md)
6. [Phase 06 — Sensor Details screen + capability wiring](phase-06-sensor-details.md)
7. [Phase 07 — Fitness Machine Service (FTMS) package](phase-07-ftms-package.md)
8. [Phase 08 — Heart Rate Service package + BPM metric](phase-08-heart-rate-package.md)
9. [Phase 09 — Cross-family metric selection + SEN-TYP-4/5 + 1 Hz guarantee](phase-09-metric-selection.md)
10. [Phase 10 — Integration tests & polish](phase-10-integration-tests.md)

## Status legend

Update the status line at the top of each phase file as work progresses:

- `Not started`
- `In progress — <branch or PR>`
- `Done — <commit / PR link>`
- `Blocked — <reason>`
