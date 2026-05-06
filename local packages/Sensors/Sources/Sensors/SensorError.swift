//
//  SensorError.swift
//  Sensors
//
//  Created by Tony Tallman on 5/5/26.
//

import CoreBluetooth

package enum SensorError: Error, @unchecked Sendable {
    case serviceNotFound(CBUUID)
    case characteristicNotFound(CBUUID, in: CBUUID)
    case underlying(Error)
    case disconnected
}
