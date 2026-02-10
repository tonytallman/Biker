// The Swift Programming Language
// https://docs.swift.org/swift-book

import Combine
import CoreLocation
import Foundation

/// Publishes speed and distance deltas from device location services. Speed is in meters per second. Distance deltas are in meters.
final public class SpeedAndDistanceService: NSObject {
    public enum AuthorizationStatus {
        case yes
        case no
        case notRequested
    }

    /// Speed obtained from location services, in meters per second.
    public let speed: AnyPublisher<Measurement<UnitSpeed>, Never>
    private let speedSubject = PassthroughSubject<Measurement<UnitSpeed>, Never>()

    /// Distance delta obtained from location services, in meters. These are instantaneous deltas that can be accumulated to get total distance.
    public let distanceDelta: AnyPublisher<Measurement<UnitLength>, Never>
    private let distanceDeltaSubject = PassthroughSubject<Measurement<UnitLength>, Never>()

    private var previousLocation: CLLocation?

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
        distanceDelta = distanceDeltaSubject.eraseToAnyPublisher()

        super.init()

        configureLocationManager()
    }

    deinit {
        locationManager.stopUpdatingLocation()
    }

    public func requestAuthorization() {
        if isAuthorized == .notRequested {
            locationManager.requestAlwaysAuthorization()
        }
    }

    private func configureLocationManager() {
        if isAuthorized == .notRequested {
            requestAuthorization()
        }

        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.activityType = .fitness
        locationManager.pausesLocationUpdatesAutomatically = false
        locationManager.allowsBackgroundLocationUpdates = true
        #if os(iOS)
        locationManager.showsBackgroundLocationIndicator = true
        #endif
        locationManager.startUpdatingLocation()
    }
}

extension SpeedAndDistanceService: CLLocationManagerDelegate {
    public func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        logger?.info("Updated location = \(locations.last?.speed.description ?? "nil")")
        guard let location = locations.last else { return }
        if location.speed >= 0 {
            speedSubject.send(Measurement(value: location.speed, unit: .metersPerSecond))
        }
        
        // Calculate distance delta from previous location
        if let previous = previousLocation {
            let delta = location.distance(from: previous)
            if delta > 0 {
                distanceDeltaSubject.send(Measurement(value: delta, unit: .meters))
            }
        }
        previousLocation = location
    }

    public func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        logger?.error("Location manager failed with error: \(error)")
    }

    public func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            logger?.info("Location permissions authorized.")
            locationManager.allowsBackgroundLocationUpdates = true
            locationManager.pausesLocationUpdatesAutomatically = false
            locationManager.startUpdatingLocation()
        case .denied, .restricted:
            logger?.info("Location permissions denied or restricted.")
        default:
            break
        }
    }
}
