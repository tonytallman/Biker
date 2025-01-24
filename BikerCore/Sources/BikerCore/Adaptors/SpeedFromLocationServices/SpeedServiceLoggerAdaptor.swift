//
//  SpeedServiceLoggerAdaptor.swift
//  BikerCore
//
//  Created by Tony Tallman on 1/24/25.
//

import SpeedFromLocationServices
import Logging

/// Adaptor that takes a ``LoggingService`` instance and makes it look like a ``SpeedFromLocationServices.Logger`` instance for use by that package.
final class SpeedServiceLoggerAdaptor: SpeedFromLocationServices.Logger {
    private let loggingService: LoggingService

    init(loggingService: LoggingService) {
        self.loggingService = loggingService
    }

    func info(_ message: String) {
        loggingService.log("[info, SpeedService]: \(message)")
    }
    
    func error(_ message: String) {
        loggingService.log("[error, SpeedService]: \(message)")
    }
}
