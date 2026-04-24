//
//  CSCFeatureParser.swift
//  CyclingSpeedAndCadenceService
//
//  CSC Measurement Service — Feature characteristic (UUID 0x2A5C).
//

import Foundation

/// Parsed CSC Feature field (first 16 bits). See Bluetooth CSC Service specification.
public struct CSCFeature: Equatable, Sendable {
    /// Bit 0 — wheel revolution data supported.
    public let supportsWheel: Bool
    /// Bit 1 — crank revolution data supported.
    public let supportsCrank: Bool

    public init(supportsWheel: Bool, supportsCrank: Bool) {
        self.supportsWheel = supportsWheel
        self.supportsCrank = supportsCrank
    }

    /// `true` when both wheel and crank capabilities are advertised (SEN-TYP-5 dual-capable sensor).
    public var isDualCapable: Bool { supportsWheel && supportsCrank }

    public static func parse(_ data: Data) -> CSCFeature? {
        guard data.count >= 2 else { return nil }
        let raw = UInt16(data[0]) | (UInt16(data[1]) << 8)
        return CSCFeature(
            supportsWheel: (raw & 0x0001) != 0,
            supportsCrank: (raw & 0x0002) != 0
        )
    }
}
