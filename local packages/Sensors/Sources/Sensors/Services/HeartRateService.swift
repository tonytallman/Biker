//
//  HeartRateService.swift
//  Sensors
//
//  Created by Tony Tallman on 5/5/26.
//

import Combine
import Foundation

package class HeartRateService {
    package protocol Delegate {
        func has(serviceId: String) async -> Bool
        func subscribeTo(characteristicId: String) -> AnyPublisher<Data, Never>
    }

    private let delegate: Delegate

    private static let serviceId = "180D"
    private static let heartRateCharacteristicId = "2A37"

    package let heartRate: AnyPublisher<Measurement<UnitFrequency>, Never>
    private let heartRateSubject = PassthroughSubject<Measurement<UnitFrequency>, Never>()
    private var cancellable: AnyCancellable?

    package init?(delegate: Delegate) async {
        guard await delegate.has(serviceId: Self.serviceId) else {
            return nil
        }

        self.delegate = delegate
        self.heartRate = heartRateSubject.eraseToAnyPublisher()

        subscribeToHeartRateData()
    }

    private func subscribeToHeartRateData() {
        cancellable = delegate.subscribeTo(characteristicId: Self.heartRateCharacteristicId)
            .map { Self.parseHeartRate(from: $0) }
            .compactMap { $0 }
            .map { Measurement(value: Double($0), unit: UnitFrequency.beatsPerMinute) }
            .sink { [weak self] measurement in
                self?.heartRateSubject.send(measurement)
            }
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
