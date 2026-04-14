//
//  SensorSettings.swift
//  Settings
//
//  Created by Tony Tallman on 4/12/26.
//

import Combine
import Foundation

@MainActor
public protocol SensorSettings {
    var sensors: AnyPublisher<[String], Never> { get }
    func scan()
}

@MainActor
public final class DefaultSensorSettings: SensorSettings {
    public let sensors: AnyPublisher<[String], Never>

    public init() {
        sensors = Just([]).eraseToAnyPublisher()
    }

    public func scan() {}
}

@MainActor
public struct PreviewSensorSettings: SensorSettings {
    public let sensors: AnyPublisher<[String], Never>

    public init() {
        sensors = Just(Self.previewSensorTitles).eraseToAnyPublisher()
    }

    public func scan() {}

    private static let previewSensorTitles = [
        "Bontrager DuoTrap",
        "Schwinn IC400",
    ]
}
