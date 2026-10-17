import XCTest
@testable import MacStateCore

final class CPUTemperatureTests: XCTestCase {
    func testSMCTemperatureFormatsAndInvalidReadings() throws {
        XCTAssertEqual(try XCTUnwrap(CPUTemperatureReader.decode(type: 0x666c7420, bytes: [0, 0, 0x2a, 0x42])), 42.5)
        XCTAssertEqual(try XCTUnwrap(CPUTemperatureReader.decode(type: 0x73703738, bytes: [0x2a, 0x80])), 42.5)
        // Negative fixed-point, zero, NaN, infinity, bad lengths/types and sentinels
        // must not turn into plausible CPU readings or break JSON encoding.
        for bytes: [UInt8] in [[0, 0, 0, 0], [0, 0, 0xc0, 0x7f], [0, 0, 0x80, 0x7f], [0, 0, 0x17, 0x43], [0, 0]] {
            XCTAssertNil(CPUTemperatureReader.decode(type: 0x666c7420, bytes: bytes))
        }
        XCTAssertNil(CPUTemperatureReader.decode(type: 0x73703738, bytes: [0xff, 0]))
        XCTAssertNil(CPUTemperatureReader.decode(type: 0x75693332, bytes: [0, 0, 0, 42]))
    }

    func testMappingsExcludeGPUProximityAndUnknownProcessors() throws {
        let m3 = try XCTUnwrap(CPUTemperatureReader.sensorGroups(cpuBrand: "Apple M3 Max")).flatMap { $0 }
        XCTAssertTrue(m3.contains("Tf04"))
        XCTAssertFalse(m3.contains("Tf14")) // Same prefix, but a GPU thermal zone.
        let m4 = try XCTUnwrap(CPUTemperatureReader.sensorGroups(cpuBrand: "Apple M4")).flatMap { $0 }
        XCTAssertTrue(m4.contains("Te05"))
        XCTAssertTrue(m4.contains("Tp01"))
        XCTAssertFalse(m4.contains("Tg0G"))
        let intel = try XCTUnwrap(CPUTemperatureReader.sensorGroups(cpuBrand: "Intel(R) Core(TM) i7")).flatMap { $0 }
        for key in ["TCGC", "TC0P", "TC0H", "TC0E", "Tp0P"] { XCTAssertFalse(intel.contains(key)) }
        XCTAssertNil(CPUTemperatureReader.sensorGroups(cpuBrand: "Apple M99"))
        XCTAssertNil(CPUTemperatureReader.sensorGroups(cpuBrand: ""))
    }

    func testPartialSensorsMeanFallbackAndJSONProvenance() throws {
        let reading = CPUTemperatureReader.sample(groups: [["Te05", "Tp01", "Tp05", "Tp09", "Tp0D"], ["TCAD"]]) { key in
            ["Te05": 40, "Tp01": 60, "Tp05": 0, "Tp09": .nan, "TCAD": 100][key]
        }
        XCTAssertEqual(reading.celsius, 50)
        XCTAssertNil(reading.unavailableReason)
        XCTAssertEqual(reading.sensors.map(\.key), ["Te05", "Tp01"])
        let temperature = TemperatureSnapshot(batteryCelsius: nil, batteryRaw: nil, cpu: reading)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(temperature)) as? [String: Any])
        XCTAssertEqual(json["cpu_celsius"] as? Double, 50)
        XCTAssertNotNil(json["cpu_source"] as? String)
        XCTAssertEqual((json["cpu_sensors"] as? [[String: Any]])?.count, 2)
        XCTAssertTrue(json["battery_celsius"] is NSNull)
        XCTAssertTrue(json["gpu_celsius"] is NSNull)

        let fallback = CPUTemperatureReader.sample(groups: [["TC0C"], ["TCAD"], ["TC0D"]]) { $0 == "TCAD" ? 55 : nil }
        XCTAssertEqual(fallback.celsius, 55)
        XCTAssertEqual(fallback.sensors.map(\.key), ["TCAD"])
        let absent = CPUTemperatureReader.sample(groups: [["Te05"]]) { _ in nil }
        XCTAssertNil(absent.celsius)
        XCTAssertNil(absent.source)
        XCTAssertNotNil(absent.unavailableReason)
        let missing = TemperatureSnapshot(batteryCelsius: nil, batteryRaw: nil, cpu: absent)
        let missingJSON = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(missing)) as? [String: Any])
        XCTAssertTrue(missingJSON["cpu_celsius"] is NSNull)
        XCTAssertTrue(missingJSON["cpu_source"] is NSNull)
        XCTAssertEqual((missingJSON["cpu_sensors"] as? [Any])?.count, 0)
    }
}
