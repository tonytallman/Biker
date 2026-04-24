# FitnessMachineService

A Swift package for Bluetooth Low Energy (BLE) [Fitness Machine Service (FTMS)](https://www.bluetooth.com/specifications/) — indoor bike speed and cadence for the Biker app.

## Type map

| Type | Role |
|------|------|
| `FitnessMachineSensorManager` | Owns `CBCentralManager`, scan/connect/disconnect, restore-on-launch, `FTMSKnownSensorStore`, and merges per-sensor speed/cadence for metric adapters. |
| `FitnessMachineSensor` | One instance per known peripheral. `CBPeripheralDelegate` for FTMS service / Indoor Bike Data `0x2AD2`, publishers for `speed` / `cadence` / `connectionState` / `isEnabled` / `derivedUpdates`. |
| `FTMSKnownSensorStore` | Coalesced in-memory mirror of known FTMS rows; encodes/decodes `[FTMSKnownSensorRecord]` as JSON under `FTMS.knownSensors.v1` via `FTMSPersistence`. |
| `FTMSPersistence` | Key-value port (`get` / `set`) matching the app’s `AppStorage` shape; `DependencyContainer` declares `FTMSPersistence` on `UserDefaultsAppStorage` and `AppStorageWithNamespacedKeys` (and test doubles as needed). |
| `IndoorBikeDataParser` | Stateless parse of raw Indoor Bike Data bytes. |
| `FTMSPeripheral` | Protocol abstracting `CBPeripheral` for tests. |

`SensorModels` (`DiscoveredSensor`, `ConnectedSensor`, `ConnectionState`) are FTMS-local DTOs for adapters at the app boundary (package independence).

**Persistence:** the package owns the store, DTOs, JSON schema, and storage key; any `AppStorage` instance (e.g. `Settings`-namespaced) is passed in as `FTMSPersistence`, yielding a full UserDefaults key like `Settings.FTMS.knownSensors.v1`.

## Testing

- Parser tests cover flag combinations and truncated payloads.
- Sensor behavior uses `internal` `_test_ingestIndoorBikeData` and fakes conforming to `FTMSPeripheral`.
- The manager is covered with `internal` test hooks and `FakeFTMSCentral`.
- `FTMSKnownSensorStore` has dedicated unit tests.
