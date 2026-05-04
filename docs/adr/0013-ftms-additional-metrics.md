# 13. FTMS heart rate and elapsed time as metric sources

- **Status**: Accepted
- **Date**: 2026-05-04
- **Supersedes**: (none)
- **Superseded by**: (none)

## Context

Fitness Machine Indoor Bike Data (UUID `0x2AD2`) can include **instantaneous heart rate** (Heart Rate Present flag, octet units in BPM per FTMS profile) and **elapsed time** (Elapsed Time Present flag, UInt16 seconds). Prior implementation advanced the payload cursor past those fields without surfacing values. Heart rate from a dedicated strap uses Heart Rate Service (`0x180D`), but many trainers also publish HR via FTMS while the rider is on the erg. Ride **elapsed time** is currently synthesized from **`TimeService`** ticks summed in **`AccumulatingMetric<UnitDuration>`** while the ride is active; trainers often expose authoritative workout-elapsed clock time via FTMS.

## Decision

1. **Parsing** — Extend Indoor Bike Data parsing so `Heart Rate Present` yields a BPM value (`Double`) and `Elapsed Time Present` yields seconds (`UInt16` → `Double`).

2. **Publishing** — `FitnessMachineSensor` exposes optional raw BPM optional stream and **`Measurement<UnitDuration>`** elapsed stream (plus compact-mapped equivalents), mirroring existing speed/cadence patterns.

3. **Cross-type priority**
   - **Heart rate**: **HRS (`0x180D`) → FTMS** (same rationale as CSC > FTMS for speed: dedicated sensor beats superset on the trainer when both exist).
   - **Elapsed time**: **FTMS elapsed time → internal ride accumulator** (`TimeService` + `AccumulatingMetric`). Dashboard `time` is driven by a **`PrioritizedMetricSelector<UnitDuration>`** mixing those sources.

4. **Tie-break among multiple FTMS sensors** — Lowest peripheral **`UUID.uuidString` lex order** among connected producers (ADR-0006 pattern), implemented in `FTMSPeripheralLexMetrics`.

## Consequences

**Positive**: One fewer connected device needed when trainer supplies HR/time; coherent timer against equipment clock when advertised.

**Negative**: When switching from FTMS elapsed time back to the local accumulator, displayed time reflects two different clocks (potential jump — accepted). Trainers omitting elapsed time in every packet replicate existing stale-field behavior alongside speed/cadence.

**Risks / follow-ups**: SRS `MET-HR-2` and new `MET-TIME-*` requirements; no persistence of elapsed/HR blobs; stale HR if trainers omit HR flag inconsistently across notifications.
