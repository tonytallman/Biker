# Phase 09 — Cross-family metric selection + SEN-TYP-4/5 + 1 Hz guarantee

- **Status**: Done
- **Depends on**: Phases 07 (FTMS) and 08 (HR) for the full source mix

## Goal

Finalize the `PrioritizedMetricSelector` wiring so every metric has the
correct ordered source list, ties break deterministically, the CSC
multi-peripheral policy (SEN-TYP-4 / SEN-TYP-5) is explicit, and every
metric publishes at ≥1 Hz while a source is active (MET-GEN-3).

## Scope

### In

- **Speed selector** sources, in order:
  1. All connected `CyclingSpeedAndCadenceSensor` instances (multi-source
     step — see below).
  2. All connected `FitnessMachineSensor` instances providing speed.
  3. CoreLocation.
- **Cadence selector** sources, in order:
  1. All connected `CyclingSpeedAndCadenceSensor` instances providing
     cadence.
  2. All connected `FitnessMachineSensor` instances providing cadence.
- **Heart Rate selector** sources:
  1. All connected `HeartRateSensor` instances.
- **Distance-delta selector** (if kept): CSC (wheel revs × per-sensor
  wheel diameter) then CoreLocation.
- Multi-peripheral step at the same priority (the CSC and FTMS steps
  above can have multiple concurrent connections):
  - Deterministic tie-break: the source whose `id.uuidString` sorts
    first lexicographically wins, per
    [ADR-0006](../../adr/0006-metric-source-selection-at-app-level.md).
  - **SEN-TYP-5**: when a single CSC sensor exposes both wheel and
    crank data sufficient for both metrics, prefer that one CSC sensor
    for both CSC-derived speed and CSC-derived cadence over using two
    CSC sensors. Implementation note: the CSC manager exposes a
    `dualCapableSensor: AnyPublisher<UUID?, Never>` that the selector
    adapter consults to bias Cadence selection when its highest-priority
    source is CSC.
  - **SEN-TYP-4**: the CSC manager supports up to two simultaneously
    connected CSC peripherals by design (no code change beyond allowing
    two concurrent connections and per-sensor state — this phase
    primarily adds the test).
- **MET-GEN-3** — at least 1 Hz while a source is active:
  - Extend `PrioritizedMetricSelector` (or wrap its output in the
    `DependencyContainer`) with a 1 Hz repeat-tick that re-emits the
    most recent value while `isAvailable` is true. The tick source
    comes from `CoreLogic`'s `TimeService` pulse to avoid introducing
    another timer.
- Wheel-diameter application for CSC speed/distance lives in the CSC
  adapter/path (already in Phase 02/03), not in the selector
  (**MET-SPD-4**).
- Tests:
  - `PrioritizedMetricSelectorTests` — ordering, tie-break, unavailable
    behavior; 1 Hz re-emit while stale.
  - `CrossFamilyMetricSelectionTests` in `DependencyContainer` — mixed
    CSC + FTMS + GPS scenarios for speed and cadence; HR-only for heart
    rate.
  - `CSCDualSensorPreferenceTests` — SEN-TYP-5 preference fires when
    one sensor can supply both metrics.

### Out

- UI display logic for "unavailable" metrics (handled in `DashboardVM`
  already; any polish belongs to a follow-up task, not this phase).

## SRS / ADR coverage

- **MET-GEN-1/2/3**, **MET-SPD-1/2/3/4**, **MET-CAD-1/2/3**,
  **MET-HR-1/2/3**.
- **SEN-TYP-3/4/5**.
- Realizes [ADR-0006](../../adr/0006-metric-source-selection-at-app-level.md).

## Deliverables

- Updates to `CoreLogic/PrioritizedMetricSelector.swift` (or a
  wrapper in `DependencyContainer`) for 1 Hz re-emission and
  deterministic tie-break.
- Updated selector wiring in `DependencyContainer.init`.
- CSC manager additions for `dualCapableSensor` plumbing.
- Tests listed above.

## Acceptance criteria

- With two CSC sensors connected (one speed-only, one cadence-only),
  dashboard shows speed from the first and cadence from the second
  (**SEN-TYP-4**).
- With one CSC sensor exposing both, that single sensor is preferred
  for both metrics even if another CSC sensor is connected
  (**SEN-TYP-5**).
- Switching off the top-priority source promotes the next priority
  source with no gap longer than 1 s in dashboard output
  (**MET-GEN-3**).
- All metric-selector tests pass, plus existing suites.

## Risks / follow-ups

- Re-emitting stale values can mask sensor stalls; pair with a
  "staleness timeout" in a later phase if user-visible behavior
  suffers.
- The deterministic tie-break uses `UUID.uuidString` ordering; document
  that choice in code comments and in the ADR's tie-break note.
