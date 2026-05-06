//
//  HeartRateService.swift
//  Sensors
//
//  Created by Tony Tallman on 5/5/26.
//

import Foundation

package final class HeartRateService: @unchecked Sendable {
    package protocol Delegate {
        func has(serviceId: String) async -> Bool
        func subscribeTo(characteristicId: String) -> AsyncStream<Data>
    }

    private let delegate: Delegate

    private static let serviceId = "180D"
    private static let heartRateCharacteristicId = "2A37"

    private let heartRateContinuation: AsyncStream<Measurement<UnitFrequency>>.Continuation
    package let heartRate: AsyncStream<Measurement<UnitFrequency>>

    private nonisolated(unsafe) var ingestTask: Task<Void, Never>?

    package init?(delegate: Delegate) async {
        guard await delegate.has(serviceId: Self.serviceId) else {
            return nil
        }

        self.delegate = delegate

        let (stream, continuation) = AsyncStream<Measurement<UnitFrequency>>.makeStream(
            bufferingPolicy: .bufferingNewest(1)
        )
        self.heartRate = stream
        self.heartRateContinuation = continuation

        let dataStream = delegate.subscribeTo(characteristicId: Self.heartRateCharacteristicId)
        ingestTask = Task { [weak self] in
            for await data in dataStream {
                guard let self else { break }
                guard let bpm = Self.parseHeartRate(from: data) else { continue }
                self.heartRateContinuation.yield(Measurement(value: Double(bpm), unit: UnitFrequency.beatsPerMinute))
            }
        }
    }

    deinit {
        ingestTask?.cancel()
        heartRateContinuation.finish()
    }

    /// Parses a Heart Rate Measurement packet (Bluetooth GATT characteristic 0x2A37).
    /// Returns BPM, or `nil` if the packet is malformed.
    private static func parseHeartRate(from data: Data) -> UInt16? {
        guard let flags = data.first else { return nil }
        let isUInt16 = (flags & 0x01) != 0

        if isUInt16 {
            return data.readUInt16LE(byteOffset: 1)
        } else {
            guard data.count >= 2 else { return nil }
            return UInt16(data[data.startIndex + 1])
        }
    }
}
