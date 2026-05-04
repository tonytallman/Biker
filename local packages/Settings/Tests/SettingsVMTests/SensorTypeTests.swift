//
//  SensorTypeTests.swift
//  SettingsVMTests
//

import Foundation
import Testing

import SettingsVM

@Suite("SensorType (SF Symbols for known-sensor rows, #37)")
struct SensorTypeTests {
    @Test(arguments: [
        (SensorType.cyclingSpeedAndCadence, "figure.outdoor.cycle.circle" as String),
        (.fitnessMachine, "figure.indoor.cycle.circle"),
        (.heartRate, "heart.circle"),
    ])
    func sfSymbolName_matchesIssueSpec(type: SensorType, expectedSymbol: String) {
        #expect(type.sfSymbolName == expectedSymbol)
    }

    @Test func sfSymbolName_coversAllCases() {
        for type in SensorType.allCases {
            #expect(!type.sfSymbolName.isEmpty)
        }
    }

    @Test func priorityRank_ordersFTMSThenCSCThenHR() {
        #expect(SensorType.fitnessMachine.priorityRank < SensorType.cyclingSpeedAndCadence.priorityRank)
        #expect(SensorType.cyclingSpeedAndCadence.priorityRank < SensorType.heartRate.priorityRank)
    }

    @Test @MainActor
    func deduplicateSensorsByPeripheralPriority_prefersFTMSOverCSCAndHR() {
        let u = UUID()
        let csc = MockPlainSensor(id: u, name: "Dev", type: .cyclingSpeedAndCadence)
        let ftms = MockPlainSensor(id: u, name: "Dev", type: .fitnessMachine)
        let hr = MockPlainSensor(id: u, name: "Dev", type: .heartRate)
        let one = deduplicateSensorsByPeripheralPriority([csc, ftms, hr])
        #expect(one.count == 1)
        #expect(one.first?.type == .fitnessMachine)

        let u2 = UUID()
        let cscOnly = MockPlainSensor(id: u2, name: "A", type: .cyclingSpeedAndCadence)
        let hrOnly = MockPlainSensor(id: u2, name: "A", type: .heartRate)
        let pickCsc = deduplicateSensorsByPeripheralPriority([cscOnly, hrOnly])
        #expect(pickCsc.count == 1)
        #expect(pickCsc.first?.type == .cyclingSpeedAndCadence)
    }
}
