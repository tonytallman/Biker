# 9. `SensorAvailability` sum type and system-wide radio state

- **Status**: Accepted
- **Date**: 2026-04-23
- **Supersedes**: (none)
- **Superseded by**: (none)

## Context

[7. BluetoothAvailability as first-class state](0007-bluetooth-availability-as-first-class-state.md) had `SensorProvider` expose a separate `bluetoothAvailability` stream and had `CompositeSensorProvider` *reduce* multiple per-manager streams. In practice, all sensor families share the system Bluetooth radio on iOS; that reduction was redundant. Separately, `SettingsVM` could observe `.poweredOff` (or other non-ready states) while still holding a `SensorProvider` reference — an *invalid* UI story if we want iOS Settings–parity: when Bluetooth is off, "My devices" and discovered devices are hidden, not empty lists with stale affordances.

## Decision

1. Define a **`SensorAvailability`** sum type in **`SettingsVM`**: non-ready cases (permission / unsupported / off / etc.) and **`case available(any SensorProvider)`** carrying the only provider the UI may call (`knownSensors`, `discoveredSensors`, `scan`, `stopScan`).

2. **`SettingsViewModel`** takes **`AnyPublisher<SensorAvailability, Never>`** (in addition to existing metrics/system settings). It subscribes to that publisher and **only** subscribes to `knownSensors` when the current value is **`.available`**. Scanning and the scan sheet are only reachable in that case.

3. **System-wide `BluetoothAvailability`** (raw radio/permission) is still produced once at the **composition root** from a **single** manager (today: `CyclingSpeedAndCadenceSensorManager`’s `CBCentralManager` observation, mapped by `BluetoothAvailabilityAdapter`). It is **not** re-published on each per-family `SensorProvider`.

4. **`CompositeSensorProvider`** takes **participants** plus **`systemAvailability: AnyPublisher<BluetoothAvailability, Never>`**, merges known/discovered/scan as before ([4. CompositeSensorProvider at the composition root](0004-composite-sensor-provider-at-composition-root.md)), and exposes **`availability: AnyPublisher<SensorAvailability, Never>`** where the payload is **`.available(self)`** iff `systemAvailability == .poweredOn`, else a non-ready `SensorAvailability` case matching the `BluetoothAvailability` (no per-participant **most-restrictive** fold — that logic is **removed**).

5. **SRS** [SEN-PERM-3](../srs/Sensors.md) is updated for **iOS Settings parity**: when the radio is off (permission granted), the **known-sensor list is not shown** (only messaging / empty section as specified).

6. [7. BluetoothAvailability as first-class state](0007-bluetooth-availability-as-first-class-state.md) is **superseded** by this ADR: the *raw* `BluetoothAvailability` type remains for mapping `CBManager` state, but the **UI contract** is `SensorAvailability`, not `SensorProvider` + parallel availability.

## Consequences

**Positive:** Illegal UI states (calling `scan()` when BT is off) are unrepresentable at the `SettingsViewModel` API. One radio observer; no spurious cross-participant reduction. Aligned with iOS Settings behavior for list visibility when Bluetooth is off.

**Negative:** Toggling BT off collapses the VM’s known-sensor `SensorViewModel` cache (by design). Previews and tests must emit `.available(mock)` with a live `MockSensorProvider` instead of toggling a parallel availability subject on the same mock.

**Risks / follow-ups:** If a future transport (USB/Wi-Fi) is added, re-evaluate whether `SensorAvailability` should carry **per-transport** or **app-wide** gating; the sum type is the extension point.
