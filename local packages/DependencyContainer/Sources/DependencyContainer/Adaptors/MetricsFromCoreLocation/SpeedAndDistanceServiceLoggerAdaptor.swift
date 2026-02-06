//
//  SpeedAndDistanceServiceLoggerAdaptor.swift
//  BikerCore
//
//  Created by Tony Tallman on 1/24/25.
//

import CoreLogic
import MetricsFromCoreLocation

/// Adaptor that takes a ``LoggingService`` instance and makes it look like a ``MetricsFromCoreLocation.Logger`` instance for use by that package.
final class SpeedAndDistanceServiceLoggerAdaptor: MetricsFromCoreLocation.Logger {
    private let loggingService: ConsoleLogger

    init(loggingService: ConsoleLogger) {
        self.loggingService = loggingService
    }

    func info(_ message: String) {
        loggingService.log("[info, SpeedAndDistanceService]: \(message)")
    }
    
    func error(_ message: String) {
        loggingService.log("[error, SpeedAndDistanceService]: \(message)")
    }
}
