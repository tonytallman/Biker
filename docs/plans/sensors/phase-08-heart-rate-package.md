# Phase 08 — Heart Rate Service package + BPM metric

- **Status**: Done — HeartRateService + DependencyContainer + dashboard HR widget
- **Depends on**: Phase 05 (composite), Phase 06 (Details UI)

## Goal

Add a new local package implementing Heart Rate Service support
(Bluetooth service UUID `0x180D`): scan, connect, parse Heart Rate
Measurement (`0x2A37`), expose a per-peripheral BPM stream, persist
known HR sensors with the typed schema (no wheel diameter), plug into
`CompositeSensorProvider` as another participant, and publish Heart Rate
to the dashboard. The composition root extends the Bluetooth
availability reducer to include the HR manager (most-restrictive across
all sensor managers).

## Scope

### In

- New local package `local packages/HeartRateService/` using the logic
  template. Contents:
  - `HeartRateSensorManager` — `CBCentralManager` delegate, scan,
    connect, per-peripheral sensor instantiation, auto-reconnect.
  - `HeartRateSensor` — `CBPeripheralDelegate` for `0x180D` and
    `0x2A37`. Exposes
    `bpm: AnyPublisher<Measurement<UnitFrequency>, Never>` (using
    `.beatsPerMinute` if defined, else a custom extension in the
    package's own module — not in `CoreLogic`).
  - `HeartRateMeasurementParser` — stateless enum (handles 8-bit vs
    16-bit flag and ignores RR intervals for now).
  - `HeartRateKnownSensorStore` with schema `id`, `name`, `sensorType`,
    `isEnabled`.
  - `HeartRatePersistence` protocol (in-package).
- `DashboardVM` / `DashboardUI` additions:
  - Introduce optional heart-rate publisher and `heartRateBPM` for a **top-trailing**
    capsule widget (`heart.fill` + BPM), hidden when unavailable (not a bottom-row tile).
- `DependencyContainer` additions:
  - `HRPersistence` adapter.
  - `HRParticipant` and `HeartRateSensorAdapter`.
  - `HRMetricAdaptors.heartRate(manager:)` producing
    `AnyMetric<UnitFrequency>`.
  - A dedicated `PrioritizedMetricSelector<UnitFrequency>` for HR
    (sources: HR service only — room for future FTMS HR).
- Wire the HR participant into `CompositeSensorProvider`.
- Tests parallel to Phase 07.

### Out

- Energy Expended / RR-interval fields (deferred).
- FTMS-reported HR (not in the SRS).

## SRS / ADR coverage

- **SEN-TYP-1** (Heart Rate is a supported sensor type).
- **MET-HR-1..3** (HR metric published at ≥1 Hz; source priority is
  HR service only).
- Reuses [ADR-0003](../../adr/0003-cycling-speed-and-cadence-sensor-as-first-class-type.md)
  and [ADR-0005](../../adr/0005-per-manager-persistence-stores.md).

## Deliverables

- New `HeartRateService` package (sources + tests + README).
- `DependencyContainer` adapters and participant.
- `Dashboard` (`DashboardVM`, `DashboardUI`) updates to surface the HR widget.
- Updated Biker scheme and Xcode project.

## Acceptance criteria

- HR straps appear in scan, connect, persist, and publish BPM to the
  dashboard at ≥1 Hz while connected (**MET-HR-3**, **MET-GEN-3**).
- If no HR sensor is connected, the HR widget is hidden (unavailable,
  **MET-GEN-2**).
- All tests pass on the `Biker` scheme.

## Risks / follow-ups

- Add `UnitFrequency.beatsPerMinute` carefully — do not pollute
  `CoreLogic` with HR-specific units; define inside `HeartRateService`
  (or introduce a Measurement adapter in the Dashboard module).
- Core Bluetooth on the simulator does not deliver HR notifications;
  exercise on device.
