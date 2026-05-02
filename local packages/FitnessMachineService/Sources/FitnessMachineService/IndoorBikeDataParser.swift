//
//  IndoorBikeDataParser.swift
//  FitnessMachineService
//
//  Parses BLE Fitness Machine Indoor Bike Data characteristic (UUID 0x2AD2).
//  See Bluetooth Fitness Machine Service specification.
//

import Foundation

public enum FTMSParseError: Error, Equatable, Sendable {
    case dataTooShort(minimumBytes: Int)
}

/// Parsed Indoor Bike Data notification (instantaneous speed / cadence / total distance when present).
public struct IndoorBikeData: Equatable, Sendable {
    public let speedMetersPerSecond: Double?
    public let cadenceRPM: Double?
    /// Total accumulated distance (last 24 bits of the field) in meters when the Total Distance flag is set.
    public let totalDistanceMeters: Double?

    public init(speedMetersPerSecond: Double?, cadenceRPM: Double?, totalDistanceMeters: Double? = nil) {
        self.speedMetersPerSecond = speedMetersPerSecond
        self.cadenceRPM = cadenceRPM
        self.totalDistanceMeters = totalDistanceMeters
    }
}

/// Stateless parse of raw Indoor Bike Data `Data` (flags + optional fields in spec order).
public enum IndoorBikeDataParser {
    private static let flagMoreData: UInt16 = 1 << 0
    private static let flagAverageSpeed: UInt16 = 1 << 1
    private static let flagInstantaneousCadence: UInt16 = 1 << 2
    private static let flagAverageCadence: UInt16 = 1 << 3
    private static let flagTotalDistance: UInt16 = 1 << 4
    private static let flagResistanceLevel: UInt16 = 1 << 5
    private static let flagInstantaneousPower: UInt16 = 1 << 6
    private static let flagAveragePower: UInt16 = 1 << 7
    private static let flagExpendedEnergy: UInt16 = 1 << 8
    private static let flagHeartRate: UInt16 = 1 << 9
    private static let flagMetabolicEquivalent: UInt16 = 1 << 10
    private static let flagElapsedTime: UInt16 = 1 << 11
    private static let flagRemainingTime: UInt16 = 1 << 12

    public static func parse(_ data: Data) -> Result<IndoorBikeData, FTMSParseError> {
        guard data.count >= 2 else {
            return .failure(.dataTooShort(minimumBytes: 2))
        }
        let flags = readUInt16LE(data, offset: 0)
        var o = 2
        var speed: Double?
        var cadence: Double?
        var totalDistance: Double?

        // Bit 0 "More Data": when set, Instantaneous Speed is omitted.
        if flags & flagMoreData == 0 {
            let need = o + 2
            guard data.count >= need else { return .failure(.dataTooShort(minimumBytes: need)) }
            let raw = readUInt16LE(data, offset: o)
            o += 2
            let kmh = Double(raw) * 0.01
            speed = Measurement(value: kmh, unit: UnitSpeed.kilometersPerHour)
                .converted(to: .metersPerSecond).value
        }

        if flags & flagAverageSpeed != 0 {
            let need = o + 2
            guard data.count >= need else { return .failure(.dataTooShort(minimumBytes: need)) }
            o += 2
        }

        if flags & flagInstantaneousCadence != 0 {
            let need = o + 2
            guard data.count >= need else { return .failure(.dataTooShort(minimumBytes: need)) }
            let raw = readUInt16LE(data, offset: o)
            o += 2
            cadence = Double(raw) * 0.5
        }

        if flags & flagAverageCadence != 0 {
            let need = o + 2
            guard data.count >= need else { return .failure(.dataTooShort(minimumBytes: need)) }
            o += 2
        }

        if flags & flagTotalDistance != 0 {
            let need = o + 3
            guard data.count >= need else { return .failure(.dataTooShort(minimumBytes: need)) }
            let raw24 = readUInt24LE(data, offset: o)
            totalDistance = Double(raw24)
            o += 3
        }

        if flags & flagResistanceLevel != 0 {
            let need = o + 2
            guard data.count >= need else { return .failure(.dataTooShort(minimumBytes: need)) }
            o += 2
        }

        if flags & flagInstantaneousPower != 0 {
            let need = o + 2
            guard data.count >= need else { return .failure(.dataTooShort(minimumBytes: need)) }
            o += 2
        }

        if flags & flagAveragePower != 0 {
            let need = o + 2
            guard data.count >= need else { return .failure(.dataTooShort(minimumBytes: need)) }
            o += 2
        }

        if flags & flagExpendedEnergy != 0 {
            let need = o + 5
            guard data.count >= need else { return .failure(.dataTooShort(minimumBytes: need)) }
            o += 5
        }

        if flags & flagHeartRate != 0 {
            let need = o + 1
            guard data.count >= need else { return .failure(.dataTooShort(minimumBytes: need)) }
            o += 1
        }

        if flags & flagMetabolicEquivalent != 0 {
            let need = o + 1
            guard data.count >= need else { return .failure(.dataTooShort(minimumBytes: need)) }
            o += 1
        }

        if flags & flagElapsedTime != 0 {
            let need = o + 2
            guard data.count >= need else { return .failure(.dataTooShort(minimumBytes: need)) }
            o += 2
        }

        if flags & flagRemainingTime != 0 {
            let need = o + 2
            guard data.count >= need else { return .failure(.dataTooShort(minimumBytes: need)) }
            o += 2
        }

        return .success(IndoorBikeData(
            speedMetersPerSecond: speed,
            cadenceRPM: cadence,
            totalDistanceMeters: totalDistance
        ))
    }

    private static func readUInt16LE(_ data: Data, offset: Int) -> UInt16 {
        let i = data.startIndex + offset
        let lo = UInt16(data[i])
        let hi = UInt16(data[i + 1]) << 8
        return lo | hi
    }

    private static func readUInt24LE(_ data: Data, offset: Int) -> UInt32 {
        let i = data.startIndex + offset
        let b0 = UInt32(data[i])
        let b1 = UInt32(data[i + 1]) << 8
        let b2 = UInt32(data[i + 2]) << 16
        return b0 | b1 | b2
    }
}
