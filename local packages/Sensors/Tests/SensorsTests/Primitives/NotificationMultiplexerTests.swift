//
//  NotificationMultiplexerTests.swift
//  SensorsTests
//

import Foundation
import Sensors
import Testing

private enum MultiplexTestErr: Error {
    case boom
}

@Suite(.serialized)
struct NotificationMultiplexerTests {

    @Test func firstSubscriberStartsUpstream_secondDoesNot() async throws {
        let upstreamCalls = EmissionCounter()
        let teardownCalls = EmissionCounter()
        let (upstreamStream, upstreamContinuation) = AsyncStream<Data>.makeStream(bufferingPolicy: .bufferingNewest(64))

        let mux = NotificationMultiplexer<String>(
            upstream: { key in
                #expect(key == "alpha")
                upstreamCalls.record()
                return upstreamStream
            },
            teardown: { key in
                #expect(key == "alpha")
                teardownCalls.record()
            }
        )

        _ = try await mux.subscribe("alpha")
        _ = try await mux.subscribe("alpha")

        #expect(upstreamCalls.value == 1)
        #expect(teardownCalls.value == 0)

        upstreamContinuation.finish()
        await mux.finishAll(throwing: CancellationError())
        try await Task.sleep(nanoseconds: 50_000_000)
    }

    @Test func emissionsFanOutToAllSubscribers() async throws {
        let (upstreamStream, upstreamContinuation) = AsyncStream<Data>.makeStream(bufferingPolicy: .bufferingNewest(64))

        let mux = NotificationMultiplexer<String>(
            upstream: { _ in upstreamStream },
            teardown: { _ in }
        )

        let s1 = try await mux.subscribe("k")
        let s2 = try await mux.subscribe("k")

        let box1 = ValueBox<Data>()
        let box2 = ValueBox<Data>()

        let t1 = Task {
            do {
                for try await value in s1 {
                    box1.store(value)
                    break
                }
            } catch {}
        }
        let t2 = Task {
            do {
                for try await value in s2 {
                    box2.store(value)
                    break
                }
            } catch {}
        }

        let payload = Data([0x01, 0x02])
        upstreamContinuation.yield(payload)

        try await Task.sleep(nanoseconds: 100_000_000)
        #expect(box1.load() == payload)
        #expect(box2.load() == payload)

        upstreamContinuation.finish()
        t1.cancel()
        t2.cancel()
    }

    @Test func finishAll_finishesAllSubscribers() async throws {
        let (upstreamStream, upstreamContinuation) = AsyncStream<Data>.makeStream(bufferingPolicy: .bufferingNewest(64))

        let mux = NotificationMultiplexer<String>(
            upstream: { _ in upstreamStream },
            teardown: { _ in }
        )

        let s1 = try await mux.subscribe("k")
        let s2 = try await mux.subscribe("k")

        let box1 = ValueBox<Error?>()
        let box2 = ValueBox<Error?>()

        let t1 = Task {
            do {
                for try await _ in s1 {}
            } catch {
                box1.store(error)
            }
        }
        let t2 = Task {
            do {
                for try await _ in s2 {}
            } catch {
                box2.store(error)
            }
        }

        await mux.finishAll(throwing: MultiplexTestErr.boom)

        try await Task.sleep(nanoseconds: 100_000_000)

        #expect(box1.load() as? MultiplexTestErr == .boom)
        #expect(box2.load() as? MultiplexTestErr == .boom)

        upstreamContinuation.finish()
        t1.cancel()
        t2.cancel()
    }

    @Test func lastSubscriberCancellationRunsTeardown() async throws {
        let teardownCalls = EmissionCounter()
        let (upstreamStream, upstreamContinuation) = AsyncStream<Data>.makeStream(bufferingPolicy: .bufferingNewest(64))

        let mux = NotificationMultiplexer<String>(
            upstream: { _ in upstreamStream },
            teardown: { _ in teardownCalls.record() }
        )

        let stream = try await mux.subscribe("solo")
        let task = Task {
            do {
                for try await _ in stream {}
            } catch {}
        }

        try await Task.sleep(nanoseconds: 30_000_000)
        task.cancel()

        try await Task.sleep(nanoseconds: 150_000_000)
        #expect(teardownCalls.value == 1)

        upstreamContinuation.finish()
    }

    @Test func upstreamFailureFinishesSubscriberAndThrows() async throws {
        struct UpstreamFailure: Error {}

        let mux = NotificationMultiplexer<String>(
            upstream: { _ in throw UpstreamFailure() },
            teardown: { _ in }
        )

        do {
            _ = try await mux.subscribe("fail")
            Issue.record("expected throw")
        } catch is UpstreamFailure {
            // ok
        } catch {
            Issue.record("unexpected \(error)")
        }
    }
}
