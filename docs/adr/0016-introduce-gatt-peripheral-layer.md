# 16. Introduce GATT peripheral layer (`GATTPeripheral`)

- **Status**: Accepted
- **Date**: 2026-05-06
- **Supersedes**: (none)
- **Superseded by**: (none)

## Context

[`Sensor`](../../local%20packages/Sensors/Sources/Sensors/Sensor.swift) talks directly to `AsyncCoreBluetooth.Peripheral` for discovery, read/write, notify, and characteristic value streams. Serialization today lives at the [`SensorPeripheral`](../../local%20packages/Sensors/Sources/Sensors/Peripheral/SensorPeripheral.swift) boundary via [`SerializedSensorPeripheral`](../../local%20packages/Sensors/Sources/Sensors/Peripheral/SerializedSensorPeripheral.swift), which mixes transport concerns with higher-level service/delegate composition.

We want a **thin GATT-shaped protocol** so decorators such as serialization (and future logging/retry) attach at the right layer, while [`SensorPeripheral`](../../local%20packages/Sensors/Sources/Sensors/Peripheral/SensorPeripheral.swift) stays oriented around services and delegate routing.

Alternatives considered:

- **UUID/string at the GATT layer** — simpler typing but duplicates catalog logic and pushes UUID plumbing deeper than needed.
- **Characteristic-typed API (chosen)** — reuse [`CharacteristicCatalog`](../../local%20packages/Sensors/Sources/Sensors/Primitives/CharacteristicCatalog.swift) for discovery; callers hold concrete [`Characteristic`](../../local%20packages/Sensors/Sources/Sensors/GATT/GATTPeripheral.swift) handles for I/O.

## Decision

1. Add **`GATTPeripheral`** ([`GATT/GATTPeripheral.swift`](../../local%20packages/Sensors/Sources/Sensors/GATT/GATTPeripheral.swift)): async throwing discover/read/write/setNotify; non-throwing `valueStream(for:)` returning `AsyncStream<Data>` (errors surface via read/setNotify; replay policy is adapter-defined via [`NotificationCharacteristicStream`](../../local%20packages/Sensors/Sources/Sensors/Primitives/NotificationCharacteristicStream.swift)).

2. Add **`AsyncCoreBluetoothGATTPeripheral`**: single adapter wrapping `AsyncCoreBluetooth.Peripheral`, mapping failures through [`SensorError.map(_:)`](../../local%20packages/Sensors/Sources/Sensors/SensorError.swift).

3. Add **`SerializedGATTPeripheral`** (actor): same gate-task chaining pattern as [`SerializedSensorPeripheral`](../../local%20packages/Sensors/Sources/Sensors/Peripheral/SerializedSensorPeripheral.swift), using `Result` to propagate thrown errors through the gate; **`valueStream` remains `nonisolated` and forwards** so stream creation does not block serialized ops.

4. Add **`AnyGATTPeripheral`** + **`eraseToAnyGATTPeripheral()`** with idempotent double-erase (mirror [`AnySensorPeripheral`](../../local%20packages/Sensors/Sources/Sensors/Peripheral/AnySensorPeripheral.swift)).

5. **Phase 2 scope**: land types, adapter, decorator, eraser, and tests; **do not** rewire [`Sensor`](../../local%20packages/Sensors/Sources/Sensors/Sensor.swift) or remove [`SerializedSensorPeripheral`](../../local%20packages/Sensors/Sources/Sensors/Peripheral/SerializedSensorPeripheral.swift) yet — a follow-up phase moves [`Sensor`](../../local%20packages/Sensors/Sources/Sensors/Sensor.swift) onto `any GATTPeripheral` and retires sensor-layer serialization where redundant.

## Consequences

**Positive**: Clear separation between raw GATT I/O and [`SensorPeripheral`](../../local%20packages/Sensors/Sources/Sensors/Peripheral/SensorPeripheral.swift); decorators stack at the transport layer; unit tests can target [`SerializedGATTPeripheral`](../../local%20packages/Sensors/Sources/Sensors/GATT/SerializedGATTPeripheral.swift) / [`AnyGATTPeripheral`](../../local%20packages/Sensors/Sources/Sensors/GATT/AnyGATTPeripheral.swift) with small stubs.

**Negative**: **Transient duplication** — [`Sensor`](../../local%20packages/Sensors/Sources/Sensors/Sensor.swift) continues to call `Peripheral` directly until the rewire; two serialization paths ([`SerializedSensorPeripheral`](../../local%20packages/Sensors/Sources/Sensors/Peripheral/SerializedSensorPeripheral.swift) vs [`SerializedGATTPeripheral`](../../local%20packages/Sensors/Sources/Sensors/GATT/SerializedGATTPeripheral.swift)) coexist briefly.

**Risks / follow-ups**: Rewire [`Sensor`](../../local%20packages/Sensors/Sources/Sensors/Sensor.swift) (or successor) to consume `any GATTPeripheral`; compose default stack at the composition root (e.g. multiplexing notify streams + serialized GATT adapter); revisit [`SensorPeripheral`](../../local%20packages/Sensors/Sources/Sensors/Peripheral/SensorPeripheral.swift)-side multi-subscriber policy in a dedicated ADR if needed.
