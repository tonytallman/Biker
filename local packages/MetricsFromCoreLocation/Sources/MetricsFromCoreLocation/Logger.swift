//
//  File.swift
//  MetricsFromCoreLocation
//
//  Created by Tony Tallman on 1/24/25.
//

import Foundation

public protocol Logger {
    func info(_ message: String)
    func error(_ message: String)
}
