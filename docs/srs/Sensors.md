# Definitions

- **Bluetooth permission**: the iOS authorization that allows the app to use Bluetooth. Distinct from Bluetooth power state.
- **Bluetooth power state**: whether the system Bluetooth radio is powered on. Distinct from permission.
- **Discovered sensor**: a sensor of a supported type that has been seen during an active scan but is not (yet) a known sensor.
- **Known sensor**: a sensor the user has connected to at least once. Persisted across app launches until forgotten.
- **Enabled / disabled**: a per-known-sensor flag that controls whether the app may auto-connect to it. Disabled sensors are remembered but never auto-connected.
- **Connection state**: one of *disconnected*, *connecting*, *connected*. Applies to both known and discovered sensors.
- **Source**: a producer of a metric (Speed, Cadence, or Heart Rate). Examples: a CSCS sensor, an FTMS sensor, CoreLocation, a Heart Rate Service sensor.
- **Wheel diameter**: the user-settable effective wheel diameter for a known Cycling Speed and Cadence Service (CSCS) sensor, used with wheel revolution counts to derive speed and wheel-based distance for that sensor.
- **Sensor Details view**: the screen shown when the user taps a known sensor (see `Sensor Details`).

# Settings

## Main Display

- `SEN-MAIN-1` The settings screen shall contain a Sensors section.
- `SEN-MAIN-2` The Sensors section shall provide an affordance to initiate a scan for sensors. See `Scan`.
- `SEN-MAIN-3` The Sensors section shall display the list of known sensors. See `Known Sensors`.

## Permissions & Bluetooth State

- `SEN-PERM-1` If Bluetooth permission is not granted, the Sensors section shall be replaced by a single message indicating that Bluetooth permission is not granted, and shall expose no scan affordance and no known-sensor list.
- `SEN-PERM-2` If Bluetooth permission is revoked while the app is running:
  - any active scan shall stop immediately,
  - all sensors shall be treated as disconnected,
  - the UI shall transition to the state described in `SEN-PERM-1`.
- `SEN-PERM-3` If Bluetooth permission is granted but the Bluetooth radio is powered off:
  - the Sensors section shall remain visible,
  - the software shall not display the known-sensor list or a discovered-sensor list (iOS Settings parity: “My devices” and “Other devices” are hidden when Bluetooth is off),
  - the scan affordance shall be disabled or not shown,
  - the software shall not attempt to auto-connect, and
  - the section shall display an indication that Bluetooth is off.
- `SEN-PERM-4` The permission-not-granted message defined in `SEN-PERM-1` shall take precedence over the Bluetooth-off indication defined in `SEN-PERM-3`.
- `SEN-PERM-5` All requirements in `Known Sensors`, `Scan`, `Sensor Details`, and `Persistence & Auto-Reconnect` are conditional on Bluetooth permission being granted.

## Known Sensors

- `SEN-KNOWN-1` The user shall be able to forget a known sensor, removing it from the list of known sensors.
- `SEN-KNOWN-2` Forgetting a sensor shall immediately disconnect it if it is connected or connecting.
- `SEN-KNOWN-3` The user shall be able to enable or disable a known sensor.
- `SEN-KNOWN-4` Disabling a sensor shall immediately disconnect it if it is connected or connecting.
- `SEN-KNOWN-5` Enabling a previously disabled sensor shall trigger a connect attempt if Bluetooth is powered on.
- `SEN-KNOWN-6` For each known sensor, the user shall be able to distinguish its connection state and its sensor type at a glance.
- `SEN-KNOWN-7` For each known sensor, the user shall be able to distinguish whether the sensor is enabled or disabled.
- `SEN-KNOWN-8` Each known Cycling Speed and Cadence Service (CSCS) sensor shall have a user-settable wheel diameter persisted with that sensor per `Persistence & Auto-Reconnect`.
- `SEN-KNOWN-9` A newly known CSCS sensor shall use a default wheel diameter supplied by the software until the user changes it.
- `SEN-KNOWN-10` Wheel diameter applies only to Speed (and wheel-revolution-based distance, if published) derived from that CSCS sensor; it does not apply to cadence, to FTMS, to CoreLocation, or to Heart Rate.

## Scan

- `SEN-SCAN-1` While scanning, the discovered-sensor experience shall be presented in a dismissible context separate from the main settings list.
- `SEN-SCAN-2` Dismissing the scan context shall stop the scan.
- `SEN-SCAN-3` The scan shall not impose a time limit; it shall run until dismissed by the user or until permission or power is lost.
- `SEN-SCAN-4` The software shall scan for all sensor types listed in `Sensor Types`.
- `SEN-SCAN-5` The software shall display a list of discovered sensors.
- `SEN-SCAN-6` For each discovered sensor, the user shall be able to distinguish its connection state and its sensor type at a glance.
- `SEN-SCAN-7` Discovered sensors shall be ordered as follows:
  - connected sensors first,
  - then unconnected sensors in order of descending signal strength (RSSI),
  - within each group, ties shall be broken by sensor name using a localized case-insensitive comparison.
- `SEN-SCAN-8` The displayed order shall not change within a single rendered frame except in response to a change in connection state or RSSI.
- `SEN-SCAN-9` The user shall be able to initiate a connection to any unconnected discovered sensor.
- `SEN-SCAN-10` The user shall be able to disconnect from any connected sensor shown in the scan list.
- `SEN-SCAN-11` Any sensor that the user has successfully connected to (whether from the scan list or any other source) shall be added to the list of known sensors and persisted per `Persistence & Auto-Reconnect`. New known sensors shall default to enabled.

## Sensor Details

- `SEN-DET-1` Tapping a known sensor in the Sensors section shall present a Sensor Details view for that sensor.
- `SEN-DET-2` The Sensor Details view shall display, at minimum:
  - sensor name,
  - sensor type,
  - connection state,
  - enabled state.
- `SEN-DET-3` The Sensor Details view shall provide controls to enable or disable the sensor, to connect or disconnect, and to forget the sensor.
- `SEN-DET-4` Forgetting a sensor from the Sensor Details view shall dismiss that view.
- `SEN-DET-5` For a known CSCS sensor, the Sensor Details view shall display the wheel diameter and shall allow the user to edit it.
- `SEN-DET-6` A change to wheel diameter for a known CSCS sensor shall take effect for Speed (and wheel-revolution-based distance, if published) derived from that sensor beginning with the next computation after the change.

## Sensor Types

- `SEN-TYP-1` The software shall support the following sensor types:
  - Cycling Speed and Cadence Service (CSCS), Bluetooth service UUID `0x1816`,
  - Fitness Machine Service (FTMS), Bluetooth service UUID `0x1826`,
  - Heart Rate Service, Bluetooth service UUID `0x180D`.
- `SEN-TYP-2` A CSC sensor may expose speed only, cadence only, or both. The source-selection rules in `Metrics` apply per metric independently.
- `SEN-TYP-3` Source selection for Speed and for Cadence is per metric. The active source for one metric may be a different physical sensor than the active source for another metric.
- `SEN-TYP-4` The software may maintain up to two simultaneously connected Cycling Speed and Cadence Service (CSCS) peripherals when required to supply Speed from one CSCS sensor and Cadence from another.
- `SEN-TYP-5` If a single connected CSCS sensor exposes both wheel and crank revolution data sufficient for Speed and Cadence, the software shall prefer that one sensor for both CSC-derived Speed and CSC-derived Cadence over using a second CSCS sensor for either metric.

## Persistence & Auto-Reconnect

- `SEN-PERS-1` The software shall persist the following per known sensor across app launches: identifier, last known name, sensor type, enabled state, and, for CSCS sensors, wheel diameter.
- `SEN-PERS-2` On app launch, when Bluetooth permission is granted and the Bluetooth radio is powered on, the software shall attempt to connect to each enabled known sensor.
- `SEN-PERS-3` When the Bluetooth radio transitions from any state to powered on, the software shall attempt to connect to each enabled known sensor that is currently disconnected.
- `SEN-PERS-4` When Bluetooth permission transitions from not-granted to granted, the software shall apply `SEN-PERS-3` as if the radio had just powered on.
- `SEN-PERS-5` Disabled known sensors shall not be auto-connected under any of `SEN-PERS-2`, `SEN-PERS-3`, or `SEN-PERS-4`.

# Metrics

## General

- `MET-GEN-1` Each metric (Speed, Cadence, Heart Rate, Elapsed Time, Distance) shall have a single active source at any time, chosen from the per-metric priority list for that metric.
- `MET-GEN-2` The active source shall be the highest-priority source that is currently connected. If no source in the priority list is connected, the metric shall be reported as unavailable and no value shall be emitted. If more than one source ties at the highest applicable priority step for that metric, the software shall select exactly one active source using a deterministic rule.
- `MET-GEN-3` While a source is active, the metric shall be published no less than once per second.

## Speed

- `MET-SPD-1` The software shall publish a Speed metric to the dashboard.
- `MET-SPD-2` The Speed source priority shall be, from highest to lowest:
  1. Cycling Speed and Cadence Service (CSCS) sensor,
  2. Fitness Machine Service (FTMS) sensor,
  3. Device location via CoreLocation.
- `MET-SPD-3` Source selection for Speed shall follow `MET-GEN-1` and `MET-GEN-2`.
- `MET-SPD-4` When Speed is derived from a CSCS sensor using wheel revolutions, the derivation shall use the wheel diameter stored for that sensor per `Known Sensors`, `Sensor Details`, and `Persistence & Auto-Reconnect`.

## Cadence

- `MET-CAD-1` The software shall publish a Cadence metric to the dashboard.
- `MET-CAD-2` The Cadence source priority shall be, from highest to lowest:
  1. Cycling Speed and Cadence Service (CSCS) sensor,
  2. Fitness Machine Service (FTMS) sensor.
- `MET-CAD-3` Source selection for Cadence shall follow `MET-GEN-1` and `MET-GEN-2`.

## Heart Rate

- `MET-HR-1` The software shall publish a Heart Rate metric to the dashboard.
- `MET-HR-2` The Heart Rate source priority shall be, from highest to lowest:
  1. Heart Rate Service (Bluetooth service UUID `0x180D`) sensor.
  2. Fitness Machine Service (FTMS) sensor (instantaneous heart rate from Indoor Bike Data when present).
- `MET-HR-3` Source selection for Heart Rate shall follow `MET-GEN-1` and `MET-GEN-2`.

## Elapsed Time

- `MET-TIME-1` The software shall publish an elapsed time metric to the dashboard for the active ride session.
- `MET-TIME-2` The Elapsed Time source priority shall be, from highest to lowest:
  1. Fitness Machine Service (FTMS) elapsed time field from Indoor Bike Data when present from a connected FTMS peripheral.
  2. Sum of periodic time increments while the ride context is active (internal ride timer).
- `MET-TIME-3` Source selection for Elapsed Time shall follow `MET-GEN-1` and `MET-GEN-2`.

## Distance

- `MET-DIST-1` The software shall publish a Distance metric to the dashboard for the active ride session.
- `MET-DIST-2` The Distance source priority shall be, from highest to lowest:
  1. Fitness Machine Service (FTMS) Total Distance from Indoor Bike Data when present from a connected FTMS peripheral.
  2. Internal distance accumulator: sum of selected distance deltas (Fitness Machine indoor-bike deltas and speed-integration fallback, Cycling Speed and Cadence-derived wheel distance deltas, and Core Location distance deltas while the ride context is active).
- `MET-DIST-3` Source selection for Distance shall follow `MET-GEN-1` and `MET-GEN-2`.
