//
//  MockBLEPeripheral.swift
//  SensorsTests
//

import CoreBluetooth
@preconcurrency import CoreBluetoothMock
import Foundation

/// Minimal Heart Rate GATT layout for ``Sensor`` integration tests.
enum MockBLEPeripheral {
    static let serviceUUID = CBUUID(string: "180D")
    static let measurementUUID = CBUUID(string: "2A37")
    static let controlUUID = CBUUID(string: "2A39")

    static let measurementCharacteristic = CBMCharacteristicMock(
        type: measurementUUID,
        properties: [.read, .notify]
    )

    static let controlCharacteristic = CBMCharacteristicMock(
        type: controlUUID,
        properties: [.write, .writeWithoutResponse]
    )

    static let heartRateService = CBMServiceMock(
        type: serviceUUID,
        primary: true,
        characteristics: [measurementCharacteristic, controlCharacteristic]
    )

    static func makeSpec(identifier: UUID = UUID(), delegate: CBMPeripheralSpecDelegate) -> CBMPeripheralSpec {
        CBMPeripheralSpec
            .simulatePeripheral(identifier: identifier, proximity: .near)
            .advertising(
                advertisementData: [
                    CBMAdvertisementDataLocalNameKey: "HR Sensor",
                    CBMAdvertisementDataServiceUUIDsKey: [heartRateService.uuid],
                    CBMAdvertisementDataIsConnectable: true as NSNumber,
                ],
                withInterval: 0.250
            )
            .connectable(
                name: "HR Sensor",
                services: [heartRateService],
                delegate: delegate,
                connectionInterval: 0.045,
                mtu: 23
            )
            .allowForRetrieval()
            .build()
    }
}

/// Tracks ATT interactions used to assert notify refcounting and read/write paths.
final class HeartRatePeripheralDelegate: CBMPeripheralSpecDelegate {

    var measurementReadPayload = Data([0x06, 65])
    private(set) var lastWrittenControlPayload: Data?
    private(set) var notifyTransitions: [(uuid: CBUUID, enabled: Bool)] = []

    func peripheral(
        _ peripheral: CBMPeripheralSpec,
        didReceiveReadRequestFor characteristic: CBMCharacteristicMock
    ) -> Result<Data, Error> {
        if characteristic.uuid == MockBLEPeripheral.measurementUUID {
            return .success(measurementReadPayload)
        }
        return .failure(CBATTError(.readNotPermitted))
    }

    func peripheral(
        _ peripheral: CBMPeripheralSpec,
        didReceiveWriteRequestFor characteristic: CBMCharacteristicMock,
        data: Data
    ) -> Result<Void, Error> {
        if characteristic.uuid == MockBLEPeripheral.controlUUID {
            lastWrittenControlPayload = data
            return .success(())
        }
        return .failure(CBATTError(.writeNotPermitted))
    }

    func peripheral(
        _ peripheral: CBMPeripheralSpec,
        didReceiveWriteCommandFor characteristic: CBMCharacteristicMock,
        data: Data
    ) {
        if characteristic.uuid == MockBLEPeripheral.controlUUID {
            lastWrittenControlPayload = data
        }
    }

    func peripheral(
        _ peripheral: CBMPeripheralSpec,
        didReceiveSetNotifyRequest enabled: Bool,
        for characteristic: CBMCharacteristicMock
    ) -> Result<Void, Error> {
        notifyTransitions.append((characteristic.uuid, enabled))
        if characteristic.uuid == MockBLEPeripheral.measurementUUID {
            return .success(())
        }
        return .failure(CBMError(.invalidHandle))
    }
}
