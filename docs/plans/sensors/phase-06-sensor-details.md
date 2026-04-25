# Phase 06 — Sensor Details screen + capability wiring

- **Status**: Not started
- **Depends on**: Phase 05 (composite wires `any Sensor` / `any WheelDiameterAdjustable`)

## Goal

Add a Sensor Details screen presented when the user taps a known
sensor. It shows name, type, connection state, and enabled state,
exposes connect/disconnect/forget/enable-toggle controls, dismisses
itself on forget, and — for CSC sensors — shows and edits wheel
diameter via an `as? any WheelDiameterAdjustable` discovery.

## Scope

### In

- In the `Settings` package:
  - `SensorDetailsViewModel` in `SettingsVM`:
    - Inputs: `any Sensor` and a dismissal closure.
    - Observable properties:
      `name`, `type`, `connectionState`, `isEnabled`,
      `wheelDiameter: Measurement<UnitLength>?` (nil for non-CSC).
    - Actions: `toggleEnabled`, `connect`, `disconnect`, `forget`,
      `setWheelDiameter(_:)`.
    - Narrows capability via `if let wheel = sensor as? any WheelDiameterAdjustable`.
  - `SensorDetailsView` in `SettingsUI`:
    - Rows for common fields; conditional wheel-diameter editor
      (e.g. `TextField` with a unit picker or a stepper in the current
      display distance unit) — converts to/from meters.
    - `Button` row for forget; confirmation alert.
    - Navigation from the known-sensor list row (push via
      `NavigationStack` or `NavigationLink`).
  - `SensorViewModel` gains a hashable identifier suitable for
    `navigationDestination(for:)` (or the view uses the sensor's UUID
    directly).
- Factory on `SettingsViewModel` (e.g. `makeSensorDetailsViewModel(for:)`)
  so the UI layer doesn't touch the provider.
- Localized strings for every new label and confirmation message.
- Tests:
  - `SensorDetailsViewModelTests` — CSC vs non-CSC: wheel-diameter is
    editable only for CSC; edits round-trip to the sensor's setter;
    forget triggers dismissal; actions forward.
  - SwiftUI preview using a `MockSensor` that conforms or does not
    conform to `WheelDiameterAdjustable`.

### Out

- Multi-family (FTMS / HR) sensors are handled automatically — this
  phase focuses on the Details surface. Once Phases 07/08 land, the
  screen must render their sensors without changes (validated in
  Phase 10 integration tests).
- Speed/distance recompute on wheel-diameter change is already handled
  by the Phase 02/03 plumbing (new diameter pushed into the calculator
  on next measurement, satisfying **SEN-DET-6**).

## SRS / ADR coverage

- **SEN-DET-1..6**.
- **SEN-KNOWN-1/2/3/4/5/7** through the Details controls.
- Realizes [ADR-0002](../../adr/0002-per-sensor-capability-protocols.md)
  in the UI (`as?` discovery of capability protocols).

## Deliverables

- `SensorDetailsViewModel.swift` in `SettingsVM`.
- `SensorDetailsView.swift` in `SettingsUI`.
- Navigation hookup in `SettingsView.swift`.
- New strings in `SettingsStrings`.
- Tests and preview.

## Acceptance criteria

- Tapping a known row pushes the Details screen with correct values
  that stay live while the sensor stream updates.
- Toggling enabled changes the row in the parent list immediately
  (disables auto-connect and disconnects if connected —
  **SEN-KNOWN-4/5**).
- Editing wheel diameter on a CSC sensor persists (Phase 03) and
  changes derived speed on the next sample (**SEN-DET-6**).
- Forget dismisses the Details view and removes the row (**SEN-DET-4**).
- Non-CSC preview sensors do not expose a wheel diameter row.

## Risks / follow-ups

- Wheel-diameter input UX: decide between free-form entry in
  millimeters and a preset list. Keep the editor internally in meters
  regardless, to avoid unit-conversion bugs.
- Dismissing on forget while a navigation transition is animating can
  race — gate the dismissal on the sensor's disappearance from the
  list or use a stable confirmation flow.
