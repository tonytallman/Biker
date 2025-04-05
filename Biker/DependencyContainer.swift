//
//  DependencyContainer.swift
//  Biker
//
//  Created by Tony Tallman on 1/10/25.
//

import Foundation
import BikerCore

/// Dependency container and composition root for the Biker app. It exposes the root object, ``ContentViewModel``, from which all other objects are indirectly accessed.
struct DependencyContainer {
    static let shared = DependencyContainer()

    private init() { }

    func getContentViewModel() -> ContentViewModel {
        ContentViewModel(metricsProvider: metricsProvider)
    }

    private let metricsProvider = MetricsProvider.shared
}
