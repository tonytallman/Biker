//
//  MockSensorSettings.swift
//  SettingsVMTests
//
//  Created by Tony Tallman on 4/12/26.
//

import Combine
import Foundation

import SettingsModel

@MainActor
final class MockSensorSettings: SensorSettings {
    private let sensorsSubject = CurrentValueSubject<[String], Never>([])

    var sensors: AnyPublisher<[String], Never> {
        sensorsSubject.eraseToAnyPublisher()
    }

    private(set) var scanCallCount = 0

    func scan() {
        scanCallCount += 1
    }

    func setSensorTitles(_ titles: [String]) {
        sensorsSubject.send(titles)
    }
}
