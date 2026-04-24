//
//  HeartRateSensorTests.swift
//  HeartRateServiceTests
//

import Combine
import Foundation
import Testing

@testable import HeartRateService

@MainActor
struct HeartRateSensorTests {
    @Test func ingest_publishesBpm() {
        let s = HeartRateSensor(
            id: UUID(),
            name: "T",
            initialConnectionState: .connected
        )
        var values: [Double] = []
        let c = s.bpm.sink { values.append($0.converted(to: .beatsPerMinute).value) }
        let data = Data([0x00, 85])
        s._test_ingestHeartRateMeasurement(data)
        #expect(values.count == 1)
        #expect(values[0] == 85)
        _ = c
    }

    @Test func disabled_skipsProcessing() {
        let s = HeartRateSensor(
            id: UUID(),
            name: "T",
            initialConnectionState: .connected,
            initialIsEnabled: false
        )
        var count = 0
        let c = s.bpm.sink { _ in count += 1 }
        let data = Data([0x00, 90])
        s._test_ingestHeartRateMeasurement(data)
        #expect(count == 0)
        _ = c
    }

    @Test func resetDerivedState_allowsFreshIngest() {
        let s = HeartRateSensor(
            id: UUID(),
            name: "T",
            initialConnectionState: .connected
        )
        var values: [Double] = []
        let c = s.bpm.sink { values.append($0.converted(to: .beatsPerMinute).value) }
        s._test_ingestHeartRateMeasurement(Data([0x00, 100]))
        s.resetDerivedState()
        s._test_ingestHeartRateMeasurement(Data([0x00, 110]))
        #expect(values == [100, 110])
        _ = c
    }
}
