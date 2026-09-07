import XCTest
@testable import MacStateCore
@testable import MacReadyCLI

final class SnapshotTests: XCTestCase {
    func testTemperatureUsesSmartBatteryKelvinAndRejectsInvalidReadings() throws {
        XCTAssertEqual(try XCTUnwrap(TemperatureReader.celsius(raw: 3003)), 27.15, accuracy: 0.001)
        for raw in [0, -1, 65535, 65536] { XCTAssertNil(TemperatureReader.celsius(raw: raw)) }
        let snapshot = TemperatureSnapshot(batteryCelsius: nil, batteryRaw: nil)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(snapshot)) as? [String: Any])
        for key in ["battery_celsius", "cpu_celsius", "gpu_celsius"] { XCTAssertTrue(json[key] is NSNull) }
    }

    func testACPowerDoesNotImplyCharging() {
        let snapshot = PowerStateReader.parse(source: "AC Power", descriptions: [[
            "Type": "InternalBattery", "Is Present": true,
            "Current Capacity": 80, "Max Capacity": 100, "Is Charging": false
        ]])
        XCTAssertEqual(snapshot.source, "ac")
        XCTAssertEqual(snapshot.batteryPercent, 80)
        XCTAssertEqual(snapshot.charging, false)
    }

    func testBatterylessMacAndMissingOrInvalidCapacityAreDistinct() {
        let desktop = PowerStateReader.parse(source: "AC Power", descriptions: [])
        XCTAssertEqual(desktop.batteryPresent, false)
        XCTAssertNil(desktop.batteryPercent)
        for current in [-1, 101] {
            let invalid = PowerStateReader.parse(source: "Battery Power", descriptions: [[
                "Type": "InternalBattery", "Is Present": true,
                "Current Capacity": current, "Max Capacity": 100
            ]])
            XCTAssertEqual(invalid.batteryPresent, true)
            XCTAssertNil(invalid.batteryPercent)
        }
        let missing = PowerStateReader.parse(source: nil, descriptions: [["Type": "InternalBattery"]])
        XCTAssertNil(missing.batteryPresent)
        XCTAssertNil(missing.charging)
        XCTAssertEqual(missing.source, "unknown")
    }

    func testPowerJSONKeepsMissingValuesExplicitlyNull() throws {
        let snapshot = PowerStateReader.parse(source: "AC Power", descriptions: [])
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(snapshot)) as? [String: Any])
        XCTAssertTrue(json["battery_percent"] is NSNull)
        XCTAssertTrue(json["charging"] is NSNull)
        XCTAssertEqual(json["battery_present"] as? Bool, false)
    }

    func testSleepSettingDoesNotMistakeIdleTimerForGlobalSetting() {
        XCTAssertEqual(SleepStateReader.parse("System-wide power settings:\n SleepDisabled 1\n sleep 0"), true)
        XCTAssertEqual(SleepStateReader.parse("SleepDisabled 0"), false)
        XCTAssertNil(SleepStateReader.parse("sleep 0 (sleep prevented by something)"))
        XCTAssertNil(SleepStateReader.parse("SleepDisabled 2"))
    }

    func testHelpVersionAndBadArgumentsNeverReadHardware() {
        for arguments in [["--help"], ["--version"], ["off"], ["status", "extra", "--json"]] {
            let result = MacReadyCommand.run(arguments, read: { XCTFail("Unexpected hardware read"); fatalError() })
            XCTAssertEqual(result.0, arguments[0].hasPrefix("--") ? 0 : 2)
            if arguments.contains("--json") {
                XCTAssertNoThrow(try JSONSerialization.jsonObject(with: Data(result.1.utf8)))
            }
        }
    }
}
