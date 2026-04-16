//
//  SensorViewModel.swift
//  Settings
//
//  Created by Tony Tallman on 4/12/26.
//

import Foundation

package struct SensorViewModel: Equatable {
    package let sensorID: UUID
    package let title: String
    package let connectionState: SensorConnectionState

    package init(sensorID: UUID, title: String, connectionState: SensorConnectionState) {
        self.sensorID = sensorID
        self.title = title
        self.connectionState = connectionState
    }
}
