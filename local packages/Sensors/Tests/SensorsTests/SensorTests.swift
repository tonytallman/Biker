import Sensors
import Testing

struct SensorsTests {
    @Test func sensorsModuleLoads() {
        let typeName = String(describing: Sensors.self)
        #expect(typeName == "Sensors")
    }
}
