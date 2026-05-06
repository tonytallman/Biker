# 15. Adopt AsyncCoreBluetooth for `Sensors` transport

- **Status**: Accepted
- **Date**: 2026-05-06
- **Supersedes**: (none)
- **Superseded by**: (none)

## Context

The `Sensors` package implemented a custom CoreBluetooth bridge (`CBPeripheralDelegate` forwarding, checked continuations, notification ref-counting, Combine bootstrap). Under Swift 6 strict concurrency and CoreBluetooth’s legacy delegate API, this layer accumulated `@unchecked Sendable` adapters and actor hopping.

[`AsyncCoreBluetooth`](https://github.com/meech-ward/AsyncCoreBluetooth) centralizes the same delegate-to-async translation for scanning, connection state, discovery, read/write, and characteristic value streams. Stable semver releases currently depend on branch-pinned transitive packages (CoreBluetooth mock), which SwiftPM rejects when the consumer depends only on tagged versions—so this repo pins **`AsyncCoreBluetooth` at branch `main`** until upstream publishes a semver graph with pinned transitive versions.

## Decision

1. Add **`AsyncCoreBluetooth`** as an SPM dependency of the **`Sensors`** package and refactor [`Sensor.swift`](../../local%20packages/Sensors/Sources/Sensors/Sensor.swift) to delegate peripheral I/O to `AsyncCoreBluetooth.Peripheral` instead of a bespoke `Forwarder`/`CBPeripheralDelegate` implementation.

2. Raise **`Sensors`** platform minimums to align with `AsyncCoreBluetooth` / `AsyncObservable`: **macOS 14**, **iOS 17**, **watchOS 10**, **tvOS 17** (replacing prior macOS 12 / tvOS 15 floors).

3. Keep **`SensorError`** and the three service types’ **`Delegate`** protocols and Combine-facing publishers unchanged so existing parsing and delegate tests remain valid.

## Consequences

**Positive**: Less custom concurrency/CoreBluetooth glue in-tree; fewer `@unchecked` bridging types; discovery/read/write/notify paths reuse a maintained async wrapper.

**Negative**: **Branch-pinned** dependency on `AsyncCoreBluetooth` (and its transitive branch pins) until upstream publishes releases with pinned transitive deps; **platform minimum bump** for `Sensors` consumers.

**Risks / follow-ups**: Monitor upstream releases for semver + pinned transitives and switch from `branch: "main"` to a version range when possible; extend tests around `Sensor` (disconnect, notify refcounting) once BLE fakes are wired.
