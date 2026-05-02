//
//  FitnessMachineSensorDistanceTests.swift
//  FitnessMachineServiceTests
//

import Combine
import Foundation
import Testing

@testable import FitnessMachineService

@MainActor
struct FitnessMachineSensorDistanceTests {
    /// More Data (omit inst. speed) + Total Distance; 24-bit LE meters = 1000.
    private var totalDistanceThousandMeters: Data {
        Data([0x11, 0x00, 0xE8, 0x03, 0x00])
    }

    @Test func totalDistance_emitsZeroThenDelta() {
        let s = FitnessMachineSensor(
            id: UUID(),
            name: "T",
            initialConnectionState: .connected
        )
        var deltas: [Double] = []
        let c = s.distanceDelta.compactMap { $0 }.sink { deltas.append($0) }

        s._test_ingestIndoorBikeData(Data([0x11, 0x00, 0x00, 0x00, 0x00]))
        s._test_ingestIndoorBikeData(Data([0x11, 0x00, 0x19, 0x00, 0x00]))
        #expect(deltas == [0, 25])
        _ = c
    }

    @Test func totalDistance_negativeDelta_emitsZeroAndReanchors() {
        let s = FitnessMachineSensor(
            id: UUID(),
            name: "T",
            initialConnectionState: .connected
        )
        var deltas: [Double] = []
        let c = s.distanceDelta.compactMap { $0 }.sink { deltas.append($0) }

        s._test_ingestIndoorBikeData(Data([0x11, 0x00, 0x10, 0x00, 0x00]))
        s._test_ingestIndoorBikeData(Data([0x11, 0x00, 0x05, 0x00, 0x00]))
        s._test_ingestIndoorBikeData(Data([0x11, 0x00, 0x0F, 0x00, 0x00]))
        #expect(deltas == [0, 0, 10])
        _ = c
    }

    @Test func speedOnly_twoSamples_emitsSpeedTimesDt() {
        let s = FitnessMachineSensor(
            id: UUID(),
            name: "T",
            initialConnectionState: .connected
        )
        var t = 0.0
        s.distanceMonotonicNow = { t }

        var deltas: [Double] = []
        let c = s.distanceDelta
            .compactMap { $0 }
            .sink { deltas.append($0) }

        // 10 m/s
        s._test_ingestIndoorBikeData(Data([0x00, 0x00, 0x10, 0x0E]))
        t = 2
        s._test_ingestIndoorBikeData(Data([0x00, 0x00, 0x10, 0x0E]))
        #expect(deltas.count == 1)
        #expect(abs(deltas[0] - 20.0) < 0.0001)
        _ = c
    }

    @Test func distanceAvailable_falseUntilDelta_thenTrue_resetClears() {
        let s = FitnessMachineSensor(
            id: UUID(),
            name: "T",
            initialConnectionState: .connected
        )
        var flags: [Bool] = []
        let c = s.distanceAvailable.sink { flags.append($0) }

        #expect(flags == [false])

        s._test_ingestIndoorBikeData(Data([0x11, 0x00, 0x00, 0x00, 0x00]))
        #expect(flags.last == true)

        s.resetDerivedState()
        #expect(flags.last == false)

        _ = c
    }

    @Test func resetDerivedState_clearsDistanceBaseline() {
        let s = FitnessMachineSensor(
            id: UUID(),
            name: "T",
            initialConnectionState: .connected
        )
        var compact: [Double] = []
        let c = s.distanceDelta.compactMap { $0 }.sink { compact.append($0) }

        s._test_ingestIndoorBikeData(totalDistanceThousandMeters)
        s.resetDerivedState()
        s._test_ingestIndoorBikeData(totalDistanceThousandMeters)
        #expect(compact.last == 0)
        _ = c
    }
}
