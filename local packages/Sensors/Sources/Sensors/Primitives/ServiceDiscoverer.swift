//
//  ServiceDiscoverer.swift
//  Sensors
//

import AsyncCoreBluetooth
import CoreBluetooth

package enum ServiceDiscoverer {
    package static func discoverAll(on peripheral: Peripheral) async throws -> CharacteristicCatalog {
        do {
            let services = try await peripheral.discoverServices(nil)
            var map: [CBUUID: [CBUUID: Characteristic]] = [:]
            for (serviceUUID, service) in services {
                map[serviceUUID] = try await peripheral.discoverCharacteristics(nil, for: service)
            }
            return CharacteristicCatalog(services: map)
        } catch {
            throw SensorError.map(error)
        }
    }
}
