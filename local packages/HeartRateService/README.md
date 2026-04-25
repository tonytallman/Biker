# HeartRateService

A Swift package for Bluetooth Low Energy (BLE) [Heart Rate Service](https://www.bluetooth.com/specifications/) (service UUID `0x180D`) — BPM for the Biker app.

## Type map

| Type | Role |
|------|------|
| `HeartRateSensorManager` | Owns `CBCentralManager`, scan/connect/disconnect, restore-on-launch, `HRKnownSensorStore`, and merges per-sensor BPM for metric adapters. |
| `HeartRateSensor` | One instance per known peripheral. `CBPeripheralDelegate` for HR service `0x180D` and Heart Rate Measurement `0x2A37`, publishers for `bpm` / `connectionState` / `isEnabled`. |
| `HRKnownSensorStore` | Coalesced in-memory mirror of known HR rows; encodes/decodes `[HRKnownSensorRecord]` as JSON under `HR.knownSensors.v1` via `HRPersistence`. |
| `HRPersistence` | Key-value port (`get` / `set`) matching the app’s `AppStorage` shape; `DependencyContainer` declares `HRPersistence` on `UserDefaultsAppStorage` and `AppStorageWithNamespacedKeys` (and test doubles as needed). |
| `HeartRateMeasurementParser` | Stateless parse of raw Heart Rate Measurement bytes (8- or 16-bit BPM; RR intervals and energy expended ignored). |
| `HRPeripheral` | Protocol abstracting `CBPeripheral` for tests. |

`SensorModels` (`DiscoveredSensor`, `ConnectedSensor`, `ConnectionState`) are HR-local DTOs for adapters at the app boundary (package independence).

**Persistence:** the package owns the store, DTOs, JSON schema, and storage key; any `AppStorage` instance (e.g. `Settings`-namespaced) is passed in as `HRPersistence`, yielding a full UserDefaults key like `Settings.HR.knownSensors.v1`.

## Testing

- Parser tests cover 8/16-bit formats, truncation, and trailing bytes.
- Sensor behavior uses `internal` `_test_ingestHeartRateMeasurement` and fakes conforming to `HRPeripheral`.
- The manager is covered with `internal` test hooks and `FakeHRCentral`.
- `HRKnownSensorStore` has dedicated unit tests.

**Cross-package (Biker app):** HR metric wiring through `HRMetricAdaptors` + `PrioritizedMetricSelector` is covered in **`DependencyContainerIntegrationTests`** (`MetricSelectionIntegrationTests`), using a fake `HRCentral` for deterministic runs.
