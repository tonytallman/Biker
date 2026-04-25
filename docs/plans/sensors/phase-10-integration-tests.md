# Phase 10 — Integration tests & polish

- **Status**: Not started
- **Depends on**: All prior phases

## Goal

Prove the target architecture end-to-end with integration tests, and
close out residual polish items (logging, documentation, strings).
The unit tests in each earlier phase verify the building blocks; this
phase verifies their composition at the `DependencyContainer` and app
boundary.

## Scope

### In

- New integration test target (Swift Testing) colocated with
  `DependencyContainer` tests — e.g.
  `local packages/DependencyContainer/Tests/DependencyContainerIntegrationTests/`
  — exercising the composite with fakes that front
  `CBCentralManager`/`CBPeripheral` per family.
- Scenarios:
  1. **Composite ordering (SEN-SCAN-7/8)** — mixed CSC/FTMS/HR
     advertisements with varying RSSI + name; verify order and frame
     stability.
  2. **Fan-out scan (SEN-SCAN-4)** — start/stop on the composite
     reaches every manager.
  3. **Permission gating (SEN-PERM-1..5)** — drive the
     `SensorAvailability` stream (from reduced `BluetoothAvailability` at
     the composition root) through every state transition and assert
     the composite + Settings behavior (message priority, scan disabled,
     list visibility).
  4. **Auto-reconnect (SEN-PERS-2..5)** — app-launch restore,
     `.poweredOff → .poweredOn`, permission grant, disabled sensors
     excluded.
  5. **Persistence round-trip** — instantiate, modify
     enabled/wheel-diameter, tear down, re-instantiate; confirm values
     persist per family.
  6. **Legacy migration** — seed the legacy `Settings.knownSensors`
     blob, launch, assert CSC store is populated and legacy key is
     removed.
  7. **Metric priority (MET-SPD/CAD/HR-*)** — multi-family source
     switching, SEN-TYP-4/5 preference, MET-GEN-3 1 Hz pulses.
  8. **Forget from Details (SEN-DET-4)** — the Details screen dismisses
     when its sensor is removed upstream.
- Traceability table update at the bottom of
  [docs/architecture/Sensors.md](../../architecture/Sensors.md) (or in a
  new companion file) marking each `SEN-*` / `MET-*` row with the test
  that covers it.
- Polish:
  - Ensure every new test target is listed in the `Biker` scheme.
  - Review and deduplicate log messages across managers; use a
    `ConsoleLogger` (already present in `CoreLogic`) pattern.
  - Update the `CyclingSpeedAndCadenceService` / `FitnessMachineService`
    / `HeartRateService` READMEs with the final public surface.
  - Update `docs/architecture/Sensors.md` diagrams if the final types
    drift from the doc, and supersede ADRs if any substantive
    design change was forced during implementation.

### Out

- Performance benchmarking and profiling (separate task if needed).
- UI tests beyond existing ones (SwiftUI snapshot tests are out of
  scope for this plan).

## SRS / ADR coverage

- Verifies every `SEN-*` / `MET-*` requirement referenced in the
  traceability table of
  [docs/architecture/Sensors.md](../../architecture/Sensors.md#srs-traceability).
- Backstops every ADR in [docs/adr/](../../adr/) with at least one
  passing test.

## Deliverables

- New integration test suite with the scenarios listed above.
- Updated READMEs for all three sensor-type packages.
- Updated traceability table pointing SRS IDs to the test symbols that
  cover them.
- Any ADR supersede entries needed after implementation.

## Acceptance criteria

- Full test suite green on the `Biker` scheme (all unit and
  integration tests).
- Every `SEN-*` / `MET-*` requirement has a referenced test.
- Manual device smoke test on iPhone: CSC, FTMS, HR sensors detected,
  connect, disconnect, forget, permission off/on, Bluetooth off/on, and
  dashboard metrics update with ≥1 Hz publishing.

## Risks / follow-ups

- Integration tests depend on fakes; any gap between the fake and
  real Core Bluetooth behavior must be tracked with a follow-up issue.
- Keep an eye on CI run-time; Swift Testing parallelism should keep it
  reasonable, but fanning out three package trees can still bloat it.
