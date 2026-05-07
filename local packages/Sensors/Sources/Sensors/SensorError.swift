//
//  SensorError.swift
//  Sensors
//
//  Created by Tony Tallman on 5/5/26.
//

import AsyncCoreBluetooth
import CoreBluetooth

package enum SensorError: Error, @unchecked Sendable {
    case serviceNotFound(CBUUID)
    case characteristicNotFound(CBUUID, in: CBUUID)
    case underlying(Error)
    case disconnected

    /// Maps CoreBluetooth / AsyncCoreBluetooth failures into ``SensorError``.
    package nonisolated static func map(_ error: Error) -> SensorError {
        if let existing = error as? SensorError {
            return existing
        }
        if let peripheralError = error as? PeripheralConnectionError, peripheralError == .disconnectedWhileWorking {
            return .disconnected
        }
        return .underlying(error)
    }
}
