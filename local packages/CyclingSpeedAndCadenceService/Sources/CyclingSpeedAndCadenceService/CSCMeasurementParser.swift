//
//  CSCMeasurementParser.swift
//  CyclingSpeedAndCadenceService
//
//  Parses BLE Cycling Speed and Cadence (CSC) Measurement characteristic (UUID 0x2A5B).
//  See Bluetooth CSC Service 1.0.
//

import Foundation

public enum CSCParseError: Error, Equatable, Sendable {
    case dataTooShort(minimumBytes: Int)
    case invalidFlags
}

/// Wheel revolution fields from CSC Measurement when the wheel flag is set.
public struct CSCWheelSample: Equatable, Sendable {
    public let cumulativeRevolutions: UInt32
    /// Last wheel event time in 1/1024 second units (UInt16 wraps).
    public let lastEventTime1024: UInt16
}

/// Crank revolution fields from CSC Measurement when the crank flag is set.
public struct CSCCrankSample: Equatable, Sendable {
    public let cumulativeRevolutions: UInt16
    public let lastEventTime1024: UInt16
}

/// Parsed CSC Measurement payload (one notification).
public struct CSCMeasurement: Equatable, Sendable {
    public let wheel: CSCWheelSample?
    public let crank: CSCCrankSample?

    public init(wheel: CSCWheelSample?, crank: CSCCrankSample?) {
        self.wheel = wheel
        self.crank = crank
    }
}

/// Derived instantaneous values from consecutive CSC measurements.
public struct CSCDerivedUpdate: Equatable, Sendable {
    /// Ground speed from wheel data, m/s. Nil if wheel data was not usable for this sample.
    public let speedMetersPerSecond: Double?
    /// Cadence from crank data, revolutions per minute. Nil if crank data was not usable.
    public let cadenceRPM: Double?
    /// Distance covered since the previous wheel sample, meters. Nil if no wheel delta.
    public let distanceDeltaMeters: Double?

    public init(
        speedMetersPerSecond: Double?,
        cadenceRPM: Double?,
        distanceDeltaMeters: Double?
    ) {
        self.speedMetersPerSecond = speedMetersPerSecond
        self.cadenceRPM = cadenceRPM
        self.distanceDeltaMeters = distanceDeltaMeters
    }
}

public enum CSCDefaults {
    /// Typical 700×25c effective circumference (meters).
    public static let defaultWheelCircumferenceMeters: Double = 2.105
}

/// Stateless parse of raw CSC Measurement `Data`.
public enum CSCMeasurementParser {
    private static let flagWheelRevolutionDataPresent: UInt8 = 1 << 0
    private static let flagCrankRevolutionDataPresent: UInt8 = 1 << 1

    /// Parses CSC Measurement bytes. Returns failure if the buffer is too short for the flags.
    public static func parse(_ data: Data) -> Result<CSCMeasurement, CSCParseError> {
        guard !data.isEmpty else {
            return .failure(.dataTooShort(minimumBytes: 1))
        }
        let flags = data[data.startIndex]
        let wheelPresent = (flags & flagWheelRevolutionDataPresent) != 0
        let crankPresent = (flags & flagCrankRevolutionDataPresent) != 0

        var offset = 1
        var wheel: CSCWheelSample?
        var crank: CSCCrankSample?

        if wheelPresent {
            let need = offset + 6
            guard data.count >= need else {
                return .failure(.dataTooShort(minimumBytes: need))
            }
            let revs = readUInt32LE(data, offset: offset)
            let time = readUInt16LE(data, offset: offset + 4)
            wheel = CSCWheelSample(cumulativeRevolutions: revs, lastEventTime1024: time)
            offset += 6
        }

        if crankPresent {
            let need = offset + 4
            guard data.count >= need else {
                return .failure(.dataTooShort(minimumBytes: need))
            }
            let revs = readUInt16LE(data, offset: offset)
            let time = readUInt16LE(data, offset: offset + 2)
            crank = CSCCrankSample(cumulativeRevolutions: revs, lastEventTime1024: time)
        }

        if !wheelPresent && !crankPresent {
            return .failure(.invalidFlags)
        }

        return .success(CSCMeasurement(wheel: wheel, crank: crank))
    }

    private static func readUInt16LE(_ data: Data, offset: Int) -> UInt16 {
        let i = data.startIndex + offset
        let lo = UInt16(data[i])
        let hi = UInt16(data[i + 1]) << 8
        return lo | hi
    }

    private static func readUInt32LE(_ data: Data, offset: Int) -> UInt32 {
        let i = data.startIndex + offset
        let b0 = UInt32(data[i])
        let b1 = UInt32(data[i + 1]) << 8
        let b2 = UInt32(data[i + 2]) << 16
        let b3 = UInt32(data[i + 3]) << 24
        return b0 | b1 | b2 | b3
    }
}

/// Computes speed, cadence, and distance deltas from successive CSC measurements (peripheral-local state).
public struct CSCDeltaCalculator {
    private var previous: CSCMeasurement?
    public var wheelCircumferenceMeters: Double

    public init(wheelCircumferenceMeters: Double = CSCDefaults.defaultWheelCircumferenceMeters) {
        self.wheelCircumferenceMeters = wheelCircumferenceMeters
        self.previous = nil
    }

    /// Feed the next measurement; returns nil on the first sample or if deltas cannot be computed.
    public mutating func push(_ measurement: CSCMeasurement) -> CSCDerivedUpdate? {
        guard let prev = previous else {
            previous = measurement
            return nil
        }
        defer { previous = measurement }

        var speed: Double?
        var distanceDelta: Double?
        if let w0 = prev.wheel, let w1 = measurement.wheel {
            let revDelta = wrappingDeltaUInt32(old: w0.cumulativeRevolutions, new: w1.cumulativeRevolutions)
            let timeDeltaSec = wrappingDeltaTimeSeconds(
                old: w0.lastEventTime1024,
                new: w1.lastEventTime1024
            )
            if let dt = timeDeltaSec, dt > 0, revDelta > 0 {
                let revD = Double(revDelta)
                distanceDelta = revD * wheelCircumferenceMeters
                speed = distanceDelta! / dt
            }
        }

        var cadenceRPM: Double?
        if let c0 = prev.crank, let c1 = measurement.crank {
            let revDelta = wrappingDeltaUInt16(old: c0.cumulativeRevolutions, new: c1.cumulativeRevolutions)
            let timeDeltaSec = wrappingDeltaTimeSeconds(
                old: c0.lastEventTime1024,
                new: c1.lastEventTime1024
            )
            if let dt = timeDeltaSec, dt > 0, revDelta > 0 {
                cadenceRPM = Double(revDelta) / dt * 60.0
            }
        }

        if speed == nil, cadenceRPM == nil, distanceDelta == nil {
            return nil
        }
        return CSCDerivedUpdate(
            speedMetersPerSecond: speed,
            cadenceRPM: cadenceRPM,
            distanceDeltaMeters: distanceDelta
        )
    }

    public mutating func reset() {
        previous = nil
    }
}

private func wrappingDeltaUInt16(old: UInt16, new: UInt16) -> UInt16 {
    new &- old
}

private func wrappingDeltaUInt32(old: UInt32, new: UInt32) -> UInt32 {
    new &- old
}

/// Converts delta in 1/1024 s units to seconds using UInt16 wrap semantics.
private func wrappingDeltaTimeSeconds(old: UInt16, new: UInt16) -> Double? {
    let delta1024 = UInt32(wrappingDeltaUInt16(old: old, new: new))
    if delta1024 == 0 { return nil }
    return Double(delta1024) / 1024.0
}
