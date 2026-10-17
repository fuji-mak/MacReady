import Darwin
import Foundation
import IOKit
import SMCBridge

public struct CPUTemperatureSensor: Encodable {
    public let key: String
    public let celsius: Double
}

struct CPUTemperatureReading {
    let sensors: [CPUTemperatureSensor]
    let unavailableReason: String?

    var celsius: Double? {
        guard !sensors.isEmpty else { return nil }
        return (sensors.reduce(0) { $0 + $1.celsius } / Double(sensors.count) * 100).rounded() / 100
    }
    var source: String? { sensors.isEmpty ? nil : "AppleSMC (mean of available CPU sensors)" }
}

enum CPUTemperatureReader {
    static func read() -> CPUTemperatureReading {
        guard let groups = sensorGroups(cpuBrand: cpuBrand()) else {
            return CPUTemperatureReading(sensors: [], unavailableReason: "No CPU sensor mapping is available for this processor.")
        }
        var connection: io_connect_t = 0
        let result = mr_smc_open(&connection)
        guard result == KERN_SUCCESS else {
            return CPUTemperatureReading(sensors: [], unavailableReason: "AppleSMC could not be opened (IOKit \(result)).")
        }
        defer { IOServiceClose(connection) }
        return sample(groups: groups) { key in
            var raw = MRSMCValue()
            let keyCode = key.utf8.reduce(UInt32(0)) { ($0 << 8) | UInt32($1) }
            guard mr_smc_read(connection, keyCode, &raw) == KERN_SUCCESS else { return nil }
            let bytes = withUnsafeBytes(of: raw.bytes) { Array($0.prefix(Int(raw.size))) }
            return decode(type: raw.type, bytes: bytes)
        }
    }

    static func sample(groups: [[String]], read: (String) -> Double?) -> CPUTemperatureReading {
        for keys in groups {
            let sensors = keys.compactMap { key -> CPUTemperatureSensor? in
                guard let value = read(key), valid(value) else { return nil }
                return CPUTemperatureSensor(key: key, celsius: value)
            }
            if !sensors.isEmpty { return CPUTemperatureReading(sensors: sensors, unavailableReason: nil) }
        }
        return CPUTemperatureReading(sensors: [], unavailableReason: "Mapped CPU sensors are absent, unreadable, or invalid on this Mac/macOS version.")
    }

    static func decode(type: UInt32, bytes: [UInt8]) -> Double? {
        let value: Double
        switch (type, bytes.count) {
        case (0x666c7420, 4): // flt : native little-endian IEEE 754 on supported Macs.
            let bits = bytes.enumerated().reduce(UInt32(0)) { $0 | (UInt32($1.element) << ($1.offset * 8)) }
            value = Double(Float(bitPattern: bits))
        case (0x73703738, 2): // sp78: signed, big-endian fixed point with 8 fractional bits.
            value = Double(Int16(bitPattern: UInt16(bytes[0]) << 8 | UInt16(bytes[1]))) / 256
        default:
            return nil
        }
        return valid(value) ? value : nil
    }

    // Reject missing/sentinel readings. This range is not an operating safety limit.
    private static func valid(_ value: Double) -> Bool { value.isFinite && value > 0 && value <= 150 }

    static func sensorGroups(cpuBrand: String) -> [[String]]? {
        // Explicit CPU mappings, not a broad T*/Tf* match: M3's Tf* includes GPU sensors.
        // Sensor keys are thermal zones, not one sensor per physical core.
        // Reference: https://github.com/exelban/stats/blob/master/Modules/Sensors/values.swift
        let appleKeys: [String: [String]] = [
            "M1": ["Tp09", "Tp0T", "Tp01", "Tp05", "Tp0D", "Tp0H", "Tp0L", "Tp0P", "Tp0X", "Tp0b"],
            "M2": ["Tp1h", "Tp1t", "Tp1p", "Tp1l", "Tp01", "Tp05", "Tp09", "Tp0D", "Tp0X", "Tp0b", "Tp0f", "Tp0j"],
            "M3": ["Te05", "Te0L", "Te0P", "Te0S", "Tf04", "Tf09", "Tf0A", "Tf0B", "Tf0D", "Tf0E", "Tf44", "Tf49", "Tf4A", "Tf4B", "Tf4D", "Tf4E"],
            "M4": ["Te05", "Te0S", "Te09", "Te0H", "Tp01", "Tp05", "Tp09", "Tp0D", "Tp0V", "Tp0Y", "Tp0b", "Tp0e"],
            "M5": ["Tp00", "Tp04", "Tp08", "Tp0C", "Tp0G", "Tp0K", "Tp0O", "Tp0R", "Tp0U", "Tp0X", "Tp0a", "Tp0d", "Tp0g", "Tp0j", "Tp0m", "Tp0p", "Tp0u", "Tp0y"]
        ]
        let words = cpuBrand.split(separator: " ")
        if words.first == "Apple", words.count >= 2 {
            return appleKeys[String(words[1])].map { [$0] }
        }
        if cpuBrand.contains("Intel") {
            // Prefer core/die readings; fall back to package then diode. Never include
            // proximity, heatsink, filtered/virtual diode, or integrated GPU TCGC.
            let indices = Array("0123456789ABCDEF")
            return [indices.map { "TC\($0)C" }, indices.map { "TC\($0)c" }, ["TCAD"], ["TC0D"]]
        }
        return nil
    }

    private static func cpuBrand() -> String {
        var size = 0
        guard sysctlbyname("machdep.cpu.brand_string", nil, &size, nil, 0) == 0, size > 0 else { return "" }
        var bytes = [CChar](repeating: 0, count: size)
        guard sysctlbyname("machdep.cpu.brand_string", &bytes, &size, nil, 0) == 0 else { return "" }
        return String(cString: bytes)
    }
}
