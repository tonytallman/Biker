# 10. CSC stopped state: zero-delta emission + idle timeout

- **Status**: Accepted
- **Date**: 2026-05-01
- **Supersedes**: (none)
- **Superseded by**: (none)

## Context

GitHub issue [#39](https://github.com/tonytallman/Biker/issues/39): speed and cadence do not drop to zero when the bike stops.

The BLE Cycling Speed and Cadence (CSC) Measurement characteristic reports **cumulative revolutions** and **last event time** (time of the most recent revolution), not “current speed”. When the wheel or crank is idle, many peripherals keep sending notifications with **unchanged** revolution counts and **unchanged** last event times — the spec’s way of signaling “no new event”. Other peripherals **stop notifying** until motion resumes.

[`CSCDeltaCalculator`](../../local%20packages/CyclingSpeedAndCadenceService/Sources/CyclingSpeedAndCadenceService/CSCMeasurementParser.swift) previously required `revDelta > 0` and `timeDelta > 0`, so frozen payloads produced no update and UI kept the last non-zero speed/cadence.

Options considered:

1. **Zero-rev + zero-time delta only** — interpret consecutive identical `(revs, lastEventTime)` as stopped; fastest path for behavior (1).
2. **Idle wall-clock timeout only** — handles sensors that go silent; does not need payload interpretation but is slower and needs a testable scheduler.
3. **Both** — zero-delta for spec-correct fast path; timeout as safety net for silent sensors.

## Decision

1. In **`CSCDeltaCalculator`**, when both samples include wheel (or crank) data and **wrapping revolution delta is 0** and **wrapping `lastEventTime1024` delta is 0**, emit **explicit zeros** for that channel (`speed`/`distanceDelta` or `cadence`). Leave **`nil`** when `revDelta > 0` but event time delta is 0 (ambiguous / duplicate event time), and when `revDelta == 0` but event time delta is non-zero (do not emit spurious zero).

2. In **`CyclingSpeedAndCadenceSensor`**, after every emitted `CSCDerivedUpdate`, arm a **default 3 s idle timer** (injectable scheduler for tests). If no further derived update arrives before it fires, publish **0** for any channel currently **non-nil and non-zero**, and a derived update with **`distanceDeltaMeters: 0`**, then **disarm** until the next real update (no repeated zero spam). Cancel the timer on disconnect, derived reset, and when the sensor is disabled.

## Consequences

**Positive:** Stopped state matches CSC semantics and common firmware behavior; silent sensors still zero out within a bounded time; constant-motion payloads still advance revs and times, so they are not confused with stopped.

**Negative:** Idle timeout adds timer bookkeeping and requires cancellation on lifecycle changes; tests use a manual scheduler instead of `Task.sleep`.

**Risks / follow-ups:** Tunable `idleTimeout` if 3 s is wrong for some peripherals or UX; no change to FTMS in this ADR (CSC-only).
