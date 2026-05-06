//
//  AsyncAlgorithmsAnchor.swift
//  Sensors
//
//  Keeps the `swift-async-algorithms` product linked for stream composition experiments.

import AsyncAlgorithms
import Foundation

private enum AsyncAlgorithmsAnchor {
    /// No-op merge of empty streams — reference types satisfy the package dependency without affecting runtime.
    static func ping() async {
        let a = AsyncStream<Int> { $0.finish() }
        let b = AsyncStream<Int> { $0.finish() }
        for await _ in merge(a, b) {
            break
        }
    }
}
