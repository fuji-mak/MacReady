import Foundation
import IOKit

public struct TemperatureSnapshot: Encodable {
    public let batteryCelsius: Double?
    public let batteryRaw: Int?
    public let batterySource = "AppleSmartBattery.Temperature (Smart Battery 0.1 K)"
    public let cpuCelsius: Double?
    public let cpuSource: String?
    public let cpuSensors: [CPUTemperatureSensor]
    let cpuUnavailableReason: String?

    init(batteryCelsius: Double?, batteryRaw: Int?, cpu: CPUTemperatureReading = CPUTemperatureReading(sensors: [], unavailableReason: "CPU temperature was not read.")) {
        self.batteryCelsius = batteryCelsius
        self.batteryRaw = batteryRaw
        self.cpuCelsius = cpu.celsius
        self.cpuSource = cpu.source
        self.cpuSensors = cpu.sensors
        self.cpuUnavailableReason = cpu.unavailableReason
    }

    enum CodingKeys: String, CodingKey {
        case batteryCelsius = "battery_celsius"
        case batteryRaw = "battery_raw"
        case batterySource = "battery_source"
        case cpuCelsius = "cpu_celsius"
        case cpuSource = "cpu_source"
        case cpuSensors = "cpu_sensors"
        case gpuCelsius = "gpu_celsius"
    }

    public func encode(to encoder: Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        try values.encode(batteryCelsius, forKey: .batteryCelsius)
        try values.encode(batteryRaw, forKey: .batteryRaw)
        try values.encode(batterySource, forKey: .batterySource)
        try values.encode(cpuCelsius, forKey: .cpuCelsius)
        try values.encode(cpuSource, forKey: .cpuSource)
        try values.encode(cpuSensors, forKey: .cpuSensors)
        try values.encodeNil(forKey: .gpuCelsius)
    }
}

public enum TemperatureReader {
    public static func read() -> TemperatureSnapshot {
        let cpu = CPUTemperatureReader.read()
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSmartBattery"))
        guard service != 0 else { return TemperatureSnapshot(batteryCelsius: nil, batteryRaw: nil, cpu: cpu) }
        defer { IOObjectRelease(service) }
        let raw = (IORegistryEntryCreateCFProperty(service, "Temperature" as CFString,
                                                 kCFAllocatorDefault, 0)?.takeRetainedValue() as? NSNumber)?.intValue
        return TemperatureSnapshot(batteryCelsius: raw.flatMap(celsius), batteryRaw: raw, cpu: cpu)
    }

    // Apple's open-source AppleSmartBattery.cpp preserves Smart Battery format
    // on macOS. SBS 1.1 section 5.1.9 specifies tenths of a Kelvin. The separate
    // VirtualTemperature key uses a different representation; do not substitute it.
    static func celsius(raw: Int) -> Double? {
        guard raw > 0, raw <= UInt16.max else { return nil }
        let value = Double(raw) / 10 - 273.15
        // Reject absent/sentinel or implausible sensor readings, not safety limits.
        guard (-50...150).contains(value) else { return nil }
        return (value * 100).rounded() / 100
    }
}
