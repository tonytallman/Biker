# 4. CompositeSensorProvider at the composition root

- **Status**: Accepted
- **Date**: 2026-04-22
- **Supersedes**: (none)
- **Superseded by**: (none)

## Context

Settings needs a **single** list of known sensors and a **single** list of discovered devices across **CSC, FTMS, and Heart Rate** ([SEN-TYP-1](../srs/Sensors.md)). The SRS defines **global ordering** for the scan list: connected first, then by RSSI descending, then by localized case-insensitive name ([SEN-SCAN-7](../srs/Sensors.md)), and stability within a single frame except on connection or RSSI change ([SEN-SCAN-8](../srs/Sensors.md)). If each per-type manager applied its own ordering in isolation, there would be no single ordered union without duplicating policy in `SettingsVM` (which must not know sensor types) or in each package (which would duplicate cross-type rules).

## Decision

1. Introduce **`CompositeSensorProvider`** (or equivalent name) implemented in **`DependencyContainer`** (or a dedicated type only referenced from the composition root).

2. The composite holds references to **`CyclingSpeedAndCadenceSensorManager`**, **`FitnessMachineSensorManager`**, and **`HeartRateSensorManager`** (and any future providers); **merges** `knownSensors` / `discoveredSensors` (or the streams that back them) into arrays of **`any Sensor`** / shared discovery DTOs; **applies SEN-SCAN-7 ordering** (and SEN-SCAN-8 stability rules) at merge time; forwards **scan** start/stop to **all** types that participate in SEN-SCAN-4; and exposes the **`SensorProvider`** surface expected by `SettingsVM`.

3. **Individual manager packages** do not depend on each other; they do not know about the composite.

4. The composite may also reduce **`bluetoothAvailability`** from managers per [7. BluetoothAvailability as first-class state](0007-bluetooth-availability-as-first-class-state.md), and it receives injected manager instances per [8. No singletons for sensor managers](0008-no-singletons-for-sensor-managers.md).

## Consequences

**Positive:** Cross-type policy is **one place**; changes to ordering or merge rules are localized. `SettingsVM` and `SettingsUI` stay **sensor-type-agnostic**; they only see `SensorProvider` and `any Sensor`.

**Negative:** The composition root grows; integration tests should cover the composite’s ordering and fan-out for scan. Slightly more indirection when debugging (always check composite + child manager).

**Risks / follow-ups:** If multiple `CBCentralManager` instances are ever required, define explicitly how the composite maps to each (out of scope until needed).
