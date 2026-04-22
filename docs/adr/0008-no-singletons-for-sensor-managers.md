# 8. No singletons for sensor managers

- **Status**: Accepted
- **Date**: 2026-04-22
- **Supersedes**: (none)
- **Superseded by**: (none)

## Context

Earlier design notes referenced **`.shared`** singletons for per-type sensor managers. Singletons complicate **testing** (global order-dependent state), **preview** apps, and **future extensions** (e.g. multiple app scenes or test doubles), and they hide **construction order** in the composition root.

## Decision

1. **`CyclingSpeedAndCadenceSensorManager`**, **`FitnessMachineSensorManager`**, and **`HeartRateSensorManager`** are **ordinary reference types** created in **`DependencyContainer`** (or a dedicated `SensorsDependencies` type owned by it).

2. **`CompositeSensorProvider`** receives these instances via **constructor injection** per [4. CompositeSensorProvider at the composition root](0004-composite-sensor-provider-at-composition-root.md).

3. **No** `static let shared` on production sensor managers. Test targets may use factory methods or test doubles as needed.

4. **Lifetime:** The composition root **retains** managers for the app lifetime, matching the need to keep `CBCentralManager` and subscriptions alive (same as current `DependencyContainer` pattern for other long-lived services).

## Consequences

**Positive:** Clear ownership and replaceability in tests; aligns with DI best practices. No hidden global initialization order.

**Negative:** Slightly more constructor parameters in `DependencyContainer` / factory types — acceptable.

**Risks / follow-ups:** None beyond keeping new long-lived services out of `static` globals; see the module map in [docs/architecture/Sensors.md](../architecture/Sensors.md).
