# 11. Per-protocol sensor row identity in Settings

- **Status**: Accepted
- **Date**: 2026-05-02

## Context

A single BLE peripheral can advertise multiple GATT services that the app treats as separate sensor stacks (e.g. Cycling Speed and Cadence `0x1816` and Fitness Machine `0x1826`). Each manager uses `peripheral.identifier` as the sensor id, so the composite provider can emit two `Sensor` instances that share the same `Sensor.id` but differ in `Sensor.type`.

SwiftUI lists (`List`, `ForEach`) key rows by `Identifiable.id`. Reusing the bare peripheral UUID for every row caused duplicate ids, broken diffing, and wrong icons / bindings when both protocols appeared for one bike. Users still want **two rows** (one per protocol) to choose which stack to connect via.

## Decision

In Settings only, the **row identity** is `SensorRowID` = `(sensorID: UUID, type: SensorType)`, keyed on `(peripheral.identifier, Sensor.type)`. `Sensor.id` remains the peripheral UUID everywhere else; per-manager connect / disconnect / forget behavior is unchanged.

Navigation, swipe actions, and scan-tap connect all use `SensorRowID` so each row is unambiguous.

## Consequences

**Positive**: Multi-service peripherals show one row per supported protocol with stable list behavior and correct per-type chrome (icons, routing).

**Negative**: A single physical device can appear as N known rows. Forgetting one row forgets that protocol’s known record only; the user must forget each protocol row if they want both stacks cleared.

**Risks / follow-ups**: If future UX prefers a single merged row, that would be a separate product decision (e.g. dedupe + primary service picker) and would supersede this row model.
