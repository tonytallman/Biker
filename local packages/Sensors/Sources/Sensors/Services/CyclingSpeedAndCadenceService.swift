//
//  CyclingSpeedAndCadenceService.swift
//  Sensors
//
//  Created by Tony Tallman on 5/5/26.
//

import Foundation

package final class CyclingSpeedAndCadenceService: @unchecked Sendable {
    package protocol Delegate {
        func has(serviceId: String) async -> Bool
        func read(characteristicId: String) async -> Data?
        func subscribeTo(characteristicId: String) -> AsyncStream<Data>
    }

    private struct WheelTrack {
        let continuation: AsyncStream<Measurement<UnitSpeed>>.Continuation
        let circumferenceMeters: Double
        var previous: (revs: UInt32, timeTicks: UInt16)?

        func finish() {
            continuation.finish()
        }
    }

    private struct CrankTrack {
        let continuation: AsyncStream<Measurement<UnitFrequency>>.Continuation
        var previous: (revs: UInt16, timeTicks: UInt16)?

        func finish() {
            continuation.finish()
        }
    }

    private let delegate: Delegate

    private static let serviceId = "1816"
    private static let measurementCharacteristicId = "2A5B"
    private static let featureCharacteristicId = "2A5C"

    package let speed: AsyncStream<Measurement<UnitSpeed>>?
    package let cadence: AsyncStream<Measurement<UnitFrequency>>?

    private var wheelTrack: WheelTrack?
    private var crankTrack: CrankTrack?

    private nonisolated(unsafe) var ingestTask: Task<Void, Never>?

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

        var speedStream: AsyncStream<Measurement<UnitSpeed>>?
        if capabilities.wheel {
            guard let wheelCircumference else {
                return nil
            }
            let (stream, continuation) = AsyncStream<Measurement<UnitSpeed>>.makeStream(
                bufferingPolicy: .bufferingNewest(1)
            )
            speedStream = stream
            self.wheelTrack = WheelTrack(
                continuation: continuation,
                circumferenceMeters: wheelCircumference.converted(to: .meters).value,
                previous: nil
            )
        }

        var cadenceStream: AsyncStream<Measurement<UnitFrequency>>?
        if capabilities.crank {
            let (stream, continuation) = AsyncStream<Measurement<UnitFrequency>>.makeStream(
                bufferingPolicy: .bufferingNewest(1)
            )
            cadenceStream = stream
            self.crankTrack = CrankTrack(continuation: continuation, previous: nil)
        }

        self.speed = speedStream
        self.cadence = cadenceStream

        let dataStream = delegate.subscribeTo(characteristicId: Self.measurementCharacteristicId)
        ingestTask = Task { [weak self] in
            for await data in dataStream {
                guard let self else { break }
                self.handleMeasurement(data)
            }
        }
    }

    deinit {
        ingestTask?.cancel()
        wheelTrack?.finish()
        crankTrack?.finish()
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
                    track.continuation.yield(
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
                    track.continuation.yield(Measurement(value: rpm, unit: UnitFrequency.revolutionsPerMinute))
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
