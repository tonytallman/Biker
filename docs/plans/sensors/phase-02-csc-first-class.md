# Phase 02 — CSC first-class per-peripheral type + manager split

- **Status**: Not started
- **Depends on**: Phase 01

## Goal

Split the monolithic `BluetoothSensorManager` in
`CyclingSpeedAndCadenceService` into:

- `CyclingSpeedAndCadenceSensorManager` — owns `CBCentralManager`, scan,
  connect/disconnect orchestration, restore-on-launch, and the SEN-TYP-4/5
  policy hooks (the policy itself arrives in Phase 09).
- `CyclingSpeedAndCadenceSensor` — one instance per known/connected
  peripheral. Owns its `CBPeripheral` as `CBPeripheralDelegate`, a
  `CSCDeltaCalculator` seeded with the sensor's wheel circumference, and
  per-peripheral streams for speed, cadence, distance-delta, and
  connection state.
- Keep `CSCMeasurementParser` as a **stateless** `enum`.

This realizes [ADR-0003](../../adr/0003-cycling-speed-and-cadence-sensor-as-first-class-type.md)
inside the package; external wiring still goes through the adapter added
in Phase 01 (persistence and UI behavior are Phases 03 and 04).

## Scope

### In

- Rename/split files in
  `local packages/CyclingSpeedAndCadenceService/Sources/CyclingSpeedAndCadenceService/`:
  - `CyclingSpeedAndCadenceSensorManager.swift` — `CBCentralManager`
    delegate, scan, connect, retain per-peripheral sensors, known/discovered
    publishers.
  - `CyclingSpeedAndCadenceSensor.swift` — `CBPeripheralDelegate`, local
    `CSCDeltaCalculator`, per-peripheral publishers:
    `speed`, `cadence`, `distanceDelta`, `connectionState`,
    `wheelDiameter`, and an `isEnabled` stream seeded from memory
    (backing store arrives in Phase 03).
  - Keep `CSCMeasurementParser.swift` stateless.
  - `CSCDeltaCalculator` is used **inside** the sensor, not the manager.
- Manager-level publishers used by the existing metric adapters keep
  their shapes (merged `derivedUpdates`, `knownSensors`,
  `discoveredSensors`, `hasConnectedSensor`) so `BLEMetricAdaptors` and
  the Phase 01 `SensorProvider` adapter keep compiling. New
  per-peripheral streams are additive.
- Expand tests:
  - `CyclingSpeedAndCadenceServiceTests/CSCMeasurementParserTests.swift`
    (already valuable — ensure coverage).
  - `CSCDeltaCalculatorTests.swift` — wrap semantics already covered;
    extend for wheel circumference changes mid-stream.
  - `CyclingSpeedAndCadenceSensorTests.swift` — per-peripheral behavior
    with a protocol-fronted fake `CBPeripheral` abstraction.
  - `CyclingSpeedAndCadenceSensorManagerTests.swift` — fan-out of
    discover/connect/disconnect events to per-peripheral sensors.

### Out

- Persistence (Phase 03), `BluetoothAvailability` (Phase 04),
  `CompositeSensorProvider` (Phase 05), Sensor Details UI (Phase 06),
  FTMS/HR packages (Phases 07/08), SEN-TYP-4/5 policy (Phase 09).
- No new local-package dependency. The package still does not import
  `SettingsVM`; it exports its own DTOs and the adapter in
  `DependencyContainer` bridges.

## SRS / ADR coverage

- **SEN-KNOWN-2**, **SEN-KNOWN-4**, **SEN-SCAN-9/10/11** are still
  satisfied through the manager's public API (no behavior regression).
- Realizes [ADR-0003](../../adr/0003-cycling-speed-and-cadence-sensor-as-first-class-type.md)
  and the ownership rows of
  [docs/architecture/Sensors.md § Ownership](../../architecture/Sensors.md#ownership).
- Prepares for [ADR-0002](../../adr/0002-per-sensor-capability-protocols.md)
  wiring in Phase 05 (the `CyclingSpeedAndCadenceSensor` will conform to
  `any Sensor` / `any WheelDiameterAdjustable` through an adapter in
  `DependencyContainer`).

## Deliverables

- Refactored package sources (see **Scope / In**).
- A protocol inside the package to front `CBPeripheral` for tests
  (e.g. `CSCPeripheral`), keeping CoreBluetooth use `@preconcurrency`
  where required.
- Tests as listed.
- Updated package README summarizing the new type map.

## Acceptance criteria

- Each connected peripheral has exactly one
  `CyclingSpeedAndCadenceSensor` instance; disposing a sensor
  (forget/disconnect) releases its calculator and delegate.
- Manager-level `derivedUpdates`, `knownSensors`, `discoveredSensors`,
  and `hasConnectedSensor` publish identical semantics to today on
  parity scenarios (guarded by a regression test using a fake central).
- Package tests pass on the `Biker` scheme.
- App still launches and exercises CSC scan + connect + notify.

## Risks / follow-ups

- Core Bluetooth delegate ownership: ensure no peripheral is delegated
  to both the manager and a sensor at the same time (manager handles
  central-level events only; sensor handles service/characteristic
  events).
- Actor isolation: both types are `@MainActor`.
- Renaming may touch the Xcode project file; verify Biker target builds.
