//
//  ValueBox.swift
//  SensorsTests
//

import Foundation

/// Holds a value across concurrent tasks without tripping Swift 6 `Sendable` checks in tests.
final class ValueBox<Value>: @unchecked Sendable {
    private let lock = NSLock()
    private var storage: Value?

    func store(_ value: Value) {
        lock.lock()
        storage = value
        lock.unlock()
    }

    func load() -> Value? {
        lock.lock()
        defer { lock.unlock() }
        return storage
    }
}

/// Counts events across concurrent tasks (for async stream tests).
final class EmissionCounter: @unchecked Sendable {
    private let lock = NSLock()
    private var count = 0

    func record() {
        lock.lock()
        count += 1
        lock.unlock()
    }

    var value: Int {
        lock.lock()
        defer { lock.unlock() }
        return count
    }
}
