//
//  CompositionRoot.swift
//  Biker
//
//  Created by Tony Tallman on 1/10/25.
//

import Foundation
import BikerCore

/// Composition root for the Biker app. It exposes the root object, ``ContentViewModel``, from which all other objects are indirectly accessed.
struct CompositionRoot {
    static let shared = CompositionRoot()

    private init() { }

    func getContentViewModel() -> ContentViewModel {
        ContentViewModel(metricsProvider: metricsProvider)
    }

    private let metricsProvider = MetricsProvider.shared
}
