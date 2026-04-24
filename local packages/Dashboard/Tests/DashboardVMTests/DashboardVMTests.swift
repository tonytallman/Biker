//
//  DashboardVMTests.swift
//  DashboardVMTests
//

import Combine
import Foundation
import Testing

@testable import DashboardVM

@MainActor
struct DashboardVMTests {
    private static var testBPMUnit: UnitFrequency {
        UnitFrequency(symbol: "bpm", converter: UnitConverterLinear(coefficient: 1.0 / 60.0))
    }

    private static var testRPMUnit: UnitFrequency {
        UnitFrequency(symbol: "rpm", converter: UnitConverterLinear(coefficient: 1.0 / 60.0))
    }

    private func makeViewModel(
        heartRate: AnyPublisher<Measurement<UnitFrequency>?, Never>
    ) -> DashboardViewModel {
        DashboardViewModel(
            speed: Just(Measurement(value: 1, unit: UnitSpeed.metersPerSecond)).eraseToAnyPublisher(),
            cadence: Just(Measurement(value: 1, unit: Self.testRPMUnit)).eraseToAnyPublisher(),
            time: Just(Measurement(value: 1, unit: UnitDuration.seconds)).eraseToAnyPublisher(),
            distance: Just(Measurement(value: 1, unit: UnitLength.meters)).eraseToAnyPublisher(),
            heartRate: heartRate
        )
    }

    @Test
    func heartRate_nil_leavesHeartRateBPMNil() {
        let vm = makeViewModel(heartRate: Just(nil).eraseToAnyPublisher())
        #expect(vm.heartRateBPM == nil)
    }

    @Test
    func heartRate_value_formatsRoundedInteger() {
        let subject = CurrentValueSubject<Measurement<UnitFrequency>?, Never>(nil)
        let vm = makeViewModel(heartRate: subject.eraseToAnyPublisher())
        #expect(vm.heartRateBPM == nil)
        subject.send(Measurement(value: 118.7, unit: Self.testBPMUnit))
        #expect(vm.heartRateBPM == "119")
    }

    @Test
    func heartRate_cleared_setsNil() {
        let subject = CurrentValueSubject<Measurement<UnitFrequency>?, Never>(
            Measurement(value: 100, unit: Self.testBPMUnit)
        )
        let vm = makeViewModel(heartRate: subject.eraseToAnyPublisher())
        #expect(vm.heartRateBPM == "100")
        subject.send(nil)
        #expect(vm.heartRateBPM == nil)
    }
}
