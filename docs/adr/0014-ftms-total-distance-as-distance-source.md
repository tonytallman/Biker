# 14. FTMS Total Distance as authoritative distance source

- **Status**: Accepted
- **Date**: 2026-05-04
- **Supersedes**: (none)
- **Superseded by**: (none)

## Context

Fitness Machine Indoor Bike Data already parses **Total Distance** (UInt24 cumulative meters when the Total Distance flag is present) into `totalDistanceMeters`, and feeds the **distance-delta pipeline** (`distanceDelta`): successive totals produce deltas consumed by CSC + GPS + FTMS deltas in **`PrioritizedMetricSelector`**, summed in **`AccumulatingMetric<UnitLength>`** for dashboard distance. Separately from that delta-derived ride total, the trainer publishes an authoritative **absolute** cumulative Total Distance alongside optional speed-integration deltas when totals are omitted.

Users want dashboard distance to mirror the trainer Total Distance whenever it is advertised, even though that cumulative may include pre-session distance or reset semantics defined by firmware (not bounded by ride start or auto-pause).

## Decision

1. **Publishing — per sensor** — `FitnessMachineSensor` publishes optional raw meters via `totalDistanceMetersOptional`, and `totalDistance` (`Measurement<UnitLength>` in meters) updated whenever a parsed packet includes `totalDistanceMeters`. The existing **delta** path and speed-integration fallback are unchanged; both may advance the local accumulator in parallel.

2. **Lex** — `FTMSPeripheralLexMetrics` exposes `totalDistance: AnyMetric<UnitLength>` from per-sensor snapshots, with **lowest `UUID.uuidString` lex order** among connected producers (ADR-0006), reusing the same scalar pick helpers as distance-delta / HR / elapsed scalars.

3. **Cross-type priority** — Dashboard **distance** is driven by **`PrioritizedMetricSelector<UnitLength>`** with sources, highest first: **FTMS Total Distance** → **local ride accumulator** (existing `AccumulatingMetric` fed by `[FTMS, CSC, GPS]` distance-delta selector). Retain **`metricTick`** for MET-GEN-3 behavior.

4. **DEBUG builds** — Fakes omit FTMS; keep `distancePublisher` from **`distanceMetric.publisher`** only (no outer selector).

## Consequences

**Positive**: Matches trainer-displayed cumulative distance when the Total Distance bit is supplied; reflects equipment-reported odometer-style totals when present.

**Negative**: Absolute Total Distance ignores ride boundaries and auto-pause on the authoritative path — **accepted**. Switching FTMS ↔ accumulator can cause **display jumps**, including on reconnect (**accepted**, parallel to ADR-0013 elapsed-time behavior). Firmware may omit Total Distance sporadically; availability follows BLE notifications.

## Risks / follow-ups

- SRS **`MET-DIST-*`** plus `MET-GEN-1` list update; architecture traceability refresh.
- No persistence of trainer Total Distance; no anchoring to ride start unless a future ADR adds it.
