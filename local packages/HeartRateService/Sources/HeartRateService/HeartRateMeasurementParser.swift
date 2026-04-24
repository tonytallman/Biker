//
//  HeartRateMeasurementParser.swift
//  HeartRateService
//
//  Parses BLE Heart Rate Measurement characteristic (UUID 0x2A37).
//

import Foundation

public enum HRParseError: Error, Equatable, Sendable {
    case dataTooShort(minimumBytes: Int)
}

/// Parsed heart rate from a single notification (BPM only; RR intervals and energy ignored).
public struct HeartRateMeasurement: Equatable, Sendable {
    public let bpm: Double

    public init(bpm: Double) {
        self.bpm = bpm
    }
}

/// Stateless parse of raw Heart Rate Measurement `Data` (flags byte + 8- or 16-bit value).
public enum HeartRateMeasurementParser {
    private static let flagHeartRateValueFormatUInt16: UInt8 = 1 << 0

    public static func parse(_ data: Data) -> Result<HeartRateMeasurement, HRParseError> {
        guard !data.isEmpty else {
            return .failure(.dataTooShort(minimumBytes: 1))
        }
        let flags = data[data.startIndex]
        let useUInt16 = (flags & Self.flagHeartRateValueFormatUInt16) != 0
        let need = useUInt16 ? 3 : 2
        guard data.count >= need else {
            return .failure(.dataTooShort(minimumBytes: need))
        }
        let bpm: Double
        if useUInt16 {
            bpm = Double(readUInt16LE(data, offset: 1))
        } else {
            bpm = Double(data[data.startIndex + 1])
        }
        return .success(HeartRateMeasurement(bpm: bpm))
    }

    private static func readUInt16LE(_ data: Data, offset: Int) -> UInt16 {
        let i = data.startIndex + offset
        let lo = UInt16(data[i])
        let hi = UInt16(data[i + 1]) << 8
        return lo | hi
    }
}
