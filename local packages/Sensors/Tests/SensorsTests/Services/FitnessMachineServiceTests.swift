//
//  FitnessMachineServiceTests.swift
//  Sensors
//
//  Created by Tony Tallman on 5/6/26.
//

import Foundation
import Testing

import Sensors

struct FitnessMachineServiceTests {
    @Test func initReturnsNilWhenServiceOrFeatureMissing() async {
        let delegate = MockFitnessMachineDelegate()
        delegate.hasFitnessMachineService = false
        delegate.featureCharacteristicValue = Data([0x00, 0x00, 0x00, 0x00])
        #expect(await FitnessMachineService(delegate: delegate) == nil)

        delegate.hasFitnessMachineService = true
        delegate.featureCharacteristicValue = nil
        #expect(await FitnessMachineService(delegate: delegate) == nil)
    }

    @Test func optionalStreamsNilWhenCapabilitiesDisabled() async throws {
        let delegate = MockFitnessMachineDelegate()
        // Only bit 0 set in feature word would be... actually 0x00000001 might still parse.
        // Use word with no cadence/distance/hr/elapsed bits.
        delegate.featureCharacteristicValue = Data([0x00, 0x00, 0x00, 0x00])
        let service = try #require(await FitnessMachineService(delegate: delegate))
        #expect(service.cadence == nil)
        #expect(service.distance == nil)
        #expect(service.heartRate == nil)
        #expect(service.elapsedTime == nil)
    }

    @Test func indoorBikeInstantaneousSpeed() async throws {
        let delegate = MockFitnessMachineDelegate()
        delegate.featureCharacteristicValue = Data([0x00, 0x00, 0x00, 0x00])
        let service = try #require(await FitnessMachineService(delegate: delegate))

        var speed: Measurement<UnitSpeed>?
        let cancellable = service.speed.sink { speed = $0 }

        // Flags 0 -> speed present; 2500 raw -> 25 km/h
        delegate.indoorBikeData.send(Data([0x00, 0x00, 0xC4, 0x09]))

        cancellable.cancel()

        #expect(speed?.value == 25.0)
        #expect(speed?.unit == .kilometersPerHour)
    }

    @Test func indoorBikeCadenceWhenCapabilityEnabled() async throws {
        let delegate = MockFitnessMachineDelegate()
        delegate.featureCharacteristicValue = Data([0x02, 0x00, 0x00, 0x00]) // cadence bit
        let service = try #require(await FitnessMachineService(delegate: delegate))

        var cadence: Measurement<UnitFrequency>?
        let cancellable = try #require(service.cadence).sink { cadence = $0 }

        // More data (omit inst speed) + cadence: flags 0x0005 LE [0x05, 0x00]; cadence raw 100 -> 50 rpm
        delegate.indoorBikeData.send(Data([0x05, 0x00, 0x64, 0x00]))

        cancellable.cancel()

        #expect(cadence?.value == 50.0)
        #expect(cadence?.unit == .revolutionsPerMinute)
    }

    @Test func indoorBikeDistanceHeartRateElapsed() async throws {
        let delegate = MockFitnessMachineDelegate()
        let featureWord = (1 << 2) | (1 << 10) | (1 << 12) // distance + HR + elapsed
        let featureLE = withUnsafeBytes(of: UInt32(featureWord).littleEndian, Array.init)
        delegate.featureCharacteristicValue = Data(featureLE)

        let service = try #require(await FitnessMachineService(delegate: delegate))

        var distance: Measurement<UnitLength>?
        var heart: Measurement<UnitFrequency>?
        var elapsed: Measurement<UnitDuration>?

        let dC = try #require(service.distance).sink { distance = $0 }
        let hC = try #require(service.heartRate).sink { heart = $0 }
        let eC = try #require(service.elapsedTime).sink { elapsed = $0 }

        // Build flags: more data (0x01) | distance (0x10) | HR (0x200) | elapsed (0x800) = 0xA11
        let indoorFlags: UInt16 = 0x0001 | 0x0010 | 0x0200 | 0x0800
        var payload = Data()
        payload.append(contentsOf: withUnsafeBytes(of: indoorFlags.littleEndian, Array.init))
        // distance 250 m (3 bytes LE)
        payload.append(contentsOf: [250, 0, 0])
        // HR 140
        payload.append(140)
        // elapsed 60 s
        payload.append(contentsOf: withUnsafeBytes(of: UInt16(60).littleEndian, Array.init))

        delegate.indoorBikeData.send(payload)

        dC.cancel()
        hC.cancel()
        eC.cancel()

        #expect(distance?.value == 250)
        #expect(distance?.unit == .meters)
        #expect(heart?.value == 140)
        #expect(heart?.unit == .beatsPerMinute)
        #expect(elapsed?.value == 60)
        #expect(elapsed?.unit == .seconds)
    }
}
