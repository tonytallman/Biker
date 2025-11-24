//
//  WatchConnectivityService.swift
//  CoreLogic
//
//  Created by Tony Tallman on 1/20/25.
//

import Foundation
import Combine
import WatchConnectivity

/// Service for sharing speed data between iOS and watchOS apps via WatchConnectivity
@MainActor
public final class WatchConnectivityService: NSObject, ObservableObject {
    public nonisolated(unsafe) static let shared = WatchConnectivityService()
    
    /// Published speed value received from iOS app
    @Published public var receivedSpeed: Double?
    
    /// Published speed units received from iOS app
    @Published public var receivedSpeedUnits: String?
    
    nonisolated(unsafe) private let session: WCSession
    private var cancellables: Set<AnyCancellable> = []
    
    nonisolated private override init() {
        self.session = WCSession.default
        super.init()
        
        if WCSession.isSupported() {
            session.delegate = self
            session.activate()
        }
    }
    
    /// Send speed data from iOS app to watch
    /// - Parameters:
    ///   - speed: Speed value as Double
    ///   - units: Speed units symbol (e.g., "mph", "km/h")
    public func sendSpeed(speed: Double, units: String) {
        guard session.activationState == .activated else { return }
        
        let message: [String: Any] = [
            "speed": speed,
            "units": units
        ]
        
        // Use sendMessage for real-time updates when watch is reachable
        if session.isReachable {
            session.sendMessage(message, replyHandler: nil) { error in
                print("Failed to send message to watch: \(error.localizedDescription)")
            }
        } else {
            // Fall back to updateApplicationContext for background delivery
            // This ensures the watch gets the latest speed even when not actively reachable
            do {
                try session.updateApplicationContext(message)
            } catch {
                print("Failed to update application context: \(error.localizedDescription)")
            }
        }
    }
}

extension WatchConnectivityService: WCSessionDelegate {
    nonisolated public func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        if let error = error {
            print("WatchConnectivity activation failed: \(error.localizedDescription)")
        }
    }
    
    nonisolated public func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any]) {
        // Extract Sendable values before entering MainActor context
        let speed = userInfo["speed"] as? Double
        let units = userInfo["units"] as? String
        
        Task { @MainActor [weak self] in
            if let speed = speed {
                self?.receivedSpeed = speed
            }
            if let units = units {
                self?.receivedSpeedUnits = units
            }
        }
    }
    
    #if os(watchOS)
    nonisolated public func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        // Extract Sendable values before entering MainActor context
        let speed = message["speed"] as? Double
        let units = message["units"] as? String
        
        Task { @MainActor [weak self] in
            if let speed = speed {
                self?.receivedSpeed = speed
            }
            if let units = units {
                self?.receivedSpeedUnits = units
            }
        }
    }
    
    nonisolated public func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        // Extract Sendable values before entering MainActor context
        let speed = applicationContext["speed"] as? Double
        let units = applicationContext["units"] as? String
        
        Task { @MainActor [weak self] in
            if let speed = speed {
                self?.receivedSpeed = speed
            }
            if let units = units {
                self?.receivedSpeedUnits = units
            }
        }
    }
    #endif
    
    #if os(iOS)
    nonisolated public func sessionDidBecomeInactive(_ session: WCSession) {
        // iOS-specific
    }
    
    nonisolated public func sessionDidDeactivate(_ session: WCSession) {
        // Reactivate session
        session.activate()
    }
    #endif
}

