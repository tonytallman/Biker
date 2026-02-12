//
//  ForegroundNotifier.swift
//  Settings
//
//  Created by Tony Tallman on 2/11/26.
//

import Combine
import UIKit

package protocol ForegroundNotifier {
    var willEnterForeground: AnyPublisher<Void, Never> { get }
}

package struct DefaultForegroundNotifier: ForegroundNotifier {
    package let willEnterForeground: AnyPublisher<Void, Never>

    package init() {
        willEnterForeground = NotificationCenter.default
            .publisher(for: UIApplication.willEnterForegroundNotification)
            .map { _ in () }
            .eraseToAnyPublisher()
    }
}
