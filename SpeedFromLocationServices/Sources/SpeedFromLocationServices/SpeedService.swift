// The Swift Programming Language
// https://docs.swift.org/swift-book

import CoreLocation
import Combine

/// Publishes speed from device location services. Speed is in meters per second.
final public class SpeedService: NSObject {
    public enum AuthorizationStatus {
        case yes
        case no
        case notRequested
    }

    /// Speed, in meters per second, obtained from location services.
    public let speed: AnyPublisher<Double, Never>
    private let speedSubject = PassthroughSubject<Double, Never>()

    /// Determines whether authorization has been granted, denied or not requested.
    public var isAuthorized: AuthorizationStatus {
        switch locationManager.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            return .yes
        case .restricted, .denied:
            return .no
        case .notDetermined:
            return .notRequested
        @unknown default:
            return .no
        }
    }

    private let locationManager = CLLocationManager()
    private let logger: Logger?

    public init(logger: Logger? = nil) {
        self.logger = logger
        speed = speedSubject.eraseToAnyPublisher()

        super.init()

        configureLocationManager()
    }

    deinit {
        locationManager.stopUpdatingLocation()
    }

    public func requestAuthorization() {
        if isAuthorized == .notRequested {
            locationManager.requestWhenInUseAuthorization()
        }
    }

    private func configureLocationManager() {
        if isAuthorized == .notRequested {
            requestAuthorization()
        }

        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.activityType = .fitness
        locationManager.startUpdatingLocation()
    }
}

extension SpeedService: CLLocationManagerDelegate {
    public func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        logger?.info("Updated location = \(locations.last?.speed.description ?? "nil")")
        guard let location = locations.last else { return }
        if location.speed >= 0 {
            speedSubject.send(location.speed)
        }
    }

    public func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        logger?.error("Location manager failed with error: \(error)")
    }

    public func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            logger?.info("Location permissions authorized.")
            locationManager.startUpdatingLocation()
        case .denied, .restricted:
            logger?.info("Location permissions denied or restricted.")
        default:
            break
        }
    }
}
