# Phase 05 — `CompositeSensorProvider` at the composition root

- **Status**: Not started
- **Depends on**: Phase 01 (protocols), Phase 04 (availability)

## Goal

Introduce `CompositeSensorProvider` in `DependencyContainer` as the
sole implementer of `SettingsVM.SensorProvider`. It merges
known/discovered streams from N per-type managers, applies SEN-SCAN-7
ordering and SEN-SCAN-8 stability, fans out scan start/stop, and exposes
`availability: AnyPublisher<SensorAvailability, Never>` by mapping a
single injected `systemAvailability: AnyPublisher<BluetoothAvailability, Never>`
(``SensorProvider`` itself is only embedded in `.available` when the
radio is `.poweredOn`). The composition root reduces multiple managers'
Bluetooth streams into that one `systemAvailability` (most-restrictive
rule per ADR-0007). This phase wires the CSC manager only; FTMS and HR
plug in during Phases 07 and 08.

## Scope

### In

- New `DependencyContainer` types:
  - `CompositeSensorProvider` implementing
    `SettingsVM.SensorProvider`.
    - Accepts an ordered array of per-type participants implementing
      `SensorProvider` (`knownSensors`, `discoveredSensors`, `scan()`,
      `stopScan()`), plus a single `systemAvailability` publisher from the
      composition root.
    - Merges known lists into a single `[any Sensor]` stable across
      updates (sort: localized case-insensitive name).
    - Merges discovered lists applying **SEN-SCAN-7** ordering
      (connected first; then RSSI descending; then name). Guarantees
      **SEN-SCAN-8** stability within a frame (re-sort only on
      connection-state or RSSI change).
    - Maps `systemAvailability` through `BluetoothAvailabilityMapping`
      so Settings receives `SensorAvailability.available(self)` only
      when the reduced Bluetooth state is `.poweredOn` — matches
      [ADR-0007](../../adr/0007-bluetooth-availability-as-first-class-state.md)
      and [ADR-0009](../../adr/0009-sensor-availability-sum-type.md).
    - Fans out `scan()` / `stopScan()` to all participants.
  - `CSCParticipant` — adapter wrapping the existing CSC manager +
    per-peripheral sensors into `any Sensor` values. A
    `CyclingSpeedAndCadenceSensorAdapter` conforms to both
    `SettingsVM.Sensor` and `SettingsVM.WheelDiameterAdjustable`.
    - Discovered rows need an RSSI-bearing `Sensor` DTO. Add
      `DiscoveredSensor` in `SettingsVM` (struct with
      `rssi: AnyPublisher<Int, Never>`) or extend `any Sensor` with an
      optional `signalStrength` stream — pick inside the phase's
      planning step. The architecture doc keeps discovery DTOs typed,
      so the adapter must translate the package's `DiscoveredSensor`
      into the new `SettingsVM` type.
- Replace `BluetoothSensorSettingsAdaptor` and the temporary Phase 01
  adapter with `CompositeSensorProvider` in `SettingsDependencies`.
- Tests:
  - `CompositeSensorProviderTests` — ordering and stability
    (SEN-SCAN-7/8); fan-out of scan start/stop; `SensorAvailability` /
    `systemAvailability` mapping.
  - `CyclingSpeedAndCadenceSensorAdapterTests` — protocol conformance
    and forwarding to the underlying sensor.

### Out

- FTMS / HR participants — Phases 07 / 08.
- Any metric-selector changes — Phase 09.

## SRS / ADR coverage

- **SEN-SCAN-4/5/7/8**, **SEN-KNOWN-6** (type + state per row),
  **SEN-MAIN-3**.
- Realizes [ADR-0004](../../adr/0004-composite-sensor-provider-at-composition-root.md).
- Ties [ADR-0007](../../adr/0007-bluetooth-availability-as-first-class-state.md)
  reduction to the composition root.

## Deliverables

- `DependencyContainer` new files:
  - `CompositeSensorProvider.swift`
  - `CSCParticipant.swift`
  - `CyclingSpeedAndCadenceSensorAdapter.swift`
- `SettingsVM` additions (likely):
  - `DiscoveredSensor` (or `signalStrength` capability on `Sensor`).
- Updates to `SettingsDependencies.swift` and
  `DependencyContainer.init`.
- Tests listed above.

## Acceptance criteria

- `SettingsVM` is wired only through `CompositeSensorProvider`.
- Discovered list ordering matches SEN-SCAN-7 and is stable
  (SEN-SCAN-8) under rapid advertising bursts (exercised in tests).
- Injected `systemAvailability` reduction behaves the same as the
  single-manager case when only CSC is present (regression safety for Phase 04).
- Scan start/stop still works end-to-end.

## Risks / follow-ups

- `Combine.Publishers.CombineLatest` of many per-participant streams
  can emit stale middle values during startup — use `combineLatest`
  with a dropped initial bool or a seeded value per participant.
- Adapter type identity: `CyclingSpeedAndCadenceSensorAdapter` must be
  `Hashable`/`Identifiable` via the underlying peripheral `id` so
  SwiftUI diffing stays stable.
