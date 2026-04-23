# CyclingSpeedAndCadenceService

A Swift package for Bluetooth Low Energy (BLE) [Cycling Speed and Cadence Service (CSCS)](https://www.bluetooth.com/specifications/) — speed, cadence, and distance deltas for a bike-computer app. It is one of several data-source packages in the Biker app.

## Type map

| Type | Role |
|------|------|
| `CyclingSpeedAndCadenceSensorManager` | Owns `CBCentralManager`, scan/connect/disconnect, restore-on-launch, and merges per-sensor `derivedUpdates` for metric adapters. Retains one `CyclingSpeedAndCadenceSensor` per known peripheral. |
| `CyclingSpeedAndCadenceSensor` | One instance per known peripheral. `CBPeripheralDelegate` for the CSC service/0x2A5B, local `CSCDeltaCalculator` (from wheel **diameter** in memory), and publishers for `speed` / `cadence` / `distanceDelta` / `connectionState` / `wheelDiameter` / `isEnabled` / `derivedUpdates`. |
| `CSCMeasurementParser` | Stateless parse of raw CSC measurement bytes. |
| `CSCDeltaCalculator` | Successive-difference math from parsed `CSCMeasurement` values. |
| `CSCPeripheral` | Protocol abstracting `CBPeripheral` for the CSC stack; tests can use fakes. |

`SensorModels` (`DiscoveredSensor`, `ConnectedSensor`, `ConnectionState`) are shared DTOs for settings/adapters at the app boundary.

**Persistence and `BluetoothAvailability`** live outside this package (composition root / `DependencyContainer` adapters). Wheel diameter and “enabled” on `CyclingSpeedAndCadenceSensor` are in-memory here until wired to per-sensor storage in a later phase.

## Testing

- Parser and calculator are pure and fully unit-tested.
- Sensor behavior is covered via `internal` ` _test_ingestCSCMeasurementData` and a `FakeCSCPeripheral` conforming to `CSCPeripheral`.
- The manager is covered with `internal` test hooks to register sensors and assert merged `derivedUpdates` and known-sensor ordering.

## Legacy name

`BluetoothSensorManager` was split into the types above; call sites have been updated to `CyclingSpeedAndCadenceSensorManager`.
