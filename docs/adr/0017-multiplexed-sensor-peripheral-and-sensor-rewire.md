# 17. Multiplexed `SensorPeripheral` and `Sensor` GATT rewire

- **Status**: Accepted
- **Date**: 2026-05-07
- **Supersedes**: (none)
- **Superseded by**: (none)

## Context

Phase 2 introduced [`GATTPeripheral`](../../local%20packages/Sensors/Sources/Sensors/GATT/GATTPeripheral.swift) and [`SerializedGATTPeripheral`](../../local%20packages/Sensors/Sources/Sensors/GATT/SerializedGATTPeripheral.swift), while [`Sensor`](../../local%20packages/Sensors/Sources/Sensors/Sensor.swift) still duplicated low-level `AsyncCoreBluetooth.Peripheral` usage and `SerializedSensorPeripheral` serialized [`SensorPeripheral`](../../local%20packages/Sensors/Sources/Sensors/Peripheral/SensorPeripheral.swift) operations at the wrong abstraction layer ([`0016-introduce-gatt-peripheral-layer.md`](0016-introduce-gatt-peripheral-layer.md)).

We need one canonical stack: **GATT serialization**, **catalog-backed `SensorPeripheral`**, **subscriber multiplexing** for multi-consumer notify semantics, and **`Sensor`** delegating read/write/notify to `any GATTPeripheral`.

Alternatives considered:

- **`MultiplexedSensorPeripheral` as an actor** — `SensorPeripheral.subscribeTo` is synchronous and must bridge into [`NotificationMultiplexer`](../../local%20packages/Sensors/Sources/Sensors/Primitives/NotificationMultiplexer.swift) with `await`; using a **`final class`** avoids illegal isolation escapes while keeping [`SerializedGATTPeripheral`](../../local%20packages/Sensors/Sources/Sensors/GATT/SerializedGATTPeripheral.swift) as the serialization choke point for `has`/`read` via [`GATTSensorPeripheral`](../../local%20packages/Sensors/Sources/Sensors/Peripheral/GATTSensorPeripheral.swift).
- **Promoting lifecycle into `GATTPeripheral`** — rejected; [`ConnectionLifecycleObserver`](../../local%20packages/Sensors/Sources/Sensors/Primitives/ConnectionLifecycleObserver.swift) stays tied to `Peripheral` identity.

## Decision

1. Rewire [`Sensor`](../../local%20packages/Sensors/Sources/Sensors/Sensor.swift) to hold `any GATTPeripheral` for discovery/read/write/notify streams. Default [`init(peripheral:)`](../../local%20packages/Sensors/Sources/Sensors/Sensor.swift) builds `SerializedGATTPeripheral(AsyncCoreBluetoothGATTPeripheral(peripheral))`, discovers via `discoverAll()`, and wires [`NotificationMultiplexer`](../../local%20packages/Sensors/Sources/Sensors/Primitives/NotificationMultiplexer.swift) upstream through `setNotify` + `valueStream`.

2. Add [`init(gatt:lifecycle:catalog:peripheral:)`](../../local%20packages/Sensors/Sources/Sensors/Sensor.swift) for injection tests and composition roots (lifecycle must observe the same `Peripheral`).

3. Add [`GATTSensorPeripheral`](../../local%20packages/Sensors/Sources/Sensors/Peripheral/GATTSensorPeripheral.swift): [`CharacteristicCatalog`](../../local%20packages/Sensors/Sources/Sensors/Primitives/CharacteristicCatalog.swift) + `find(_:)` for cross-service characteristic lookup; maps string IDs to `gatt.read` / lazy `setNotify` inside `subscribeTo`’s stream.

4. Add [`MultiplexedSensorPeripheral`](../../local%20packages/Sensors/Sources/Sensors/Peripheral/MultiplexedSensorPeripheral.swift): **final class** wrapping `any SensorPeripheral`, multiplexing `subscribeTo(characteristicId:)` with `NotificationMultiplexer<String>`; **`has`/`read` forward without multiplex**. Teardown hook is intentionally empty until `SensorPeripheral` exposes explicit notify teardown.

5. Retire **`SerializedSensorPeripheral`** (removed); serialization for overlapping GATT awaits belongs in [`SerializedGATTPeripheral`](../../local%20packages/Sensors/Sources/Sensors/GATT/SerializedGATTPeripheral.swift).

Default composition at the root:

`MultiplexedSensorPeripheral(GATTSensorPeripheral(SerializedGATTPeripheral(AsyncCoreBluetoothGATTPeripheral(peripheral))))`.

## Consequences

**Positive**: Single transport serialization layer; `Sensor` and string-ID services share GATT primitives; reusable multiplex decorator for multi-subscriber `SensorPeripheral` streams.

**Negative**: **`SensorPeripheral.subscribeTo` cannot symmetrically disable notify on last cancel** without protocol changes; today teardown relies on disconnect or higher-layer policy. **`MultiplexedSensorPeripheral`** does not serialize `has`/`read` — callers MUST wrap inner [`GATTSensorPeripheral`](../../local%20packages/Sensors/Sources/Sensors/Peripheral/GATTSensorPeripheral.swift) with [`SerializedGATTPeripheral`](../../local%20packages/Sensors/Sources/Sensors/GATT/SerializedGATTPeripheral.swift) if overlapping suspensions must not interleave on transport.

**Risks / follow-ups**: Add explicit teardown to [`SensorPeripheral`](../../local%20packages/Sensors/Sources/Sensors/Peripheral/SensorPeripheral.swift) or a `MultiplexedGATTPeripheral` if `setNotify(false)` on unsubscribe becomes mandatory for battery/GATT hygiene; wire default composition at the app [`DependencyContainer`](../../local%20packages/DependencyContainer/Sources/DependencyContainer/) when HR/CSC/FTMS migrate off legacy stacks.
