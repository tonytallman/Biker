
import Combine
import CoreBluetooth
import Foundation

class FitnessMachineService {
    let speed: AnyPublisher<Measurement<UnitSpeed>, Error>?
    let cadence: AnyPublisher<Measurement<UnitFrequency>, Error>?
    
    init?(with peripheral: CBPeripheral) async {
        
    }
}
