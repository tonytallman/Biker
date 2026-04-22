# 7. BluetoothAvailability as first-class state

- **Status**: Accepted
- **Date**: 2026-04-22
- **Supersedes**: (none)
- **Superseded by**: (none)

## Context

The SRS constrains Settings UI and behavior based on **Bluetooth permission** vs **radio power** ([SEN-PERM-1](../srs/Sensors.md)–[SEN-PERM-5](../srs/Sensors.md)) and ties **auto-reconnect** to permission and power ([SEN-PERS-2](../srs/Sensors.md)–[SEN-PERS-5](../srs/Sensors.md)). If each view or manager reads `CBCentralManager` state ad hoc, the UI will drift and bugs will be hard to reason about.

## Decision

1. Define a small **`BluetoothAvailability`** type (enum or struct) that models the **reduced** states Settings needs: permission not determined / denied / restricted (as applicable on iOS); central **unsupported** or **resetting** (if exposed); **powered off** vs **powered on** when authorized.

2. **`SensorProvider`** exposes `bluetoothAvailability: AnyPublisher<BluetoothAvailability, Never>` (or `AsyncStream` if the app standardizes on that later).

3. Each **per-type manager** that uses Core Bluetooth may expose its own `CBManager` state; the **`CompositeSensorProvider`** in [4. CompositeSensorProvider at the composition root](0004-composite-sensor-provider-at-composition-root.md) **reduces** multiple streams to **one** availability for Settings (managers for the same radio should agree; if not, the composite defines precedence — e.g. most restrictive for UI **gating**). Availability is tied to constructed managers per [8. No singletons for sensor managers](0008-no-singletons-for-sensor-managers.md).

4. **Auto-reconnect** and **scan** are **gated** by this availability: e.g. no auto-connect when power off or permission denied, matching the SRS. The Bluetooth section of [docs/architecture/Sensors.md](../architecture/Sensors.md) ties this to the SRS permission IDs.

## Consequences

**Positive:** Settings can render **one** permission vs power story; behavior matches SEN-PERM and SEN-PERS in one place. Previews and tests can inject a mock `SensorProvider` with a controlled availability stream.

**Negative:** Must map Apple’s evolving `CBManager` authorization and state APIs carefully; add unit tests when iOS changes behavior.

**Risks / follow-ups:** If reduction ever disagrees across managers, document the rule in the composite and add an integration test.
