# Phase 03 — Per-manager typed persistence (CSC) + legacy migration

- **Status**: Not started
- **Depends on**: Phase 02

## Goal

Replace the legacy `knownSensors` blob (id + name only) with a typed,
CSC-scoped persistence store that records `id`, `name`, `sensorType`,
`isEnabled`, and `wheelDiameter`. Migrate existing data on first launch
after the change and remove the legacy key once migration completes.

## Scope

### In

- In the CSC package, add `CSCKnownSensorStore` (or equivalent) owned by
  the manager. The store is injected with an abstraction over
  persistence (protocol defined **inside the package** per package
  independence); the concrete `UserDefaults`/`AppStorage` adapter lives
  in `DependencyContainer`.
- Schema (JSON under a single namespaced key, e.g.
  `CSC.knownSensors.v1`):
  ```
  [
    {
      "id": "<UUID string>",
      "name": "<last known name>",
      "sensorType": "cyclingSpeedAndCadence",
      "isEnabled": true,
      "wheelDiameterMeters": 0.670
    }
  ]
  ```
  - Default wheel diameter for newly known sensors is a documented
    constant (aligns with `CSCDefaults.defaultWheelCircumferenceMeters`).
  - `isEnabled` defaults to `true` on new known sensors
    (**SEN-SCAN-11**).
- Migration:
  - On first launch after deploy, read legacy `knownSensors`
    (`[{id, name}]`) under its old namespaced key and write it to the
    new schema (defaulting `sensorType = cyclingSpeedAndCadence`,
    `isEnabled = true`, `wheelDiameterMeters` = default).
  - Delete the legacy key after successful migration.
  - Migration is idempotent and safe to run multiple times.
- Wire the store into the manager (load on init, save on write).
  Per-peripheral `wheelDiameter` and `isEnabled` streams (added in
  Phase 02) now read/write through the store.
- Add the `DependencyContainer` adapter that provides the persistence
  abstraction from `AppStorage` / `UserDefaults`, reusing
  `AppStorageWithNamespacedKeys` and related types already present.
- Tests:
  - `CSCKnownSensorStoreTests` — round-trip, defaults, corruption
    tolerance (malformed entries are skipped).
  - `CSCKnownSensorStoreMigrationTests` — legacy payload migrates and
    legacy key is removed.
  - Extend manager tests to verify that forget removes the persisted
    entry and that connect-from-scan appends with `isEnabled = true`.

### Out

- `WheelDiameterAdjustable` UI editing (Phase 06).
- FTMS / HR stores (Phases 07 / 08 — they follow the same pattern without
  wheel diameter).
- `BluetoothAvailability`-gated auto-reconnect (Phase 04).

## SRS / ADR coverage

- **SEN-PERS-1** (persist per-sensor fields across launches), plus
  wheel-diameter persistence (**SEN-KNOWN-8**, **SEN-KNOWN-9**,
  **SEN-DET-5/6**).
- **SEN-SCAN-11** (new known sensors default to enabled).
- Realizes [ADR-0005](../../adr/0005-per-manager-persistence-stores.md).

## Deliverables

- `CyclingSpeedAndCadenceService` package additions:
  - `CSCKnownSensorStore.swift`
  - `CSCKnownSensorPersistence.swift` (protocol and DTO)
  - Updates to `CyclingSpeedAndCadenceSensorManager` and
    `CyclingSpeedAndCadenceSensor` to use the store.
- `DependencyContainer` adapter implementing
  `CSCKnownSensorPersistence` over `AppStorage`.
- Tests listed above.

## Acceptance criteria

- Old users upgrading from the legacy shape retain all known sensors
  with `isEnabled = true` and the default wheel diameter; the legacy
  key is gone after the first launch.
- Toggling enabled or changing wheel diameter is durable across app
  launches.
- Forgetting a sensor removes it from the store.
- Tests pass; no regression in Phase 02 behavior.

## Risks / follow-ups

- Write amplification: coalesce writes or compare before writing to
  avoid thrashing `UserDefaults` on every notification.
- Schema evolution: include a `version` sentinel or use a versioned
  key (`CSC.knownSensors.v1`) so future changes are safe.
- The legacy key lives in the `DependencyContainer` persistence
  namespace — confirm the exact key used today
  (`Settings.knownSensors` based on current wiring) and hard-code the
  migration source.
