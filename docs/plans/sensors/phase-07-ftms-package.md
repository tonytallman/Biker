# Phase 07 — Fitness Machine Service (FTMS) package

- **Status**: Done — Phase 07 implementation (FTMS package + composition root)
- **Depends on**: Phase 05 (composite), Phase 06 (Details UI ready to show FTMS rows)

## Goal

Add a new local package implementing Fitness Machine Service support
(Bluetooth service UUID `0x1826`): scan, connect, parse Indoor Bike
Data (`0x2AD2`) for speed and cadence, expose per-peripheral sensors,
persist known FTMS sensors with the typed schema from Phase 03 (minus
wheel diameter), and plug into `CompositeSensorProvider` as a second
`SensorProvider` participant. The composition root combines CSC and FTMS
`bluetoothAvailability` streams with a most-restrictive reducer and
passes the result to `CompositeSensorProvider(systemAvailability:)`.

## Scope

### In

- New local package `local packages/FitnessMachineService/` using the
  logic template (`templates/Package.logic.swift`). Contents:
  - `FitnessMachineSensorManager` — `CBCentralManager` delegate,
    scan, connect, per-peripheral sensor instantiation, auto-reconnect
    wiring parallel to CSC.
  - `FitnessMachineSensor` — `CBPeripheralDelegate` for `0x1826` service
    and `0x2AD2` (Indoor Bike Data) characteristic. Exposes
    `speed: AnyPublisher<Measurement<UnitSpeed>, Never>` and
    `cadence: AnyPublisher<Measurement<UnitFrequency>, Never>`.
  - `IndoorBikeDataParser` — stateless enum parsing flags + fields.
  - `FTMSKnownSensorStore` — schema `id`, `name`, `sensorType`,
    `isEnabled` (no wheel diameter).
  - `FTMSKnownSensorPersistence` protocol (in-package abstraction).
- Add the package to the Xcode project and register the test target in
  the `Biker` scheme (per the unit-tests rule).
- `DependencyContainer` additions:
  - `FTMSPersistence` adapter over `AppStorage`.
  - `FTMSParticipant` wrapping the manager for the composite.
  - `FitnessMachineSensorAdapter` conforming to
    `SettingsVM.Sensor` (not `WheelDiameterAdjustable`).
  - `FTMSMetricAdaptors.speed(manager:)` and `.cadence(manager:)`
    producing `AnyMetric<UnitSpeed>` / `AnyMetric<UnitFrequency>`.
- Wire the FTMS participant into `CompositeSensorProvider`.
- Wire FTMS adapters into the existing speed/cadence metric selectors
  (full cross-family policy finalized in Phase 09).
- Tests:
  - `IndoorBikeDataParserTests` — each flag combination and known
    payloads.
  - `FitnessMachineSensorTests` — state and stream semantics with a
    fake peripheral.
  - `FitnessMachineSensorManagerTests` — discover/connect/disconnect
    with a fake central.
  - `FTMSKnownSensorStoreTests` — round-trip.
  - `CompositeSensorProviderTests` extended with FTMS participants
    (ordering, fan-out).

### Out

- Indoor-bike control-point writes (start/stop/resistance). Not needed
  for Biker's dashboard.
- The cross-family tie-break and SEN-TYP-4/5 policy — Phase 09.
- Migration of any legacy FTMS records (none exist).

## SRS / ADR coverage

- **SEN-TYP-1** (FTMS is a supported sensor type).
- **MET-SPD-2 #2** and **MET-CAD-2 #2** (FTMS as a priority source).
- Reuses [ADR-0003](../../adr/0003-cycling-speed-and-cadence-sensor-as-first-class-type.md)
  shape (manager + per-peripheral sensor + stateless parser) for the
  FTMS family.
- Reuses [ADR-0005](../../adr/0005-per-manager-persistence-stores.md)
  per-family store.

## Deliverables

- New `FitnessMachineService` package (sources + tests + README).
- `Package.swift` for the package.
- `DependencyContainer` adapters and participant.
- Updated `Biker` scheme and Xcode project.

## Acceptance criteria

- FTMS devices appear in the merged scan list with correct type
  indicators, can be connected, persist across launches, and publish
  speed/cadence to the dashboard when selected.
- CSC-only regressions are absent — existing CSC devices still work
  identically.
- All tests pass on the `Biker` scheme.

## Risks / follow-ups

- Indoor Bike Data flag parsing has many optional fields; cover with
  real-device captures when available.
- Dual `CBCentralManager` instances are fine but consume more radio
  time; consider consolidating if the composite's availability
  reduction highlights disagreements.
