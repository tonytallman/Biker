//
//  Storage.swift
//  CyclingSpeedAndCadenceService
//
//  Created by Tony Tallman on 4/30/26.
//

public protocol Storage {
    func get(forKey key: String) -> Any?
    func set(value: Any?, forKey key: String)
}
