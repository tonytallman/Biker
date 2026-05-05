

import Combine
import CoreBluetooth
import Foundation

class CyclingSpeedAndCadenceService {
    let heartRate: AnyPublisher<Measurement<UnitFrequency>, Error>
    
    init?(with peripheral: CBPeripheral) async {
        
    }
}
