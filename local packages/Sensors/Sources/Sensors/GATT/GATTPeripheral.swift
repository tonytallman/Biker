//
//  GATTPeripheral.swift
//  Sensors
//

import AsyncCoreBluetooth
import CoreBluetooth

/// Low-level GATT-oriented peripheral surface (UUID discovery lives in ``CharacteristicCatalog``).
///
/// Upper layers such as ``SensorPeripheral`` map string IDs onto ``Characteristic`` via the catalog.
package protocol GATTPeripheral: Sendable {
    func discoverAll() async throws -> CharacteristicCatalog

    func read(_ characteristic: Characteristic) async throws -> Data

    func write(
        _ data: Data,
        to characteristic: Characteristic,
        type: CBCharacteristicWriteType
    ) async throws

    func setNotify(_ enabled: Bool, for characteristic: Characteristic) async throws

    /// Notify-style value updates (replay suppression is adapter-defined).
    func valueStream(for characteristic: Characteristic) -> AsyncStream<Data>
}
