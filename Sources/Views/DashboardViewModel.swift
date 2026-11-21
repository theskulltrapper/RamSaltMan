import Foundation
import Combine

public final class DashboardViewModel: ObservableObject {
    public static let shared = DashboardViewModel()

    @Published public var selectedTab: MainTab = .dashboard
    @Published public var memorySnapshot: MemorySnapshot = .zero
    @Published public var cpuSnapshot: CPUSnapshot = .zero
    @Published public var thermals: ThermalState = .zero
    @Published public var fans: [FanInfo] = []
    @Published public var fanSliderValues: [Int: Double] = [:]

    public init() {}

    public func refresh() {
        memorySnapshot = MemoryMonitor.shared.sample()
        cpuSnapshot = CPUMonitor.shared.sample()
        fans = SMCClient.shared.getAllFans()

        for f in fans {
            if fanSliderValues[f.index] == nil {
                let minBound = max(1000.0, f.minRPM > 0 ? f.minRPM : 1200.0)
                let maxBound = max(minBound + 500.0, f.maxRPM > 0 ? f.maxRPM : 5000.0)
                let target = f.targetRPM > 0 ? f.targetRPM : minBound
                fanSliderValues[f.index] = min(maxBound, max(minBound, target))
            }
        }

        let isThermalTab = (selectedTab == .dashboard || selectedTab == .fans)
        if isThermalTab || AppSettings.shared.liveThermalMonitoring {
            thermals = ThermalMonitor.shared.sample(forceLive: false, liveAllowed: true)
        }
    }

    public func forceThermalRefresh() {
        thermals = ThermalMonitor.shared.sample(forceLive: true, liveAllowed: true)
    }

    public func setFanSpeed(index: Int, speed: Double) {
        fanSliderValues[index] = speed
        _ = SMCClient.shared.setFanSpeed(index: index, targetRPM: speed)
        refresh()
    }

    public func setFanAuto(index: Int) {
        _ = SMCClient.shared.setFanAuto(index: index)
        refresh()
    }

    public func resetAllFans() {
        _ = SMCClient.shared.resetAllFans()
        refresh()
    }

    public func purgeMemory() {
        MemoryMonitor.shared.purgeMemory()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.refresh()
        }
    }
}
