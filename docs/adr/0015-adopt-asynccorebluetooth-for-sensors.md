# 15. Adopt AsyncCoreBluetooth for `Sensors` transport

- **Status**: Accepted
- **Date**: 2026-05-06
- **Supersedes**: (none)
- **Superseded by**: (none)

## Context

The `Sensors` package previously implemented a custom CoreBluetooth bridge (`CBPeripheralDelegate` forwarding, checked continuations, notification ref-counting). Under Swift 6 strict concurrency and CoreBluetooth’s legacy delegate API, that layer accumulated `@unchecked Sendable` adapters and actor hopping.

[`AsyncCoreBluetooth`](https://github.com/meech-ward/AsyncCoreBluetooth) centralizes the same delegate-to-async translation for scanning, connection state, discovery, read/write, and characteristic value streams. Stable semver releases currently depend on branch-pinned transitive packages (CoreBluetooth mock), which SwiftPM rejects when the consumer depends only on tagged versions—so this repo pins **`AsyncCoreBluetooth` at branch `main`** until upstream publishes a semver graph with pinned transitive versions.

## Decision

1. Add **`AsyncCoreBluetooth`** as an SPM dependency of the **`Sensors`** package and refactor [`Sensor.swift`](../../local%20packages/Sensors/Sources/Sensors/Sensor.swift) to delegate peripheral I/O to `AsyncCoreBluetooth.Peripheral` instead of a bespoke `Forwarder`/`CBPeripheralDelegate` implementation.

2. Raise **`Sensors`** platform minimums to align with `AsyncCoreBluetooth` / `AsyncObservable`: **macOS 14**, **iOS 17**, **watchOS 10**, **tvOS 17** (replacing prior macOS 12 / tvOS 15 floors).

3. Expose streaming sensor data as **`AsyncSequence`** / `AsyncStream` / `AsyncThrowingStream` (not Combine): [`Sensor.subscribe(to:in:)`](../../local%20packages/Sensors/Sources/Sensors/Sensor.swift) returns `AsyncThrowingStream<Data, Error>` with continuation multiplexing for multi-consumer notify ref-counting; service types expose `AsyncStream<Measurement<…>>` outputs and `Delegate.subscribeTo` returns `AsyncStream<Data>`. Add **`swift-async-algorithms`** as an SPM dependency (prototype; [`AsyncAlgorithmsAnchor.swift`](../../local%20packages/Sensors/Sources/Sensors/AsyncAlgorithmsAnchor.swift) keeps the product linked for composition experiments).

4. Keep **`SensorError`**, GATT parsers, and the three service **`Delegate`** shapes stable aside from the Combine → `AsyncSequence` substitution so parsing and delegate tests remain valid.

## Consequences

**Positive**: Less custom concurrency/CoreBluetooth glue in-tree; Combine/`Future`/`PassthroughSubject` bridging removed from `Sensor` and services; discovery/read/write/notify paths reuse a maintained async wrapper; streaming API aligns with Swift concurrency.

**Negative**: **Branch-pinned** dependency on `AsyncCoreBluetooth` (and its transitive branch pins) until upstream publishes releases with pinned transitive deps; **platform minimum bump** for `Sensors` consumers; **additional** `swift-async-algorithms` dependency; service classes use **`@unchecked Sendable`** where ingest `Task` closures touch instance state.

**Risks / follow-ups**: Monitor upstream releases for semver + pinned transitives and switch from `branch: "main"` to a version range when possible; `Sensor` integration tests cover disconnect and notify refcounting via `CoreBluetoothMock`; `AsyncCoreBluetooth`’s characteristic `value` stream may replay cached values—[`Sensor`](../../local%20packages/Sensors/Sources/Sensors/Sensor.swift) skips the first replay after re-subscribe where needed; re-evaluate `AsyncAlgorithmsAnchor` / algorithms usage once composition patterns land.
