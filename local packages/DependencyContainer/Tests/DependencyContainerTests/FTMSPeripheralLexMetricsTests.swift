//
//  FTMSPeripheralLexMetricsTests.swift
//  DependencyContainerTests
//

import Combine
import Foundation
import Testing

@testable import DependencyContainer
@testable import FitnessMachineService

@MainActor
private func lexFlushDeliveries() async {
    await MainActor.run {}
    await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
        DispatchQueue.main.async {
            DispatchQueue.main.async {
                cont.resume()
            }
        }
    }
    try? await Task.sleep(nanoseconds: 200_000_000)
}

@MainActor
private func lexYieldForLexWiring() async {
    await MainActor.run {}
    await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
        DispatchQueue.main.async {
            DispatchQueue.main.async {
                cont.resume()
            }
        }
    }
    try? await Task.sleep(nanoseconds: 150_000_000)
}

@MainActor
@Suite("FTMSPeripheralLexMetrics", .serialized)
struct FTMSPeripheralLexMetricsTests {
    @Test func heartRate_pickLexPreferLowerUuid() async throws {
        let idLo = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
        let idHi = UUID(uuidString: "00000000-0000-0000-0000-000000000002")!

        let manager = FitnessMachineSensorManager(
            persistence: InMemoryFTMSPersistence(),
            central: TestFakeFTMSCentral()
        )
        let lex = FTMSPeripheralLexMetrics(manager: manager)
        var lastBpm: Double?
        let cancellable = lex.heartRate.publisher
            .sink { lastBpm = $0.converted(to: .beatsPerMinute).value }

        let lo = FitnessMachineSensor(id: idLo, name: "Lo", initialConnectionState: .connected)
        let hi = FitnessMachineSensor(id: idHi, name: "Hi", initialConnectionState: .connected)
        manager._test_registerSensor(hi)
        manager._test_registerSensor(lo)
        await lexYieldForLexWiring()

        // Higher UUID emits first; lex must still tie-break toward lower UUID.
        hi._test_ingestIndoorBikeData(Data([0x01, 0x02, 170]))
        lo._test_ingestIndoorBikeData(Data([0x01, 0x02, 155]))
        await lexFlushDeliveries()

        guard let picked = lastBpm else {
            Issue.record("expected heart rate emission")
            return
        }
        #expect(abs(picked - 155.0) < 0.001)

        cancellable.cancel()
    }

    @Test func elapsedTime_pickLexPreferLowerUuid() async throws {
        let idLo = UUID(uuidString: "00000000-0000-0000-0000-0000000000AA")!
        let idHi = UUID(uuidString: "00000000-0000-0000-0000-0000000000BB")!

        let manager = FitnessMachineSensorManager(
            persistence: InMemoryFTMSPersistence(),
            central: TestFakeFTMSCentral()
        )
        let lex = FTMSPeripheralLexMetrics(manager: manager)
        var lastSeconds: Double?
        let cancellable = lex.elapsedTime.publisher
            .sink { lastSeconds = $0.converted(to: .seconds).value }

        let lo = FitnessMachineSensor(id: idLo, name: "Lo", initialConnectionState: .connected)
        let hi = FitnessMachineSensor(id: idHi, name: "Hi", initialConnectionState: .connected)
        manager._test_registerSensor(hi)
        manager._test_registerSensor(lo)
        await lexYieldForLexWiring()

        hi._test_ingestIndoorBikeData(Data([0x01, 0x08, 0x88, 0x13]))
        lo._test_ingestIndoorBikeData(Data([0x01, 0x08, 0x58, 0x02]))
        await lexFlushDeliveries()

        guard let secs = lastSeconds else {
            Issue.record("expected elapsed time emission")
            return
        }
        #expect(abs(secs - 600.0) < 0.001)

        cancellable.cancel()
    }

    @Test func totalDistance_pickLexPreferLowerUuid() async throws {
        let idLo = UUID(uuidString: "00000000-0000-0000-0000-0000000000CC")!
        let idHi = UUID(uuidString: "00000000-0000-0000-0000-0000000000DD")!

        let manager = FitnessMachineSensorManager(
            persistence: InMemoryFTMSPersistence(),
            central: TestFakeFTMSCentral()
        )
        let lex = FTMSPeripheralLexMetrics(manager: manager)
        var lastMeters: Double?
        let cancellable = lex.totalDistance.publisher
            .sink { lastMeters = $0.converted(to: .meters).value }

        let lo = FitnessMachineSensor(id: idLo, name: "Lo", initialConnectionState: .connected)
        let hi = FitnessMachineSensor(id: idHi, name: "Hi", initialConnectionState: .connected)
        manager._test_registerSensor(hi)
        manager._test_registerSensor(lo)
        await lexYieldForLexWiring()

        // 888 m vs 777 m LE24 — lex picks lower UUID (777).
        hi._test_ingestIndoorBikeData(Data([0x11, 0x00, 0x78, 0x03, 0x00]))
        lo._test_ingestIndoorBikeData(Data([0x11, 0x00, 0x09, 0x03, 0x00]))
        await lexFlushDeliveries()

        guard let m = lastMeters else {
            Issue.record("expected total distance emission")
            return
        }
        #expect(abs(m - 777.0) < 0.001)

        cancellable.cancel()
    }
}
