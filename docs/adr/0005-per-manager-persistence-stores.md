# 5. Per-manager persistence stores

- **Status**: Accepted
- **Date**: 2026-04-22
- **Supersedes**: (none)
- **Superseded by**: (none)

## Context

The SRS requires per known sensor, across launches: **identifier, last known name, sensor type, enabled state**, and for **CSCS** sensors **wheel diameter** ([SEN-PERS-1](../srs/Sensors.md)). A single `UserDefaults` blob keyed e.g. `knownSensors` with only `id` and `name` cannot represent type-specific fields or enabled state, and conflates all types into one untyped array.

## Decision

1. Each **`SensorManager`** (or a small `KnownSensorStore` type owned by that package) is responsible for **persisting and restoring** its own known sensors to **`AppStorage` / `UserDefaults`** (namespaced as appropriate).

2. **Schemas are typed per family:** **CSC:** `id` (UUID), `name` (String), `sensorType` (or implicit), `isEnabled` (Bool), `wheelDiameter` (e.g. `Measurement<UnitLength>` or meters as `Double`) with a documented default for new sensors ([SEN-KNOWN-9](../srs/Sensors.md)). **FTMS / HR:** same fields **except** wheel diameter.

3. **Migration:** On first run after this change, read the legacy `knownSensors` payload if present, migrate into the appropriate per-manager store(s), then **remove** the old key to avoid double sources of truth. Exact migration steps belong in implementation work items.

4. **On connect** from scan or other flows, the owning manager **appends** to its store and defaults **enabled** to true ([SEN-SCAN-11](../srs/Sensors.md)).

Wheel diameter on the sensor instance is [3. CyclingSpeedAndCadenceSensor as a first-class type](0003-cycling-speed-and-cadence-sensor-as-first-class-type.md). Editing in UI is [2. Per-sensor capability protocols](0002-per-sensor-capability-protocols.md). The **composite** in [4. CompositeSensorProvider at the composition root](0004-composite-sensor-provider-at-composition-root.md) still presents one logical list while persistence remains split by family.

## Consequences

**Positive:** Type-specific fields stay next to the code that enforces invariants (e.g. wheel diameter only for CSC). No giant untyped JSON blob in Settings or DependencyContainer.

**Negative:** Multiple keys and migration logic; must document key names in one place (README or `KnownSensorStore` type). "Global" known-sensor list is **logical** only — physically split across stores.

**Risks / follow-ups:** Migration from the legacy key must be tested on real device restores of old app data.
