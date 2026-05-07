//
//  NotificationMultiplexer.swift
//  Sensors
//

import CoreBluetooth
import Foundation

package struct NotificationSubscriptionKey: Hashable, Sendable {
    package let service: CBUUID
    package let characteristic: CBUUID

    package init(service: CBUUID, characteristic: CBUUID) {
        self.service = service
        self.characteristic = characteristic
    }
}

/// Multiplexes many ``AsyncThrowingStream`` subscribers onto one upstream notify-style ``AsyncStream`` per key.
package actor NotificationMultiplexer<Key: Hashable & Sendable> {
    package typealias UpstreamFactory = @Sendable (Key) async throws -> AsyncStream<Data>
    package typealias TeardownHook = @Sendable (Key) async -> Void

    private struct Pipeline {
        var continuations: [UUID: AsyncThrowingStream<Data, Error>.Continuation] = [:]
        var listenTask: Task<Void, Never>?
    }

    private var pipelines: [Key: Pipeline] = [:]

    private let upstream: UpstreamFactory
    private let teardown: TeardownHook

    package init(upstream: @escaping UpstreamFactory, teardown: @escaping TeardownHook) {
        self.upstream = upstream
        self.teardown = teardown
    }

    package func subscribe(_ key: Key) async throws -> AsyncThrowingStream<Data, Error> {
        let subscriberID = UUID()
        let (stream, continuation) = AsyncThrowingStream<Data, Error>.makeStream(
            bufferingPolicy: .bufferingNewest(64)
        )

        let wasEmpty = pipelines[key]?.continuations.isEmpty ?? true

        var pipeline = pipelines[key] ?? Pipeline()
        pipeline.continuations[subscriberID] = continuation
        pipelines[key] = pipeline

        let multiplexer = self
        continuation.onTermination = { @Sendable _ in
            Task {
                await multiplexer.unregisterSubscriber(id: subscriberID, key: key)
            }
        }

        if wasEmpty {
            do {
                let upstreamStream = try await upstream(key)
                guard var p = pipelines[key], p.continuations[subscriberID] != nil else {
                    return stream
                }
                p.listenTask = Task {
                    await multiplexer.runListenLoop(key: key, stream: upstreamStream)
                }
                pipelines[key] = p
            } catch {
                pipelines[key]?.continuations.removeValue(forKey: subscriberID)
                if pipelines[key]?.continuations.isEmpty == true {
                    pipelines.removeValue(forKey: key)
                }
                continuation.finish(throwing: error)
                throw error
            }
        }

        return stream
    }

    package func finishAll(throwing error: Error) {
        let snapshot = pipelines
        pipelines.removeAll()
        for (_, pipeline) in snapshot {
            pipeline.listenTask?.cancel()
            for (_, continuation) in pipeline.continuations {
                continuation.finish(throwing: error)
            }
        }
    }

    private func unregisterSubscriber(id: UUID, key: Key) async {
        guard var pipeline = pipelines[key] else { return }
        pipeline.continuations.removeValue(forKey: id)
        if pipeline.continuations.isEmpty {
            pipeline.listenTask?.cancel()
            pipelines.removeValue(forKey: key)
            await teardown(key)
        } else {
            pipelines[key] = pipeline
        }
    }

    private func runListenLoop(key: Key, stream: AsyncStream<Data>) async {
        for await data in stream {
            if Task.isCancelled {
                break
            }
            guard let subs = pipelines[key]?.continuations else { continue }
            for (_, continuation) in subs {
                continuation.yield(data)
            }
        }
    }
}
