# 3. CyclingSpeedAndCadenceSensor as a first-class type

- **Status**: Accepted
- **Date**: 2026-04-22
- **Supersedes**: (none)
- **Superseded by**: (none)

## Context

The current `BluetoothSensorManager` in `CyclingSpeedAndCadenceService` combines `CBCentralManager` and scanning, `CBPeripheral` delegate work for CSC, and per-peripheral `CSCDeltaCalculator` state and `CSCMeasurementParser` use in a single type. The SRS also requires **up to two** simultaneous CSCS peripherals when one supplies speed and another cadence ([SEN-TYP-4](../srs/Sensors.md)), and a **preference rule** when one sensor supplies both ([SEN-TYP-5](../srs/Sensors.md)). A clear ownership boundary per peripheral is needed for testing and for per-sensor **wheel diameter** and **enabled** state ([SEN-KNOWN-8](../srs/Sensors.md), [SEN-PERS-1](../srs/Sensors.md)).

## Decision

1. **`CyclingSpeedAndCadenceSensorManager`** owns `CBCentralManager`, scan for CSC UUIDs, connect/disconnect orchestration, restore-on-launch, and **policy** for which connected CSCS peripherals feed published manager-level speed/cadence (SEN-TYP-4, SEN-TYP-5).

2. **`CyclingSpeedAndCadenceSensor`** (one instance per known/connected logical peripheral) owns its `CBPeripheral` as `CBPeripheralDelegate` for the CSC service/characteristic path; a `CSCDeltaCalculator` (with **wheel circumference** derived from user wheel diameter for that sensor); streams for speed/cadence/availability as needed by the manager and metric adapters; and user state: **enabled** flag, **wheel diameter** (persisted per [5. Per-manager persistence stores](0005-per-manager-persistence-stores.md)).

3. **`CSCMeasurementParser`** remains a **stateless** `enum` (or static functions); parsing does not require `CBPeripheral`.

4. **`CyclingSpeedAndCadenceSensor`** conforms to **`Sensor`** and **`WheelDiameterAdjustable`** as defined in [2. Per-sensor capability protocols](0002-per-sensor-capability-protocols.md), via app-layer / adapter wiring as appropriate.

## Consequences

**Positive:** Clear unit-test surface: parser and calculator independent of Core Bluetooth; sensor type mockable; manager testable with fake central. SEN-TYP-4/5 policy lives in one place (the manager) while each sensor exposes raw per-peripheral metrics.

**Negative:** More types and files than a monolithic manager; the composition root must construct and wire them, as described in [8. No singletons for sensor managers](0008-no-singletons-for-sensor-managers.md).

**Risks / follow-ups:** Keep manager arbitration logic [6. Metric source selection at the app level](0006-metric-source-selection-at-app-level.md) separate from per-sensor streams so dashboard priority remains app-level, not per-manager.
