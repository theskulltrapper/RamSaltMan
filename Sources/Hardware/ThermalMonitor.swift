import Foundation

public final class ThermalMonitor {
    public static let shared = ThermalMonitor()

    private let smc = SMCClient.shared
    private var cachedState: ThermalState = .zero
    private var lastSampleTime: TimeInterval = 0

    private init() {}

    public func sample(forceLive: Bool = false, liveAllowed: Bool = false) -> ThermalState {
        let now = Date().timeIntervalSince1970
        // Throttle to 1.0s to avoid unnecessary polling unless force requested
        if !forceLive && !liveAllowed && cachedState.hasSensors && (now - lastSampleTime < 1.0) {
            return cachedState
        }

        let thermals = smc.getThermals()
        if thermals.hasSensors {
            cachedState = thermals
            lastSampleTime = now
        }
        return cachedState
    }

    public static func formatTemp(_ celsius: Double, useFahrenheit: Bool = false) -> String {
        if celsius <= 0 {
            return "-- °C"
        }
        if useFahrenheit {
            let f = (celsius * 9.0 / 5.0) + 32.0
            return String(format: "%.0f°F", f)
        }
        return String(format: "%.0f°C", celsius)
    }
}
