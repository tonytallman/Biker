import Sensors
import Testing

struct SensorTests {
    @Test func sensorsModuleLoads() {
        let typeName = String(describing: Sensor.self)
        #expect(typeName == "Sensor")
    }
}
