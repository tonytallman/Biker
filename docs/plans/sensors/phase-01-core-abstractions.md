# Phase 01 — Core sensor abstractions in `SettingsVM`

- **Status**: Not started
- **Depends on**: (none)

## Goal

Introduce the type-agnostic sensor contracts that the rest of the plan
depends on. After this phase, `SettingsVM` is the source of truth for
the `Sensor`, `SensorProvider`, `WheelDiameterAdjustable`, `SensorType`,
`BluetoothAvailability` (system radio / permission reduction), and
`SensorAvailability` (Settings gating that wraps a ``SensorProvider`` in
`.available`), and UI code consumes them — without yet changing concrete
behavior in the CSC package.

## Scope

### In

- Define the following in the `SettingsVM` target
  (`local packages/Settings/Sources/SettingsVM/`):
  - `SensorType` — enum with cases for `cyclingSpeedAndCadence`, `fitnessMachine`,
    `heartRate` (room to grow). Localized display names live in `SettingsStrings`.
  - `Sensor` protocol — identity (`id: UUID`), `name: String` (or stream),
    `type: SensorType`, `connectionState: AnyPublisher<SensorConnectionState, Never>`,
    `isEnabled: AnyPublisher<Bool, Never>`, and actions
    `connect()`, `disconnect()`, `forget()`, `setEnabled(_: Bool)`.
  - `WheelDiameterAdjustable: Sensor` — adds
    `wheelDiameter: AnyPublisher<Measurement<UnitLength>, Never>`
    and `setWheelDiameter(_: Measurement<UnitLength>)`.
  - `BluetoothAvailability` — enum covering `notDetermined`, `denied`,
    `restricted`, `unsupported`, `resetting`, `poweredOff`, `poweredOn`
    (system-level; not on ``SensorProvider``).
  - `SensorAvailability` — gating enum for Settings; when the radio is
    ready, `.available(any SensorProvider)` carries the active provider.
  - `SensorProvider` protocol — `knownSensors: AnyPublisher<[any Sensor], Never>`,
    `discoveredSensors: AnyPublisher<[any Sensor], Never>`,
    `scan()`, `stopScan()`.
- Replace `SettingsViewModel.SensorSettings` with `SensorProvider`
  (keep `ConnectedSensorInfo` / `DiscoveredSensorInfo` DTOs only if still
  needed by UI rows; otherwise render directly from `any Sensor`).
- Update `SettingsViewModel`, `ScanViewModel`, `SensorViewModel`, and
  `SettingsView` / `ScanView` to the new surface. Subscribe to per-sensor
  `connectionState` / `isEnabled` streams instead of rebuilding DTOs.
- Update `PreviewSensorSettings` (rename to e.g. `PreviewSensorProvider`)
  so SwiftUI previews still work; add a `MockSensor` that conforms to
  `Sensor` and optionally to `WheelDiameterAdjustable`.
- Unit tests with Swift Testing for the new VM logic (mock
  `SensorAvailability` / `SensorProvider` + mock sensors). Ensure no import of
  `CyclingSpeedAndCadenceService` from `SettingsVM`.

### Out

- No changes inside the `CyclingSpeedAndCadenceService` package yet
  (Phase 02).
- No real `BluetoothAvailability` production wiring — the adapter can
  return a static `.poweredOn` for now (real reduction arrives in
  Phase 04).
- No `any Sensor` in persistence; Phase 03 handles that.
- No `CompositeSensorProvider` yet (Phase 05).

## SRS / ADR coverage

- Introduces the protocol surface behind **SEN-MAIN-1/2/3**,
  **SEN-KNOWN-6/7**, **SEN-SCAN-6**, **SEN-DET-2**, **SEN-TYP-3**.
- Realizes [ADR-0002](../../adr/0002-per-sensor-capability-protocols.md)
  (base + capability protocols) and the protocol pointers in
  [docs/architecture/Sensors.md](../../architecture/Sensors.md#key-protocols-pointers).
- Lays the ground for [ADR-0007](../../adr/0007-bluetooth-availability-as-first-class-state.md)
  by shipping the `BluetoothAvailability` type (concrete reduction is
  Phase 04).

## Deliverables

- New files in `local packages/Settings/Sources/SettingsVM/`:
  - `Sensor.swift`
  - `SensorType.swift`
  - `WheelDiameterAdjustable.swift`
  - `SensorProvider.swift`
  - `BluetoothAvailability.swift`
  - `SensorAvailability.swift` (gating + `BluetoothAvailabilityMapping`)
  - `MockSensor.swift` (preview + tests)
- Updates to existing files:
  - `SettingsViewModel.swift` — swap protocol; subscribe to per-sensor streams.
  - `ScanViewModel.swift`, `SensorViewModel.swift`, `SettingsView.swift`,
    `ScanView.swift`, `SensorSettings.swift` (preview provider).
- Tests in `local packages/Settings/Tests/SettingsVMTests/`:
  - `SensorsListTests.swift` — `SettingsViewModel` reacts to mock
    `SensorProvider` updates.
  - `ScanListTests.swift` — scan list sort and actions.
- `DependencyContainer` updates a thin adapter that wraps the existing
  `BluetoothSensorManager` to the new `SensorProvider` shape so the app
  still compiles and runs (temporary — superseded in Phase 05).

## Acceptance criteria

- `SettingsVM` has no `import CyclingSpeedAndCadenceService`
  (enforced by the package-independence rule).
- `SettingsView` renders the known-sensor list and the scan list from
  `any Sensor`; per-row connection state and enabled state update
  reactively.
- Swift Testing suites pass on the `Biker` scheme; SwiftUI previews
  in `SettingsView` and `ScanView` build.
- The app still launches and the existing CSC flows (scan, connect,
  disconnect, forget) behave as today.

## Risks / follow-ups

- Protocol-creep: keep `Sensor` narrow. Resist putting type-specific
  fields on the base protocol — capability protocols are the extension
  point.
- Threading: every `Sensor` is `@MainActor`. Document it on the
  protocol.
- Temporary adapter in `DependencyContainer` is load-bearing until
  Phase 05; mark with a `// TODO(phase-05):` comment.
