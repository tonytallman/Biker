//
//  CharacteristicCatalog.swift
//  Sensors
//

import AsyncCoreBluetooth
import CoreBluetooth

/// Snapshot of discovered services and characteristics keyed by ``CBUUID``.
package struct CharacteristicCatalog: @unchecked Sendable {
    private let services: [CBUUID: [CBUUID: Characteristic]]

    package init(services: [CBUUID: [CBUUID: Characteristic]]) {
        self.services = services
    }

    package func has(service: CBUUID) -> Bool {
        services[service] != nil
    }

    package func has(characteristic: CBUUID, in service: CBUUID) -> Bool {
        services[service]?[characteristic] != nil
    }

    package func require(_ characteristic: CBUUID, in service: CBUUID) throws -> Characteristic {
        guard services[service] != nil else {
            throw SensorError.serviceNotFound(service)
        }
        guard let ch = services[service]?[characteristic] else {
            throw SensorError.characteristicNotFound(characteristic, in: service)
        }
        return ch
    }

    /// First characteristic matching `characteristic` UUID across any discovered service (typical layout has unique characteristic UUIDs).
    package func find(_ characteristic: CBUUID) -> Characteristic? {
        for (_, chars) in services {
            if let ch = chars[characteristic] {
                return ch
            }
        }
        return nil
    }
}
