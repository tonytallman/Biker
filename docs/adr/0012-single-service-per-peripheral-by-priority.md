# 12. Single service exposed per peripheral (FTMS > CSCS > HRS)

- **Status**: Accepted
- **Date**: 2026-05-04
- **Supersedes**: `0011-per-protocol-sensor-row-identity.md`
- **Superseded by**: (none)

## Context

Some BLE peripherals advertise or implement multiple GATT service families that the app maps to distinct sensor stacks (`SensorType`), e.g. an indoor bike with Fitness Machine (FTMS), Cycling Speed and Cadence (CSCS), and Heart Rate (HRS). For typical trainers, FTMS is a superset of what CSCS and HRS offer on that same physical device.

[11. Per-protocol sensor row identity in Settings](0011-per-protocol-sensor-row-identity.md) addressed duplicate `Sensor.id` in SwiftUI by keying rows as `(peripheral UUID, SensorType)`. That model made multi-service devices show **multiple rows** for the same peripheral, with extra forget/disconnect complexity.

## Decision

1. Each peripheral UUID SHALL appear at most **once** in merged **known** and **discovered** sensor lists exposed to Settings: keep the **highest-precedence** `SensorType` for that `Sensor.id` using this order: **FTMS → CSCS → HRS** (lower index = higher priority).

2. **Deduplication** is applied in **`CompositeSensorProvider`** when merging per-family `SensorProvider` streams, before global ordering (SEN-SCAN-7/8) and name sort for known sensors.

3. **Row identity** in Settings returns to **`Sensor.id`** (BLE `peripheral.identifier`) alone; per-protocol row keys are removed.

4. **UI-only enforcement**: lower-priority per-type managers may still scan, persist known sensors, and auto-reconnect on their own; those entries are simply **omitted** from the composite’s merged lists. No cross-manager `forget()` or migration is required as part of this decision.

## Consequences

**Positive**: Static capabilities per row in UI; one icon and one Settings row per physical device; simpler navigation and actions than ADR-0011.

**Negative**: If a device exposed only CSCS+HRS but not FTMS, the UI would show a single CSCS row (CSCS wins over HRS); choosing HR-only connection for that edge case is not represented as a second row (theoretical).

**Risks / follow-ups**: Stale known records in a non-winning manager can still run until the user forgets them through a future flow or we add explicit cleanup. Metric source ordering (`MET-SPD-2`, etc.) remains unchanged at the selector layer; multi-service devices are expected to surface primarily as FTMS to the app when present.
