# Phase 04 — `BluetoothAvailability` + permission/power UI behavior

- **Status**: Not started
- **Depends on**: Phase 01 (protocol), Phase 02 (per-peripheral streams)

## Goal

Produce a real `BluetoothAvailability` stream from Core Bluetooth
(authorization + `CBManagerState`) and make the Settings UI conform to
SEN-PERM-1..5 and auto-reconnect to SEN-PERS-2..5 when only CSC is
wired. Multi-manager reduction is trivial here (single manager); the
generalized reduction moves into Phase 05.

## Scope

### In

- In the CSC package:
  - Expose `bluetoothAvailability` from
    `CyclingSpeedAndCadenceSensorManager`: a reduction from
    `CBManager.authorization` + `CBCentralManager.state` to the enum
    defined in Phase 01.
  - Gate scan and auto-connect on availability:
    - Do not start scan unless `.poweredOn`.
    - On transitions to `.denied` / `.notDetermined`: stop scan, treat
      all known sensors as disconnected.
    - On transitions to `.poweredOn` (from any state): attempt to
      reconnect every enabled, disconnected known sensor.
  - Unit tests via a fake central wrapper covering each transition.
- In `DependencyContainer`:
  - `BluetoothAvailabilityAdapter` projects the CSC manager's stream
    into the `SettingsVM` type. (Temporary one-manager reducer; Phase 05
    replaces with a composite reducer.)
- In `SettingsVM` / `SettingsUI`:
  - The composition root exposes `SensorAvailability` (e.g. from
    `CompositeSensorProvider.availability`): when `BluetoothAvailability`
    is `.poweredOn`, the case is `.available(compositeSensorProvider)`;
    otherwise the case mirrors the non-ready Bluetooth state.
  - `SettingsViewModel` / `SensorsSectionViewModel` observe that
    `SensorAvailability` stream (not a property on ``SensorProvider``).
  - `SettingsView` renders, in priority order:
    1. Permission-not-granted message (SEN-PERM-1, SEN-PERM-4) when
       availability is `.notDetermined` / `.denied` / `.restricted` —
       no scan affordance, no known-sensor list.
    2. BT-off indicator with known-sensor list shown disconnected
       (SEN-PERM-3, SEN-PERS-5 implied) when `.poweredOff` /
       `.unsupported` / `.resetting`.
    3. Normal Sensors section when `.poweredOn`.
  - Disable the scan affordance outside `.poweredOn`.
  - Dismiss the scan sheet (Phase 01's `ScanView`) automatically on
    availability loss (SEN-SCAN-3 and SEN-PERM-2 / SEN-PERM-3 tie-in).
- Localized strings added to `SettingsStrings`.
- Tests:
  - `SettingsViewModelPermissionTests` — each availability case maps
    to the expected UI sub-state.
  - `CyclingSpeedAndCadenceSensorManagerAvailabilityTests` — auto-reconnect
    fires on `.poweredOff → .poweredOn`, does not fire for
    disabled sensors (depends on Phase 03).

### Out

- Multi-manager reduction and precedence rules — Phase 05.
- Details-screen wiring — Phase 06.

## SRS / ADR coverage

- **SEN-PERM-1..5** (UI gating and priority of messages).
- **SEN-PERS-2..5** (auto-reconnect on permission/power transitions;
  disabled sensors never auto-connect).
- Realizes [ADR-0007](../../adr/0007-bluetooth-availability-as-first-class-state.md).

## Deliverables

- `CyclingSpeedAndCadenceService` availability reducer + tests.
- `DependencyContainer`'s `BluetoothAvailabilityAdapter`.
- `SettingsVM` / `SettingsUI` changes to consume availability.
- New `SettingsStrings` entries for permission and BT-off messaging.
- Tests listed above.

## Acceptance criteria

- With Bluetooth permission revoked in Settings.app, the Sensors
  section shows only the permission message; re-granting permission
  restores the list and kicks off auto-reconnect (SEN-PERM-1 /
  SEN-PERM-2 / SEN-PERS-4).
- With Bluetooth powered off, the list is visible, entries are
  disconnected, the scan affordance is disabled, and a BT-off indicator
  appears; turning Bluetooth back on reconnects enabled sensors
  (SEN-PERM-3 / SEN-PERS-3 / SEN-PERS-5).
- All Phase 04 tests pass; no regression in Phases 01–03 suites.

## Risks / follow-ups

- `CBManager.authorization` is a static class property on iOS 13.1+.
  Confirm minimum deployment target matches the package manifests.
- Starting a `CBCentralManager` before authorization has been
  determined will trigger the system prompt; the VM must not change
  behavior based on the first-prompt transition.
- SwiftUI redraws: debounce availability to avoid flicker during
  `.resetting` bounces.
