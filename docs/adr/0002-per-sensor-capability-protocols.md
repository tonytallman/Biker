# 2. Per-sensor capability protocols

- **Status**: Accepted
- **Date**: 2026-04-22
- **Supersedes**: (none)
- **Superseded by**: (none)

## Context

The Sensors SRS requires per-sensor-type behavior that does not apply uniformly: for example, **wheel diameter** applies only to known Cycling Speed and Cadence Service (CSCS) sensors ([SEN-KNOWN-8](../srs/Sensors.md), [SEN-DET-5](../srs/Sensors.md)). Settings and shared view models should stay **agnostic of concrete sensor types** (no `switch` on CSC vs FTMS vs HR for core list/scan actions), while Sensor Details must still show and edit type-specific fields.

We rejected a **data-driven** `Sensor.editableFields` array that would describe UI fields in the domain layer, because it centralizes a schema enum that grows with every new field type and inverts layering (UI concerns encoded on `Sensor`). We also rejected **per-sensor-type** detail protocols and separate Details views (e.g. `CSCDetailsView` vs `FTMSDetailsView`) selected by `sensor.type`, because that reintroduces type switches in navigation, multiplies view types, and weakens the composite-provider goal for Settings.

## Decision

1. Define a **narrow base protocol** `Sensor` in the consuming module (`SettingsVM`) with identity, name, `SensorType`, connection state, enabled state, and connect/disconnect/forget — the common contract for list and scan rows.

2. Define **optional capability protocols** that refine `Sensor`, for example `WheelDiameterAdjustable: Sensor` that exposes wheel diameter as a stream and a setter.

3. The **Sensor Details** view (or a small subview) **discovers** optional capabilities with Swift’s `as?`, e.g. `if let csc = sensor as? any WheelDiameterAdjustable { ... }`.

4. New per-type fields are added as **new capability protocols** (or extensions of existing ones), not by changing unrelated sensor types.

See also [3. CyclingSpeedAndCadenceSensor as a first-class type](0003-cycling-speed-and-cadence-sensor-as-first-class-type.md) for how a CSC sensor concretely conforms to `Sensor` and `WheelDiameterAdjustable`, and [docs/architecture/Sensors.md](../architecture/Sensors.md) for the overall module map.

## Consequences

**Positive:** The base `Sensor` protocol stays small and [ISP](https://en.wikipedia.org/wiki/Interface_segregation_principle)-compliant. Settings does not import CSC/FTMS/HR implementation modules. Additive changes do not require editing every conforming type. Unit tests can provide mock sensors that conform only to the capabilities under test.

**Negative:** One or more `as?` checks in the Details layer — an explicit, local trade-off accepted for clarity over a UI schema in the domain.

**Risks / follow-ups:** If many orthogonal capabilities accumulate, the Details screen may need small composable subviews per capability to avoid a long `if` chain, without changing the protocol shape.
