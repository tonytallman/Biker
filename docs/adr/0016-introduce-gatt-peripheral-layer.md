# 16. Introduce GATT peripheral layer (`GATTPeripheral`)

- **Status**: Accepted
- **Date**: 2026-05-06
- **Supersedes**: (none)
- **Superseded by**: (none)

## Context

**Historical note (Phase 3 complete):** [`Sensor`](../../local%20packages/Sensors/Sources/Sensors/Sensor.swift) now consumes `any GATTPeripheral`; see [`0017-multiplexed-sensor-peripheral-and-sensor-rewire.md`](0017-multiplexed-sensor-peripheral-and-sensor-rewire.md).

At decision time, [`Sensor`](../../local%20packages/Sensors/Sources/Sensors/Sensor.swift) talked directly to `AsyncCoreBluetooth.Peripheral` for discovery, read/write, notify, and characteristic value streams. Serialization lived at the [`SensorPeripheral`](../../local%20packages/Sensors/Sources/Sensors/Peripheral/SensorPeripheral.swift) boundary via `SerializedSensorPeripheral` (later removed in Phase 3), which mixed transport concerns with higher-level service/delegate composition.

We want a **thin GATT-shaped protocol** so decorators such as serialization (and future logging/retry) attach at the right layer, while [`SensorPeripheral`](../../local%20packages/Sensors/Sources/Sensors/Peripheral/SensorPeripheral.swift) stays oriented around services and delegate routing.

Alternatives considered:

- **UUID/string at the GATT layer** — simpler typing but duplicates catalog logic and pushes UUID plumbing deeper than needed.
- **Characteristic-typed API (chosen)** — reuse [`CharacteristicCatalog`](../../local%20packages/Sensors/Sources/Sensors/Primitives/CharacteristicCatalog.swift) for discovery; callers hold concrete [`Characteristic`](../../local%20packages/Sensors/Sources/Sensors/GATT/GATTPeripheral.swift) handles for I/O.

## Decision

1. Add **`GATTPeripheral`** ([`GATT/GATTPeripheral.swift`](../../local%20packages/Sensors/Sources/Sensors/GATT/GATTPeripheral.swift)): async throwing discover/read/write/setNotify; non-throwing `valueStream(for:)` returning `AsyncStream<Data>` (errors surface via read/setNotify; replay policy is adapter-defined via [`NotificationCharacteristicStream`](../../local%20packages/Sensors/Sources/Sensors/Primitives/NotificationCharacteristicStream.swift)).

2. Add **`AsyncCoreBluetoothGATTPeripheral`**: single adapter wrapping `AsyncCoreBluetooth.Peripheral`, mapping failures through [`SensorError.map(_:)`](../../local%20packages/Sensors/Sources/Sensors/SensorError.swift).

3. Add **`SerializedGATTPeripheral`** (actor): same gate-task chaining pattern as the retired `SerializedSensorPeripheral` (Phase 3 — [`0017-multiplexed-sensor-peripheral-and-sensor-rewire.md`](0017-multiplexed-sensor-peripheral-and-sensor-rewire.md)), using `Result` to propagate thrown errors through the gate; **`valueStream` remains `nonisolated` and forwards** so stream creation does not block serialized ops.

4. Add **`AnyGATTPeripheral`** + **`eraseToAnyGATTPeripheral()`** with idempotent double-erase (mirror [`AnySensorPeripheral`](../../local%20packages/Sensors/Sources/Sensors/Peripheral/AnySensorPeripheral.swift)).

5. **Phase 2 scope**: land types, adapter, decorator, eraser, and tests; defer rewiring [`Sensor`](../../local%20packages/Sensors/Sources/Sensors/Sensor.swift) onto `any GATTPeripheral` and defer retiring `SerializedSensorPeripheral` to Phase 3 ([`0017-multiplexed-sensor-peripheral-and-sensor-rewire.md`](0017-multiplexed-sensor-peripheral-and-sensor-rewire.md)).

## Consequences

**Positive**: Clear separation between raw GATT I/O and [`SensorPeripheral`](../../local%20packages/Sensors/Sources/Sensors/Peripheral/SensorPeripheral.swift); decorators stack at the transport layer; unit tests can target [`SerializedGATTPeripheral`](../../local%20packages/Sensors/Sources/Sensors/GATT/SerializedGATTPeripheral.swift) / [`AnyGATTPeripheral`](../../local%20packages/Sensors/Sources/Sensors/GATT/AnyGATTPeripheral.swift) with small stubs.

**Negative**: **Transient duplication** — until Phase 3, [`Sensor`](../../local%20packages/Sensors/Sources/Sensors/Sensor.swift) called `Peripheral` directly alongside [`SerializedGATTPeripheral`](../../local%20packages/Sensors/Sources/Sensors/GATT/SerializedGATTPeripheral.swift); sensor-layer serialization coexisted briefly (resolved in [`0017-multiplexed-sensor-peripheral-and-sensor-rewire.md`](0017-multiplexed-sensor-peripheral-and-sensor-rewire.md)).

**Risks / follow-ups**: Phase 3 rewired [`Sensor`](../../local%20packages/Sensors/Sources/Sensors/Sensor.swift) and introduced [`GATTSensorPeripheral`](../../local%20packages/Sensors/Sources/Sensors/Peripheral/GATTSensorPeripheral.swift) / [`MultiplexedSensorPeripheral`](../../local%20packages/Sensors/Sources/Sensors/Peripheral/MultiplexedSensorPeripheral.swift) — see [`0017-multiplexed-sensor-peripheral-and-sensor-rewire.md`](0017-multiplexed-sensor-peripheral-and-sensor-rewire.md). Remaining: explicit notify teardown via [`SensorPeripheral`](../../local%20packages/Sensors/Sources/Sensors/Peripheral/SensorPeripheral.swift) if needed; wiring the default stack at the app composition root.
