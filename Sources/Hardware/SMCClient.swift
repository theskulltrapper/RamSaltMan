import Foundation

public struct FanInfo: Identifiable, Equatable {
    public var id: Int { index }
    public let index: Int
    public let name: String
    public let currentRPM: Double
    public let minRPM: Double
    public let maxRPM: Double
    public let targetRPM: Double
    public let isManual: Bool

    public var percentage: Double {
        guard maxRPM > minRPM else { return 0 }
        let clamped = min(max(currentRPM, minRPM), maxRPM)
        return ((clamped - minRPM) / (maxRPM - minRPM)) * 100.0
    }

    public var formattedRPM: String {
        if currentRPM <= 0 {
            return "0 RPM (Silent)"
        }
        return "\(Int(currentRPM)) RPM"
    }
}

public struct ThermalState: Equatable {
    public let cpuTemp: Double
    public let gpuTemp: Double
    public let socTemp: Double
    public let batteryTemp: Double
    public let maxTemp: Double
    public let hasSensors: Bool

    public var statusDescription: String {
        if maxTemp <= 0 { return "Monitoring Ready" }
        if maxTemp < 55.0 { return "Cool & Optimal" }
        if maxTemp < 75.0 { return "Normal Operating" }
        if maxTemp < 85.0 { return "Warm Under Load" }
        return "Hot - High Thermal Load"
    }

    public static let zero = ThermalState(
        cpuTemp: 0, gpuTemp: 0, socTemp: 0, batteryTemp: 0, maxTemp: 0, hasSensors: false
    )
}

public final class SMCClient {
    public static let shared = SMCClient()

    private let safetyTempThreshold: Double = 85.0

    private init() {
        _ = smc_bridge_init()
    }

    deinit {
        smc_bridge_close()
    }

    public func getFanCount() -> Int {
        return Int(smc_bridge_get_fan_count())
    }

    public var isHelperInstalled: Bool {
        return smc_bridge_is_helper_installed()
    }

    public func installHelper() -> Bool {
        let bundle = Bundle.main.bundlePath
        let helperPath = "\(bundle)/Contents/Resources/RamSaltManHelper"
        return smc_bridge_install_helper(helperPath)
    }

    public func getAllFans() -> [FanInfo] {
        let count = getFanCount()
        var fans: [FanInfo] = []
        for i in 0..<count {
            var raw = FanData()
            if smc_bridge_get_fan_info(Int32(i), &raw) {
                let name = withUnsafePointer(to: &raw.name.0) { String(cString: $0) }
                fans.append(FanInfo(
                    index: Int(raw.fanIndex),
                    name: name.isEmpty ? "Fan \(i + 1)" : name,
                    currentRPM: Double(raw.currentRPM),
                    minRPM: Double(raw.minRPM),
                    maxRPM: Double(raw.maxRPM),
                    targetRPM: Double(raw.targetRPM),
                    isManual: raw.isManual
                ))
            }
        }
        return fans
    }

    @discardableResult
    public func setFanSpeed(index: Int, targetRPM: Double) -> Bool {
        return smc_bridge_set_fan_speed(Int32(index), Float(targetRPM))
    }

    @discardableResult
    public func setFanAuto(index: Int) -> Bool {
        return smc_bridge_set_fan_auto(Int32(index))
    }

    @discardableResult
    public func resetAllFans() -> Bool {
        return smc_bridge_reset_all_fans()
    }

    public func getThermals() -> ThermalState {
        var raw = ThermalData()
        if smc_bridge_get_thermals(&raw) && raw.hasSensors {
            let state = ThermalState(
                cpuTemp: Double(raw.cpuTemp),
                gpuTemp: Double(raw.gpuTemp),
                socTemp: Double(raw.socTemp),
                batteryTemp: Double(raw.batteryTemp),
                maxTemp: Double(raw.maxTemp),
                hasSensors: true
            )

            // Thermal Safety Override:
            // If system temperature exceeds safety threshold, automatically ramp up fans
            if state.maxTemp >= safetyTempThreshold {
                enforceThermalSafety()
            }

            return state
        }
        return .zero
    }

    private func enforceThermalSafety() {
        let fans = getAllFans()
        for fan in fans {
            if fan.isManual && fan.targetRPM < fan.maxRPM * 0.85 {
                // Safeguard override: push to maximum cooling
                setFanSpeed(index: fan.index, targetRPM: fan.maxRPM)
            }
        }
    }
}
