//
//  CyclingSpeedAndCadenceService.swift
//  Sensors
//
//  Created by Tony Tallman on 5/5/26.
//

import Combine
import Foundation

package class CyclingSpeedAndCadenceService {
    package protocol Delegate {
        func has(serviceId: String) async -> Bool
        func read(characteristicId: String) async -> Data?
        func subscribeTo(characteristicId: String) -> AnyPublisher<Data, Never>
    }

    private struct WheelTrack {
        let subject: PassthroughSubject<Measurement<UnitSpeed>, Never>
        let circumferenceMeters: Double
        var previous: (revs: UInt32, timeTicks: UInt16)?
    }

    private struct CrankTrack {
        let subject: PassthroughSubject<Measurement<UnitFrequency>, Never>
        var previous: (revs: UInt16, timeTicks: UInt16)?
    }

    private let delegate: Delegate

    private static let serviceId = "1816"
    private static let measurementCharacteristicId = "2A5B"
    private static let featureCharacteristicId = "2A5C"

    package let speed: AnyPublisher<Measurement<UnitSpeed>, Never>?
    package let cadence: AnyPublisher<Measurement<UnitFrequency>, Never>?

    private var wheelTrack: WheelTrack?
    private var crankTrack: CrankTrack?

    private var cancellable: AnyCancellable?

    package init?(delegate: Delegate, wheelCircumference: Measurement<UnitLength>?) async {
        guard
            await delegate.has(serviceId: Self.serviceId),
            let featureData = await delegate.read(characteristicId: Self.featureCharacteristicId),
            let capabilities = Self.parseFeature(featureData),
            capabilities.wheel || capabilities.crank
        else {
            return nil
        }

        self.delegate = delegate
        self.wheelTrack = nil
        self.crankTrack = nil

        if capabilities.wheel {
            guard let wheelCircumference else {
                return nil
            }
            self.wheelTrack = WheelTrack(
                subject: PassthroughSubject(),
                circumferenceMeters: wheelCircumference.converted(to: .meters).value,
                previous: nil
            )
        }
        if capabilities.crank {
            self.crankTrack = CrankTrack(subject: PassthroughSubject(), previous: nil)
        }

        self.speed = self.wheelTrack?.subject.eraseToAnyPublisher()
        self.cadence = self.crankTrack?.subject.eraseToAnyPublisher()

        subscribeToMeasurement()
    }

    private func subscribeToMeasurement() {
        cancellable = delegate.subscribeTo(characteristicId: Self.measurementCharacteristicId)
            .sink { [weak self] data in
                self?.handleMeasurement(data)
            }
    }

    private func handleMeasurement(_ data: Data) {
        guard let parsed = Self.parseMeasurement(data) else {
            return
        }

        if var track = wheelTrack,
           let revs = parsed.wheelRevs,
           let ticks = parsed.wheelEventTicks {
            if let prev = track.previous {
                let deltaTicks = ticks &- prev.timeTicks
                if deltaTicks != 0 {
                    let deltaRevs = Double(revs &- prev.revs)
                    let seconds = Double(deltaTicks) / 1024.0
                    track.subject.send(
                        Measurement(value: deltaRevs * track.circumferenceMeters / seconds, unit: UnitSpeed.metersPerSecond)
                    )
                }
            }
            track.previous = (revs, ticks)
            wheelTrack = track
        }

        if var track = crankTrack,
           let revs = parsed.crankRevs,
           let ticks = parsed.crankEventTicks {
            if let prev = track.previous {
                let deltaTicks = ticks &- prev.timeTicks
                if deltaTicks != 0 {
                    let deltaRevs = Double(revs &- prev.revs)
                    let rpm = deltaRevs / (Double(deltaTicks) / 1024.0) * 60.0
                    track.subject.send(Measurement(value: rpm, unit: UnitFrequency.revolutionsPerMinute))
                }
            }
            track.previous = (revs, ticks)
            crankTrack = track
        }
    }

    /// CSC Feature characteristic `2A5C`; first word is UInt16 LE feature flags.
    private static func parseFeature(_ data: Data) -> (wheel: Bool, crank: Bool)? {
        guard let word = data.readUInt16LE(byteOffset: 0) else { return nil }
        let wheel = (word & 0x01) != 0
        let crank = (word & 0x02) != 0
        return (wheel, crank)
    }

    private struct ParsedMeasurement {
        var wheelRevs: UInt32?
        var wheelEventTicks: UInt16?
        var crankRevs: UInt16?
        var crankEventTicks: UInt16?
    }

    /// CSC Measurement characteristic `2A5B`; layout follows CSC Service specification.
    private static func parseMeasurement(_ data: Data) -> ParsedMeasurement? {
        guard let flagsByte = data.first else {
            return nil
        }
        var parsed = ParsedMeasurement()
        var offset = 1

        if (flagsByte & 0x01) != 0 {
            guard let revs = data.readUInt32LE(byteOffset: offset) else { return nil }
            offset += 4
            guard let ticks = data.readUInt16LE(byteOffset: offset) else { return nil }
            offset += 2
            parsed.wheelRevs = revs
            parsed.wheelEventTicks = ticks
        }

        if (flagsByte & 0x02) != 0 {
            guard let revs = data.readUInt16LE(byteOffset: offset) else { return nil }
            offset += 2
            guard let ticks = data.readUInt16LE(byteOffset: offset) else { return nil }
            offset += 2
            parsed.crankRevs = revs
            parsed.crankEventTicks = ticks
        }

        return parsed
    }
}
