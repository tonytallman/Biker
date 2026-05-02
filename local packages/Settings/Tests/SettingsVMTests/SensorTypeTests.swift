//
//  SensorTypeTests.swift
//  SettingsVMTests
//

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
}
