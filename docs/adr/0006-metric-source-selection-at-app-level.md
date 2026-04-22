# 6. Metric source selection at the app level

- **Status**: Accepted
- **Date**: 2026-04-22
- **Supersedes**: (none)
- **Superseded by**: (none)

## Context

The SRS defines **per-metric** priority among sources ([MET-SPD-2](../srs/Sensors.md), [MET-CAD-2](../srs/Sensors.md), [MET-HR-2](../srs/Sensors.md)), **ties** at the same priority step ([MET-GEN-2](../srs/Sensors.md)), and that **Speed** and **Cadence** may use **different** physical sensors ([SEN-TYP-3](../srs/Sensors.md)). It also requires **wheel diameter** when deriving speed from CSC wheel revolutions ([MET-SPD-4](../srs/Sensors.md)). If each `SensorManager` claimed to be the source of truth for dashboard metrics in isolation, those rules would be impossible to satisfy without cross-type knowledge inside every manager.

## Decision

1. Each **`SensorManager`** exposes **typed metric streams** suitable for adaptation, e.g. `AnyMetric<UnitSpeed>`, `AnyMetric<UnitFrequency>`, `AnyMetric<UnitLength>` (for distance deltas), via small **adapters** in `DependencyContainer` (same pattern as existing `BLEMetricAdaptors`).

2. **`PrioritizedMetricSelector`** (or equivalent) in **`DependencyContainer`** wires **one selector per metric** (Speed, Cadence, Heart Rate, distance delta if applicable) with an **ordered list of sources** matching the SRS priorities (CSC before FTMS before CoreLocation for Speed, etc.).

3. **Tie-break** at the same priority step: use a **deterministic** rule documented in code, e.g. **lowest peripheral `UUID` as `String` lexicographic order** among tied connected sources. Any deterministic rule is acceptable if it is **stable** for a given set of connections.

4. **Managers do not** encode cross-type priority; they only publish "this is my speed if I have it" style streams.

5. **MET-SPD-4:** CSC speed/distance derivation uses the **wheel diameter stored for that CSC sensor** ([5. Per-manager persistence stores](0005-per-manager-persistence-stores.md), [3. CyclingSpeedAndCadenceSensor as a first-class type](0003-cycling-speed-and-cadence-sensor-as-first-class-type.md)) inside the CSC adapter/manager path, not inside the selector.

Per-sensor CSC streams feeding adapters are described in [3. CyclingSpeedAndCadenceSensor as a first-class type](0003-cycling-speed-and-cadence-sensor-as-first-class-type.md). The module map and sequence diagram are in [docs/architecture/Sensors.md](../architecture/Sensors.md).

## Consequences

**Positive:** Single place to audit priority and ties; matches existing `DependencyContainer` direction. New sensor types add a new adapter plus one line in the priority list.

**Negative:** The selector must receive **availability** per source correctly so `MET-GEN-2` unavailability behavior holds.

**Risks / follow-ups:** **MET-GEN-3** (≥1 Hz while active) may require combining selector output with a timer; document in implementation when wiring `CoreLogic` / `DependencyContainer`.
